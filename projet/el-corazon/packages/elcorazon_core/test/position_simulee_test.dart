import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulation de position — la couche qui rend le GPS vérifiable à distance.
///
/// Le développement se fait depuis Abidjan et l'établissement est à Lomé, à
/// 600 km : la couverture d'une adresse, la distance au restaurant, le
/// franchissement d'une zone et l'arrivée d'un livreur sont invérifiables sans
/// elle.
///
/// Ce qui est gardé ici, ce n'est pas « la simulation marche » — ce serait
/// tester Dart — mais les deux propriétés dont dépend sa fiabilité :
///
/// * **l'interpolation respecte le temps**, pas les segments. Sauter d'un
///   sommet à l'autre ferait franchir une zone entière entre deux relevés,
///   c'est-à-dire manquer exactement l'événement qu'on cherche à observer ;
/// * **la position revient au capteur** dès qu'on la désactive.
void main() {
  // Lomé → un point ~2 km à l'est.
  const lome = GeoPoint(6.1319, 1.2255);
  const est = GeoPoint(6.1319, 1.2455);

  group('Distance', () {
    test('deux points identiques sont à zéro mètre', () {
      expect(PositionSimulee.distanceMetres(lome, lome), 0);
    });

    test('deux degrés de longitude à Lomé font environ 2,2 km', () {
      final metres = PositionSimulee.distanceMetres(lome, est);

      // Bornes larges à dessein : c'est l'ordre de grandeur qui compte, et un
      // seuil serré ne ferait que garder la formule contre elle-même.
      expect(metres, greaterThan(2000));
      expect(metres, lessThan(2500));
    });
  });

  group('Interpolation', () {
    test('un trajet est découpé en pas réguliers', () {
      // 25 km/h pendant 2 s font ~13,9 m par tic ; sur ~2,2 km, cela donne un
      // peu moins de 160 points.
      final pas = PositionSimulee.interpoler([lome, est]);

      expect(pas.length, greaterThan(100));
      expect(pas.first, lome);
      expect(pas.last, est);
    });

    test('le pas est constant à travers un virage', () {
      // Deux segments de longueurs très différentes. Sans report du reste d'un
      // segment au suivant, la cadence se réinitialiserait à chaque sommet et
      // le livreur simulé ralentirait à chaque virage.
      const court = GeoPoint(6.1319, 1.2275);
      final pas = PositionSimulee.interpoler([lome, court, est]);

      final ecarts = [
        for (var i = 0; i < pas.length - 2; i++)
          PositionSimulee.distanceMetres(pas[i], pas[i + 1]),
      ];

      // Tous les écarts intermédiaires se ressemblent à un mètre près.
      final minimum = ecarts.reduce((a, b) => a < b ? a : b);
      final maximum = ecarts.reduce((a, b) => a > b ? a : b);
      expect(maximum - minimum, lessThan(1.0));
    });

    test('une vitesse plus élevée donne moins de points', () {
      final lent = PositionSimulee.interpoler([lome, est], vitesseKmH: 10);
      final rapide = PositionSimulee.interpoler([lome, est], vitesseKmH: 60);

      expect(rapide.length, lessThan(lent.length));
    });

    test('un trajet d’un seul point se réduit à lui-même', () {
      expect(PositionSimulee.interpoler([lome]), [lome]);
    });
  });

  group('Activation', () {
    tearDown(() => PositionSimulee().fermer());

    test('la position simulée remplace le capteur', () {
      final simulation = PositionSimulee()..activer(5.3600, -4.0083);

      expect(simulation.estActive, isTrue);
      expect(simulation.point?.latitude, 5.3600);
      expect(simulation.point?.longitude, -4.0083);
    });

    test('la désactivation rend la main au capteur', () {
      final simulation = PositionSimulee()..activer(5.3600, -4.0083);

      simulation.desactiver();

      expect(simulation.estActive, isFalse);
      expect(simulation.point, isNull);
    });

    test('le flux porte chaque position posée', () async {
      final simulation = PositionSimulee();
      final recues = <GeoPoint>[];
      final abonnement = simulation.flux.listen(recues.add);

      simulation.activer(6.1319, 1.2255);
      simulation.activer(5.3600, -4.0083);
      await Future<void>.delayed(Duration.zero);
      await abonnement.cancel();

      expect(recues, hasLength(2));
      expect(recues.last.latitude, 5.3600);
    });
  });
}
