import 'package:dio/dio.dart';

import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/delivery/assignment.dart';
import 'package:elcorazon_core/src/delivery/courier_application.dart';
import 'package:elcorazon_core/src/delivery/courier_profile.dart';
import 'package:elcorazon_core/src/delivery/earnings.dart';

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
/// Une pièce justificative prête à partir — des **octets**, pas un chemin.
///
/// `MultipartFile.fromFile` échoue sur le web, où un fichier choisi n'a pas de
/// chemin lisible, et le projet vise aussi le navigateur. Lire les octets
/// fonctionne partout, au prix de tenir la pièce en mémoire — ce qui est sans
/// conséquence pour une photo de permis, et ce que fait déjà l'envoi d'image du
/// catalogue.
///
/// [contentType] est facultatif mais utile : sans lui le serveur reçoit
/// `application/octet-stream`, que le stockage range comme un fichier brut
/// plutôt que comme une image — et l'écran de validation du back-office ne sait
/// alors plus l'afficher en vignette.
class PieceJustificative {
  const PieceJustificative({
    required this.filename,
    required this.bytes,
    this.contentType,
  });

  final String filename;
  final List<int> bytes;

  /// `image/jpeg`, `image/png`, `application/pdf`…
  final String? contentType;

  MultipartFile versMultipart() => MultipartFile.fromBytes(
    bytes,
    filename: filename,
    contentType: contentType == null ? null : DioMediaType.parse(contentType!),
  );
}


class DeliveryRepository {
  DeliveryRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Dépose une candidature de livreur (`POST /delivery/apply/`).
  ///
  /// La seule méthode de ce dépôt qui s'appelle **sans session** — on n'a par
  /// construction pas encore de compte. Elle ne rend aucun jeton : le serveur
  /// s'y refuse pour que l'écran de saisie du code ne soit pas une étape que
  /// le client pourrait sauter. La session s'ouvre ensuite par
  /// `SessionNotifier.verifyAccount`.
  ///
  /// Le dossier créé est **en attente** : le candidat pourra se connecter, pas
  /// accepter de course. C'est `can_accept_orders`, calculé par le serveur, qui
  /// tranche (L1) — jamais l'application.
  Future<CourierApplicationReceipt> apply(CourierApplication application) async {
    final response = await apiClient.post('/delivery/apply/', data: application.toJson());
    return CourierApplicationReceipt.fromJson(response.data as Map<String, dynamic>);
  }

  /// Le dossier du livreur qui appelle (`/delivery/me/`).
  Future<CourierProfile> me() async {
    final response = await apiClient.get('/delivery/me/');
    return CourierProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Dépose des pièces justificatives (`POST /delivery/me/`, `multipart`).
  ///
  /// ## Pourquoi cette méthode a manqué si longtemps
  ///
  /// La route existe côté serveur depuis l'origine et n'avait **aucun
  /// appelant** : aucune des trois applications ne savait téléverser une pièce.
  /// Le dossier d'un livreur ne pouvait donc jamais être complété — l'écran
  /// d'attente lui annonçait qu'El Corazón vérifiait des pièces qui n'avaient
  /// jamais été envoyées, et l'écran de validation du back-office montrait trois
  /// emplacements vides pour tout le monde.
  ///
  /// ## Ce que le dépôt déclenche
  ///
  /// **Il rouvre l'instruction du dossier** quand celui-ci était validé ou
  /// refusé (L5), et remet le livreur hors ligne. Ce n'est pas un effet de
  /// bord : un dossier validé sur des pièces qu'on a remplacées n'est plus
  /// validé, et un dossier refusé qui ne repasserait pas en attente resterait
  /// hors de la file d'instruction — le livreur corrigerait dans le vide.
  ///
  /// Un dossier **suspendu** reste suspendu : une sanction ne se lève pas en
  /// téléversant une carte grise.
  ///
  /// Les trois pièces sont facultatives — on remplace ce qu'on remplace — mais
  /// il en faut au moins une, sinon le serveur refuse en 400 plutôt que de
  /// rendre 200 sur un dépôt qui n'a rien déposé.
  ///
  /// Rend le dossier à jour : y lire `verificationStatus` plutôt que de
  /// supposer ce que le dépôt a produit.
  Future<CourierProfile> submitDocuments({
    PieceJustificative? idDocument,
    PieceJustificative? licenceDocument,
    PieceJustificative? vehicleDocument,
  }) async {
    final champs = <String, MultipartFile>{
      if (idDocument != null) 'id_document': idDocument.versMultipart(),
      if (licenceDocument != null) 'licence_document': licenceDocument.versMultipart(),
      if (vehicleDocument != null) 'vehicle_document': vehicleDocument.versMultipart(),
    };
    if (champs.isEmpty) {
      throw ArgumentError('Aucune pièce à déposer : fournissez-en au moins une.');
    }

    final response = await apiClient.post('/delivery/me/', data: FormData.fromMap(champs));
    return CourierProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Corrige les champs **descriptifs** du dossier (`PATCH /delivery/me/`).
  ///
  /// Le véhicule qu'il conduit, sa plaque, et les deux numéros que portent ses
  /// pièces : ce que le livreur est seul à connaître. Le reste du dossier lui
  /// est fermé côté serveur — en particulier `verificationStatus`, dont
  /// dépend l'invariant L1, et les compteurs, qui sont des agrégats de faits.
  ///
  /// **Ne rouvre pas l'instruction**, contrairement à [submitDocuments] : c'est
  /// la pièce qu'un instructeur lit, pas le champ texte à côté. Remettre un
  /// dossier en attente parce qu'une plaque a perdu un tiret suspendrait un
  /// livreur en pleine tournée.
  ///
  /// Le nom et le téléphone ne passent **pas** par ici : ils appartiennent au
  /// compte, et `PATCH /auth/me/` les porte pour tous les types de comptes.
  ///
  /// Une chaîne vide efface la valeur ; `null` signifie « ne pas y toucher ».
  /// Au moins un champ doit être fourni.
  Future<CourierProfile> updateMe({
    String? vehicleType,
    String? vehiclePlate,
    String? nationalIdNumber,
    String? licenceNumber,
  }) async {
    final champs = <String, String>{
      if (vehicleType != null) 'vehicle_type': vehicleType,
      if (vehiclePlate != null) 'vehicle_plate': vehiclePlate,
      if (nationalIdNumber != null) 'national_id_number': nationalIdNumber,
      if (licenceNumber != null) 'licence_number': licenceNumber,
    };
    if (champs.isEmpty) {
      throw ArgumentError('Aucun champ à corriger.');
    }

    final response = await apiClient.patch('/delivery/me/', data: champs);
    return CourierProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Les gains du livreur, agrégés par le serveur (`/delivery/me/earnings/`).
  ///
  /// À préférer **toujours** à une somme faite sur [recentlyDelivered] : cette
  /// liste est bornée à quelques pages, et un total mensuel calculé dessus est
  /// silencieusement tronqué dès qu'un livreur travaille un peu. Voir
  /// [Earnings].
  Future<Earnings> earnings() async {
    final response = await apiClient.get('/delivery/me/earnings/');
    return Earnings.fromJson(response.data as Map<String, dynamic>);
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
  /// courses derrière lui, et les écrans qui s'en servent n'en montrent qu'une
  /// liste.
  ///
  /// **Ne rien totaliser à partir d'ici.** La borne était comprise comme « les
  /// jours écoulés », et l'écran des gains en tirait un total *mensuel* : trois
  /// pages de vingt, soit soixante courses, ce qui couvre six jours à dix
  /// courses par jour. Le montant affiché était donc plus petit que la réalité,
  /// sans que rien ne le signale. Les sommes se demandent à [earnings], qui les
  /// calcule en base sur la totalité de l'historique.
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
