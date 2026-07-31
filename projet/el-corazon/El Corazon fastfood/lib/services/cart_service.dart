import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/models/address.dart';
import 'package:elcora_fast/services/offline_sync_service.dart';
import 'package:elcora_fast/services/delivery_fee_service.dart';
// import 'package:elcora_fast/services/wallet_service.dart'; // Portefeuille désactivé temporairement

/// Service de gestion du panier (local + synchronisation Supabase)
class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final List<CartItem> _items = [];
  double _deliveryFee = 500.0;
  double _promoDiscount = 0.0;
  String? _promoCode;

  SharedPreferences? _prefs;
  bool _isInitialized = false;
  String? _userId;
  bool _isHydrating = false;
  bool _isSyncing = false;

  /// Future de la dernière synchronisation déclenchée par `_persistChanges`
  /// (non attendue là-bas) — permet à `ensureSynced` d'attendre celle déjà en
  /// cours plutôt que d'en réarmer une seconde qui se contenterait de
  /// ressortir immédiatement (`_isSyncing` déjà vrai).
  Future<void>? _pendingCartSync;

  final eccore.CartRepository _cartRepository = eccore.CartRepository(apiClient: apiClient);
  final OfflineSyncService _offlineSyncService = OfflineSyncService();
  final DeliveryFeeService _deliveryFeeService = DeliveryFeeService();

  // Getters
  List<CartItem> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal => _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get deliveryFee => _deliveryFee;
  double get discount => _promoDiscount;
  double get total =>
      (subtotal + _deliveryFee - discount).clamp(0.0, double.infinity);
  String? get promoCode => _promoCode;
  bool get isInitialized => _isInitialized;
  String? get userId => _userId;

  String get _cartItemsKey => 'cart_items_${_userId ?? 'guest'}';
  String get _deliveryFeeKey => 'cart_delivery_fee_${_userId ?? 'guest'}';
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
      debugPrint('❌ Error initializing CartService: $e');
    }
  }

  /// Initialise le panier pour un utilisateur connecté (sync Supabase)
  Future<void> initializeForUser(String userId) async {
    await initialize();

    if (_userId == userId) {
      await _loadCartFromDatabase();
      return;
    }

    _userId = userId;
    await _loadCartFromStorage();
    await _loadCartFromDatabase();
    await _syncDatabaseWithLocal(overwriteRemote: _items.isNotEmpty);
  }

  /// Nettoie le panier lors de la déconnexion
  Future<void> clearForLogout() async {
    if (_userId != null) {
      try {
        await _cartRepository.clear(restaurantSlug: AppConstants.restaurantSlug);
      } catch (e) {
        debugPrint('CartService: erreur lors du nettoyage distant - $e');
      }
    }

    await _removeStoredCartKeys();

    _userId = null;
    _items.clear();
    _deliveryFee = 500.0;
    _promoDiscount = 0.0;
    _promoCode = null;

    await _loadCartFromStorage(); // recharger le panier "invité"
    notifyListeners();
  }

  /// Ajoute un article au panier avec protection contre les doublons
  void addItem(
    MenuItem menuItem, {
    int quantity = 1,
    Map<String, dynamic>? customizations,
  }) {
    if (quantity <= 0) {
      debugPrint('⚠️ La quantité doit être supérieure à 0');
      return;
    }

    if (quantity > 999) {
      debugPrint('⚠️ La quantité maximale est de 999');
      quantity = 999;
    }

    final normalizedCustomizations = _normalizeCustomizations(customizations);

    final existingIndex = _items.indexWhere(
      (item) =>
          item.menuItemId == menuItem.id &&
          _mapsEqual(item.customizations, normalizedCustomizations),
    );

    if (existingIndex >= 0) {
      final existingItem = _items[existingIndex];
      final currentQuantity = existingItem.quantity;
      final newQuantity = (currentQuantity + quantity).clamp(1, 999);

      _items[existingIndex] = existingItem.copyWith(quantity: newQuantity);
      debugPrint(
        '✅ Quantité mise à jour: ${menuItem.name} ($currentQuantity → $newQuantity)',
      );
    } else {
      final newItem = CartItem(
        id: '${menuItem.id}_${DateTime.now().millisecondsSinceEpoch}',
        menuItemId: menuItem.id,
        name: menuItem.name,
        price: menuItem.price,
        quantity: quantity,
        imageUrl: menuItem.imageUrl,
        customizations: normalizedCustomizations,
      );

      _items.add(newItem);
      debugPrint('✅ Article ajouté: ${menuItem.name} (quantité: $quantity)');
    }

    notifyListeners();
    _persistChanges();
  }

  /// Met à jour la quantité d'un article par son index
  void updateItemQuantity(int index, int newQuantity) {
    if (index < 0 || index >= _items.length) {
      debugPrint('⚠️ Index invalide: $index');
      return;
    }

    if (newQuantity <= 0) {
      final itemName = _items[index].name;
      _items.removeAt(index);
      debugPrint('✅ Article retiré: $itemName');
    } else if (newQuantity <= 999) {
      _items[index] = _items[index].copyWith(quantity: newQuantity);
      debugPrint(
        '✅ Quantité mise à jour: ${_items[index].name} → $newQuantity',
      );
    } else {
      debugPrint('⚠️ Quantité maximale de 999 atteinte');
      return;
    }

    notifyListeners();
    _persistChanges();
  }

  /// Retire un article par son index
  void removeItem(int index) {
    if (index < 0 || index >= _items.length) {
      debugPrint('⚠️ Index invalide pour removeItem: $index');
      return;
    }

    final itemName = _items[index].name;
    _items.removeAt(index);
    debugPrint('✅ Article retiré: $itemName');
    notifyListeners();
    _persistChanges();
  }

  /// Retire un article par son ID unique dans le panier
  void removeItemByCartItemId(String cartItemId) {
    final initialLength = _items.length;
    _items.removeWhere((item) => item.id == cartItemId);

    if (_items.length < initialLength) {
      debugPrint('✅ Article retiré par ID: $cartItemId');
      notifyListeners();
      _persistChanges();
    } else {
      debugPrint('⚠️ Aucun article trouvé avec l\'ID: $cartItemId');
    }
  }

  /// Retire tous les articles avec le même menuItemId
  void removeItemById(String menuItemId) {
    final initialLength = _items.length;
    _items.removeWhere((item) => item.menuItemId == menuItemId);

    if (_items.length < initialLength) {
      debugPrint('✅ Articles retirés pour menuItemId: $menuItemId');
      notifyListeners();
      _persistChanges();
    }
  }

  /// Met à jour les customizations d'un article
  void updateItemCustomizations(
    int index,
    Map<String, dynamic>? customizations,
  ) {
    if (index < 0 || index >= _items.length) {
      debugPrint('⚠️ Index invalide pour updateItemCustomizations: $index');
      return;
    }

    final normalizedCustomizations = _normalizeCustomizations(customizations);
    _items[index] =
        _items[index].copyWith(customizations: normalizedCustomizations);
    debugPrint('✅ Customizations mises à jour pour: ${_items[index].name}');
    notifyListeners();
    _persistChanges();
  }

  /// Vide complètement le panier
  void clear() {
    final itemCount = _items.length;
    _items.clear();
    _promoDiscount = 0.0;
    _promoCode = null;
    debugPrint('✅ Panier vidé ($itemCount articles)');
    notifyListeners();
    _persistChanges();
  }

  /// Incrémente la quantité d'un article par son menuItemId
  void incrementItemQuantity(String menuItemId) {
    final index = _items.indexWhere((item) => item.menuItemId == menuItemId);
    if (index < 0) {
      debugPrint('⚠️ Article non trouvé pour increment: $menuItemId');
      return;
    }

    final currentQuantity = _items[index].quantity;
    if (currentQuantity < 999) {
      _items[index] = _items[index].copyWith(quantity: currentQuantity + 1);
      debugPrint(
        '✅ Quantité incrémentée: ${_items[index].name} ($currentQuantity → ${currentQuantity + 1})',
      );
      notifyListeners();
      _persistChanges();
    } else {
      debugPrint(
        '⚠️ Quantité maximale de 999 atteinte pour ${_items[index].name}',
      );
    }
  }

  /// Décrémente la quantité d'un article par son menuItemId
  void decrementItemQuantity(String menuItemId) {
    final index = _items.indexWhere((item) => item.menuItemId == menuItemId);
    if (index < 0) {
      debugPrint('⚠️ Article non trouvé pour decrement: $menuItemId');
      return;
    }

    final currentQuantity = _items[index].quantity;
    final itemName = _items[index].name;

    if (currentQuantity > 1) {
      _items[index] = _items[index].copyWith(quantity: currentQuantity - 1);
      debugPrint(
        '✅ Quantité décrémentée: $itemName ($currentQuantity → ${currentQuantity - 1})',
      );
    } else {
      _items.removeAt(index);
      debugPrint('✅ Article retiré (quantité = 0): $itemName');
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

  /// Définit les frais de livraison
  void setDeliveryFee(double fee) {
    if (fee < 0) {
      debugPrint('⚠️ Les frais de livraison ne peuvent pas être négatifs');
      return;
    }
    _deliveryFee = fee;
    notifyListeners();
    _persistChanges();
  }

  /// Calcule et met à jour automatiquement les frais de livraison basés sur la distance
  ///
  /// [deliveryAddress] : Adresse de livraison (texte)
  /// [deliveryLatitude] : Latitude de l'adresse (optionnel)
  /// [deliveryLongitude] : Longitude de l'adresse (optionnel)
  /// [address] : Objet Address (optionnel, prioritaire sur les autres paramètres)
  Future<void> calculateAndSetDeliveryFee({
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    Address? address,
  }) async {
    try {
      // Initialiser le service si nécessaire
      if (!_deliveryFeeService.isInitialized) {
        await _deliveryFeeService.initialize();
      }

      // Le statut VIP n'entre pas dans le calcul : le portefeuille est
      // désactivé, et la remise correspondante n'a donc aucun appelant.

      double fee;

      if (address != null) {
        // Utiliser l'objet Address si fourni
        fee = await _deliveryFeeService.calculateDeliveryFeeFromAddress(
          address: address,
          orderSubtotal: subtotal,
        );
      } else {
        // Utiliser les paramètres fournis
        fee = await _deliveryFeeService.calculateDeliveryFee(
          deliveryAddress: deliveryAddress,
          deliveryLatitude: deliveryLatitude,
          deliveryLongitude: deliveryLongitude,
          orderSubtotal: subtotal,
        );
      }

      setDeliveryFee(fee);
      debugPrint(
          '✅ CartService: Frais de livraison calculés et mis à jour: ${fee.toStringAsFixed(0)} FCFA',);
    } catch (e) {
      debugPrint('❌ CartService: Erreur calcul frais livraison - $e');
      // En cas d'erreur, utiliser le prix par défaut
      setDeliveryFee(1000.0);
    }
  }

  /// Applique directement une remise validée (après sélection d'un code promo)
  /// Cette méthode est utilisée après validation via PromoCodeService
  void applyPromoDiscount({required String code, required double discount}) {
    if (discount < 0) {
      debugPrint('⚠️ La remise ne peut pas être négative');
      return;
    }
    _promoCode = code;
    _promoDiscount = discount;
    debugPrint(
      '✅ Remise appliquée: $_promoCode (-${discount.toStringAsFixed(2)} FCFA)',
    );
    notifyListeners();
    _persistChanges();
  }

  /// Valide et applique un code promo via PromoCodeService
  ///
  /// ⚠️ DÉPRÉCIÉ: Cette méthode est dépréciée car elle ne peut pas accéder au Provider.
  /// Utilisez `PromoCodeService.validateAndApplyPromoCode` directement via Provider dans les écrans.
  ///
  /// Pour appliquer un code promo, utilisez:
  /// ```dart
  /// final promoCodeService = Provider.of<PromoCodeService>(context, listen: false);
  /// final result = await promoCodeService.validateAndApplyPromoCode(...);
  /// if (result.isValid) {
  ///   cartService.applyPromoDiscount(code: result.promoCode!.code, discount: result.discountAmount);
  /// }
  /// ```
  @Deprecated(
      'Utilisez PromoCodeService.validateAndApplyPromoCode directement avec Provider',)
  Future<bool> validatePromoCode(
    String code,
    double orderAmount,
    List<String> categoryNames,
  ) async {
    debugPrint(
        '⚠️ validatePromoCode est déprécié. Utilisez PromoCodeService directement via Provider.',);
    return false;
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
      'delivery_fee': _deliveryFee,
      'discount': discount,
      'promo_code': _promoCode,
      'total': total,
    };
  }

  /// Sauvegarde le panier (exposed for compatibilité)
  Future<void> saveToStorage() async => _saveCartToStorage();

  /// Attend que le panier serveur reflète l'état local — `_persistChanges`
  /// déclenche la synchronisation sans l'attendre (`unawaited`), ce qui
  /// convient pour un ajout/retrait isolé mais pas avant de créer une
  /// commande : `OrderService.create_from_cart` (backend) lit le panier
  /// serveur tel quel au moment de l'appel.
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
        debugPrint(
          '✅ Cart chargé depuis le stockage local: ${_items.length} articles',
        );
      } else {
        _items.clear();
      }

      _deliveryFee = _prefs?.getDouble(_deliveryFeeKey) ?? 500.0;

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
      debugPrint('❌ Erreur lors du chargement du panier local: $e');
    }
  }

  Future<void> _saveCartToStorage() async {
    try {
      if (_prefs == null) return;

      final itemsData = _items.map((item) => item.toMap()).toList();
      await _prefs!.setString(_cartItemsKey, json.encode(itemsData));
      await _prefs!.setDouble(_deliveryFeeKey, _deliveryFee);
      await _prefs!.setDouble(_promoDiscountKey, _promoDiscount);

      // Remove legacy discount key
      await _prefs!.remove(_discountKey);

      if (_promoCode != null && _promoCode!.isNotEmpty) {
        await _prefs!.setString(_promoCodeKey, _promoCode!);
      } else {
        await _prefs!.remove(_promoCodeKey);
      }

      debugPrint('✅ Panier sauvegardé localement (${_items.length} articles)');
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde du panier local: $e');
    }
  }

  Future<void> _removeStoredCartKeys() async {
    if (_prefs == null) return;
    await _prefs!.remove(_cartItemsKey);
    await _prefs!.remove(_deliveryFeeKey);
    await _prefs!.remove(_promoDiscountKey);
    await _prefs!.remove(_discountKey); // Legacy
    await _prefs!.remove(_promoCodeKey);
  }

  /// Traduit une ligne de panier Django vers le modèle local. Le prix et le
  /// nom sont relus du serveur (invariant C1) ; `customizations` ne porte que
  /// le texte libre stocké dans `notes` — la structure fine (options
  /// choisies) n'est pas encore portée par cette tranche, voir
  /// `_notesFromCustomizations`.
  CartItem _fromRemoteLine(eccore.CartLine line) {
    return CartItem(
      id: line.id,
      menuItemId: line.menuItemId,
      name: line.name,
      price: line.unitPrice.toMajorUnits(),
      quantity: line.quantity,
      imageUrl: line.image,
      customizations: line.notes.isEmpty ? {} : {'note': line.notes},
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

      debugPrint(
        '✅ Panier synchronisé depuis le backend (${_items.length} articles)',
      );

      await _saveCartToStorage();
      notifyListeners();
    } catch (e) {
      // Si erreur de connexion, on garde le panier local
      if (!_offlineSyncService.isOnline) {
        debugPrint('📴 Mode hors ligne: utilisation du panier local');
      } else {
        debugPrint('CartService: erreur lors du chargement distant - $e');
      }
    } finally {
      _isHydrating = false;
    }
  }

  /// Condense les personnalisations libres en texte pour la ligne Django
  /// (`CartLine.notes`) — pas de portage des options structurées dans cette
  /// tranche. Trié par clé pour être déterministe : deux personnalisations
  /// équivalentes doivent produire la même note, sans quoi
  /// `CartService._identical_line` (serveur) les traiterait comme deux
  /// lignes distinctes à chaque resynchronisation.
  String _notesFromCustomizations(Map<String, dynamic> customizations) {
    if (customizations.isEmpty) return '';
    final sortedKeys = customizations.keys.toList()..sort();
    return sortedKeys.map((key) => '$key: ${customizations[key]}').join(', ');
  }

  /// Réécrit intégralement le panier serveur depuis l'état local — même
  /// stratégie que l'ancien `DatabaseService.upsertUserCart` (delete puis
  /// insert), nécessaire ici en l'absence de correspondance stable entre
  /// `CartItem.id` local et l'identifiant de ligne Django.
  Future<void> _replaceRemoteCart() async {
    await _cartRepository.clear(restaurantSlug: AppConstants.restaurantSlug);
    for (final item in _items) {
      await _cartRepository.addLine(
        restaurantSlug: AppConstants.restaurantSlug,
        menuItemId: item.menuItemId,
        quantity: item.quantity,
        notes: _notesFromCustomizations(item.customizations),
      );
    }
  }

  Future<void> _syncCartToDatabase() async {
    if (_userId == null || _isHydrating) return;
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      await _replaceRemoteCart();
    } catch (e) {
      // Si erreur de connexion, sauvegarder hors ligne
      if (!_offlineSyncService.isOnline) {
        debugPrint('📴 Mode hors ligne: sauvegarde du panier localement');
        await _offlineSyncService.saveCartUpdateOffline(
          _userId!,
          List<CartItem>.from(_items),
          _deliveryFee,
          discount,
          _promoCode,
        );
      } else {
        debugPrint(
          'CartService: erreur lors de la synchronisation distante - $e',
        );
      }
    } finally {
      _isSyncing = false;
    }
  }

  void _persistChanges() {
    if (_prefs != null) {
      unawaited(_saveCartToStorage());
    }
    if (_userId != null && !_isHydrating) {
      final sync = _syncCartToDatabase();
      _pendingCartSync = sync;
      unawaited(sync);
    }
  }

  /// Réconcilie panier local et panier serveur au premier chargement d'une
  /// session (`initializeForUser`). Les frais de livraison, remise et code
  /// promo n'ont pas d'équivalent côté serveur (hors scope de cette tranche)
  /// et restent donc uniquement pilotés par l'état local, quelle que soit la
  /// branche empruntée ici.
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

      if (shouldOverwriteRemote) {
        await _replaceRemoteCart();
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

        await _replaceRemoteCart();
      }
    } catch (e) {
      debugPrint(
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
      final key =
          '${item.menuItemId}_${jsonEncode(_normalizeCustomizations(item.customizations))}';
      seen[key] = item;
      merged.add(item);
    }

    for (final item in localItems) {
      final key =
          '${item.menuItemId}_${jsonEncode(_normalizeCustomizations(item.customizations))}';
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
