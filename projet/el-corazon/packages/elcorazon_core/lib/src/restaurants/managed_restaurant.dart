import 'package:elcorazon_core/src/restaurants/restaurant_lifecycle.dart';

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
    required this.status,
    required this.isActive,
    required this.acceptsOrders,
    required this.defaultPreparationMinutes,
    this.ordersCount = 0,
    this.couriersCount = 0,
    this.menuItemsCount = 0,
    this.description = '',
    this.phone,
    this.email,
    this.coverImage,
    this.cityName = '',
    this.citySlug = '',
    this.countryIsoCode = '',
    this.zoneName = '',
    this.configurationGaps = const [],
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
      cityName: json['city'] as String? ?? '',
      citySlug: json['city_slug'] as String? ?? '',
      countryIsoCode: json['country'] as String? ?? '',
      zoneName: json['zone_name'] as String? ?? '',
      status: RestaurantLifecycle.fromCode(json['status'] as String),
      configurationGaps: (json['configuration_gaps'] as List<dynamic>? ?? const [])
          .map((phrase) => phrase as String)
          .toList(growable: false),
      isActive: json['is_active'] as bool? ?? false,
      acceptsOrders: json['accepts_orders'] as bool? ?? true,
      defaultPreparationMinutes: json['default_preparation_minutes'] as int,
      ordersCount: json['orders_count'] as int? ?? 0,
      couriersCount: json['couriers_count'] as int? ?? 0,
      menuItemsCount: json['menu_items_count'] as int? ?? 0,
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

  /// Ville, code pays et zone de rattachement — rendus par le serveur pour
  /// situer l'établissement sans trois appels de plus. Vides sur une réponse
  /// d'une version antérieure du contrat.
  final String cityName;
  final String citySlug;
  final String countryIsoCode;
  final String zoneName;

  /// Où en est l'établissement dans son provisionnement.
  ///
  /// C'est désormais la seule chose qu'on écrit : [isActive] en découle côté
  /// serveur. Un back-office qui basculerait le booléen verrait son effet
  /// annulé au prochain enregistrement.
  final RestaurantLifecycle status;

  /// Ce qui manque pour ouvrir au public, en clair — carte vide, horaires
  /// absents, aucun livreur approuvé, position hors de la zone.
  ///
  /// Calculée par le serveur à chaque lecture plutôt que stockée : elle dépend
  /// du catalogue, des horaires et de la flotte, qui changent sans passer par
  /// la fiche de l'établissement.
  final List<String> configurationGaps;

  /// Projection de [status] : vrai pour le seul état « en service ». Rendu par
  /// le serveur, jamais envoyé.
  final bool isActive;

  /// Prend-il des commandes **maintenant** ? C'est le drapeau du coup de feu,
  /// pas celui de la fermeture définitive.
  final bool acceptsOrders;

  final int defaultPreparationMinutes;

  /// Compteurs d'exploitation — la ligne de tableau du back-office.
  ///
  /// Comptés par le serveur en une requête annotée, jamais dérivés d'une liste
  /// chargée ici : le tableau de bord précédent téléchargeait les commandes
  /// pour les compter à l'écran, et le total ne portait que sur la page
  /// affichée.
  ///
  /// `menuItemsCount` exclut les articles retirés de la carte : « 43 produits »
  /// dont la moitié sont supprimés n'aide personne à décider si un
  /// établissement est prêt à ouvrir.
  ///
  /// Zéro par défaut plutôt que nul : la réponse d'une transition de statut
  /// rend l'objet sans ses annotations, et un affichage doit montrer « 0 »
  /// plutôt que disparaître.
  final int ordersCount;
  final int couriersCount;
  final int menuItemsCount;

  /// L'établissement est-il configuré au point de pouvoir ouvrir ?
  bool get isReadyToPublish => configurationGaps.isEmpty;

  /// « El Corazón — Abidjan », ou le seul nom quand la ville manque.
  String get label => cityName.isEmpty ? name : '$name — $cityName';
}
