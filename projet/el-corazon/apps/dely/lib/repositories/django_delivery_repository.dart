import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:elcora_dely/presentation/libelles_course.dart';

/// Une course telle que l'app la manipule : l'affectation Django.
///
/// L'affectation transporte les articles, le total, l'adresse et les consignes
/// dont le livreur a besoin. Toutes ses actions s'adressent à elle
/// (`/delivery/assignments/{id}/...`) ; la commande cliente n'est jamais
/// relue.
///
/// Jusqu'au lot 3, cette classe portait en plus une **copie locale** de la
/// commande, de forme héritée de Supabase, que l'adaptateur recomposait champ
/// par champ. Elle n'existe plus : les écrans lisent les entités du socle, et
/// ce que l'affichage réclame en propre est calculé ici, une fois.
@immutable
class Course {
  const Course({required this.assignment});

  final eccore.Assignment assignment;

  String get assignmentId => assignment.id;

  /// L'identifiant que les écrans exposent est celui de la **commande** : c'est
  /// lui qui ouvre le suivi (`ws/orders/{id}/tracking/`) et la discussion.
  String get orderId => assignment.orderId;

  /// Référence lisible de la commande, telle que le serveur la fabrique.
  ///
  /// Les écrans affichaient jusqu'ici les huit premiers caractères de l'UUID
  /// — `#3F2A1B9C`. Illisible à voix haute au téléphone, et introuvable dans
  /// le back-office, qui ne connaît que cette référence-là. Le champ voyage
  /// depuis toujours dans l'affectation (`order_reference`) ; personne ne le
  /// lisait. Le repli sur l'identifiant court reste pour le cas, théorique,
  /// d'une commande sans référence.
  String get reference => assignment.orderReference.isNotEmpty
      ? assignment.orderReference
      : assignmentId.substring(0, assignmentId.length.clamp(0, 8)).toUpperCase();

  /// Étapes que le serveur autorise depuis l'état courant. C'est la source des
  /// boutons à afficher : la machine à états n'est pas rejouée côté client.
  List<String> get allowedTransitions => assignment.allowedTransitions;

  EtapeCourse get etape => EtapeCourse.depuisServeur(assignment.status);

  /// La prochaine étape que le livreur peut demander, ou `null` s'il n'y en a
  /// aucune.
  ///
  /// ## Pourquoi cette lecture, et pas un `switch` sur [etape]
  ///
  /// Les trois écrans rejouaient la machine à états côté client, chacun avec
  /// son propre `switch`, et chacun avec un trou différent : l'écran des
  /// livraisons n'avait pas de cas pour `acceptee`, si bien que son bouton
  /// « Suivant » ne faisait rien sur une course fraîchement acceptée ;
  /// l'écran de suivi proposait « Livré » dès l'acceptation, une transition
  /// que le serveur refuse (la machine est acyclique et sans raccourci).
  ///
  /// `allowed_transitions` est calculé par `DELIVERY_MACHINE.targets_from` et
  /// rendu sur chaque affectation. C'est **la** source des boutons : la table
  /// des transitions ne se recopie pas, elle se lit.
  ///
  /// Les issues qui ne sont pas une progression — refus, annulation — en sont
  /// exclues : elles ont leurs propres gestes, avec leurs propres
  /// confirmations, et ne doivent jamais tomber sous le bouton « suivant ».
  EtapeCourse? get prochaineEtape {
    for (final etape in const [
      EtapeCourse.recuperee,
      EtapeCourse.enRoute,
      EtapeCourse.livree,
    ]) {
      if (allowedTransitions.contains(etape.versServeur)) return etape;
    }
    return null;
  }

  /// Le serveur accepte-t-il que je prenne cette course ?
  bool get peutAccepter =>
      allowedTransitions.contains(eccore.DeliveryStatus.accepted);

  /// Le serveur accepte-t-il que je la refuse ?
  ///
  /// Refuser est un geste distinct de l'annulation : décliner une proposition
  /// n'incrémente pas le compteur d'annulations du livreur.
  bool get peutRefuser =>
      allowedTransitions.contains(eccore.DeliveryStatus.declined);

  /// Point de retrait — l'établissement, tel que le serveur le situe.
  ///
  /// Ces quatre coordonnées voyagent dans chaque affectation
  /// (`pickup_location`, `delivery_location`, obligatoires côté serveur).
  /// L'écran de suivi les ignorait : il géocodait la **chaîne** d'adresse de
  /// livraison, et plaçait le restaurant sur un point écrit en dur.
  double get latitudeRetrait => assignment.pickupLatitude;
  double get longitudeRetrait => assignment.pickupLongitude;

  /// Point de dépôt — l'adresse du client, telle que la commande la porte.
  double get latitudeLivraison => assignment.deliveryLatitude;
  double get longitudeLivraison => assignment.deliveryLongitude;

  /// Le livreur a-t-il déjà le repas en main ?
  ///
  /// Décide de la destination à afficher : le restaurant avant la
  /// récupération, le client après. Envoyer un livreur chez le client alors
  /// qu'il n'a pas encore récupéré la commande est le défaut le plus coûteux
  /// que puisse commettre un écran de navigation.
  bool get repasRecupere =>
      assignment.status == eccore.DeliveryStatus.pickedUp ||
      assignment.status == eccore.DeliveryStatus.onTheWay ||
      assignment.status == eccore.DeliveryStatus.delivered;

  MoyenPaiement get moyenPaiement => MoyenPaiement.depuisServeur(
    assignment.paymentMethod.isNotEmpty ? assignment.paymentMethod : commande?.paymentMethod,
  );

  /// Ce qu'il faut encaisser à la porte — nul quand la commande est déjà payée.
  ///
  /// Porté par la course elle-même : une course proposée ou livrée n'a pas
  /// toujours sa commande relue, et un livreur qui part sans connaître le
  /// montant l'apprend du client, sur le pas de la porte.
  eccore.Money? get aEncaisser => assignment.amountToCollect;

  /// Zone et ville de livraison, figées sur la commande — vides d'un serveur
  /// antérieur.
  String get zoneLivraison => [
    assignment.deliveryZoneName,
    assignment.cityName,
  ].where((partie) => partie.isNotEmpty).join(', ');

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
    final texte = assignment.deliveryInstructions;
    return texte.isEmpty ? null : texte;
  }

  List<eccore.AssignmentItem> get articles => assignment.items;

  eccore.Money? get total => assignment.orderTotal;

  /// Moment où la commande a été passée, à défaut celui où la course a été
  /// proposée — l'historique n'a que le second.
  DateTime get passeeLe => assignment.offeredAt;

  DateTime? get livraisonEstimeeA => assignment.estimatedDeliveryAt;

  /// Moment où la course a été **livrée**, tel que le serveur l'a horodaté.
  ///
  /// C'est la date qui compte pour les gains et l'historique. Ils se
  /// fondaient sur [passeeLe], c'est-à-dire, pour une course livrée dont le
  /// détail n'est plus relu, sur `offered_at` — le moment où la course a été
  /// *proposée*. Une course proposée à 23 h 50 et livrée à 00 h 10 tombait
  /// donc dans les gains de la veille, et le total du jour ne correspondait
  /// à aucune journée de travail.
  DateTime? get livreeLe => assignment.deliveredAt;

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
      _tracking = eccore.TrackingRepository(apiClient: apiClient);

  final eccore.DeliveryRepository _delivery;
  final eccore.TrackingRepository _tracking;

  /// Dépose une candidature de livreur — **la seule méthode sans session**.
  ///
  /// Elle ne rend aucun jeton : le serveur s'y refuse pour que la saisie du
  /// code reste une étape obligée. La session s'ouvre ensuite par
  /// `AppService.verifierCompte`.
  Future<eccore.CourierApplicationReceipt> apply(eccore.CourierApplication application) =>
      _delivery.apply(application);

  /// Le dossier du livreur connecté.
  Future<eccore.CourierProfile> profile() => _delivery.me();

  /// Dépose des pièces justificatives — `POST /delivery/me/`, en `multipart`.
  ///
  /// Les trois emplacements sont facultatifs : on remplace ce qu'on remplace,
  /// et une pièce omise reste celle qui est déjà en place. Il en faut au moins
  /// une — le serveur refuse un dépôt vide plutôt que de rendre 200 sur une
  /// requête qui n'a rien déposé.
  ///
  /// Les noms français correspondent aux trois champs du contrat, dans l'ordre
  /// où l'écran les demande : `id_document`, `licence_document`,
  /// `vehicle_document`.
  ///
  /// Rend le dossier **à jour**, statut compris : un dépôt rouvre l'instruction
  /// d'un dossier validé ou refusé (L5), et le résultat se lit au lieu d'être
  /// supposé.
  Future<eccore.CourierProfile> deposerPieces({
    eccore.PieceJustificative? identite,
    eccore.PieceJustificative? permis,
    eccore.PieceJustificative? carteGrise,
  }) => _delivery.submitDocuments(
    idDocument: identite,
    licenceDocument: permis,
    vehicleDocument: carteGrise,
  );

  /// Corrige les champs descriptifs du dossier — `PATCH /delivery/me/`.
  ///
  /// Ne rouvre pas l'instruction, contrairement à [deposerPieces].
  Future<eccore.CourierProfile> corrigerDossier({
    String? vehicleType,
    String? vehiclePlate,
    String? nationalIdNumber,
    String? licenceNumber,
  }) => _delivery.updateMe(
    vehicleType: vehicleType,
    vehiclePlate: vehiclePlate,
    nationalIdNumber: nationalIdNumber,
    licenceNumber: licenceNumber,
  );

  /// Les gains agrégés par le serveur — voir `eccore.Earnings`.
  ///
  /// À préférer toujours à une somme faite sur les courses chargées : celles-ci
  /// sont bornées à quelques pages, et le total mensuel s'en trouvait tronqué.
  Future<eccore.Earnings> earnings() => _delivery.earnings();

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
    return assignments.map((assignment) => Course(assignment: assignment)).toList(growable: false);
  }

  Future<Course> loadCourse(String assignmentId) async {
    return Course(assignment: await _delivery.getById(assignmentId));
  }

  /// L2 — l'acceptation est exclusive côté serveur : deux livreurs sur la même
  /// commande, le second reçoit un refus métier. L'appelant ne doit donc rien
  /// afficher comme acquis avant que ce futur ne soit résolu.
  Future<Course> accept(String assignmentId) async {
    return Course(assignment: await _delivery.accept(assignmentId));
  }

  Future<Course> decline(String assignmentId, {String reason = ''}) async {
    return Course(assignment: await _delivery.decline(assignmentId, reason: reason));
  }

  /// Fait avancer la course. [target] doit venir de [Course.allowedTransitions].
  Future<Course> advanceTo(String assignmentId, String target) async {
    return Course(assignment: await _delivery.transitionTo(assignmentId, target));
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

}
