import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:elcora_fast/main.dart' show apiClient;

/// Abonnement du client, contre `/api/v1/loyalty/subscriptions/` (Phase 6).
///
/// Sert d'abord à savoir si les articles `vip_exclusive` du catalogue sont
/// ouverts au compte connecté. L'ancienne version lisait cet état dans
/// `WalletService`, qui mêlait un solde de portefeuille — jamais porté par le
/// backend v2 — et un abonnement VIP maison. Seul l'abonnement existe côté
/// serveur, et c'est lui qui décide.
///
/// Le droit ne dépend plus du **nom** du plan (`'VIP Premium'`) mais de
/// l'existence d'un abonnement en cours : les plans sont un catalogue en base,
/// que l'exploitation renomme sans prévenir le client.
class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  eccore.LoyaltyRepository get _loyalty => eccore.LoyaltyRepository(apiClient: apiClient);

  eccore.Subscription? _current;
  bool _isLoaded = false;

  /// L'abonnement qui ouvre des droits aujourd'hui, `null` sinon.
  eccore.Subscription? get current => _current;

  /// Faux tant que rien n'a été chargé : en l'absence de réponse du serveur,
  /// on ne présume pas d'un droit.
  bool get hasActiveSubscription => _current != null;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    try {
      _current = await _loyalty.getCurrentSubscription();
    } on eccore.ApiException catch (e) {
      // 401 sur un écran public (catalogue visité sans compte) : pas un
      // incident, simplement aucun abonnement à afficher.
      if (!e.isUnauthorized) {
        eccore.Journal.trace('SubscriptionService: chargement impossible — $e');
      }
      _current = null;
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Vide l'état à la déconnexion — sans quoi le compte suivant hériterait des
  /// droits du précédent.
  void clear() {
    _current = null;
    _isLoaded = false;
    notifyListeners();
  }
}
