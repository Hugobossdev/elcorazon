import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:elcora_fast/config/api_config.dart';
import 'package:elcora_fast/services/rest_client.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

class PlaceSuggestion {
  final String placeId;
  final String description;

  const PlaceSuggestion({
    required this.placeId,
    required this.description,
  });
}

class PlaceDetails {
  const PlaceDetails({
    required this.placeId,
    required this.formattedAddress,
    required this.location,
    this.city,
    this.country,
    this.countryCode,
    this.neighborhood,
  });

  final String placeId;
  final String formattedAddress;
  final LatLng location;

  /// Composants d'adresse rendus par le serveur, quand il les connaît.
  ///
  /// L'ancienne API n'était interrogée que sur `geometry/location` et
  /// `formatted_address` : la ville était ensuite **devinée** en cherchant son
  /// nom dans le texte de l'adresse. Ces champs viennent de
  /// `addressComponents`, c'est-à-dire de ce que Google a réellement classé,
  /// et non de ce qui se trouve dans une chaîne.
  final String? city;
  final String? country;

  /// Code pays ISO 3166-1 alpha-2, en majuscules tel que rendu par Google.
  final String? countryCode;

  /// Quartier ou localité fine, si le lieu en porte un.
  final String? neighborhood;
}

/// Google Places — **Places API (New)**, `places.googleapis.com/v1`.
///
/// L'implémentation précédente appelait `maps.googleapis.com/maps/api/place/*`
/// (autocomplete et details « legacy »). Google ne l'active plus sur les
/// projets qui ne l'utilisaient pas déjà et répond `REQUEST_DENIED` :
/// « You're calling a legacy API, which is not enabled for your project ». Les
/// suggestions revenaient donc systématiquement vides — sans message, puisque
/// le statut n'était que tracé.
///
/// Deux différences de forme comptent pour qui relit :
///
/// * l'autocomplétion est un **POST** dont les critères sont dans le corps, et
///   la clé voyage dans l'en-tête `X-Goog-Api-Key`, plus en paramètre d'URL ;
/// * le détail d'un lieu **exige** un masque de champs (`X-Goog-FieldMask`) :
///   sans lui la requête est refusée, et tout champ non demandé est absent de
///   la réponse — c'est aussi ce qui borne la facturation.
///
/// La clé reste celle du projet (`GOOGLE_MAPS_API_KEY` dans `.env`) ; ce
/// service n'en connaît aucune autre.
class PlacesService {
  static final PlacesService _instance = PlacesService._internal();
  factory PlacesService() => _instance;
  PlacesService._internal();

  static const String _host = 'places.googleapis.com';

  /// Rayon retenu quand l'appelant biaise la recherche sans en préciser un.
  /// La nouvelle API exige un rayon avec le centre, là où l'ancienne acceptait
  /// un point seul ; le maximum admis (50 km) conserve le biais sans jamais
  /// exclure de résultat.
  static const double _defaultBiasRadiusMeters = 50000;
  static const double _maxBiasRadiusMeters = 50000;

  /// Champs demandés au détail d'un lieu. Chacun est facturé : n'y ajouter que
  /// ce que l'écran affiche ou enregistre réellement.
  static const String _detailsFieldMask =
      'id,formattedAddress,location,addressComponents';

  final RestClient _rest = const RestClient();
  final Uuid _uuid = const Uuid();

  /// Jeton de session — regroupe les frappes d'une même recherche **et** le
  /// détail du lieu finalement choisi en une seule facturation. Sans lui,
  /// chaque lettre est facturée séparément.
  ///
  /// Ouvert à la première frappe, refermé dès qu'un détail a été demandé : la
  /// recherche suivante ouvre donc une nouvelle session, comme Google
  /// l'attend.
  String? _sessionToken;

  String _openSession() => _sessionToken ??= _uuid.v4();

  /// Autocomplete (suggestions) — `POST /v1/places:autocomplete`.
  ///
  /// [countryCode] est un code pays ISO 3166-1 alpha-2 (`tg` pour le Togo) ;
  /// il est transmis tel quel dans `includedRegionCodes`. Aucun pays n'est
  /// écrit ici : l'appelant fournit celui de sa configuration.
  Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    String? language,
    String? countryCode,
    LatLng? locationBias,
    int? radiusMeters,
  }) async {
    final apiKey = ApiConfig.googleMapsApiKey;
    if (apiKey.isEmpty) return const [];

    final trimmed = input.trim();
    if (trimmed.length < 3) return const [];

    final body = <String, dynamic>{
      'input': trimmed,
      'sessionToken': _openSession(),
      if (language != null && language.isNotEmpty) 'languageCode': language,
      if (countryCode != null && countryCode.isNotEmpty)
        'includedRegionCodes': <String>[countryCode],
      if (locationBias != null)
        'locationBias': {
          'circle': {
            'center': {
              'latitude': locationBias.latitude,
              'longitude': locationBias.longitude,
            },
            'radius': _biasRadius(radiusMeters),
          },
        },
    };

    try {
      final data = await _rest.postJson(
        Uri.https(_host, '/v1/places:autocomplete'),
        headers: {'X-Goog-Api-Key': apiKey},
        body: body,
      );

      return suggestionsFromResponse(data);
    } on RestClientException catch (e) {
      // Le motif du refus est journalisé en clair : une API non activée sur le
      // projet et une recherche sans résultat se lisaient toutes deux comme
      // une liste vide, et rien ne les distinguait.
      Journal.trace('PlacesService.autocomplete refusé : ${_reason(e)}');
      return const [];
    } catch (e) {
      Journal.trace('PlacesService.autocomplete indisponible : $e');
      return const [];
    }
  }

  /// Détails d'un lieu — `GET /v1/places/{placeId}`.
  ///
  /// Rend le point exact du lieu choisi, son adresse formatée, et les
  /// composants qui permettent de renseigner ville et pays sans les deviner.
  Future<PlaceDetails?> getDetails(
    String placeId, {
    String? language,
  }) async {
    final apiKey = ApiConfig.googleMapsApiKey;
    if (apiKey.isEmpty) return null;
    if (placeId.isEmpty) return null;

    final session = _sessionToken;
    final query = <String, String>{
      if (language != null && language.isNotEmpty) 'languageCode': language,
      if (session != null) 'sessionToken': session,
    };

    try {
      final data = await _rest.getJson(
        Uri.https(_host, '/v1/places/$placeId', query.isEmpty ? null : query),
        headers: {
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': _detailsFieldMask,
        },
      );

      return detailsFromResponse(data, requestedPlaceId: placeId);
    } on RestClientException catch (e) {
      Journal.trace('PlacesService.getDetails refusé : ${_reason(e)}');
      return null;
    } catch (e) {
      Journal.trace('PlacesService.getDetails indisponible : $e');
      return null;
    } finally {
      // La session se referme, qu'on ait obtenu le détail ou non : Google la
      // considère consommée dès qu'un détail lui a été demandé.
      _sessionToken = null;
    }
  }

  /// Transforme la réponse d'autocomplétion en suggestions de l'application.
  ///
  /// Séparée de l'appel réseau pour être vérifiable sur une réponse réelle :
  /// c'est cette traduction, et non l'envoi, qui peut faire régresser l'écran.
  @visibleForTesting
  static List<PlaceSuggestion> suggestionsFromResponse(
    Map<String, dynamic> data,
  ) {
    final suggestions = data['suggestions'] as List<dynamic>? ?? const [];
    return suggestions
        .whereType<Map<String, dynamic>>()
        .map((s) => s['placePrediction'] as Map<String, dynamic>?)
        // Une suggestion peut être une simple requête (`queryPrediction`), qui
        // ne désigne aucun lieu et n'a donc aucun détail à demander.
        .whereType<Map<String, dynamic>>()
        .map(
          (p) => PlaceSuggestion(
            placeId: p['placeId']?.toString() ?? '',
            description: _text(p['text']),
          ),
        )
        .where((p) => p.placeId.isNotEmpty && p.description.isNotEmpty)
        .toList();
  }

  /// Transforme la réponse de détail en [PlaceDetails].
  ///
  /// Rend `null` plutôt qu'un objet incomplet : sans point ni adresse, l'écran
  /// n'a rien à afficher ni à enregistrer, et un lieu à demi lu produirait une
  /// adresse dont personne ne saurait qu'elle est fausse.
  @visibleForTesting
  static PlaceDetails? detailsFromResponse(
    Map<String, dynamic> data, {
    required String requestedPlaceId,
  }) {
    final formatted = data['formattedAddress']?.toString() ?? '';
    final location = data['location'] as Map<String, dynamic>?;
    final lat = (location?['latitude'] as num?)?.toDouble();
    final lon = (location?['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null || formatted.isEmpty) return null;

    final components = data['addressComponents'] as List<dynamic>? ?? const [];

    return PlaceDetails(
      // `id` est rendu par le serveur ; à défaut, celui qu'on a demandé.
      placeId: data['id']?.toString() ?? requestedPlaceId,
      formattedAddress: formatted,
      location: LatLng(lat, lon),
      // `locality` est la ville au sens courant ; les agglomérations découpées
      // en communes ne la portent pas toujours, et le niveau administratif
      // prend alors le relais.
      city: _component(components, const [
        'locality',
        'postal_town',
        'administrative_area_level_2',
        'administrative_area_level_1',
      ]),
      country: _component(components, const ['country']),
      countryCode: _component(components, const ['country'], short: true),
      neighborhood: _component(components, const [
        'neighborhood',
        'sublocality_level_1',
        'sublocality',
      ]),
    );
  }

  static double _biasRadius(int? radiusMeters) {
    if (radiusMeters == null || radiusMeters <= 0) {
      return _defaultBiasRadiusMeters;
    }
    return radiusMeters
        .toDouble()
        .clamp(1, _maxBiasRadiusMeters)
        .toDouble();
  }

  /// Les libellés de la nouvelle API sont des objets `{text, languageCode}`.
  static String _text(Object? localized) {
    if (localized is Map<String, dynamic>) {
      return localized['text']?.toString() ?? '';
    }
    return '';
  }

  /// Premier composant dont le type figure dans [types], dans cet ordre de
  /// préférence — le classement de Google n'est pas garanti.
  static String? _component(
    List<dynamic> components,
    List<String> types, {
    bool short = false,
  }) {
    for (final type in types) {
      for (final raw in components) {
        if (raw is! Map<String, dynamic>) continue;
        final componentTypes = (raw['types'] as List<dynamic>? ?? const [])
            .map((t) => t.toString());
        if (!componentTypes.contains(type)) continue;

        final value = (short ? raw['shortText'] : raw['longText'])?.toString();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return null;
  }

  /// Message utile d'un refus : Google explique dans le corps ce qu'il attend
  /// (API non activée sur le projet, clé restreinte, champ inconnu).
  static String _reason(RestClientException e) {
    final body = e.body;
    if (body == null || body.isEmpty) return e.toString();
    return 'HTTP ${e.statusCode} — ${body.length > 400 ? body.substring(0, 400) : body}';
  }
}
