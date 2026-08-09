import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:elcora_dely/presentation/libelles_course.dart';

/// Une course telle que l'app la manipule : l'affectation Django, et le détail
/// de la commande quand il a pu être lu.
///
/// Les deux voyagent ensemble parce que les écrans montrent une commande
/// (articles, montants, adresse) alors que **toutes les actions du livreur
/// s'adressent à la course** (`/delivery/assignments/{id}/...`). Garder
/// l'affectation sous la main évite de la rechercher à chaque geste.
///
/// Jusqu'au lot 3, cette classe portait en plus une **copie locale** de la
/// commande, de forme héritée de Supabase, que l'adaptateur recomposait champ
/// par champ. Elle n'existe plus : les écrans lisent les entités du socle, et
/// ce que l'affichage réclame en propre est calculé ici, une fois.
@immutable
class Course {
  const Course({required this.assignment, this.commande});

  final eccore.Assignment assignment;

  /// Détail de la commande — articles, montants, moyen de paiement.
  ///
  /// `null` pour les courses **livrées** : leur détail n'est pas relu, ce qui
  /// coûterait une requête par ligne d'historique pour des articles que plus
  /// personne ne regarde. `null` aussi quand la lecture a échoué, auquel cas la
  /// course reste affichable — mieux vaut une course incomplète qu'une course
  /// disparue de l'écran.
  final eccore.Order? commande;

  String get assignmentId => assignment.id;

  /// L'identifiant que les écrans exposent est celui de la **commande** : c'est
  /// lui qui ouvre le suivi (`ws/orders/{id}/tracking/`) et la discussion.
  String get orderId => assignment.orderId;

  /// Étapes que le serveur autorise depuis l'état courant. C'est la source des
  /// boutons à afficher : la machine à états n'est pas rejouée côté client.
  List<String> get allowedTransitions => assignment.allowedTransitions;

  EtapeCourse get etape => EtapeCourse.depuisServeur(assignment.status);

  MoyenPaiement get moyenPaiement =>
      MoyenPaiement.depuisServeur(commande?.paymentMethod);

  /// Ce que le livreur touche pour cette course, tel que le serveur le calcule.
  ///
  /// Lu sur l'affectation et non déduit d'un pourcentage du panier : le taux de
  /// commission appartient au serveur. L'écran des gains appliquait 10 % à un
  /// total qui vaut zéro sur toute course livrée — il affichait donc zéro.
  eccore.Money? get remuneration => assignment.courierFee;

  /// Adresse de dépôt, repère compris quand il y en a un.
  String get adresseLivraison => assignment.deliveryLandmark.isEmpty
      ? assignment.deliveryAddressLine
      : '${assignment.deliveryAddressLine} (${assignment.deliveryLandmark})';

  String get destinataire => assignment.recipientName;
  String get telephoneDestinataire => assignment.recipientPhone;

  /// Consignes de livraison, ou `null` s'il n'y en a pas — pour que l'écran
  /// n'affiche pas un encart vide.
  String? get consignes {
    final texte = commande?.deliveryInstructions ?? '';
    return texte.isEmpty ? null : texte;
  }

  List<eccore.OrderLine> get articles => commande?.lines ?? const [];

  eccore.Money? get total => commande?.total;
  eccore.Money? get sousTotal => commande?.subtotal;
  eccore.Money? get fraisLivraison => commande?.deliveryFee;
  eccore.Money? get remise => commande?.discount;

  /// Moment où la commande a été passée, à défaut celui où la course a été
  /// proposée — l'historique n'a que le second.
  DateTime get passeeLe => commande?.placedAt ?? assignment.offeredAt;

  DateTime? get livraisonEstimeeA => commande?.estimatedDeliveryAt;

  /// La course m'est proposée et je n'y ai pas encore répondu.
  bool get estProposee => assignment.status == eccore.DeliveryStatus.offered;

  /// Elle est à moi — acceptée, en cours, ou déjà livrée.
  bool get estMienne => !estProposee;
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

  /// Assemble la course et, quand elle est en cours, le détail de sa commande.
  ///
  /// L'affectation ne porte ni les articles, ni les montants, ni le moyen de
  /// paiement — or un livreur qui encaisse en espèces a besoin de savoir
  /// combien, et de vérifier le sac avant de partir. Le contrat le lui
  /// permet : `OrderViewSet` rend au livreur les commandes qui lui sont
  /// confiées, et rien d'autre.
  ///
  /// L'échec de cette lecture n'emporte pas la course : voir [Course.commande].
  Future<Course> _toCourse(eccore.Assignment assignment) async {
    if (!assignment.isActive) return Course(assignment: assignment);

    try {
      return Course(
        assignment: assignment,
        commande: await _orders.getById(assignment.orderId),
      );
    } catch (e) {
      eccore.Journal.trace('⚠️ Commande ${assignment.orderId} illisible : $e');
      return Course(assignment: assignment);
    }
  }
}
