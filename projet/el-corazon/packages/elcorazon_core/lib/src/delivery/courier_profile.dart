import 'package:elcorazon_core/src/models/money.dart';

/// Ce que le client voit du livreur qui lui apporte sa commande — miroir de
/// `CourierPublicSerializer` (`backend/apps/delivery/serializers.py`). Ni
/// téléphone, ni pièces, ni position : de quoi le reconnaître à la porte, pas
/// de quoi le suivre.
class CourierSummary {
  const CourierSummary({
    required this.id,
    required this.fullName,
    required this.vehicleType,
    required this.ratingAverage,
    required this.ratingCount,
    this.avatar,
  });

  factory CourierSummary.fromJson(Map<String, dynamic> json) {
    return CourierSummary(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      avatar: json['avatar'] as String?,
      vehicleType: json['vehicle_type'] as String,
      ratingAverage: double.parse('${json['rating_average']}'),
      ratingCount: json['rating_count'] as int,
    );
  }

  final String id;
  final String fullName;
  final String? avatar;

  /// `moto` | `velo` | `voiture` | ... (`VehicleType` côté serveur).
  final String vehicleType;
  final double ratingAverage;
  final int ratingCount;
}

/// Une zone de livraison nommée — l'identifiant pour écrire, le nom pour lire.
class ZoneRef {
  const ZoneRef({required this.id, required this.name});

  factory ZoneRef.fromJson(Map<String, dynamic> json) =>
      ZoneRef(id: json['id'].toString(), name: json['name'] as String? ?? '');

  final String id;
  final String name;
}

/// Dossier livreur complet — miroir de `CourierProfileSerializer`.
///
/// Tous les champs sont en lecture seule côté serveur, y compris
/// [verificationStatus], [deliveriesCompleted] et [totalEarnings] : un livreur
/// qui pourrait écrire son statut de dossier se validerait lui-même, et un
/// livreur qui pourrait écrire ses compteurs se paierait (invariants L1/L4).
/// Cette classe n'a donc volontairement pas de `toJson()` — il n'y a rien à
/// renvoyer.
class CourierProfile {
  const CourierProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.restaurantSlug,
    required this.verificationStatus,
    required this.vehicleType, required this.isOnline, required this.canAcceptOrders, required this.deliveriesCompleted, required this.deliveriesCancelled, required this.ratingAverage, required this.ratingCount, required this.createdAt, required this.updatedAt, this.idDocument,
    this.licenceDocument,
    this.vehicleDocument,
    this.verificationNotes = '',
    this.verifiedAt,
    this.vehiclePlate = '',
    this.nationalIdNumber = '',
    this.licenceNumber = '',
    this.lastLatitude,
    this.lastLongitude,
    this.lastLocationAt,
    this.totalEarnings,
    this.phone = '',
    this.serviceZones = const [],
  });

  factory CourierProfile.fromJson(Map<String, dynamic> json) {
    final location = json['last_location'] as Map<String, dynamic>?;
    final earnings = json['total_earnings'] as Map<String, dynamic>?;
    return CourierProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      // Rendu par `CourierProfileSerializer` au personnel et au titulaire du
      // dossier — jamais au client, qui joint son livreur par le canal d'appel
      // sans qu'aucun numéro personnel ne circule. Vide plutôt qu'absent : un
      // livreur peut ne pas en avoir déclaré.
      phone: json['phone'] as String? ?? '',
      restaurantSlug: json['restaurant'] as String,
      verificationStatus: json['verification_status'] as String,
      idDocument: json['id_document'] as String?,
      licenceDocument: json['licence_document'] as String?,
      vehicleDocument: json['vehicle_document'] as String?,
      verificationNotes: json['verification_notes'] as String? ?? '',
      verifiedAt: _parseDate(json['verified_at']),
      vehicleType: json['vehicle_type'] as String,
      vehiclePlate: json['vehicle_plate'] as String? ?? '',
      nationalIdNumber: json['national_id_number'] as String? ?? '',
      licenceNumber: json['licence_number'] as String? ?? '',
      isOnline: json['is_online'] as bool,
      canAcceptOrders: json['can_accept_orders'] as bool,
      lastLatitude: location == null ? null : (location['lat'] as num).toDouble(),
      lastLongitude: location == null ? null : (location['lon'] as num).toDouble(),
      lastLocationAt: _parseDate(json['last_location_at']),
      deliveriesCompleted: json['deliveries_completed'] as int,
      deliveriesCancelled: json['deliveries_cancelled'] as int,
      ratingAverage: double.parse('${json['rating_average']}'),
      ratingCount: json['rating_count'] as int,
      totalEarnings: earnings == null ? null : Money.fromJson(earnings),
      serviceZones: (json['service_zones'] as List<dynamic>? ?? const [])
          .map((zone) => ZoneRef.fromJson(zone as Map<String, dynamic>))
          .toList(growable: false),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String fullName;
  final String email;

  /// Téléphone du livreur — pour le personnel qui doit le joindre quand une
  /// course coince. Vide s'il n'en a pas déclaré.
  ///
  /// Absent de [CourierSummary], qui est ce qu'un **client** voit de son
  /// livreur : le joindre pendant la course passe par le canal d'appel
  /// (`apps.calls`), sans qu'aucun numéro personnel ne circule.
  final String phone;

  /// Établissement de rattachement, par son slug.
  final String restaurantSlug;

  /// Zones où il roule. **Vide : toutes celles que dessert sa cuisine** — le
  /// cas courant. Renseignée, la liste restreint les courses qu'il reçoit.
  final List<ZoneRef> serviceZones;

  /// `pending` | `approved` | `rejected` | `suspended` (`VerificationStatus`).
  final String verificationStatus;
  final String verificationNotes;

  /// Pièces justificatives — URL **signées**, qui expirent.
  ///
  /// Le stockage est privé : ces adresses ne se mettent ni en cache ni en
  /// favori. L'implémentation précédente les déposait dans un compartiment
  /// public, où une pièce d'identité restait lisible indéfiniment par
  /// quiconque connaissait l'adresse.
  ///
  /// Elles ne s'écrivent pas depuis le back-office : c'est le livreur qui
  /// dépose ses pièces, et tout dépôt repasse le dossier en attente (L5).
  final String? idDocument;
  final String? licenceDocument;
  final String? vehicleDocument;

  /// Le dossier porte-t-il ses trois pièces ?
  bool get hasAllDocuments => piecesManquantes.isEmpty;

  /// Les pièces qui manquent encore, par leur nom de champ au contrat.
  ///
  /// Ce que l'écran de dépôt affiche, et ce qui décide s'il y a lieu de le
  /// proposer. Les valeurs sont celles qu'attend `DocumentsSerializer` —
  /// `id_document`, `licence_document`, `vehicle_document` — et non des
  /// libellés : ce sont des identifiants d'API, et les traduire ici ferait
  /// refuser le dépôt.
  ///
  /// L'ordre est celui dans lequel on les demande : la pièce d'identité
  /// d'abord, parce qu'elle conditionne l'examen des deux autres.
  List<String> get piecesManquantes => [
    if (idDocument == null || idDocument!.isEmpty) 'id_document',
    if (licenceDocument == null || licenceDocument!.isEmpty) 'licence_document',
    if (vehicleDocument == null || vehicleDocument!.isEmpty) 'vehicle_document',
  ];

  final DateTime? verifiedAt;
  final String vehicleType;
  final String vehiclePlate;

  /// Numéro de la pièce d'identité, tel qu'il a été enregistré. Vide s'il ne
  /// l'a pas été.
  ///
  /// Distinct de [idDocument], qui est la **photo** de la pièce : le numéro se
  /// relit et se compare, l'image se regarde. Les deux se saisissent
  /// séparément, et le second ne remplace pas le premier.
  final String nationalIdNumber;

  /// Numéro du permis de conduire — même distinction avec [licenceDocument].
  final String licenceNumber;

  /// Bascule volontaire du livreur — ce qu'il déclare, pas ce qu'il peut.
  final bool isOnline;

  /// L1 — la seule condition d'éligibilité qui vaille : en ligne **et** dossier
  /// validé **et** compte actif. Elle est calculée par le serveur ; ne jamais
  /// la recomposer à partir de [isOnline] et [verificationStatus], c'est
  /// exactement la duplication de règle métier que la Phase 6 supprime.
  final bool canAcceptOrders;
  final double? lastLatitude;
  final double? lastLongitude;
  final DateTime? lastLocationAt;
  final int deliveriesCompleted;
  final int deliveriesCancelled;
  final double ratingAverage;
  final int ratingCount;
  final Money? totalEarnings;
  final DateTime createdAt;
  final DateTime updatedAt;

  static DateTime? _parseDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}
