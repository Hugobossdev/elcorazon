import 'package:elcora_fast/presentation/trajet_livreur.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Distance et vitesse moyenne du suivi de livraison.
///
/// Le calcul écrivait dans l'état d'un widget de 1 589 lignes ; il n'était
/// atteignable par rien. Ces cas décrivent les trois règles qu'il porte.
void main() {
  /// Une distance factice : un kilomètre par degré de latitude.
  double unKmParDegre(LatLng a, LatLng b) => (a.latitude - b.latitude).abs();

  Map<String, dynamic> releve({
    required double lat,
    required DateTime quand,
    double? vitesseGps,
  }) =>
      {
        'latitude': lat,
        'longitude': 1.23,
        'timestamp': quand,
        'speed': vitesseGps,
      };

  StatistiquesTrajet mesure(List<Map<String, dynamic>> historique) =>
      statistiquesDuTrajet(historique, distanceEntre: unKmParDegre);

  group('Trop peu de relevés', () {
    test('aucun relevé ne donne rien à mesurer', () {
      final stats = mesure(const []);

      expect(stats.distanceParcourue, 0);
      expect(stats.vitesseMoyenne, isNull);
    });

    test('un seul relevé non plus : il faut deux points pour un segment', () {
      final stats = mesure([releve(lat: 6.14, quand: DateTime(2026, 8, 8, 12))]);

      expect(stats.distanceParcourue, 0);
      expect(stats.vitesseMoyenne, isNull);
    });
  });

  group('Distance', () {
    test('additionne les sauts entre positions successives', () {
      final stats = mesure([
        releve(lat: 6.16, quand: DateTime(2026, 8, 8, 12, 30)),
        releve(lat: 6.15, quand: DateTime(2026, 8, 8, 12, 15)),
        releve(lat: 6.12, quand: DateTime(2026, 8, 8, 12)),
      ]);

      expect(stats.distanceParcourue, closeTo(0.04, 0.0001));
    });
  });

  group('Vitesse', () {
    test('se déduit de la distance et du temps', () {
      // 0,5 km en 30 minutes : 1 km/h. L'historique va du plus récent au plus
      // ancien — c'est ce qui rend l'écart de temps positif.
      final stats = mesure([
        releve(lat: 6.5, quand: DateTime(2026, 8, 8, 12, 30)),
        releve(lat: 6, quand: DateTime(2026, 8, 8, 12)),
      ]);

      expect(stats.vitesseMoyenne, closeTo(1, 0.0001));
    });

    test('la vitesse du GPS compte aussi, convertie des m/s', () {
      // 10 m/s = 36 km/h, moyennée avec le 1 km/h déduit du trajet.
      final stats = mesure([
        releve(lat: 6.5, quand: DateTime(2026, 8, 8, 12, 30), vitesseGps: 10),
        releve(lat: 6, quand: DateTime(2026, 8, 8, 12)),
      ]);

      expect(stats.vitesseMoyenne, closeTo((1 + 36) / 2, 0.0001));
    });

    test('les valeurs aberrantes sont écartées', () {
      // 200 km/h sur un scooter : le relevé est faux, pas le livreur rapide.
      final stats = mesure([
        releve(
          lat: 6.5,
          quand: DateTime(2026, 8, 8, 12, 30),
          vitesseGps: 55.6,
        ),
        releve(lat: 6, quand: DateTime(2026, 8, 8, 12)),
      ]);

      expect(stats.vitesseMoyenne, closeTo(1, 0.0001));
    });

    test('un livreur à l’arrêt ne donne aucune vitesse, pas zéro', () {
      // Deux relevés au même endroit : la distance est nulle, donc la vitesse
      // aussi, et zéro est écarté comme non plausible. `null` dit « on ne sait
      // pas », ce qui est plus honnête que « 0 km/h ».
      final stats = mesure([
        releve(lat: 6, quand: DateTime(2026, 8, 8, 12, 30)),
        releve(lat: 6, quand: DateTime(2026, 8, 8, 12)),
      ]);

      expect(stats.distanceParcourue, 0);
      expect(stats.vitesseMoyenne, isNull);
    });

    test('deux relevés au même instant ne produisent pas de division par zéro', () {
      final stats = mesure([
        releve(lat: 6.5, quand: DateTime(2026, 8, 8, 12)),
        releve(lat: 6, quand: DateTime(2026, 8, 8, 12)),
      ]);

      expect(stats.distanceParcourue, closeTo(0.5, 0.0001));
      expect(stats.vitesseMoyenne, isNull);
    });
  });

  group('Alerte de proximité', () {
    test('le seuil est de 500 mètres', () {
      expect(seuilDAlerteDeProximite, 0.5);
    });

    test('en deçà, on prévient ; au-delà, non', () {
      expect(livreurToutProche(0.49), isTrue);
      expect(livreurToutProche(0.5), isFalse);
      expect(livreurToutProche(2), isFalse);
    });
  });

  group('Estimation de repli', () {
    test('deux minutes par kilomètre', () {
      expect(minutesEstimeesPourKm(3), 6);
      expect(minutesEstimeesPourKm(0.5), 1);
    });

    test('sous 250 mètres, l’estimation tombe à zéro minute', () {
      // C'est le comportement actuel : l'arrondi à la minute avale les
      // distances courtes.
      expect(minutesEstimeesPourKm(0.2), 0);
    });
  });
}
