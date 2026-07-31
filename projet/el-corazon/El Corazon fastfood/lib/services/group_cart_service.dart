import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/models/order.dart';

/// Commande de groupe, contre `/api/v1/group-carts/` (Phase 6).
///
/// Remplace `SocialService`, dont l'écran de commande groupée était le seul
/// consommateur. Le changement n'est pas qu'une question de backend : **le
/// modèle du domaine n'est pas le même**.
///
/// Côté Supabase, il fallait d'abord créer un « groupe famille » persistant
/// (`social_groups`, code d'invitation permanent), puis ouvrir une commande
/// dedans. Côté Django, le panier collaboratif **est** l'unité : il porte son
/// propre code d'invitation, ne vit que le temps du repas, et cesse d'accepter
/// les invitations à sa clôture. Il n'y a plus deux objets à tenir synchrones,
/// donc plus de commande de groupe orpheline dans un groupe dissous.
///
/// Trois gestes que l'ancienne implémentation se permettait n'existent plus, et
/// c'est le serveur qui les refuse :
/// * déposer une ligne au nom d'un autre participant (l'auteur vient du jeton) ;
/// * répartir les montants entre convives côté client (le serveur rend les
///   totaux par participant) ;
/// * confirmer sans être l'hôte.
class GroupCartService extends ChangeNotifier {
  static final GroupCartService _instance = GroupCartService._internal();
  factory GroupCartService() => _instance;
  GroupCartService._internal();

  final eccore.GroupCartRepository _repository =
      eccore.GroupCartRepository(apiClient: apiClient);

  eccore.GroupCart? _current;
  bool _isInitialized = false;
  bool _isLoading = false;

  eccore.RealtimeChannel? _channel;
  StreamSubscription<eccore.RealtimeEvent>? _subscription;

  eccore.GroupCart? get current => _current;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;

  /// Vrai tant que le panier accepte des ajouts — décidé par le serveur, pas
  /// par une comparaison d'échéance sur l'horloge du téléphone.
  bool get acceptsContributions => _current?.acceptsContributions ?? false;

  /// Charge le panier collaboratif en cours, s'il y en a un.
  ///
  /// Le serveur ne rend que les paniers dont l'appelant est membre : il n'y a
  /// pas d'identifiant d'utilisateur à passer, ni de filtre à écrire ici.
  Future<void> initialize() async {
    if (_isInitialized) return;
    await refresh();
    _isInitialized = true;
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    try {
      final carts = await _repository.list();
      final ouvert = carts.where((cart) => cart.status == 'open' || cart.status == 'locked');
      _attach(ouvert.isEmpty ? null : ouvert.first);
    } on eccore.ApiException catch (e) {
      debugPrint('GroupCartService: chargement impossible — ${e.code}');
      _attach(null);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ouvre un panier collaboratif. Le code d'invitation est **généré par le
  /// serveur** : le client ne le choisit pas, sous peine de pouvoir deviner
  /// celui d'un autre panier.
  Future<eccore.GroupCart?> open({String title = '', int? windowMinutes}) async {
    try {
      final cart = await _repository.open(
        restaurantSlug: AppConstants.restaurantSlug,
        title: title,
        windowMinutes: windowMinutes,
      );
      _attach(cart);
      notifyListeners();
      return cart;
    } on eccore.ApiException catch (e) {
      debugPrint('GroupCartService: ouverture refusée — ${e.code} (${e.detail})');
      return null;
    }
  }

  /// Rejoint un panier par son code. La capacité et l'échéance sont vérifiées
  /// côté serveur, sous verrou — pas devinées ici depuis un état déjà périmé au
  /// moment où on le lit.
  Future<bool> join(String code) async {
    try {
      _attach(await _repository.join(code.trim().toUpperCase()));
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      debugPrint('GroupCartService: adhésion refusée — ${e.code} (${e.detail})');
      return false;
    }
  }

  Future<bool> addItem({
    required String menuItemId,
    int quantity = 1,
    List<String> optionIds = const [],
    String notes = '',
  }) async {
    final cart = _current;
    if (cart == null) return false;

    return _write(
      () => _repository.addLine(
        groupCartId: cart.id,
        menuItemId: menuItemId,
        quantity: quantity,
        optionIds: optionIds,
        notes: notes,
      ),
    );
  }

  /// Modifie la quantité d'une ligne. Le serveur refuse de toucher à la ligne
  /// d'un autre participant.
  Future<bool> setQuantity({required String lineId, required int quantity}) async {
    final cart = _current;
    if (cart == null) return false;

    return _write(
      () => _repository.setQuantity(groupCartId: cart.id, lineId: lineId, quantity: quantity),
    );
  }

  Future<bool> removeItem(String lineId) async {
    final cart = _current;
    if (cart == null) return false;

    return _write(() => _repository.removeLine(groupCartId: cart.id, lineId: lineId));
  }

  /// Clôt les ajouts sans commander — réservé à l'hôte.
  Future<bool> lock() async {
    final cart = _current;
    if (cart == null) return false;

    return _write(() => _repository.lock(cart.id));
  }

  /// Transforme le panier en commande — réservé à l'hôte.
  ///
  /// Rend la commande créée, ou `null` si le serveur refuse (panier vide, ligne
  /// devenue indisponible, appelant qui n'est pas l'hôte). Aucun total n'est
  /// envoyé : c'est le serveur qui les calcule, comme pour une commande
  /// ordinaire.
  Future<eccore.Order?> confirm({
    required String addressId,
    required PaymentMethod paymentMethod,
    String instructions = '',
    String promoCode = '',
  }) async {
    final cart = _current;
    if (cart == null) return null;

    try {
      final order = await _repository.confirm(
        groupCartId: cart.id,
        addressId: addressId,
        paymentMethod: _toRemotePaymentMethod(paymentMethod),
        instructions: instructions,
        promoCode: promoCode,
      );
      await refresh();
      return order;
    } on eccore.ApiException catch (e) {
      debugPrint('GroupCartService: confirmation refusée — ${e.code} (${e.detail})');
      return null;
    }
  }

  /// Renonce au panier — réservé à l'hôte.
  Future<bool> cancel(String reason) async {
    final cart = _current;
    if (cart == null) return false;

    final ok = await _write(() => _repository.cancel(groupCartId: cart.id, reason: reason));
    if (ok) _attach(null);
    notifyListeners();
    return ok;
  }

  /// Quitte l'écran sans fermer le panier : le socket se referme, le panier
  /// continue de vivre pour les autres participants.
  Future<void> detach() async {
    await _subscription?.cancel();
    await _channel?.close();
    _subscription = null;
    _channel = null;
  }

  Future<bool> _write(Future<eccore.GroupCart> Function() action) async {
    try {
      // Toute écriture rend le panier entier, totaux recalculés : il n'y a rien
      // à recomposer localement, et donc aucune divergence possible entre ce
      // que voient deux participants.
      _current = await action();
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      debugPrint('GroupCartService: écriture refusée — ${e.code} (${e.detail})');
      return false;
    }
  }

  void _attach(eccore.GroupCart? cart) {
    final sameCart = _current?.id == cart?.id;
    _current = cart;
    if (sameCart) return;

    unawaited(detach());
    if (cart != null) _listen(cart.id);
  }

  /// Écoute `ws/group-carts/{id}/`.
  ///
  /// Le canal est **en lecture seule** côté serveur : les contributions passent
  /// par HTTP, qui valide l'article, ses options et l'échéance. L'ancienne
  /// implémentation écrivait par le temps réel, sans validation nulle part.
  ///
  /// Les événements ne portent que ce qui a changé ; on relit le panier plutôt
  /// que d'appliquer un delta, pour que les totaux restent ceux du serveur.
  void _listen(String groupCartId) {
    final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000/api/v1';
    final apiUri = Uri.parse(apiBaseUrl);
    final wsUrl = Uri(
      scheme: apiUri.scheme == 'https' ? 'wss' : 'ws',
      host: apiUri.host,
      port: apiUri.port,
      path: '/ws/group-carts/$groupCartId/',
    ).toString();

    final channel = eccore.RealtimeChannel(wsUrl: wsUrl, tokenStorage: eccore.TokenStorage());
    _channel = channel;

    _subscription = channel.connect().listen((event) async {
      if (!event.type.startsWith('groupcart.')) return;

      try {
        _current = await _repository.getById(groupCartId);
        notifyListeners();
      } on eccore.ApiException catch (e) {
        debugPrint('GroupCartService: relecture impossible — ${e.code}');
      }
    });
  }

  /// Django n'a qu'un moyen de paiement « carte » — `creditCard`/`debitCard`
  /// s'y confondent (`common/models.py PaymentMethod`), comme pour une commande
  /// ordinaire.
  static String _toRemotePaymentMethod(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.mobileMoney:
        return 'mobile_money';
      case PaymentMethod.creditCard:
      case PaymentMethod.debitCard:
        return 'card';
      case PaymentMethod.wallet:
        return 'wallet';
      case PaymentMethod.cash:
        return 'cash';
    }
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}
