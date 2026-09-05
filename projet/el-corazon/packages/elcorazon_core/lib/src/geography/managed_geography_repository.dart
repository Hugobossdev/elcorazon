import 'package:elcorazon_core/src/models/money.dart';
import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/geography/delivery_zone.dart';
import 'package:elcorazon_core/src/geography/managed_city.dart';
import 'package:elcorazon_core/src/geography/managed_country.dart';

/// Géographie du back-office — `/api/v1/geography/manage/*`
/// (`backend/apps/geography/backoffice.py`), réservée au **siège**.
///
/// Séparé de [GeographyRepository], qui rend au visiteur la liste des villes
/// desservies : ici on écrit des contours et des barèmes, c'est-à-dire ce que
/// paiera chaque client de la zone. Le serveur réserve ces routes aux comptes
/// non cloisonnés — une zone n'appartient à aucun établissement, et l'accorder
/// à qui a un périmètre étroit lui donnerait le pouvoir de tarifer les autres.
class ManagedGeographyRepository {
  ManagedGeographyRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Pays d'opération, **fermés compris**.
  ///
  /// Premier échelon de la hiérarchie et le seul qu'on ne pouvait pas ouvrir
  /// sans passer par `django-admin` : la route existait des deux côtés,
  /// personne ne l'appelait.
  Future<List<ManagedCountry>> countries({bool? isActive}) {
    return _collect(
      '/geography/manage/countries/',
      ManagedCountry.fromJson,
      queryParameters: {if (isActive != null) 'is_active': isActive.toString()},
    );
  }

  /// Ouvre un marché.
  ///
  /// [currency] et [timezone] engagent tout ce qui suivra : la devise est figée
  /// sur chaque commande passée dans ce pays, et le fuseau décide de l'heure à
  /// laquelle ses restaurants ouvrent. Les corriger après les premières
  /// commandes ne convertit rien — d'où leur présence ici, à l'ouverture, et
  /// non dans un écran de réglages.
  Future<ManagedCountry> createCountry({
    required String isoCode,
    required String name,
    required String currency,
    required String phonePrefix,
    required String timezone,
    String defaultLanguage = 'fr',
    bool isActive = true,
  }) async {
    final response = await apiClient.post(
      '/geography/manage/countries/',
      data: {
        'iso_code': isoCode.toUpperCase(),
        'name': name,
        'currency': currency.toUpperCase(),
        'phone_prefix': phonePrefix,
        'timezone': timezone,
        'default_language': defaultLanguage,
        'is_active': isActive,
      },
    );
    return ManagedCountry.fromJson(response.data as Map<String, dynamic>);
  }

  /// Modification partielle d'un pays — un paramètre omis n'est pas transmis.
  ///
  /// `currency` n'est volontairement pas modifiable ici. Le serveur l'accepte,
  /// mais rien ne se convertit rétroactivement : la changer sur un marché en
  /// activité laisserait le catalogue et l'historique dans deux unités. Fermer
  /// le pays et en ouvrir un autre est le geste qui correspond à l'intention.
  Future<ManagedCountry> updateCountry({
    required String isoCode,
    String? name,
    String? phonePrefix,
    String? timezone,
    String? defaultLanguage,
    bool? isActive,
  }) async {
    final response = await apiClient.patch(
      '/geography/manage/countries/${isoCode.toUpperCase()}/',
      data: {
        if (name != null) 'name': name,
        if (phonePrefix != null) 'phone_prefix': phonePrefix,
        if (timezone != null) 'timezone': timezone,
        if (defaultLanguage != null) 'default_language': defaultLanguage,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return ManagedCountry.fromJson(response.data as Map<String, dynamic>);
  }

  /// Ouvre une ville dans un pays.
  ///
  /// Le pays est désigné par son **code ISO** : c'est ce que le serveur attend
  /// (`SlugRelatedField(slug_field: "iso_code")`), et c'est ce qui rend
  /// impossible la combinaison incohérente que redoute l'exploitation — une
  /// ville ne peut pas appartenir à un autre pays que celui qu'on nomme ici,
  /// puisqu'elle n'a qu'une seule clé de rattachement.
  ///
  /// Le [centroid] centre une carte et trie par proximité ; il ne décide
  /// **jamais** d'une livrabilité, qui est le rôle du contour de la zone.
  Future<ManagedCity> createCity({
    required String countryIsoCode,
    required String name,
    required String slug,
    required double latitude,
    required double longitude,
    bool isActive = true,
  }) async {
    final response = await apiClient.post(
      '/geography/manage/cities/',
      data: {
        'country': countryIsoCode.toUpperCase(),
        'name': name,
        'slug': slug,
        'centroid': {'lat': latitude, 'lon': longitude},
        'is_active': isActive,
      },
    );
    return ManagedCity.fromJson(response.data as Map<String, dynamic>);
  }

  /// Modification partielle d'une ville.
  ///
  /// Le pays n'est pas modifiable ici : déplacer une ville d'un marché à un
  /// autre changerait la devise de ses zones et de leurs barèmes, donc le prix
  /// de commandes déjà passées. C'est une opération de reprise de données, pas
  /// un champ de formulaire.
  Future<ManagedCity> updateCity({
    required String cityId,
    String? name,
    String? slug,
    double? latitude,
    double? longitude,
    bool? isActive,
  }) async {
    if ((latitude == null) != (longitude == null)) {
      throw ArgumentError(
        'Une latitude seule ne situe rien : les deux coordonnées se fournissent ensemble.',
      );
    }

    final response = await apiClient.patch(
      '/geography/manage/cities/$cityId/',
      data: {
        if (name != null) 'name': name,
        if (slug != null) 'slug': slug,
        if (latitude != null && longitude != null)
          'centroid': {'lat': latitude, 'lon': longitude},
        if (isActive != null) 'is_active': isActive,
      },
    );
    return ManagedCity.fromJson(response.data as Map<String, dynamic>);
  }

  /// Villes, **fermées comprises**, pour la même raison que [zones].
  ///
  /// Le back-office s'en sert pour **nommer** la ville d'une zone : la zone ne
  /// porte que sa clé (`ManagedDeliveryZoneSerializer` sérialise `city` en
  /// `PrimaryKeyRelatedField`), et un écran qui doit choisir les quartiers
  /// desservis ne peut pas afficher un UUID à la place de « Lomé ».
  Future<List<ManagedCity>> cities({String? countryIsoCode, bool? isActive}) {
    return _collect(
      '/geography/manage/cities/',
      ManagedCity.fromJson,
      queryParameters: {
        if (countryIsoCode != null) 'country__iso_code': countryIsoCode.toUpperCase(),
        if (isActive != null) 'is_active': isActive.toString(),
      },
    );
  }

  /// Zones, **inactives comprises** : la liste publique les filtre, celle-ci
  /// les montre — sans quoi désactiver une zone la ferait disparaître de
  /// l'écran qui sert à la rouvrir.
  Future<List<DeliveryZone>> zones({String? citySlug, String? cityId, bool? isActive}) {
    return _collect(
      '/geography/manage/zones/',
      DeliveryZone.fromJson,
      queryParameters: {
        if (citySlug != null) 'city__slug': citySlug,
        if (cityId != null) 'city': cityId,
        if (isActive != null) 'is_active': isActive.toString(),
      },
    );
  }

  /// Crée une zone.
  ///
  /// [boundary] est du GeoJSON (`Polygon` ou `MultiPolygon`) — la forme que
  /// produisent les outils de dessin cartographique.
  Future<DeliveryZone> createZone({
    required String cityId,
    required String name,
    required Map<String, dynamic> boundary,
    required Money baseFee,
    required Money feePerKm,
    Money? freeDeliveryThreshold,
    Money? minOrderAmount,
    double maxDistanceKm = 15,
    int estimatedDeliveryMinutes = 30,
  }) async {
    final response = await apiClient.post(
      '/geography/manage/zones/',
      data: {
        'city': cityId,
        'name': name,
        'boundary': boundary,
        'base_fee': baseFee.toJson(),
        'fee_per_km': feePerKm.toJson(),
        if (freeDeliveryThreshold != null)
          'free_delivery_threshold': freeDeliveryThreshold.toJson(),
        if (minOrderAmount != null) 'min_order_amount': minOrderAmount.toJson(),
        'max_distance_km': maxDistanceKm,
        'estimated_delivery_minutes': estimatedDeliveryMinutes,
      },
    );
    return DeliveryZone.fromJson(response.data as Map<String, dynamic>);
  }

  /// Modification partielle d'une zone.
  ///
  /// Un paramètre omis n'est pas transmis : le `PATCH` ne touche que ce qu'on
  /// lui donne. D'où [clearFreeDeliveryThreshold] et [clearMinOrderAmount],
  /// qui n'ont l'air redondants que jusqu'à ce qu'on veuille **retirer** un
  /// seuil : passer `null` à `freeDeliveryThreshold` se confond avec « ne pas
  /// y toucher », si bien qu'une zone qui offrait la livraison au-dessus d'un
  /// montant ne pouvait plus cesser de le faire. Ces deux drapeaux envoient un
  /// `null` explicite, que le serveur accepte (`allow_null=True`).
  Future<DeliveryZone> updateZone({
    required String zoneId,
    String? name,
    Map<String, dynamic>? boundary,
    Money? baseFee,
    Money? feePerKm,
    Money? freeDeliveryThreshold,
    Money? minOrderAmount,
    double? maxDistanceKm,
    int? estimatedDeliveryMinutes,
    bool? isActive,
    bool clearFreeDeliveryThreshold = false,
    bool clearMinOrderAmount = false,
  }) async {
    if (clearFreeDeliveryThreshold && freeDeliveryThreshold != null) {
      throw ArgumentError(
        'Un seuil de franco ne peut pas être posé et retiré dans le même appel.',
      );
    }
    if (clearMinOrderAmount && minOrderAmount != null) {
      throw ArgumentError(
        'Un minimum de commande ne peut pas être posé et retiré dans le même appel.',
      );
    }

    final response = await apiClient.patch(
      '/geography/manage/zones/$zoneId/',
      data: {
        if (name != null) 'name': name,
        if (boundary != null) 'boundary': boundary,
        if (baseFee != null) 'base_fee': baseFee.toJson(),
        if (feePerKm != null) 'fee_per_km': feePerKm.toJson(),
        if (freeDeliveryThreshold != null)
          'free_delivery_threshold': freeDeliveryThreshold.toJson()
        else if (clearFreeDeliveryThreshold) 'free_delivery_threshold': null,
        if (minOrderAmount != null)
          'min_order_amount': minOrderAmount.toJson()
        else if (clearMinOrderAmount) 'min_order_amount': null,
        if (maxDistanceKm != null) 'max_distance_km': maxDistanceKm,
        if (estimatedDeliveryMinutes != null)
          'estimated_delivery_minutes': estimatedDeliveryMinutes,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return DeliveryZone.fromJson(response.data as Map<String, dynamic>);
  }

  // --------------------------------------------------------------- interne

  /// Suit la pagination jusqu'au bout.
  ///
  /// Les trois listes de ce dépôt alimentent des sélecteurs — un pays, une
  /// ville, une zone —, et une deuxième page oubliée y rend une option
  /// invisible, donc inchoisissable. Même assistant que
  /// `ManagedCatalogRepository`, écrit ici plutôt que partagé : les deux dépôts
  /// n'ont pas d'ancêtre commun, et s'en inventer un pour six lignes coûterait
  /// plus qu'il ne rapporte.
  Future<List<T>> _collect<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final items = <T>[];
    String? next = path;
    Map<String, dynamic>? parameters = queryParameters;

    while (next != null) {
      final response = await apiClient.get(next, queryParameters: parameters);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      items.addAll(results.map((json) => fromJson(json as Map<String, dynamic>)));
      next = body['next'] as String?;
      parameters = null;
    }

    return items;
  }
}
