import 'package:elcorazon_core/src/delivery/assignment.dart';
import 'package:elcorazon_core/src/models/money.dart';
import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/network/page.dart';

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

  /// **Une page** de courses — l'historique d'un livreur, borné dans le temps.
  ///
  /// [deliveredFrom]/[deliveredTo] portent sur la livraison : c'est la date
  /// qu'on lit dans un historique. Sans elles, l'écran chargeait toutes les
  /// courses d'un livreur, puis les croisait avec un an de commandes
  /// téléchargées pour retrouver les siennes.
  Future<Page<Assignment>> page({
    String? courierId,
    String? status,
    DateTime? deliveredFrom,
    DateTime? deliveredTo,
    int page = 1,
    int pageSize = 25,
  }) async {
    final response = await apiClient.get(
      '/delivery/manage/assignments/',
      queryParameters: _filtres(
        courierId: courierId,
        status: status,
        deliveredFrom: deliveredFrom,
        deliveredTo: deliveredTo,
      )
        ..['page'] = page
        ..['page_size'] = pageSize,
    );
    return Page<Assignment>.fromJson(
      response.data as Map<String, dynamic>,
      Assignment.fromJson,
    );
  }

  /// Totaux d'une sélection de courses : compte par statut, et **gains par
  /// devise** du livreur.
  ///
  /// Les gains sont `courier_fee` — ce que le livreur a gagné. L'historique du
  /// back-office affichait à la place la somme des **totaux des commandes**,
  /// c'est-à-dire ce que les clients ont payé, toutes devises confondues.
  Future<CourierEarnings> summary({
    String? courierId,
    String? status,
    DateTime? deliveredFrom,
    DateTime? deliveredTo,
  }) async {
    final response = await apiClient.get(
      '/delivery/manage/assignments/summary/',
      queryParameters: _filtres(
        courierId: courierId,
        status: status,
        deliveredFrom: deliveredFrom,
        deliveredTo: deliveredTo,
      ),
    );
    return CourierEarnings.fromJson(response.data as Map<String, dynamic>);
  }

  Map<String, dynamic> _filtres({
    String? courierId,
    String? status,
    DateTime? deliveredFrom,
    DateTime? deliveredTo,
  }) {
    return {
      if (courierId != null) 'courier': courierId,
      if (status != null) 'status': status,
      if (deliveredFrom != null) 'delivered_at__gte': deliveredFrom.toUtc().toIso8601String(),
      if (deliveredTo != null) 'delivered_at__lte': deliveredTo.toUtc().toIso8601String(),
    };
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

/// Ce qu'une sélection de courses représente pour un livreur — `summary`.
class CourierEarnings {
  const CourierEarnings({
    required this.assignments,
    required this.byStatus,
    required this.earnings,
  });

  factory CourierEarnings.fromJson(Map<String, dynamic> json) {
    return CourierEarnings(
      assignments: json['assignments'] as int,
      byStatus: {
        for (final entree in (json['by_status'] as Map<String, dynamic>).entries)
          entree.key: (entree.value as num).toInt(),
      },
      earnings: [
        for (final ligne in json['earnings'] as List<dynamic>)
          (
            amount: Money(
              amountMinor: ((ligne as Map<String, dynamic>)['earnings_minor'] as num).toInt(),
              currency: ligne['currency'] as String,
            ),
            deliveries: (ligne['deliveries'] as num).toInt(),
          ),
      ],
    );
  }

  final int assignments;

  /// Tous les statuts de course, à zéro le cas échéant.
  final Map<String, int> byStatus;

  /// Gains **livrés**, une entrée par devise : un livreur de Douala est payé
  /// en XAF, celui de Lomé en XOF.
  final List<({Money amount, int deliveries})> earnings;

  int compteDe(String statut) => byStatus[statut] ?? 0;
}
