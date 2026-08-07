import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

/// Simule Google Directions / Distance Matrix et retient la dernière URL reçue
/// — c'est elle qui prouve que les paramètres sont encodés.
class _FauxGoogle implements HttpClientAdapter {
  _FauxGoogle(this.reponse);

  final Map<String, dynamic> reponse;
  Uri? derniereUri;
  int appels = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    derniereUri = options.uri;
    appels++;
    return ResponseBody.fromString(jsonEncode(reponse), 200, headers: _jsonHeaders);
  }
}

/// Une réponse d'itinéraire minimale mais complète.
Map<String, dynamic> _itineraire({
  int distanceMetres = 3400,
  int dureeSecondes = 900,
  int? dureeTraficSecondes,
  String trace = '_p~iF~ps|U',
}) {
  return {
    'status': 'OK',
    'routes': [
      {
        'overview_polyline': {'points': trace},
        'legs': [
          {
            'distance': {'value': distanceMetres},
            'duration': {'value': dureeSecondes},
            if (dureeTraficSecondes != null)
              'duration_in_traffic': {'value': dureeTraficSecondes},
          },
        ],
      },
    ],
  };
}

/// Itinéraires — le seul dépôt du socle qui s'adresse à un tiers.
///
/// Il vient des deux copies que `fastfood` et `dely` portaient chacune de leur
/// côté (86 % de similarité, lot 2.3). Ce qui est vérifié ici est ce que les
/// deux copies faisaient sans filet : l'encodage des paramètres, le décodage du
/// tracé, le cache, et la traduction des refus de Google.
void main() {
  const lome = GeoPoint(6.1319, 1.2228);
  const kara = GeoPoint(9.5511, 1.1861);

  group('Requête', () {
    test('les paramètres sont encodés, pas concaténés', () async {
      // C'est la divergence entre les deux copies : `dely` construisait l'URL à
      // la main et n'encodait pas ses points de passage.
      final google = _FauxGoogle(_itineraire());
      final depot = DirectionsRepository(apiKey: 'cle-test', testAdapter: google);

      await depot.getRoute(
        origin: lome,
        destination: kara,
        waypoints: const [GeoPoint(7.0, 1.2), GeoPoint(8.0, 1.3)],
      );

      final uri = google.derniereUri!;
      expect(uri.host, 'maps.googleapis.com');
      expect(uri.path, '/maps/api/directions/json');
      expect(uri.queryParameters['origin'], '6.1319,1.2228');
      expect(uri.queryParameters['waypoints'], '7.0,1.2|8.0,1.3');
      expect(uri.queryParameters['key'], 'cle-test');
      // Le séparateur de points de passage et la virgule des coordonnées sont
      // des caractères réservés : ils doivent voyager encodés dans la chaîne
      // brute. La copie de `dely` les y laissait tels quels.
      expect(uri.query, contains('%7C'));
      expect(uri.query, contains('%2C'));
    });

    test('sans clé configurée, rend null au lieu de partir', () async {
      // L'écran affiche alors son tracé de repli. Partir sans clé consommerait
      // un aller-retour pour un refus certain.
      final google = _FauxGoogle(_itineraire());
      for (final cle in ['', 'YOUR_GOOGLE_MAPS_API_KEY', 'your-google-maps-api-key']) {
        final depot = DirectionsRepository(apiKey: cle, testAdapter: google);
        expect(await depot.getRoute(origin: lome, destination: kara), isNull);
      }
      expect(google.appels, 0);
    });
  });

  group('Lecture de la réponse', () {
    test('distance et durée sont converties pour l’affichage', () async {
      final depot = DirectionsRepository(
        apiKey: 'cle-test',
        testAdapter: _FauxGoogle(_itineraire()),
      );

      final route = (await depot.getRoute(origin: lome, destination: kara))!;
      expect(route.distanceMeters, 3400);
      expect(route.distanceKm, closeTo(3.4, 0.001));
      expect(route.durationMinutes, 15);
      expect(route.formattedDistance, '3.4 km');
      expect(route.formattedDuration, '15min');
    });

    test('la durée dans le trafic prend le pas quand Google la donne', () async {
      final depot = DirectionsRepository(
        apiKey: 'cle-test',
        testAdapter: _FauxGoogle(
          _itineraire(dureeTraficSecondes: 1500),
        ),
      );

      final route = (await depot.getRoute(origin: lome, destination: kara))!;
      expect(route.durationMinutes, 15);
      expect(route.durationInTrafficMinutes, 25);
      expect(route.effectiveDurationMinutes, 25);
      expect(route.formattedDuration, '25min');
    });

    test('sous le kilomètre, la distance s’affiche en mètres', () async {
      final depot = DirectionsRepository(
        apiKey: 'cle-test',
        testAdapter: _FauxGoogle(_itineraire(distanceMetres: 850)),
      );

      final route = (await depot.getRoute(origin: lome, destination: kara))!;
      expect(route.formattedDistance, '850m');
    });

    test('au-delà de l’heure, la durée s’écrit en heures et minutes', () async {
      final depot = DirectionsRepository(
        apiKey: 'cle-test',
        testAdapter: _FauxGoogle(_itineraire(dureeSecondes: 4500)),
      );

      final route = (await depot.getRoute(origin: lome, destination: kara))!;
      expect(route.formattedDuration, '1h 15min');
    });
  });

  group('Tracé', () {
    test('le décodage rend les points du format compressé de Google', () {
      // Exemple de la documentation Google : « _p~iF~ps|U_ulLnnqC_mqNvxq`@ »
      // décode en (38.5, -120.2), (40.7, -120.95), (43.252, -126.453).
      final depot = DirectionsRepository(apiKey: 'cle-test');
      final points = depot.decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');

      expect(points, hasLength(3));
      expect(points[0].latitude, closeTo(38.5, 0.0001));
      expect(points[0].longitude, closeTo(-120.2, 0.0001));
      expect(points[1].latitude, closeTo(40.7, 0.0001));
      expect(points[2].longitude, closeTo(-126.453, 0.0001));
    });

    test('un tracé vide ne rend aucun point', () {
      expect(DirectionsRepository(apiKey: 'cle-test').decodePolyline(''), isEmpty);
    });

    test('le tracé compressé est conservé tel quel', () async {
      final depot = DirectionsRepository(
        apiKey: 'cle-test',
        testAdapter: _FauxGoogle(_itineraire()),
      );

      final route = (await depot.getRoute(origin: lome, destination: kara))!;
      expect(route.encodedPolyline, '_p~iF~ps|U');
      expect(route.polylinePoints, hasLength(1));
    });
  });

  group('Cache', () {
    test('deux fois le même trajet ne fait qu’un appel', () async {
      final google = _FauxGoogle(_itineraire());
      final depot = DirectionsRepository(apiKey: 'cle-test', testAdapter: google);

      await depot.getRoute(origin: lome, destination: kara);
      await depot.getRoute(origin: lome, destination: kara);
      expect(google.appels, 1);
    });

    test('un trajet différent n’est pas servi par le cache', () async {
      final google = _FauxGoogle(_itineraire());
      final depot = DirectionsRepository(apiKey: 'cle-test', testAdapter: google);

      await depot.getRoute(origin: lome, destination: kara);
      await depot.getRoute(origin: lome, destination: kara, mode: 'walking');
      await depot.getRoute(origin: kara, destination: lome);
      expect(google.appels, 3);
    });

    test('passé le délai, l’itinéraire est recalculé', () async {
      // Le trafic a bougé : servir une durée d'il y a une heure induit en
      // erreur bien plus qu'un aller-retour ne coûte.
      final google = _FauxGoogle(_itineraire());
      final depot = DirectionsRepository(
        apiKey: 'cle-test',
        cacheDuration: Duration.zero,
        testAdapter: google,
      );

      await depot.getRoute(origin: lome, destination: kara);
      await depot.getRoute(origin: lome, destination: kara);
      expect(google.appels, 2);
    });

    test('vider le cache force le recalcul', () async {
      final google = _FauxGoogle(_itineraire());
      final depot = DirectionsRepository(apiKey: 'cle-test', testAdapter: google);

      await depot.getRoute(origin: lome, destination: kara);
      depot.clearCache();
      await depot.getRoute(origin: lome, destination: kara);
      expect(google.appels, 2);
    });
  });

  group('Refus de Google', () {
    Future<void> attendRefus(String status, String attendu) async {
      final depot = DirectionsRepository(
        apiKey: 'cle-test',
        testAdapter: _FauxGoogle({'status': status, 'routes': <dynamic>[]}),
      );

      await expectLater(
        depot.getRoute(origin: lome, destination: kara),
        throwsA(
          isA<DirectionsException>()
              .having((e) => e.status, 'status', status)
              .having((e) => e.message, 'message', attendu),
        ),
      );
    }

    test('chaque code porte son message', () async {
      await attendRefus('ZERO_RESULTS', 'Aucun itinéraire trouvé entre ces points');
      await attendRefus('OVER_QUERY_LIMIT', 'Quota API dépassé. Veuillez réessayer plus tard');
      await attendRefus('REQUEST_DENIED', 'Requête refusée. Vérifiez votre clé API');
    });

    test('un code inconnu remonte le message de Google', () async {
      final depot = DirectionsRepository(
        apiKey: 'cle-test',
        testAdapter: _FauxGoogle({
          'status': 'INVALID_REQUEST',
          'error_message': 'Invalid request. Missing the placeholder',
          'routes': <dynamic>[],
        }),
      );

      await expectLater(
        depot.getRoute(origin: lome, destination: kara),
        throwsA(
          isA<DirectionsException>().having(
            (e) => e.message,
            'message',
            'Invalid request. Missing the placeholder',
          ),
        ),
      );
    });
  });

  group('Distance Matrix', () {
    test('rend les mesures sans tracé', () async {
      final google = _FauxGoogle({
        'status': 'OK',
        'rows': [
          {
            'elements': [
              {
                'status': 'OK',
                'distance': {'value': 12000},
                'duration': {'value': 1800},
              },
            ],
          },
        ],
      });
      final depot = DirectionsRepository(apiKey: 'cle-test', testAdapter: google);

      final mesure = (await depot.getDistanceAndTime(origin: lome, destination: kara))!;
      expect(google.derniereUri!.path, '/maps/api/distancematrix/json');
      expect(mesure.distanceKm, 12.0);
      expect(mesure.formattedDistance, '12.0 km');
      expect(mesure.formattedDuration, '30min');
    });

    test('un élément refusé lève plutôt que de rendre zéro', () async {
      final depot = DirectionsRepository(
        apiKey: 'cle-test',
        testAdapter: _FauxGoogle({
          'status': 'OK',
          'rows': [
            {
              'elements': [
                {'status': 'ZERO_RESULTS'},
              ],
            },
          ],
        }),
      );

      await expectLater(
        depot.getDistanceAndTime(origin: lome, destination: kara),
        throwsA(isA<DirectionsException>()),
      );
    });
  });

  group('Distance à vol d’oiseau', () {
    test('elle approche la distance réelle Lomé — Kara', () {
      // ~380 km à vol d'oiseau. Sert de repli quand Google est injoignable.
      final depot = DirectionsRepository(apiKey: 'cle-test');
      expect(depot.straightLineDistanceKm(lome, kara), closeTo(380, 10));
    });

    test('un point avec lui-même donne zéro', () {
      final depot = DirectionsRepository(apiKey: 'cle-test');
      expect(depot.straightLineDistanceKm(lome, lome), 0);
    });

    test('elle est symétrique', () {
      final depot = DirectionsRepository(apiKey: 'cle-test');
      expect(
        depot.straightLineDistanceKm(lome, kara),
        closeTo(depot.straightLineDistanceKm(kara, lome), 0.0001),
      );
    });
  });
}
