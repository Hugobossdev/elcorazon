import '../models/money.dart';

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
    this.idDocument,
    this.licenceDocument,
    this.vehicleDocument,
    required this.vehicleType,
    required this.isOnline,
    required this.canAcceptOrders,
    required this.deliveriesCompleted,
    required this.deliveriesCancelled,
    required this.ratingAverage,
    required this.ratingCount,
    required this.createdAt,
    required this.updatedAt,
    this.verificationNotes = '',
    this.verifiedAt,
    this.vehiclePlate = '',
    this.lastLatitude,
    this.lastLongitude,
    this.lastLocationAt,
    this.totalEarnings,
  });

  factory CourierProfile.fromJson(Map<String, dynamic> json) {
    final location = json['last_location'] as Map<String, dynamic>?;
    final earnings = json['total_earnings'] as Map<String, dynamic>?;
    return CourierProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      restaurantSlug: json['restaurant'] as String,
      verificationStatus: json['verification_status'] as String,
      idDocument: json['id_document'] as String?,
      licenceDocument: json['licence_document'] as String?,
      vehicleDocument: json['vehicle_document'] as String?,
      verificationNotes: json['verification_notes'] as String? ?? '',
      verifiedAt: _parseDate(json['verified_at']),
      vehicleType: json['vehicle_type'] as String,
      vehiclePlate: json['vehicle_plate'] as String? ?? '',
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
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String fullName;
  final String email;

  /// Établissement de rattachement, par son slug.
  final String restaurantSlug;

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
  bool get hasAllDocuments =>
      idDocument != null && licenceDocument != null && vehicleDocument != null;
  final DateTime? verifiedAt;
  final String vehicleType;
  final String vehiclePlate;

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
