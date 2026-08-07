import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/delivery/assignment.dart';
import 'package:elcorazon_core/src/delivery/courier_profile.dart';

/// Accès à `/api/v1/delivery/*` du point de vue du **livreur** — voir
/// `backend/apps/delivery/{serializers,views,services}.py`.
///
/// Ce repository ne connaît pas les routes du personnel
/// (`/delivery/couriers/`, `/delivery/orders/{id}/offer/`) : elles demandent
/// des permissions nommées qu'un compte livreur n'a pas, et les exposer ici
/// laisserait croire le contraire. Elles reviendront avec l'app `admin`.
///
/// Deux absences volontaires, qui découlent du contrat plutôt que d'un oubli :
///
/// * **il n'y a pas de vivier de courses à parcourir.** Un livreur ne
///   « prend » pas une course dans une liste ouverte : le personnel la lui
///   propose (`AssignmentService.offer`), et il la voit arriver dans ses
///   propres affectations. `pendingOffers()` est donc l'équivalent exact de
///   l'ancien « commandes disponibles » de l'app Supabase, restreint à ce qui
///   lui est adressé ;
/// * **aucune méthode n'écrit un statut de commande.** La commande suit par
///   projection déclarée côté serveur (`ORDER_STATUS_PROJECTION`) quand la
///   course avance. C'est une projection écrite à la main côté client qui
///   avait produit C4.
class DeliveryRepository {
  DeliveryRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Le dossier du livreur qui appelle (`/delivery/me/`).
  Future<CourierProfile> me() async {
    final response = await apiClient.get('/delivery/me/');
    return CourierProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Bascule de disponibilité. Le serveur rend le dossier à jour : lire
  /// `canAcceptOrders` sur la réponse plutôt que de supposer qu'un passage à
  /// `true` suffit — un dossier non validé reste inéligible (L1).
  Future<CourierProfile> setOnline({required bool isOnline}) async {
    final response = await apiClient.post('/delivery/me/online/', data: {'is_online': isOnline});
    return CourierProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Courses du livreur, de la plus récemment proposée à la plus ancienne.
  ///
  /// [maxPages] borne la pagination suivie. La valeur par défaut ne borne rien,
  /// ce qui convient aux filtres naturellement courts (une course proposée, une
  /// course en cours) ; l'historique des livraisons, lui, croît sans limite et
  /// doit être demandé borné.
  Future<List<Assignment>> assignments({
    String? status,
    String? orderId,
    int? maxPages,
  }) async {
    final assignments = <Assignment>[];
    String? path = '/delivery/assignments/';
    Map<String, dynamic>? queryParameters = {
      if (status != null) 'status': status,
      if (orderId != null) 'order': orderId,
    };
    var pages = 0;

    while (path != null && (maxPages == null || pages < maxPages)) {
      pages++;
      final response = await apiClient.get(path, queryParameters: queryParameters);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      assignments.addAll(
        results.map((json) => Assignment.fromJson(json as Map<String, dynamic>)),
      );
      path = body['next'] as String?;
      queryParameters = null;
    }

    return assignments;
  }

  /// Les propositions en attente de réponse.
  Future<List<Assignment>> pendingOffers() => assignments(status: DeliveryStatus.offered);

  /// Les courses engagées — celles qui occupent réellement le livreur.
  ///
  /// Trois appels plutôt qu'un filtre `status__in` : le `filterset_fields` du
  /// serveur ne déclare que `exact` sur `status`, et un paramètre inconnu
  /// serait ignoré en silence, ce qui rendrait *toutes* les courses, y compris
  /// les livrées et les refusées.
  Future<List<Assignment>> activeAssignments() async {
    final batches = await Future.wait([
      assignments(status: DeliveryStatus.accepted),
      assignments(status: DeliveryStatus.pickedUp),
      assignments(status: DeliveryStatus.onTheWay),
    ]);
    return [for (final batch in batches) ...batch]
      ..sort((a, b) => b.offeredAt.compareTo(a.offeredAt));
  }

  /// Les livraisons récentes, du plus récent au plus ancien.
  ///
  /// Borné à dessein : un livreur en poste depuis un an a des centaines de
  /// courses derrière lui, et les écrans qui s'en servent (gains,
  /// statistiques) ne regardent que les jours écoulés. Les totaux de carrière
  /// se lisent sur le dossier ([me]), qui les tient à jour côté serveur, pas
  /// en additionnant des pages.
  Future<List<Assignment>> recentlyDelivered({int maxPages = 3}) =>
      assignments(status: DeliveryStatus.delivered, maxPages: maxPages);

  Future<Assignment> getById(String id) async {
    final response = await apiClient.get('/delivery/assignments/$id/');
    return Assignment.fromJson(response.data as Map<String, dynamic>);
  }

  /// L2 — l'acceptation est exclusive côté serveur. Deux livreurs sur la même
  /// commande : le second reçoit une `ApiException` métier, pas une course.
  /// L'appelant ne doit donc pas considérer la course comme acquise avant que
  /// ce futur ne soit résolu (pas de mise à jour optimiste sur cette étape-là).
  Future<Assignment> accept(String id) async {
    final response = await apiClient.post('/delivery/assignments/$id/accept/');
    return Assignment.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Assignment> decline(String id, {String reason = ''}) async {
    final response = await apiClient.post(
      '/delivery/assignments/$id/decline/',
      data: {'reason': reason},
    );
    return Assignment.fromJson(response.data as Map<String, dynamic>);
  }

  /// Progression de la course : `picked_up`, `on_the_way`, `delivered`.
  ///
  /// [target] doit venir de `Assignment.allowedTransitions` : la machine à
  /// états est acyclique côté serveur, une étape déjà franchie est refusée
  /// plutôt que rejouée (c'est ce rejeu qui réincrémentait les compteurs du
  /// livreur — C3).
  Future<Assignment> transitionTo(String id, String target, {String reason = ''}) async {
    final response = await apiClient.post(
      '/delivery/assignments/$id/status/',
      data: {'status': target, 'reason': reason},
    );
    return Assignment.fromJson(response.data as Map<String, dynamic>);
  }
}
