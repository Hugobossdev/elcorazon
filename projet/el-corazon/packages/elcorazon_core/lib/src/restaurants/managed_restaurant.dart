/// Établissement vu de l'exploitation — miroir de `ManagedRestaurantSerializer`
/// (`backend/apps/restaurants/serializers.py`).
///
/// C'est la réponse à une question que le back-office se posait jusqu'ici en
/// écrivant `el-corazon-lome` dans cinq fichiers : **sur quoi ce compte
/// travaille-t-il ?** Le serveur le sait — `ManagedRestaurantViewSet` filtre
/// sur le périmètre du personnel connecté — et il le dit sur
/// `/restaurants/manage/`. Une constante ne le savait que pour une enseigne, et
/// se trompait pour toutes les autres.
///
/// `isActive` et `acceptsOrders` sont tous les deux repris, et les confondre
/// perdrait l'information : le premier dit si l'établissement existe, le second
/// s'il prend des commandes maintenant.
///
/// La devise et le fuseau ne sont pas modifiables (ADR-006, hérités du pays à
/// travers la zone) mais sont rendus : un montant affiché sans sa devise, ou
/// une heure d'ouverture sans son fuseau, ne veulent rien dire.
class ManagedRestaurant {
  const ManagedRestaurant({
    required this.id,
    required this.name,
    required this.slug,
    required this.zoneId,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.currency,
    required this.timezone,
    required this.isActive,
    required this.acceptsOrders,
    required this.defaultPreparationMinutes,
    this.description = '',
    this.phone,
    this.email,
    this.coverImage,
  });

  factory ManagedRestaurant.fromJson(Map<String, dynamic> json) {
    // `LocationField` rend `{"lat": …, "lon": …}` — nommé, parce que PostGIS
    // attend `Point(x=lon, y=lat)` et que l'ordre positionnel est le piège
    // classique. On l'aplatit ici comme le font `Order` et `CourierProfile`.
    final location = json['location'] as Map<String, dynamic>;

    return ManagedRestaurant(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String? ?? '',
      zoneId: json['zone'].toString(),
      address: json['address'] as String? ?? '',
      latitude: (location['lat'] as num).toDouble(),
      longitude: (location['lon'] as num).toDouble(),
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      coverImage: json['cover_image'] as String?,
      currency: json['currency'] as String,
      timezone: json['timezone'] as String,
      isActive: json['is_active'] as bool? ?? true,
      acceptsOrders: json['accepts_orders'] as bool? ?? true,
      defaultPreparationMinutes: json['default_preparation_minutes'] as int,
    );
  }

  final String id;
  final String name;

  /// Identifiant fonctionnel de l'établissement dans les URL et les corps de
  /// requête (`restaurant__slug`, `restaurant`). C'est lui que le back-office
  /// écrivait en dur.
  final String slug;

  final String description;
  final String zoneId;
  final String address;

  /// Position de l'établissement. La carte de supervision s'ouvre dessus —
  /// elle s'ouvrait auparavant sur une coordonnée écrite dans le code, celle
  /// de Dakar, à deux mille kilomètres du restaurant qu'elle prétendait
  /// montrer.
  final double latitude;
  final double longitude;

  final String? phone;
  final String? email;
  final String? coverImage;

  /// Hérités du pays à travers la zone (ADR-006) : lecture seule côté serveur.
  final String currency;
  final String timezone;

  /// L'établissement existe-t-il encore ? Un établissement inactif reste
  /// visible du siège et disparaît des applications clientes.
  final bool isActive;

  /// Prend-il des commandes **maintenant** ? C'est le drapeau du coup de feu,
  /// pas celui de la fermeture définitive.
  final bool acceptsOrders;

  final int defaultPreparationMinutes;
}
