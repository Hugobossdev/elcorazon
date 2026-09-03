import 'package:elcora_fast/presentation/deplacement_livreur.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Le repère du livreur sautait d'une centaine de mètres à chaque relevé — dix
/// fois par minute. Ces règles décident quand il glisse, pendant combien de
/// temps, et quand il vaut mieux le reposer d'un coup.
void main() {
  const cadence = Duration(seconds: 10);

  group('dureeDeGlissement', () {
    test('un déplacement imperceptible ne s’anime pas', () {
      // Sous trois mètres, c'est du bruit GPS : l'animer coûterait des images
      // pour un mouvement que personne ne voit.
      expect(dureeDeGlissement(1, cadence: cadence), Duration.zero);
      expect(dureeDeGlissement(0, cadence: cadence), Duration.zero);
    });

    test('un saut trop grand se repose au lieu de glisser', () {
      // Trois kilomètres entre deux relevés, ce n'est pas un déplacement
      // observé : c'est un premier point, ou une reprise après un tunnel.
      // L'animer montrerait un livreur traverser la ville en ligne droite.
      expect(dureeDeGlissement(3000, cadence: cadence), Duration.zero);
      expect(
        dureeDeGlissement(sautAuDelaDeMetres, cadence: cadence),
        Duration.zero,
      );
    });

    test('un déplacement ordinaire glisse, sans traîner', () {
      final duree = dureeDeGlissement(80, cadence: cadence);

      expect(duree, greaterThan(Duration.zero));
      // Borné : au-delà, le repère rampe et prend du retard sur le relevé
      // suivant.
      expect(duree, lessThanOrEqualTo(const Duration(milliseconds: 1500)));
      expect(duree, greaterThanOrEqualTo(const Duration(milliseconds: 250)));
    });

    test('plus le déplacement est long, plus le glissement dure', () {
      final court = dureeDeGlissement(10, cadence: cadence);
      final long = dureeDeGlissement(150, cadence: cadence);
      expect(long, greaterThanOrEqualTo(court));
    });

    test('la durée reste bornée même sur une cadence absurde', () {
      // Un `.env` qui annoncerait dix minutes ne doit pas produire un repère
      // qui met dix minutes à parcourir cent mètres.
      final duree = dureeDeGlissement(80, cadence: const Duration(minutes: 10));
      expect(duree, lessThanOrEqualTo(const Duration(milliseconds: 1500)));
    });
  });

  group('pointIntermediaire', () {
    const depart = LatLng(6.1319, 1.2255);
    const arrivee = LatLng(6.1419, 1.2355);

    test('à 0, le point de départ', () {
      expect(pointIntermediaire(depart, arrivee, 0), depart);
    });

    test('à 1, le point d’arrivée', () {
      expect(pointIntermediaire(depart, arrivee, 1), arrivee);
    });

    test('à mi-parcours, le milieu', () {
      final milieu = pointIntermediaire(depart, arrivee, 0.5);
      expect(milieu.latitude, closeTo(6.1369, 1e-9));
      expect(milieu.longitude, closeTo(1.2305, 1e-9));
    });

    test('un avancement hors bornes est ramené dans l’intervalle', () {
      // Le dernier tic d'une courbe élastique déborde : sans borne, le repère
      // se projetterait au-delà de la position relevée, donc devant un livreur
      // qui n'y est pas.
      expect(pointIntermediaire(depart, arrivee, 1.4), arrivee);
      expect(pointIntermediaire(depart, arrivee, -0.3), depart);
    });
  });

  group('capDuSegment', () {
    test('un déplacement plein nord donne 0°', () {
      final cap = capDuSegment(const LatLng(6.13, 1.22), const LatLng(6.14, 1.22));
      expect(cap, closeTo(0, 0.5));
    });

    test('un déplacement plein est donne 90°', () {
      final cap = capDuSegment(const LatLng(6.13, 1.22), const LatLng(6.13, 1.23));
      expect(cap, closeTo(90, 0.5));
    });

    test('un déplacement plein sud donne 180°', () {
      final cap = capDuSegment(const LatLng(6.14, 1.22), const LatLng(6.13, 1.22));
      expect(cap, closeTo(180, 0.5));
    });

    test('un déplacement plein ouest donne 270°', () {
      final cap = capDuSegment(const LatLng(6.13, 1.23), const LatLng(6.13, 1.22));
      expect(cap, closeTo(270, 0.5));
    });

    test('deux points confondus n’ont pas de cap', () {
      // Un livreur immobile n'a pas de direction : faire pivoter son repère
      // vers un cap calculé sur du bruit GPS le ferait tourner sur place.
      expect(capDuSegment(const LatLng(6.13, 1.22), const LatLng(6.13, 1.22)),
          isNull);
    });
  });
}
