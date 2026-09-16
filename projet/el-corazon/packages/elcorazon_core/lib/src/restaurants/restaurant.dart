/// Un établissement tel que le public le voit — miroir de `RestaurantSerializer`
/// (`backend/apps/restaurants/serializers.py`), servi par `GET /restaurants/`.
///
/// ## Pourquoi ce modèle existe
///
/// L'application cliente n'appelait pas cette route. Elle portait à la place
/// six constantes — le slug de l'établissement, sa latitude, sa longitude, le
/// slug de sa ville, le nom de cette ville et le code de son pays — recopiées à
/// travers une trentaine d'appels. Chacune était juste pour un seul
/// établissement et fausse pour tous les autres, si bien qu'ouvrir un second
/// restaurant demandait de modifier le code de l'application, de la recompiler
/// et de la republier sur deux magasins.
///
/// Tout ce que ces constantes disaient est ici, rendu par le serveur.
///
/// ## Un verdict et son motif
///
/// [canOrderNow] est la réponse du juge de disponibilité du serveur, et
/// [unavailableCode] dit pourquoi elle est négative : « fermé » n'est pas
/// « débordé, réessayez dans dix minutes », et les deux n'appellent pas le même
/// geste de la part du client. L'application compare le code ; elle ne
/// recompose plus la règle à partir de [isOpen] et [acceptsOrders], qui restent
/// des informations — les horaires, le drapeau du coup de feu — et non des
/// conditions à assembler.
class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.slug,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.cityName,
    required this.citySlug,
    required this.countryIsoCode,
    required this.currency,
    required this.estimatedDeliveryMinutes,
    required this.defaultPreparationMinutes,
    required this.isOpen,
    required this.acceptsOrders,
    required this.canOrderNow,
    this.unavailableCode = '',
    this.unavailableReason = '',
    this.isTemporarilyClosed = false,
    this.reopensAt,
    this.reopensLabel = '',
    this.description = '',
    this.phone,
    this.phonePrefix = '',
    this.coverImage,
    this.distanceMeters,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    // `LocationField` rend `{"lat": …, "lon": …}` — nommé, parce que PostGIS
    // attend `Point(x=lon, y=lat)` et que l'ordre positionnel est le piège
    // classique.
    final location = json['location'] as Map<String, dynamic>?;

    return Restaurant(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: location == null ? 0 : (location['lat'] as num).toDouble(),
      longitude: location == null ? 0 : (location['lon'] as num).toDouble(),
      cityName: json['city'] as String? ?? '',
      citySlug: json['city_slug'] as String? ?? '',
      countryIsoCode: json['country'] as String? ?? '',
      phonePrefix: json['phone_prefix'] as String? ?? '',
      phone: json['phone'] as String?,
      coverImage: json['cover_image'] as String?,
      currency: json['currency'] as String? ?? '',
      estimatedDeliveryMinutes: json['estimated_delivery_minutes'] as int? ?? 0,
      defaultPreparationMinutes: json['default_preparation_minutes'] as int? ?? 0,
      isOpen: json['is_open'] as bool? ?? false,
      acceptsOrders: json['accepts_orders'] as bool? ?? false,
      canOrderNow: json['can_order_now'] as bool? ?? false,
      unavailableCode: json['unavailable_code'] as String? ?? '',
      unavailableReason: json['unavailable_reason'] as String? ?? '',
      isTemporarilyClosed: json['is_temporarily_closed'] as bool? ?? false,
      reopensAt: DateTime.tryParse(json['reopens_at'] as String? ?? ''),
      reopensLabel: json['reopens_label'] as String? ?? '',
      // Absent quand la requête ne portait pas de point de référence.
      // Volontairement laissé nul plutôt que ramené à `0` : un zéro inventé
      // ferait croire à une proximité qu'on n'a pas mesurée.
      distanceMeters: (json['distance_m'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String name;

  /// Identifiant fonctionnel dans les URL et les corps de requête
  /// (`restaurant__slug`, `restaurant`). C'est lui que l'application cliente
  /// portait en constante.
  final String slug;

  final String description;
  final String address;

  /// Point de retrait des courses, et **origine du calcul de distance**.
  ///
  /// L'application le lisait dans ses constantes, où il désignait le premier
  /// établissement : la carte d'adresse dessinait donc ses cercles de
  /// couverture autour de Lomé, quel que soit le restaurant regardé.
  final double latitude;
  final double longitude;

  final String cityName;

  /// Clé de la ville, pour rattacher une adresse. Le nom ne suffit pas : deux
  /// villes homonymes de deux pays ne se distinguent que par là.
  final String citySlug;

  /// Code ISO 3166-1 alpha-2, en majuscules. Borne l'autocomplétion de lieux
  /// au bon pays — l'application la bornait à `ci` en dur, si bien qu'un
  /// client de Lomé ne recevait aucune suggestion.
  final String countryIsoCode;

  /// Indicatif du pays (`+228`), pour les champs de saisie téléphonique.
  final String phonePrefix;

  final String? phone;
  final String? coverImage;

  /// Devise héritée du pays (ADR-006), jamais choisie par l'établissement.
  final String currency;

  final int estimatedDeliveryMinutes;
  final int defaultPreparationMinutes;

  /// Dans une plage d'ouverture, **horaires seulement**.
  final bool isOpen;

  /// Prend-il des commandes maintenant ? Le drapeau du coup de feu.
  final bool acceptsOrders;

  /// Le verdict du serveur : l'établissement prend-il une commande maintenant ?
  /// C'est ce que teste un bouton « Commander ».
  final bool canOrderNow;

  /// Pourquoi [canOrderNow] est faux — une constante de
  /// `MotifIndisponibilite`, vide sinon.
  final String unavailableCode;

  /// La phrase à afficher quand [canOrderNow] est faux, vide sinon.
  final String unavailableReason;

  /// Fermée par une fermeture exceptionnelle datée — un jour férié, des travaux.
  final bool isTemporarilyClosed;

  /// Premier instant où elle rouvre, quand elle est fermée et que le serveur
  /// le connaît ; nul sinon, ou d'un serveur antérieur à ce champ.
  final DateTime? reopensAt;

  /// Cette réouverture en toutes lettres — « demain à 11 h 00 » —, **composée
  /// par le serveur dans le fuseau du pays** : l'horloge du téléphone n'est
  /// pas celle de la cuisine. Vide quand il n'y a rien à annoncer.
  final String reopensLabel;

  /// « Fermé — réouverture demain à 11 h 00 », « Ouvert », « Commandes en pause ».
  ///
  /// L'étiquette courte d'une cuisine, pour une carte ou un en-tête. La phrase
  /// longue reste [unavailableReason].
  String get statusLabel {
    if (canOrderNow) return 'Ouvert';
    final reouverture = reopensLabel.isEmpty ? '' : ' — réouverture $reopensLabel';
    return switch (unavailableCode) {
      'kitchen_temporarily_closed' => 'Fermé exceptionnellement$reouverture',
      'kitchen_closed' => 'Fermé$reouverture',
      'kitchen_paused' => 'Commandes en pause',
      'kitchen_suspended' => 'Indisponible',
      _ => 'Indisponible',
    };
  }

  /// Distance depuis le point de référence de la requête, en mètres, ou `null`
  /// si la requête n'en portait pas.
  final double? distanceMeters;

  /// « El Corazón — Lomé », ou le seul nom quand la ville manque.
  String get label => cityName.isEmpty ? name : '$name — $cityName';
}
