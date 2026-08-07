import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:elcora_fast/main.dart' show apiClient;

/// Notation du livreur, contre `/api/v1/delivery/orders/{id}/rating/`.
///
/// Trois champs ont disparu de la signature d'envoi par rapport à la version
/// Supabase, et c'est le cœur du changement : ni `driverId`, ni `customerId`,
/// ni la table de destination. Le livreur se déduit de la course, l'auteur du
/// jeton. Les accepter du client, comme avant, permettait de noter le livreur
/// d'un autre depuis sa propre commande.
///
/// La note moyenne d'un livreur n'est plus interrogeable en tant que telle :
/// elle arrive avec le suivi de commande (`tracking/orders/{id}/`, bloc
/// `courier`) — le client voit la note de celui qui lui livre, pas celle de
/// n'importe quel livreur de la flotte.
class DriverRatingService {
  eccore.ApiClient get _client => apiClient;

  /// Soumet une note (1 à 5) sur la livraison de [orderId].
  ///
  /// Rend `false` sur refus du serveur : livraison déjà notée (409), course
  /// non livrée ou commande d'autrui (404).
  Future<bool> submitRating({
    required String orderId,
    required int rating,
    String? comment,
  }) async {
    try {
      await _client.post(
        '/delivery/orders/$orderId/rating/',
        data: {'score': rating, if (comment != null && comment.isNotEmpty) 'comment': comment},
      );
      return true;
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('DriverRatingService: notation refusée — ${e.code} (${e.detail})');
      return false;
    }
  }

  /// La livraison a-t-elle déjà été notée ? Le 404 est la réponse « pas
  /// encore », pas un incident.
  Future<bool> hasRatedOrder(String orderId) async {
    try {
      await _client.get('/delivery/orders/$orderId/rating/');
      return true;
    } on eccore.ApiException {
      return false;
    }
  }

  /// Note et nombre d'avis du livreur affecté à [orderId], lus dans le suivi.
  /// `null` tant qu'aucun livreur n'est affecté.
  Future<({double average, int count})?> courierRatingForOrder(String orderId) async {
    try {
      final tracking = await eccore.TrackingRepository(apiClient: _client).forOrder(orderId);
      if (!tracking.hasCourier) return null;

      final average = tracking.courier['rating_average'];
      final count = tracking.courier['rating_count'];
      return (
        average: double.tryParse('$average') ?? 0.0,
        count: count is int ? count : int.tryParse('$count') ?? 0,
      );
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('DriverRatingService: suivi indisponible — ${e.code}');
      return null;
    }
  }
}
