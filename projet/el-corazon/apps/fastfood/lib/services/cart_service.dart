import 'dart:async';
import 'dart:convert';

import 'package:elcora_fast/presentation/catalogue.dart';
import 'package:elcora_fast/presentation/reprise_de_commande.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/presentation/tarification.dart';
import 'package:elcora_fast/services/offline_sync_service.dart';
import 'package:elcora_fast/services/delivery_fee_service.dart';
// import 'package:elcora_fast/services/wallet_service.dart'; // Portefeuille désactivé temporairement

/// Service de gestion du panier (local + synchronisation Supabase)
class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final List<CartItem> _items = [];

  /// Dernier devis rendu par le serveur — frais de livraison, remise et total.
  ///
  /// Nul tant qu'aucun n'a été demandé, et c'est un état normal : tant qu'une
  /// adresse n'est pas choisie, personne ne sait ce que coûte la course. Le
  /// panier portait auparavant `_deliveryFee = 500.0` par défaut, persisté
  /// entre deux sessions, ce qui affichait un montant inventé puis périmé.
  eccore.OrderQuote? _quote;

  double _promoDiscount = 0.0;
  String? _promoCode;

  SharedPreferences? _prefs;
  bool _isInitialized = false;
  String? _userId;
  bool _isHydrating = false;
  bool _isSyncing = false;

  /// Queue des synchronisations : dernière réécriture du panier serveur mise
  /// en file, chacune enchaînée après la précédente. `ensureSynced` l'attend
  /// avant de laisser chiffrer ou commander.
  Future<void>? _pendingCartSync;

  /// Construit à la **première** écriture distante, et non à la construction du
  /// service.
  ///
  /// `apiClient` lit le conteneur Riverpod monté par `main()` : l'évaluer dans
  /// l'initialiseur de champ faisait échouer toute construction du service hors
  /// de l'application lancée — donc toute vérification du panier autrement
  /// qu'en démarrant l'app. Le panier local, lui, n'a besoin d'aucun réseau :
  /// composer, chiffrer et fusionner des lignes se tiennent sans session.
  late final eccore.CartRepository _cartRepository =
      eccore.CartRepository(apiClient: apiClient);
  final OfflineSyncService _offlineSyncService = OfflineSyncService();
  final DeliveryFeeService _deliveryFeeService = DeliveryFeeService();

  // Getters
  List<CartItem> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  /// Somme des lignes, telle qu'affichée. Le serveur relit les prix au
  /// catalogue à la commande (invariant C1) : ce cumul sert à montrer un
  /// panier, jamais à décider d'un montant.
  ///
  /// Dès qu'un devis existe, c'est **son** sous-total qui est rendu : lui seul
  /// a relu le catalogue. Le cumul local ne sert qu'avant, et il compte
  /// désormais les suppléments d'options que les lignes portent
  /// ([CartItem.supplementOptions]) — sans quoi le sous-total montait d'un
  /// coup, sans explication, à l'arrivée du devis.
  double get subtotal =>
      _quote?.subtotal.toMajorUnits() ??
      sousTotalDuPanier(_items.map((item) => item.totalPrice));

  /// Frais de livraison du dernier devis. Zéro tant qu'aucun devis n'existe —
  /// et [hasQuote] permet à l'écran de dire « calculés à la validation »
  /// plutôt que d'annoncer une livraison gratuite.
  double get deliveryFee => _quote?.deliveryFee.toMajorUnits() ?? 0.0;

  /// Remise retenue par le serveur quand un devis existe ; à défaut, celle que
  /// `PromoCodeService` a fait valider. Les deux viennent du serveur, mais
  /// seule la première tient compte du panier complet.
  double get discount => _quote?.discount.toMajorUnits() ?? _promoDiscount;

  double get total =>
      _quote?.total.toMajorUnits() ??
      (subtotal - _promoDiscount).clamp(0.0, double.infinity);

  /// Vrai quand le serveur a chiffré ce panier — donc quand [total] est le
  /// montant qui sera facturé, et non un cumul d'affichage.
  bool get hasQuote => _quote != null;

  /// Le serveur refuse de commander ce panier (article devenu indisponible,
  /// prix changé). `null` tant qu'aucun devis n'a été demandé.
  bool? get isOrderable => _quote?.isOrderable;

  String? get promoCode => _promoCode;
  bool get isInitialized => _isInitialized;
  String? get userId => _userId;

  String get _cartItemsKey => 'cart_items_${_userId ?? 'guest'}';

  /// Clé de l'ancien montant de livraison mémorisé localement. Elle n'est plus
  /// écrite — seulement effacée : un frais rendu par le serveur pour un panier
  /// et une adresse donnés n'a aucun sens à la session suivante.
  String get _legacyDeliveryFeeKey => 'cart_delivery_fee_${_userId ?? 'guest'}';
  String get _promoDiscountKey => 'cart_promo_discount_${_userId ?? 'guest'}';
  // Legacy key for migration
  String get _discountKey => 'cart_discount_${_userId ?? 'guest'}';
  String get _promoCodeKey => 'cart_promo_code_${_userId ?? 'guest'}';

  /// Initialise le service (chargement local)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadCartFromStorage();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      eccore.Journal.trace('❌ Error initializing CartService: $e');
    }
  }

  /// Ouvre le panier du client connecté — appelé par `AppService` dès que la
  /// session est connue, et seul endroit qui renseigne [_userId], donc seule
  /// condition qui autorise les écritures vers `/carts/`.
  Future<void> initializeForUser(String userId) async {
    await initialize();

    if (_userId == userId) {
      await _loadCartFromDatabase();
      return;
    }

    // Les clés de stockage portent l'identité : passer de « invité » au compte
    // change celle qu'on relit, et la relire seule effaçait sous les yeux du
    // client ce qu'il avait mis dans son panier avant de se connecter. Le
    // transfert n'a lieu qu'au départ d'une visite anonyme — d'un compte à
    // l'autre, le panier du premier ne suit pas le second.
    final bool depuisVisiteAnonyme = _userId == null;
    final String cleVisiteur = _cartItemsKey;
    final List<CartItem> panierVisiteur =
        depuisVisiteAnonyme ? List<CartItem>.from(_items) : const <CartItem>[];

    _userId = userId;
    await _loadCartFromStorage();

    if (panierVisiteur.isNotEmpty) {
      if (_items.isEmpty) {
        _items.addAll(panierVisiteur);
        await _saveCartToStorage();
      }
      await _prefs?.remove(cleVisiteur);
    }

    await _loadCartFromDatabase();
    await _syncDatabaseWithLocal(overwriteRemote: _items.isNotEmpty);
  }

  /// Nettoie le panier lors de la déconnexion
  Future<void> clearForLogout() async {
    if (_userId != null) {
      try {
        await _cartRepository.clear(restaurantSlug: AppConstants.restaurantSlug);
      } catch (e) {
        eccore.Journal.trace('CartService: erreur lors du nettoyage distant - $e');
      }
    }

    await _removeStoredCartKeys();

    _userId = null;
    _items.clear();
    _quote = null;
    _promoDiscount = 0.0;
    _promoCode = null;

    await _loadCartFromStorage(); // recharger le panier "invité"
    notifyListeners();
  }

  /// Ajoute un article au panier avec protection contre les doublons
  ///
  /// [optionIds] porte les options du catalogue retenues sur la ligne. Le
  /// serveur reste seul à les valoriser (invariant C1) et son devis fait foi ;
  /// [optionsSupplement] n'est que le montant **déjà annoncé au client** par la
  /// fiche produit, reporté sur la ligne pour que le panier affiche le même
  /// total que l'écran d'où il vient. Il est nul dès que le serveur a rendu son
  /// `unit_price`, qui intègre les options.
  ///
  /// Deux lignes du même article aux options différentes restent deux lignes —
  /// la même règle que `CartService._identical_line` côté serveur.
  /// Repose au panier les articles d'une commande passée.
  ///
  /// La **décision** — quels articles sont encore à la carte — vit dans
  /// `presentation/reprise_de_commande.dart`, où elle s'éprouve sans panier.
  /// Cette méthode n'en applique que l'effet, et rend ce qui a été écarté pour
  /// que l'écran puisse le dire.
  ({int ajoutes, List<String> indisponibles}) reprendreLaCommande(
    List<LigneAReprendre> lignes,
    List<eccore.MenuItem> catalogue,
  ) {
    final tri = trierLaReprise(lignes, catalogue);
    var ajoutes = 0;

    for (final retenue in tri.retenues) {
      addItem(
        retenue.article,
        quantity: retenue.ligne.quantite,
        customizations: retenue.ligne.options,
      );
      ajoutes += retenue.ligne.quantite;
    }

    return (ajoutes: ajoutes, indisponibles: tri.indisponibles);
  }

  /// Compteur de lignes, pour que deux ajouts rapprochés ne se confondent pas.
  ///
  /// L'identifiant était `'<article>_<millisecondes>'`. Deux lignes du même
  /// article ajoutées dans la **même milliseconde** — deux appuis rapides, ou
  /// la reprise d'une commande passée, qui les ajoute en boucle — recevaient
  /// donc le même identifiant. `removeItemByCartItemId` en retirait alors deux
  /// pour un, et la modification d'une ligne cherchait sa jumelle en croyant
  /// s'être trouvée elle-même.
  static int _compteurDeLignes = 0;

  static String _nouvelIdentifiantDeLigne(String menuItemId) {
    return '${menuItemId}_${DateTime.now().millisecondsSinceEpoch}'
        '_${_compteurDeLignes++}';
  }

  void addItem(
    eccore.MenuItem menuItem, {
    int quantity = 1,
    Map<String, dynamic>? customizations,
    List<String> optionIds = const [],
    double optionsSupplement = 0.0,
    bool compositionLibre = false,
  }) {
    if (quantity <= 0) {
      eccore.Journal.trace('⚠️ La quantité doit être supérieure à 0');
      return;
    }

    if (quantity > 999) {
      eccore.Journal.trace('⚠️ La quantité maximale est de 999');
      quantity = 999;
    }

    final normalizedCustomizations = _normalizeCustomizations(customizations);
    final normalizedOptionIds = List<String>.from(optionIds)..sort();

    final existingIndex = _items.indexWhere(
      (item) =>
          item.menuItemId == menuItem.id &&
          _mapsEqual(item.customizations, normalizedCustomizations) &&
          _listsEqual(item.selectedOptionIds, normalizedOptionIds),
    );

    if (existingIndex >= 0) {
      final existingItem = _items[existingIndex];
      final currentQuantity = existingItem.quantity;
      final newQuantity = (currentQuantity + quantity).clamp(1, 999);

      _items[existingIndex] = existingItem.copyWith(quantity: newQuantity);
      eccore.Journal.trace(
        '✅ Quantité mise à jour: ${menuItem.name} ($currentQuantity → $newQuantity)',
      );
    } else {
      final newItem = CartItem(
        id: _nouvelIdentifiantDeLigne(menuItem.id),
        menuItemId: menuItem.id,
        name: menuItem.name,
        price: menuItem.prixAffiche,
        quantity: quantity,
        imageUrl: menuItem.image,
        customizations: normalizedCustomizations,
        selectedOptionIds: normalizedOptionIds,
        supplementOptions: optionsSupplement,
        compositionLibre: compositionLibre,
      );

      _items.add(newItem);
      eccore.Journal.trace('✅ Article ajouté: ${menuItem.name} (quantité: $quantity)');
    }

    notifyListeners();
    _persistChanges();
  }

  /// Met à jour la quantité d'un article par son index
  void updateItemQuantity(int index, int newQuantity) {
    if (index < 0 || index >= _items.length) {
      eccore.Journal.trace('⚠️ Index invalide: $index');
      return;
    }

    if (newQuantity <= 0) {
      final itemName = _items[index].name;
      _items.removeAt(index);
      eccore.Journal.trace('✅ Article retiré: $itemName');
    } else if (newQuantity <= 999) {
      _items[index] = _items[index].copyWith(quantity: newQuantity);
      eccore.Journal.trace(
        '✅ Quantité mise à jour: ${_items[index].name} → $newQuantity',
      );
    } else {
      eccore.Journal.trace('⚠️ Quantité maximale de 999 atteinte');
      return;
    }

    notifyListeners();
    _persistChanges();
  }

  /// Retire un article par son index
  void removeItem(int index) {
    if (index < 0 || index >= _items.length) {
      eccore.Journal.trace('⚠️ Index invalide pour removeItem: $index');
      return;
    }

    final itemName = _items[index].name;
    _items.removeAt(index);
    eccore.Journal.trace('✅ Article retiré: $itemName');
    notifyListeners();
    _persistChanges();
  }

  /// Retire un article par son ID unique dans le panier
  void removeItemByCartItemId(String cartItemId) {
    final initialLength = _items.length;
    _items.removeWhere((item) => item.id == cartItemId);

    if (_items.length < initialLength) {
      eccore.Journal.trace('✅ Article retiré par ID: $cartItemId');
      notifyListeners();
      _persistChanges();
    } else {
      eccore.Journal.trace('⚠️ Aucun article trouvé avec l\'ID: $cartItemId');
    }
  }

  /// Retire tous les articles avec le même menuItemId
  void removeItemById(String menuItemId) {
    final initialLength = _items.length;
    _items.removeWhere((item) => item.menuItemId == menuItemId);

    if (_items.length < initialLength) {
      eccore.Journal.trace('✅ Articles retirés pour menuItemId: $menuItemId');
      notifyListeners();
      _persistChanges();
    }
  }

  /// Rejoue la personnalisation d'une ligne déjà au panier.
  ///
  /// La méthode n'écrivait que [CartItem.customizations] — les **libellés
  /// d'affichage** — en laissant [CartItem.selectedOptionIds] et
  /// [CartItem.supplementOptions] intacts. Une ligne modifiée annonçait donc
  /// « XL, Bacon » tout en emportant au serveur les identifiants de l'ancien
  /// choix, et en affichant l'ancien supplément : les trois faces d'une même
  /// ligne racontaient trois choses différentes. Elle n'avait aucun appelant,
  /// ce qui est la seule raison pour laquelle cela ne s'était jamais vu.
  ///
  /// Les trois partent donc ensemble, avec la quantité — c'est ce que le
  /// configurateur rend quand on le rouvre depuis le panier.
  ///
  /// Si la ligne modifiée devient identique à une autre — même article, mêmes
  /// options, mêmes libellés — les deux fusionnent, comme le font [addItem] ici
  /// et `CartService.update_line` côté serveur. Laisser deux lignes que plus
  /// rien ne distingue obligerait le client à comprendre pourquoi son panier
  /// affiche deux fois la même chose.
  void updateItemCustomizations(
    int index, {
    Map<String, dynamic>? customizations,
    List<String>? optionIds,
    double? optionsSupplement,
    int? quantity,
  }) {
    if (index < 0 || index >= _items.length) {
      eccore.Journal.trace('⚠️ Index invalide pour updateItemCustomizations: $index');
      return;
    }

    final ancienne = _items[index];
    final normalizedCustomizations = customizations == null
        ? ancienne.customizations
        : _normalizeCustomizations(customizations);
    final normalizedOptionIds = optionIds == null
        ? ancienne.selectedOptionIds
        : (List<String>.from(optionIds)..sort());
    final nouvelleQuantite = (quantity ?? ancienne.quantity).clamp(1, 999);

    final modifiee = ancienne.copyWith(
      customizations: normalizedCustomizations,
      selectedOptionIds: normalizedOptionIds,
      supplementOptions: optionsSupplement ?? ancienne.supplementOptions,
      quantity: nouvelleQuantite,
    );

    // La ligne réécrite est écartée **par sa position** et non par son
    // identifiant : c'est la position que l'appelant a donnée, et elle reste
    // juste quand bien même deux lignes porteraient le même identifiant.
    var jumelle = -1;
    for (var i = 0; i < _items.length; i++) {
      if (i == index) continue;
      final item = _items[i];
      if (item.menuItemId == modifiee.menuItemId &&
          _mapsEqual(item.customizations, modifiee.customizations) &&
          _listsEqual(item.selectedOptionIds, modifiee.selectedOptionIds)) {
        jumelle = i;
        break;
      }
    }

    if (jumelle >= 0) {
      final fusionnee = _items[jumelle];
      _items[jumelle] = fusionnee.copyWith(
        quantity: (fusionnee.quantity + modifiee.quantity).clamp(1, 999),
      );
      _items.removeAt(index);
      eccore.Journal.trace(
        '✅ Ligne modifiée fusionnée avec une ligne identique : ${modifiee.name}',
      );
    } else {
      _items[index] = modifiee;
      eccore.Journal.trace('✅ Personnalisation mise à jour : ${modifiee.name}');
    }

    notifyListeners();
    _persistChanges();
  }

  /// Position d'une ligne par son identifiant de panier, −1 si elle n'y est
  /// plus.
  ///
  /// L'écran de personnalisation est ouvert par-dessus le panier : entre son
  /// ouverture et son enregistrement, une synchronisation serveur a pu
  /// réordonner les lignes. Enregistrer sur l'index relevé à l'ouverture
  /// écrirait alors sur la ligne du voisin.
  int indexOfCartItem(String cartItemId) {
    return _items.indexWhere((item) => item.id == cartItemId);
  }

  /// Vide complètement le panier
  void clear() {
    final itemCount = _items.length;
    _items.clear();
    _promoDiscount = 0.0;
    _promoCode = null;
    eccore.Journal.trace('✅ Panier vidé ($itemCount articles)');
    notifyListeners();
    _persistChanges();
  }

  /// Incrémente la quantité d'un article par son menuItemId
  void incrementItemQuantity(String menuItemId) {
    final index = _items.indexWhere((item) => item.menuItemId == menuItemId);
    if (index < 0) {
      eccore.Journal.trace('⚠️ Article non trouvé pour increment: $menuItemId');
      return;
    }

    final currentQuantity = _items[index].quantity;
    if (currentQuantity < 999) {
      _items[index] = _items[index].copyWith(quantity: currentQuantity + 1);
      eccore.Journal.trace(
        '✅ Quantité incrémentée: ${_items[index].name} ($currentQuantity → ${currentQuantity + 1})',
      );
      notifyListeners();
      _persistChanges();
    } else {
      eccore.Journal.trace(
        '⚠️ Quantité maximale de 999 atteinte pour ${_items[index].name}',
      );
    }
  }

  /// Décrémente la quantité d'un article par son menuItemId
  void decrementItemQuantity(String menuItemId) {
    final index = _items.indexWhere((item) => item.menuItemId == menuItemId);
    if (index < 0) {
      eccore.Journal.trace('⚠️ Article non trouvé pour decrement: $menuItemId');
      return;
    }

    final currentQuantity = _items[index].quantity;
    final itemName = _items[index].name;

    if (currentQuantity > 1) {
      _items[index] = _items[index].copyWith(quantity: currentQuantity - 1);
      eccore.Journal.trace(
        '✅ Quantité décrémentée: $itemName ($currentQuantity → ${currentQuantity - 1})',
      );
    } else {
      _items.removeAt(index);
      eccore.Journal.trace('✅ Article retiré (quantité = 0): $itemName');
    }

    notifyListeners();
    _persistChanges();
  }

  /// Obtient la quantité d'un article par son menuItemId
  int getItemQuantity(String menuItemId) {
    final item = _items.firstWhere(
      (item) => item.menuItemId == menuItemId,
      orElse: () => CartItem(
        id: '',
        menuItemId: '',
        name: '',
        price: 0,
        quantity: 0,
      ),
    );
    return item.quantity;
  }

  /// Vérifie si un article est dans le panier
  bool hasItem(String menuItemId) {
    return _items.any((item) => item.menuItemId == menuItemId);
  }

  /// Demande au serveur le chiffrage du panier pour une adresse donnée.
  ///
  /// Remplace le calcul local des frais, qui appliquait un barème écrit dans
  /// l'application (500 F + 200 F/km, plafonné à 5 000) sans rapport avec
  /// celui de la zone qui dessert réellement l'adresse. Le panier n'est pas
  /// transmis : le serveur le relit et le chiffre lui-même.
  ///
  /// L'échec **n'invente pas de montant de repli** — il propage. Un « 1 000 F
  /// par défaut » affiché à la place d'une erreur réseau est un prix que
  /// personne ne facturera.
  Future<eccore.OrderQuote> refreshQuote({eccore.Address? address}) async {
    // La commande est créée depuis le panier serveur : sans cette attente, le
    // devis chiffrerait l'état d'avant le dernier ajout.
    await ensureSynced();

    final quote = await _deliveryFeeService.quoteOrder(
      addressId: address?.id,
      promoCode: _promoCode ?? '',
    );

    _quote = quote;
    notifyListeners();
    return quote;
  }

  /// Oublie le devis — après un ajout au panier, un retrait, ou un changement
  /// d'adresse. L'écran cesse alors d'afficher un total qui ne correspond plus
  /// à ce qu'il montre, jusqu'au prochain [refreshQuote].
  void invalidateQuote() {
    if (_quote == null) return;
    _quote = null;
    notifyListeners();
  }

  /// Applique directement une remise validée (après sélection d'un code promo)
  /// Cette méthode est utilisée après validation via PromoCodeService
  void applyPromoDiscount({required String code, required double discount}) {
    if (discount < 0) {
      eccore.Journal.trace('⚠️ La remise ne peut pas être négative');
      return;
    }
    _promoCode = code;
    _promoDiscount = discount;
    eccore.Journal.trace(
      '✅ Remise appliquée: $_promoCode (-${discount.toStringAsFixed(2)} FCFA)',
    );
    notifyListeners();
    _persistChanges();
  }

  /// Soumet un code promotionnel au serveur et l'applique s'il est retenu.
  ///
  /// Rend `null` en cas de succès, sinon le message à montrer au client.
  ///
  /// ## Ce qu'elle remplace
  ///
  /// `validatePromoCode`, dépréciée, qui traçait un avertissement et rendait
  /// `false` sans rien tenter : tout code passé par là était refusé, quel
  /// qu'il soit. Les écrans qui savaient l'éviter réécrivaient chacun les
  /// vingt lignes ci-dessous — `PromoCodesScreen` les avait, le panier ne les
  /// avait pas.
  ///
  /// ## Pourquoi c'est le serveur qui tranche
  ///
  /// La remise dépend du panier, de la zone de livraison et du barème en
  /// vigueur, qu'aucun d'eux n'est connu ici avec certitude. `POST
  /// /orders/preview/` relit le panier **serveur**, applique le code et rend
  /// la remise réelle. Une remise calculée par l'application est une promesse
  /// que la facture peut démentir.
  ///
  /// [addressId] affine le devis quand une adresse est déjà choisie : les
  /// frais de livraison entrent dans le total, et certains codes portent sur
  /// eux. Sans adresse, seule la remise sur le sous-total est exploitée.
  Future<String?> appliquerCodePromo(String code, {String? addressId}) async {
    final normalise = code.trim().toUpperCase();
    if (normalise.isEmpty) return 'Entrez un code promo';

    try {
      final quote = await _deliveryFeeService.quoteOrder(
        addressId: addressId,
        promoCode: normalise,
      );

      // Le serveur rend un code **vide** quand il l'a refusé. Le distinguer
      // d'une remise nulle importe : un code périmé doit se voir, pas se
      // taire.
      if (!quote.hasPromotion) return 'Code promo refusé ou expiré';

      applyPromoDiscount(
        code: quote.promotionCode,
        discount: quote.discount.toMajorUnits(),
      );
      _quote = quote;
      notifyListeners();
      return null;
    } catch (e) {
      eccore.Journal.trace('❌ Code promo « $normalise » : $e');
      return 'Impossible de vérifier le code pour le moment';
    }
  }

  /// Retire le code promo
  void removePromoCode() {
    _promoCode = null;
    _promoDiscount = 0.0;

    notifyListeners();
    _persistChanges();
  }

  /// Convertit le panier en données de commande
  Map<String, dynamic> toOrderData() {
    return {
      'items': _items
          .map(
            (item) => {
              'menu_item_id': item.menuItemId,
              'name': item.name,
              'price': item.price,
              'quantity': item.quantity,
              'customizations': item.customizations,
            },
          )
          .toList(),
      'subtotal': subtotal,
      'delivery_fee': deliveryFee,
      'discount': discount,
      'promo_code': _promoCode,
      'total': total,
    };
  }

  /// Sauvegarde le panier (exposed for compatibilité)
  Future<void> saveToStorage() async => _saveCartToStorage();

  /// Attend que le panier serveur reflète l'état local — `_persistChanges`
  /// déclenche la synchronisation sans l'attendre (`unawaited`), ce qui
  /// convient pour un ajout/retrait isolé mais pas avant de chiffrer ou de
  /// créer une commande : `OrderService.preview` et `create_from_cart`
  /// (backend) lisent le panier serveur tel quel au moment de l'appel.
  ///
  /// Attendre la dernière synchronisation de la file suffit : elle démarre
  /// après toutes les précédentes, et reproduit l'état du panier au moment où
  /// elle s'exécute.
  Future<void> ensureSynced() async {
    if (_userId == null) return;
    await (_pendingCartSync ?? _syncCartToDatabase());
  }

  /// Charge le panier depuis le stockage local
  Future<void> loadFromStorage() async => _loadCartFromStorage();

  // === Méthodes privées ===

  Future<void> _loadCartFromStorage() async {
    try {
      final cartData = _prefs?.getString(_cartItemsKey);

      if (cartData != null) {
        final List<dynamic> itemsData = json.decode(cartData);
        _items
          ..clear()
          ..addAll(
            itemsData
                .map((item) => CartItem.fromMap(item as Map<String, dynamic>))
                .toList(),
          );
        eccore.Journal.trace(
          '✅ Cart chargé depuis le stockage local: ${_items.length} articles',
        );
      } else {
        _items.clear();
      }

      // Les frais de livraison ne sont plus relus du stockage : ils dépendent
      // de l'adresse et du panier du moment, et un montant vieux d'une session
      // ne serait juste que par accident. La clé résiduelle est effacée.
      await _prefs?.remove(_legacyDeliveryFeeKey);

      // Migration from single discount to split discount
      if (_prefs?.containsKey(_discountKey) == true) {
        final legacyDiscount = _prefs!.getDouble(_discountKey) ?? 0.0;
        // If we have a legacy discount, we assume it's promo if not free meal, or mixed?
        // Safest is to put it in promo for now if not free meal.
        _promoDiscount = legacyDiscount;
        // Clean up legacy key later or now? Let's leave it for safety or remove it.
        // removing it in _removeStoredCartKeys is enough.
      } else {
        _promoDiscount = _prefs?.getDouble(_promoDiscountKey) ?? 0.0;
      }

      _promoCode = _prefs?.getString(_promoCodeKey);
    } catch (e) {
      eccore.Journal.trace('❌ Erreur lors du chargement du panier local: $e');
    }
  }

  Future<void> _saveCartToStorage() async {
    try {
      if (_prefs == null) return;

      final itemsData = _items.map((item) => item.toMap()).toList();
      await _prefs!.setString(_cartItemsKey, json.encode(itemsData));
      await _prefs!.setDouble(_promoDiscountKey, _promoDiscount);

      // Remove legacy discount key
      await _prefs!.remove(_discountKey);

      if (_promoCode != null && _promoCode!.isNotEmpty) {
        await _prefs!.setString(_promoCodeKey, _promoCode!);
      } else {
        await _prefs!.remove(_promoCodeKey);
      }

      eccore.Journal.trace('✅ Panier sauvegardé localement (${_items.length} articles)');
    } catch (e) {
      eccore.Journal.trace('❌ Erreur lors de la sauvegarde du panier local: $e');
    }
  }

  Future<void> _removeStoredCartKeys() async {
    if (_prefs == null) return;
    await _prefs!.remove(_cartItemsKey);
    await _prefs!.remove(_legacyDeliveryFeeKey);
    await _prefs!.remove(_promoDiscountKey);
    await _prefs!.remove(_discountKey); // Legacy
    await _prefs!.remove(_promoCodeKey);
  }

  /// Traduit une ligne de panier Django vers le modèle local.
  ///
  /// Tout vient du serveur : le nom, le prix unitaire — options comprises,
  /// puisque `unit_price` les intègre déjà (invariant C1) — et les options
  /// elles-mêmes, regroupées par leur groupe d'origine pour l'affichage. Le
  /// texte libre de `notes` reste à part : c'est ce que le client a écrit, pas
  /// ce qu'il a choisi.
  CartItem _fromRemoteLine(eccore.CartLine line) {
    final customizations = <String, dynamic>{};
    for (final option in line.options) {
      final category = option.groupName.isEmpty ? 'Options' : option.groupName;
      final existing = customizations[category] as String?;
      customizations[category] =
          existing == null ? option.name : '$existing, ${option.name}';
    }
    if (line.notes.isNotEmpty) {
      customizations['note'] = line.notes;
    }

    return CartItem(
      id: line.id,
      menuItemId: line.menuItemId,
      name: line.name,
      price: line.unitPrice.toMajorUnits(),
      quantity: line.quantity,
      imageUrl: line.image,
      customizations: customizations,
      selectedOptionIds: line.options.map((option) => option.id).toList()..sort(),
      // `supplementOptions` reste à zéro, et c'est le point : `unit_price`
      // intègre déjà les options. Y reporter le supplément estimé par la fiche
      // produit les compterait deux fois — 5 000 + 500 deviendrait 6 000 au
      // retour de synchronisation.
    );
  }

  Future<void> _loadCartFromDatabase() async {
    if (_userId == null) return;

    _isHydrating = true;
    try {
      final remoteCart = await _cartRepository.getCart(
        restaurantSlug: AppConstants.restaurantSlug,
      );

      if (remoteCart.lines.isEmpty) {
        return;
      }

      _items
        ..clear()
        ..addAll(remoteCart.lines.map(_fromRemoteLine));

      // Frais de livraison, code promo et remises n'existent pas dans le
      // panier Django (hors scope de cette tranche) — conservés tels quels.

      eccore.Journal.trace(
        '✅ Panier synchronisé depuis le backend (${_items.length} articles)',
      );

      await _saveCartToStorage();
      notifyListeners();
    } catch (e) {
      // Si erreur de connexion, on garde le panier local
      if (!_offlineSyncService.isOnline) {
        eccore.Journal.trace('📴 Mode hors ligne: utilisation du panier local');
      } else {
        eccore.Journal.trace('CartService: erreur lors du chargement distant - $e');
      }
    } finally {
      _isHydrating = false;
    }
  }

  /// Réécrit intégralement le panier serveur depuis l'état local — même
  /// stratégie que l'ancien `DatabaseService.upsertUserCart` (delete puis
  /// insert), nécessaire ici en l'absence de correspondance stable entre
  /// `CartItem.id` local et l'identifiant de ligne Django.
  ///
  /// Une ligne que le serveur refuse (article retiré du menu, option qui
  /// n'existe plus, identifiant forgé hors catalogue) **n'interrompt plus la
  /// boucle**. Elle le faisait, après le `clear` : un seul article devenu
  /// invalide vidait le panier distant et emportait tous les suivants. Les
  /// refus sont signalés ; seule une panne de réseau propage, pour que
  /// [_pousserPanier] bascule sur la file hors ligne.
  Future<void> _replaceRemoteCart() async {
    // L'état à reproduire est figé avant le premier appel : un ajout d'article
    // pendant que la synchronisation est en vol modifierait `_items` en cours
    // d'itération, ce que Dart refuse. L'exception coupait la reprise au
    // milieu, laissant le panier serveur amputé des lignes suivantes — et
    // vide, si elle survenait juste après le `clear`.
    final lignes = List<CartItem>.from(_items);

    await _cartRepository.clear(restaurantSlug: AppConstants.restaurantSlug);

    final refused = <String>[];
    for (final item in lignes) {
      try {
        await _cartRepository.addLine(
          restaurantSlug: AppConstants.restaurantSlug,
          menuItemId: item.menuItemId,
          quantity: item.quantity,
          optionIds: item.selectedOptionIds,
          notes: item.remoteNotes,
        );
      } on eccore.ApiException catch (error) {
        // `status == 0` est une panne réseau (`ApiException.network`), 5xx une
        // panne serveur : dans les deux cas la ligne est encore valide et doit
        // repartir plus tard. Seul un refus 4xx est définitif.
        if (error.status < 400 || error.status >= 500) rethrow;
        refused.add('${item.name} (${error.code})');
      }
    }

    if (refused.isNotEmpty) {
      eccore.Journal.trace(
        '⚠️ Lignes refusées par le serveur, non synchronisées : ${refused.join(' ; ')}',
      );
    }
  }

  /// Met une réécriture du panier serveur **à la suite** de celle déjà en vol.
  ///
  /// L'appel concurrent était auparavant abandonné (`_isSyncing` déjà vrai) :
  /// la modification qui l'avait déclenché ne partait jamais, et `ensureSynced`
  /// se retrouvait à attendre un futur déjà terminé — donc rendait la main
  /// pendant que le panier serveur était encore à l'état précédent, voire vide,
  /// [_replaceRemoteCart] commençant par le purger. Mis en file, le dernier
  /// appel décrit l'état courant, et c'est celui-là que `ensureSynced` attend.
  Future<void> _syncCartToDatabase() {
    if (_userId == null || _isHydrating) return Future<void>.value();

    final suivante =
        (_pendingCartSync ?? Future<void>.value()).then((_) => _pousserPanier());
    _pendingCartSync = suivante;
    return suivante;
  }

  /// Une réécriture, qui ne relance jamais : la file ne doit pas se rompre sur
  /// l'échec d'un maillon.
  Future<void> _pousserPanier() async {
    try {
      await _replaceRemoteCart();
    } catch (e) {
      // Si erreur de connexion, sauvegarder hors ligne
      if (!_offlineSyncService.isOnline) {
        eccore.Journal.trace('📴 Mode hors ligne: sauvegarde du panier localement');
        await _offlineSyncService.saveCartUpdateOffline(
          _userId!,
          List<CartItem>.from(_items),
          deliveryFee,
          discount,
          _promoCode,
        );
      } else {
        eccore.Journal.trace(
          'CartService: erreur lors de la synchronisation distante - $e',
        );
      }
    }
  }

  void _persistChanges() {
    // Le panier vient de changer : le devis qui le chiffrait ne le décrit
    // plus. Le garder afficherait l'ancien total sous la nouvelle liste.
    _quote = null;

    if (_prefs != null) {
      unawaited(_saveCartToStorage());
    }
    // La synchronisation n'est pas attendue ici — l'écran ne doit pas attendre
    // le réseau pour montrer l'article ajouté. `_syncCartToDatabase` la place
    // dans la file, et `ensureSynced` attend cette file avant de commander.
    unawaited(_syncCartToDatabase());
  }

  /// Réconcilie panier local et panier serveur au premier chargement d'une
  /// session (`initializeForUser`). Le code promotionnel reste local jusqu'à
  /// la commande ; les frais et le total, eux, viennent du devis serveur
  /// (`refreshQuote`) et non de cet état.
  Future<void> _syncDatabaseWithLocal({bool overwriteRemote = false}) async {
    if (_userId == null) return;
    if (_isSyncing) return;

    try {
      _isSyncing = true;
      final remoteCart = await _cartRepository.getCart(
        restaurantSlug: AppConstants.restaurantSlug,
      );
      final remoteItems = remoteCart.lines.map(_fromRemoteLine).toList();

      final bool shouldOverwriteRemote = overwriteRemote || remoteItems.isEmpty;

      // Les réécritures passent toutes par la même file : deux `clear` puis
      // deux séries d'ajouts entrelacés livreraient un panier serveur en
      // double, chaque ligne comptée deux fois.
      if (shouldOverwriteRemote) {
        await _syncCartToDatabase();
      } else if (_items.isEmpty) {
        _items
          ..clear()
          ..addAll(remoteItems);
        notifyListeners();
        await _saveCartToStorage();
      } else {
        final merged = _mergeCartItems(_items, remoteItems);
        _items
          ..clear()
          ..addAll(merged);
        notifyListeners();
        await _saveCartToStorage();

        await _syncCartToDatabase();
      }
    } catch (e) {
      eccore.Journal.trace(
          'CartService: erreur lors de la synchronisation initiale - $e',);
    } finally {
      _isSyncing = false;
    }
  }

  List<CartItem> _mergeCartItems(
    List<CartItem> localItems,
    List<CartItem> remoteItems,
  ) {
    final merged = <CartItem>[];
    final seen = <String, CartItem>{};

    for (final item in remoteItems) {
      final key = _mergeKey(item);
      seen[key] = item;
      merged.add(item);
    }

    for (final item in localItems) {
      final key = _mergeKey(item);
      if (seen.containsKey(key)) {
        final existing = seen[key]!;
        final combinedQuantity =
            (existing.quantity + item.quantity).clamp(1, 999);
        final updated = existing.copyWith(quantity: combinedQuantity);
        final index = merged.indexOf(existing);
        merged[index] = updated;
        seen[key] = updated;
      } else {
        merged.add(item);
        seen[key] = item;
      }
    }

    return merged;
  }

  /// Ce qui fait que deux lignes n'en sont qu'une : même article, mêmes
  /// options, mêmes personnalisations libres. Exactement le critère de
  /// `CartService._identical_line` côté serveur — s'en écarter ferait
  /// réapparaître une ligne fusionnée ici à chaque relecture distante.
  String _mergeKey(CartItem item) {
    final options = List<String>.from(item.selectedOptionIds)..sort();
    final customizations = jsonEncode(
      _normalizeCustomizations(item.customizations),
    );
    return '${item.menuItemId}_${options.join(',')}_$customizations';
  }

  bool _listsEqual(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    final sortedFirst = List<String>.from(first)..sort();
    final sortedSecond = List<String>.from(second)..sort();
    for (var index = 0; index < sortedFirst.length; index++) {
      if (sortedFirst[index] != sortedSecond[index]) return false;
    }
    return true;
  }

  Map<String, dynamic> _normalizeCustomizations(
    Map<String, dynamic>? customizations,
  ) {
    if (customizations == null || customizations.isEmpty) return {};

    final normalized = <String, dynamic>{};
    final sortedKeys = customizations.keys.toList()..sort();

    for (final key in sortedKeys) {
      final value = customizations[key];
      if (value is List) {
        normalized[key] = List.from(value)..sort();
      } else {
        normalized[key] = value;
      }
    }

    return normalized;
  }

  bool _mapsEqual(Map<String, dynamic>? map1, Map<String, dynamic>? map2) {
    if (map1 == null && map2 == null) return true;
    if (map1 == null || map2 == null) return false;
    if (map1.length != map2.length) return false;

    final normalized1 = _normalizeCustomizations(map1);
    final normalized2 = _normalizeCustomizations(map2);

    for (final key in normalized1.keys) {
      if (!normalized2.containsKey(key)) return false;

      final value1 = normalized1[key];
      final value2 = normalized2[key];

      if (value1 is List && value2 is List) {
        if (value1.length != value2.length) return false;
        final sorted1 = List.from(value1)..sort();
        final sorted2 = List.from(value2)..sort();
        for (int i = 0; i < sorted1.length; i++) {
          if (sorted1[i] != sorted2[i]) return false;
        }
      } else if (value1 != value2) {
        return false;
      }
    }

    return true;
  }

  // === Méthodes de compatibilité ===
  int getTotalItems() => itemCount;
  double getTotalPrice() => total;
}
