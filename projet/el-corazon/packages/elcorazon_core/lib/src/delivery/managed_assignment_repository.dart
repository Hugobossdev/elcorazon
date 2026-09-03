import 'package:elcorazon_core/src/delivery/assignment.dart';
import 'package:elcorazon_core/src/network/api_client.dart';

/// Courses vues par l'exploitation — `GET /api/v1/delivery/manage/assignments/`
/// (`backend/apps/delivery/backoffice.py`).
///
/// Répond à la seule question que le back-office ne savait pas poser : **qui
/// porte cette commande ?**
///
/// `OrderSerializer` ne le dit pas, et ne le dira pas : `apps.orders` ne peut
/// pas dépendre d'`apps.delivery` (ADR-002). La flèche va dans l'autre sens —
/// la livraison connaît la commande, la commande ignore qu'on la livre — et
/// c'est donc du côté livraison que la réponse se lit.
///
/// Séparé de [DeliveryRepository], qui est le point de vue du **livreur** :
/// `/delivery/assignments/` filtre sur le dossier de l'appelant et exige
/// `IsCourier`, si bien qu'un compte du personnel y recevait une liste vide.
/// Ces routes-ci demandent `orders.read` et rendent le périmètre du compte.
///
/// Lecture seule, et c'est voulu : proposer une course reste
/// [ManagedCourierRepository.offer] (`orders.assign_courier`), l'annuler reste
/// [ManagedCourierRepository.cancelAssignment]. Savoir qui porte une commande
/// ne donne pas de quoi en changer.
class ManagedAssignmentRepository {
  ManagedAssignmentRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Courses du périmètre, la plus récemment proposée d'abord.
  ///
  /// [orderId] répond à « qui porte celle-ci » sans télécharger le reste ;
  /// [courierId] donne l'historique d'un livreur ; [status] sert les écrans de
  /// supervision qui ne s'intéressent qu'aux courses en cours.
  Future<List<Assignment>> list({
    String? orderId,
    String? courierId,
    String? status,
  }) async {
    final courses = <Assignment>[];
    String? path = '/delivery/manage/assignments/';
    Map<String, dynamic>? queryParameters = {
      if (orderId != null) 'order': orderId,
      if (courierId != null) 'courier': courierId,
      if (status != null) 'status': status,
    };

    while (path != null) {
      final response = await apiClient.get(path, queryParameters: queryParameters);
      final body = response.data as Map<String, dynamic>;
      courses.addAll(
        (body['results'] as List<dynamic>).map(
          (json) => Assignment.fromJson(json as Map<String, dynamic>),
        ),
      );
      path = body['next'] as String?;
      queryParameters = null;
    }

    return courses;
  }

  /// La course **encore vivante** d'une commande, ou `null`.
  ///
  /// Il n'y en a jamais deux — la base le garantit (L2, index unique partiel
  /// sur les statuts non terminaux). Les courses refusées ou annulées de la
  /// même commande sont écartées ici plutôt qu'affichées : elles racontent
  /// l'historique de l'affectation, pas qui transporte le repas maintenant.
  Future<Assignment?> activeFor(String orderId) async {
    final courses = await list(orderId: orderId);
    for (final course in courses) {
      if (course.isActive) return course;
    }
    return null;
  }

  /// Les courses vivantes du périmètre, rangées par identifiant de commande.
  ///
  /// Un seul appel pour un écran qui affiche une liste de livraisons : la
  /// version par commande demanderait une requête par ligne, et c'est
  /// exactement le motif que le reste du socle évite.
  Future<Map<String, Assignment>> activeByOrder() async {
    final courses = await list();
    return {
      for (final course in courses)
        if (course.isActive) course.orderId: course,
    };
  }
}
