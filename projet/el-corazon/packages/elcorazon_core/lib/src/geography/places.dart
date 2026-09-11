import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:elcorazon_core/src/diagnostics/journal.dart';
import 'package:elcorazon_core/src/directions/geo_point.dart';

/// Une suggestion d'autocomplétion.
class PlaceSuggestion {
  const PlaceSuggestion({required this.placeId, required this.description});

  final String placeId;
  final String description;
}

/// Le détail d'un lieu choisi.
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
  final GeoPoint location;

  /// Composants d'adresse rendus par Google, quand il les connaît.
  ///
  /// L'ancienne API n'était interrogée que sur `geometry/location` et
  /// `formatted_address` : la ville était ensuite **devinée** en cherchant son
  /// nom dans le texte de l'adresse. Ces champs viennent de
  /// `addressComponents`, c'est-à-dire de ce que Google a réellement classé.
  final String? city;
  final String? country;

  /// Code ISO 3166-1 alpha-2, en majuscules.
  final String? countryCode;

  /// Quartier ou localité fine, si le lieu en porte un.
  final String? neighborhood;
}

/// Google Places — **Places API (New)**, `places.googleapis.com/v1`.
///
/// ## Pourquoi ce service vit dans le socle partagé
///
/// Il vivait dans l'application cliente, et le back-office ne l'avait pas :
/// pour placer un établissement, un administrateur tapait sa latitude et sa
/// longitude au clavier. L'y recopier aurait produit deux implémentations d'une
/// intégration facturée à l'appel — donc deux jeux de session, deux masques de
/// champs, et deux factures dont l'une resterait à corriger.
///
/// Il ne dépend d'aucun moteur de carte : [GeoPoint] remplace `LatLng`, et
/// `dio` remplace le client HTTP propre au client. Les trois applications
/// peuvent donc l'appeler.
///
/// ## Deux différences de forme qui comptent
///
/// * l'autocomplétion est un **POST** dont les critères sont dans le corps, et
///   la clé voyage dans l'en-tête `X-Goog-Api-Key` ;
/// * le détail d'un lieu **exige** un masque de champs (`X-Goog-FieldMask`) :
///   sans lui la requête est refusée, et tout champ non demandé est absent de
///   la réponse — c'est aussi ce qui borne la facturation.
///
/// L'implémentation précédente appelait `maps.googleapis.com/maps/api/place/*`
/// (« legacy »), que Google n'active plus sur les projets qui ne l'utilisaient
/// pas déjà : les suggestions revenaient systématiquement vides, sans message.
class PlacesRepository {
  PlacesRepository({required this.apiKey, Dio? httpClient})
      : _http = httpClient ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
              ),
            );

  /// Clé du projet Google. Vide, le service rend des listes vides plutôt que de
  /// lever : un back-office sans clé doit rester utilisable en saisie manuelle.
  final String apiKey;

  final Dio _http;

  static const String _base = 'https://places.googleapis.com/v1';

  /// Rayon retenu quand l'appelant biaise la recherche sans en préciser un.
  ///
  /// La nouvelle API **exige** un rayon avec le centre, là où l'ancienne
  /// acceptait un point seul ; le maximum admis conserve le biais sans jamais
  /// exclure de résultat.
  static const double _rayonDeBiaisParDefaut = 50000;
  static const double _rayonDeBiaisMaximal = 50000;

  /// Champs demandés au détail d'un lieu. Chacun est facturé : n'y ajouter que
  /// ce que l'écran affiche ou enregistre réellement.
  static const String _masqueDeDetail =
      'id,formattedAddress,location,addressComponents';

  /// Jeton de session — regroupe les frappes d'une même recherche **et** le
  /// détail du lieu finalement choisi en une seule facturation. Sans lui,
  /// chaque lettre est facturée séparément.
  ///
  /// Ouvert à la première frappe, refermé dès qu'un détail a été demandé.
  String? _sessionToken;

  String _ouvrirSession() => _sessionToken ??= _nouveauJeton();

  /// Jeton d'opacité suffisante, sans dépendre d'un paquet de plus.
  ///
  /// Google n'attend qu'une chaîne stable le temps d'une recherche ; elle n'a ni
  /// à être un UUID conforme, ni à résister à une attaque — elle ne protège
  /// rien, elle regroupe une facturation.
  static String _nouveauJeton() {
    final alea = Random();
    return List.generate(32, (_) => alea.nextInt(16).toRadixString(16)).join();
  }

  /// Suggestions pour une saisie — `POST /v1/places:autocomplete`.
  ///
  /// [countryCode] est un code ISO 3166-1 alpha-2 (`tg`), transmis tel quel
  /// dans `includedRegionCodes`. **Aucun pays n'est écrit ici** : l'appelant
  /// fournit celui de son contexte, ce qui est la condition pour que le
  /// back-office puisse chercher au Cameroun comme au Togo.
  ///
  /// En deçà de trois caractères, rien n'est demandé : les deux premières
  /// lettres d'une rue ne discriminent rien et sont facturées comme le reste.
  Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    String? language,
    String? countryCode,
    GeoPoint? locationBias,
    int? radiusMeters,
  }) async {
    if (apiKey.isEmpty) return const [];

    final saisie = input.trim();
    if (saisie.length < 3) return const [];

    try {
      final reponse = await _http.post<Map<String, dynamic>>(
        '$_base/places:autocomplete',
        options: Options(headers: {'X-Goog-Api-Key': apiKey}),
        data: {
          'input': saisie,
          'sessionToken': _ouvrirSession(),
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
                'radius': _rayonDeBiais(radiusMeters),
              },
            },
        },
      );
      return suggestionsFromResponse(reponse.data ?? const {});
    } on DioException catch (e) {
      // Le motif du refus est journalisé en clair : une API non activée sur le
      // projet et une recherche sans résultat se lisaient toutes deux comme une
      // liste vide, et rien ne les distinguait.
      Journal.trace('Places.autocomplete refusé : ${_motif(e)}');
      return const [];
    }
  }

  /// Détail d'un lieu — `GET /v1/places/{placeId}`.
  ///
  /// Rend le point exact, l'adresse formatée, et les composants qui permettent
  /// de renseigner ville et pays **sans les deviner**.
  Future<PlaceDetails?> getDetails(String placeId, {String? language}) async {
    if (apiKey.isEmpty || placeId.isEmpty) return null;

    final session = _sessionToken;
    try {
      final reponse = await _http.get<Map<String, dynamic>>(
        '$_base/places/$placeId',
        queryParameters: {
          if (language != null && language.isNotEmpty) 'languageCode': language,
          if (session != null) 'sessionToken': session,
        },
        options: Options(
          headers: {
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask': _masqueDeDetail,
          },
        ),
      );
      return detailsFromResponse(reponse.data ?? const {}, requestedPlaceId: placeId);
    } on DioException catch (e) {
      Journal.trace('Places.getDetails refusé : ${_motif(e)}');
      return null;
    } finally {
      // La session se referme, qu'on ait obtenu le détail ou non : Google la
      // considère consommée dès qu'un détail lui a été demandé.
      _sessionToken = null;
    }
  }

  /// Traduit la réponse d'autocomplétion.
  ///
  /// Séparée de l'appel réseau pour être vérifiable sur une réponse réelle :
  /// c'est cette traduction, et non l'envoi, qui peut faire régresser l'écran.
  @visibleForTesting
  static List<PlaceSuggestion> suggestionsFromResponse(Map<String, dynamic> data) {
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
            description: _texte(p['text']),
          ),
        )
        .where((p) => p.placeId.isNotEmpty && p.description.isNotEmpty)
        .toList();
  }

  /// Traduit la réponse de détail.
  ///
  /// Rend `null` plutôt qu'un objet incomplet : sans point ni adresse, l'écran
  /// n'a rien à afficher ni à enregistrer, et un lieu à demi lu produirait une
  /// adresse dont personne ne saurait qu'elle est fausse.
  @visibleForTesting
  static PlaceDetails? detailsFromResponse(
    Map<String, dynamic> data, {
    required String requestedPlaceId,
  }) {
    final adresse = data['formattedAddress']?.toString() ?? '';
    final position = data['location'] as Map<String, dynamic>?;
    final lat = (position?['latitude'] as num?)?.toDouble();
    final lon = (position?['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null || adresse.isEmpty) return null;

    final composants = data['addressComponents'] as List<dynamic>? ?? const [];

    return PlaceDetails(
      // `id` est rendu par le serveur ; à défaut, celui qu'on a demandé.
      placeId: data['id']?.toString() ?? requestedPlaceId,
      formattedAddress: adresse,
      location: GeoPoint(lat, lon),
      // `locality` est la ville au sens courant ; les agglomérations découpées
      // en communes ne la portent pas toujours, et le niveau administratif
      // prend alors le relais — le cas fréquent des villes africaines.
      city: _composant(composants, const [
        'locality',
        'postal_town',
        'administrative_area_level_2',
        'administrative_area_level_1',
      ]),
      country: _composant(composants, const ['country']),
      countryCode: _composant(composants, const ['country'], court: true),
      neighborhood: _composant(composants, const [
        'neighborhood',
        'sublocality_level_1',
        'sublocality',
      ]),
    );
  }

  static double _rayonDeBiais(int? metres) {
    if (metres == null || metres <= 0) return _rayonDeBiaisParDefaut;
    return metres > _rayonDeBiaisMaximal ? _rayonDeBiaisMaximal : metres.toDouble();
  }

  static String _texte(Object? localise) {
    if (localise is Map<String, dynamic>) return localise['text']?.toString() ?? '';
    return localise?.toString() ?? '';
  }

  /// Premier composant d'un des types demandés, dans l'ordre de préférence.
  static String? _composant(
    List<dynamic> composants,
    List<String> types, {
    bool court = false,
  }) {
    for (final type in types) {
      for (final brut in composants) {
        if (brut is! Map<String, dynamic>) continue;
        final siens = (brut['types'] as List<dynamic>? ?? const [])
            .map((t) => t.toString())
            .toSet();
        if (siens.contains(type)) {
          final valeur =
              (court ? brut['shortText'] : brut['longText'])?.toString() ?? '';
          if (valeur.isNotEmpty) return valeur;
        }
      }
    }
    return null;
  }

  static String _motif(DioException e) {
    final corps = e.response?.data;
    if (corps is Map<String, dynamic>) {
      final erreur = corps['error'];
      if (erreur is Map<String, dynamic>) {
        return '${erreur['status'] ?? ''} ${erreur['message'] ?? ''}'.trim();
      }
    }
    return '${e.response?.statusCode ?? ''} ${e.message ?? ''}'.trim();
  }
}
