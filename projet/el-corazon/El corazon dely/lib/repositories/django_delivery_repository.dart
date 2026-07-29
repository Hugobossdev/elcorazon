import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import '../models/order.dart';

/// Une course telle que l'app la manipule : la course Django (`Assignment`) et
/// la commande qu'elle porte, traduite dans le modèle `Order` local.
///
/// Les deux voyagent ensemble parce que les écrans raisonnent en commandes
/// (`order.id`, `order.status`) alors que **toutes les actions du livreur
/// s'adressent à la course** (`/delivery/assignments/{id}/...`). Garder
/// l'affectation sous la main évite de la rechercher à chaque geste.
@immutable
class Course {
  const Course({required this.assignment, required this.order});

  final eccore.Assignment assignment;

  /// La même course, vue comme une commande — c'est ce que les écrans
  /// existants affichent.
  final Order order;

  String get assignmentId => assignment.id;
  String get orderId => assignment.orderId;

  /// Étapes que le serveur autorise depuis l'état courant. C'est la source des
  /// boutons à afficher : la machine à états n'est pas rejouée côté client.
  List<String> get allowedTransitions => assignment.allowedTransitions;
}

/// Courses du livreur contre le backend Django (Phase 6) — remplace les appels
/// Supabase de `DatabaseService` (`getAvailableOrders`, `getAssignedOrders`,
/// `updateActiveDeliveryStatus`, `updateDeliveryLocation`).
///
/// Deux différences de fond avec ce que faisait l'app Supabase, qui ne sont pas
/// des simplifications mais le contrat lui-même :
///
/// * **il n'existe pas de vivier de commandes à se partager.** Un livreur ne
///   pioche pas dans une liste ouverte : le personnel lui propose une course
///   (`AssignmentService.offer`) et elle apparaît dans ses affectations. Ce que
///   l'app appelait « commandes disponibles » devient donc « courses qui me
///   sont proposées » — c'est plus restreint, et volontairement ;
/// * **le client n'écrit jamais le statut de la commande.** Il fait avancer la
///   *course* ; la commande suit par projection déclarée côté serveur
///   (`ORDER_STATUS_PROJECTION`). C'est une projection écrite à la main côté
///   client qui avait produit C4.
class DjangoDeliveryRepository {
  DjangoDeliveryRepository({required eccore.ApiClient apiClient})
    : _delivery = eccore.DeliveryRepository(apiClient: apiClient),
      _orders = eccore.OrderRepository(apiClient: apiClient),
      _tracking = eccore.TrackingRepository(apiClient: apiClient);

  final eccore.DeliveryRepository _delivery;
  final eccore.OrderRepository _orders;
  final eccore.TrackingRepository _tracking;

  /// Le dossier du livreur connecté.
  Future<eccore.CourierProfile> profile() => _delivery.me();

  /// Bascule de disponibilité. Rend le dossier à jour : c'est
  /// `canAcceptOrders`, pas `isOnline`, qui dit si des courses arriveront (L1).
  Future<eccore.CourierProfile> setOnline({required bool isOnline}) =>
      _delivery.setOnline(isOnline: isOnline);

  /// Ce qui concerne le livreur : les courses qu'on lui propose, celles qu'il a
  /// en cours, et l'historique récent des livrées — dont vivent les écrans de
  /// gains et de statistiques. L'historique est borné (voir
  /// `DeliveryRepository.recentlyDelivered`) : les totaux de carrière se lisent
  /// sur le dossier, pas en additionnant des pages.
  Future<List<Course>> loadCourses() async {
    final batches = await Future.wait([
      _delivery.pendingOffers(),
      _delivery.activeAssignments(),
      _delivery.recentlyDelivered(),
    ]);
    final assignments = [for (final batch in batches) ...batch];
    return Future.wait(assignments.map(_toCourse));
  }

  Future<Course> loadCourse(String assignmentId) async {
    return _toCourse(await _delivery.getById(assignmentId));
  }

  /// L2 — l'acceptation est exclusive côté serveur : deux livreurs sur la même
  /// commande, le second reçoit un refus métier. L'appelant ne doit donc rien
  /// afficher comme acquis avant que ce futur ne soit résolu.
  Future<Course> accept(String assignmentId) async {
    return _toCourse(await _delivery.accept(assignmentId));
  }

  Future<Course> decline(String assignmentId, {String reason = ''}) async {
    return _toCourse(await _delivery.decline(assignmentId, reason: reason));
  }

  /// Fait avancer la course. [target] doit venir de [Course.allowedTransitions].
  Future<Course> advanceTo(String assignmentId, String target) async {
    return _toCourse(await _delivery.transitionTo(assignmentId, target));
  }

  /// Dépose une position sur une course en cours. Rend `false` quand
  /// l'échantillonnage serveur a écarté le relevé (202) — ce n'est pas un
  /// échec : la position a été reçue et le dossier rafraîchi.
  Future<bool> sendPing({
    required String assignmentId,
    required double latitude,
    required double longitude,
    DateTime? recordedAt,
    double? accuracyMeters,
    double? speedMetersPerSecond,
    double? headingDegrees,
  }) async {
    final ping = await _tracking.sendPing(
      assignmentId: assignmentId,
      latitude: latitude,
      longitude: longitude,
      recordedAt: recordedAt ?? DateTime.now(),
      accuracyMeters: accuracyMeters,
      speedMetersPerSecond: speedMetersPerSecond,
      headingDegrees: headingDegrees,
    );
    return ping != null;
  }

  /// Assemble la course et la commande qu'elle porte.
  ///
  /// La commande est relue parce que l'affectation ne porte ni les articles, ni
  /// les montants, ni le moyen de paiement — or un livreur qui encaisse en
  /// espèces a besoin de savoir combien, et de vérifier le sac avant de partir.
  /// Le contrat le lui permet : `OrderViewSet` rend au livreur les commandes
  /// qui lui sont confiées, et rien d'autre.
  ///
  /// **Seulement pour les courses en cours**, en revanche : relire le détail de
  /// chaque livraison passée coûterait une requête par ligne d'historique pour
  /// des articles que plus personne ne regarde. Ce que l'historique doit
  /// montrer — la date, l'adresse, la rémunération — est déjà sur
  /// l'affectation.
  ///
  /// L'échec de cette lecture n'emporte pas la course : elle reste affichable à
  /// partir de la seule affectation, ce qui vaut mieux que de faire disparaître
  /// de l'écran une course bien réelle.
  Future<Course> _toCourse(eccore.Assignment assignment) async {
    eccore.Order? order;
    if (assignment.isActive) {
      try {
        order = await _orders.getById(assignment.orderId);
      } catch (e) {
        debugPrint('⚠️ Commande ${assignment.orderId} illisible : $e');
      }
    }
    return Course(assignment: assignment, order: _toLocalOrder(assignment, order));
  }

  Order _toLocalOrder(eccore.Assignment assignment, eccore.Order? order) {
    return Order(
      // L'identifiant exposé aux écrans est celui de la **commande** : c'est
      // lui qui ouvre le suivi (`ws/orders/{id}/tracking/`) et le chat.
      id: assignment.orderId,
      // Le client n'est pas exposé au livreur — ni identifiant, ni historique.
      // Il voit un destinataire, un point de dépôt et un téléphone d'appoint.
      userId: '',
      items: [
        for (final line in order?.lines ?? const <eccore.OrderLine>[])
          OrderItem(
            menuItemId: line.menuItemId,
            menuItemName: line.itemName,
            name: line.itemName,
            category: '',
            menuItemImage: line.itemImage ?? '',
            quantity: line.quantity,
            unitPrice: line.unitPrice.toMajorUnits(),
            totalPrice: line.lineTotal.toMajorUnits(),
            notes: line.notes.isEmpty ? null : line.notes,
          ),
      ],
      subtotal: order?.subtotal.toMajorUnits() ?? 0,
      deliveryFee: order?.deliveryFee.toMajorUnits() ?? 0,
      discount: order?.discount.toMajorUnits() ?? 0,
      total: order?.total.toMajorUnits() ?? 0,
      status: _toLocalStatus(assignment.status),
      deliveryAddress: assignment.deliveryLandmark.isEmpty
          ? assignment.deliveryAddressLine
          : '${assignment.deliveryAddressLine} (${assignment.deliveryLandmark})',
      deliveryNotes: order?.deliveryInstructions.isEmpty ?? true
          ? null
          : order!.deliveryInstructions,
      paymentMethod: _toLocalPaymentMethod(order?.paymentMethod),
      orderTime: order?.placedAt ?? assignment.offeredAt,
      createdAt: order?.createdAt ?? assignment.createdAt,
      estimatedDeliveryTime: order?.estimatedDeliveryAt,
      // Renseigné dès que la course est acceptée : c'est ce que les écrans
      // lisent pour distinguer « proposée » de « la mienne ».
      deliveryPersonId:
          assignment.status == eccore.DeliveryStatus.offered ? null : assignment.courier.id,
    );
  }

  /// Étape de course → statut affiché par les écrans du livreur.
  ///
  /// C'est bien l'étape de la **course** qui est traduite, pas le statut de la
  /// commande : côté livreur, ce sont ses propres gestes qui doivent piloter
  /// l'écran. `accepted` retombe sur `confirmed`, faute d'équivalent dans
  /// l'énumération locale — c'était déjà la convention de l'app Supabase.
  static OrderStatus _toLocalStatus(String deliveryStatus) {
    switch (deliveryStatus) {
      case eccore.DeliveryStatus.offered:
        return OrderStatus.pending;
      case eccore.DeliveryStatus.accepted:
        return OrderStatus.confirmed;
      case eccore.DeliveryStatus.pickedUp:
        return OrderStatus.pickedUp;
      case eccore.DeliveryStatus.onTheWay:
        return OrderStatus.onTheWay;
      case eccore.DeliveryStatus.delivered:
        return OrderStatus.delivered;
      default:
        return OrderStatus.cancelled;
    }
  }

  static PaymentMethod _toLocalPaymentMethod(String? method) {
    switch (method) {
      case 'mobile_money':
        return PaymentMethod.mobileMoney;
      case 'card':
        return PaymentMethod.creditCard;
      case 'wallet':
        return PaymentMethod.wallet;
      default:
        return PaymentMethod.cash;
    }
  }
}
