/// Adresse du carnet client — miroir de `AddressSerializer`
/// (`backend/apps/profiles/serializers.py`). `location` est obligatoire côté
/// serveur : ne construire cette classe, côté écriture, que pour une adresse
/// dont le géocodage a réussi (voir `DjangoAddressRepository` dans l'app
/// `fastfood`).
class Address {
  const Address({
    required this.label,
    required this.kind,
    required this.line1,
    required this.city,
    required this.latitude,
    required this.longitude,
    this.id,
    this.recipientName = '',
    this.recipientPhone = '',
    this.line2 = '',
    this.landmark = '',
    this.cityName,
    this.deliveryInstructions = '',
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>;
    return Address(
      id: json['id'] as String,
      label: json['label'] as String,
      kind: json['kind'] as String,
      recipientName: json['recipient_name'] as String? ?? '',
      recipientPhone: json['recipient_phone'] as String? ?? '',
      line1: json['line1'] as String,
      line2: json['line2'] as String? ?? '',
      landmark: json['landmark'] as String? ?? '',
      city: json['city'] as String,
      cityName: json['city_name'] as String?,
      latitude: (location['lat'] as num).toDouble(),
      longitude: (location['lon'] as num).toDouble(),
      deliveryInstructions: json['delivery_instructions'] as String? ?? '',
      isDefault: json['is_default'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// `null` avant création côté serveur.
  final String? id;
  final String label;

  /// `home` | `work` | `other` (`AddressKind` côté serveur).
  final String kind;
  final String recipientName;
  final String recipientPhone;
  final String line1;
  final String line2;
  final String landmark;

  /// Id (UUID) de la `City` — résolu via `GeographyRepository.getCities()`.
  final String city;
  final String? cityName;
  final double latitude;
  final double longitude;
  final String deliveryInstructions;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Forme d'écriture (`POST`/`PATCH`) — sans les champs en lecture seule.
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'kind': kind,
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'line1': line1,
      'line2': line2,
      'landmark': landmark,
      'city': city,
      'location': {'lat': latitude, 'lon': longitude},
      'delivery_instructions': deliveryInstructions,
      'is_default': isDefault,
    };
  }
}
