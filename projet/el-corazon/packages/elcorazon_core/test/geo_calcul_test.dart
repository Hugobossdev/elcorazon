import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// La géométrie sur laquelle repose toute la navigation.
///
/// Elle ne se vérifie pas à la lecture : une inversion de latitude et de
/// longitude dans une projection donne un code qui compile, qui tourne, et qui
/// annonce une sortie d'itinéraire à un livreur qui roule droit. Ces valeurs de
/// référence sont donc des distances connues, sur des points connus.
void main() {
  // Lomé — l'établissement. Les points voisins sont calculés à partir de lui
  // plutôt qu'écrits en dur : un degré de latitude vaut 111,32 km partout, un
  // degré de longitude vaut ce que le cosinus de la latitude en fait.
  const lome = GeoPoint(6.1319, 1.2228);
  const kara = GeoPoint(9.5511, 1.1861);

  group('Distance', () {
    test('un point avec lui-même donne zéro', () {
      expect(GeoCalcul.distanceMetres(lome, lome), 0);
    });

    test('elle est symétrique', () {
      expect(
        GeoCalcul.distanceMetres(lome, kara),
        closeTo(GeoCalcul.distanceMetres(kara, lome), 0.001),
      );
    });

    test('Lomé — Kara fait environ 380 km à vol d’oiseau', () {
      expect(GeoCalcul.distanceMetres(lome, kara) / 1000, closeTo(380, 5));
    });

    test('un centième de degré de latitude fait environ 1,1 km', () {
      const nord = GeoPoint(6.1419, 1.2228);
      expect(GeoCalcul.distanceMetres(lome, nord), closeTo(1113, 5));
    });
  });

  group('Cap', () {
    test('plein nord vaut 0 degré', () {
      const nord = GeoPoint(6.2319, 1.2228);
      expect(GeoCalcul.capDegres(lome, nord), closeTo(0, 0.5));
    });

    test('plein est vaut 90 degrés', () {
      const est = GeoPoint(6.1319, 1.3228);
      expect(GeoCalcul.capDegres(lome, est), closeTo(90, 0.5));
    });

    test('plein sud vaut 180 degrés', () {
      const sud = GeoPoint(6.0319, 1.2228);
      expect(GeoCalcul.capDegres(lome, sud), closeTo(180, 0.5));
    });

    test('plein ouest vaut 270 degrés', () {
      const ouest = GeoPoint(6.1319, 1.1228);
      expect(GeoCalcul.capDegres(lome, ouest), closeTo(270, 0.5));
    });

    test('le cap reste dans [0, 360[', () {
      const ouest = GeoPoint(6.1319, 1.1228);
      final cap = GeoCalcul.capDegres(lome, ouest);
      expect(cap, greaterThanOrEqualTo(0));
      expect(cap, lessThan(360));
    });
  });

  group('Écart de cap', () {
    test('il prend toujours le chemin le plus court', () {
      // Le piège : 359 et 1 sont voisins de deux degrés, pas éloignés de 358.
      // Sans cette règle, la carte pivoterait d'un tour complet sur un livreur
      // qui roule droit vers le nord.
      expect(GeoCalcul.ecartDeCap(359, 1), closeTo(2, 0.001));
      expect(GeoCalcul.ecartDeCap(1, 359), closeTo(2, 0.001));
    });

    test('il ne dépasse jamais 180 degrés', () {
      expect(GeoCalcul.ecartDeCap(0, 190), closeTo(170, 0.001));
      expect(GeoCalcul.ecartDeCap(10, 200), closeTo(170, 0.001));
    });

    test('deux caps identiques ne s’écartent pas', () {
      expect(GeoCalcul.ecartDeCap(42, 42), 0);
    });
  });

  group('Projection sur un segment', () {
    // Un segment de 1 km vers le nord depuis Lomé.
    const debut = lome;
    const fin = GeoPoint(6.1409, 1.2228);

    test('un point sur le segment est à distance nulle', () {
      const milieu = GeoPoint(6.1364, 1.2228);
      final projection = GeoCalcul.projeterSurSegment(milieu, debut, fin);
      expect(projection.distanceMetres, closeTo(0, 1));
      expect(projection.fraction, closeTo(0.5, 0.02));
    });

    test('un point de côté est à sa distance perpendiculaire', () {
      // Décalé vers l'est au milieu du segment. À cette latitude, un
      // millième de degré de longitude vaut environ 110 mètres.
      const deCote = GeoPoint(6.1364, 1.2238);
      final projection = GeoCalcul.projeterSurSegment(deCote, debut, fin);
      expect(projection.distanceMetres, closeTo(110, 5));
    });

    test('la longitude est corrigée par la latitude', () {
      // Sans le cosinus, un degré de longitude compterait autant qu'un degré
      // de latitude : à 6 degrés de latitude, l'écart serait surestimé de
      // moins d'un pour cent — mais à Paris, de plus d'un tiers. La règle se
      // vérifie donc là où elle se voit.
      const parisDebut = GeoPoint(48.8566, 2.3522);
      const parisFin = GeoPoint(48.8656, 2.3522);
      const parisDeCote = GeoPoint(48.8611, 2.3622);
      final projection =
          GeoCalcul.projeterSurSegment(parisDeCote, parisDebut, parisFin);
      // 0,01 degré de longitude à Paris ≈ 733 m, et non 1113 m.
      expect(projection.distanceMetres, closeTo(733, 15));
    });

    test('un point au-delà de l’extrémité se projette sur l’extrémité', () {
      // Le pied de la perpendiculaire tombe hors du segment : c'est alors
      // l'extrémité qui est le point le plus proche, pas un point imaginaire
      // dans le prolongement.
      const auDela = GeoPoint(6.1509, 1.2228);
      final projection = GeoCalcul.projeterSurSegment(auDela, debut, fin);
      expect(projection.fraction, 1.0);
      expect(projection.distanceMetres, closeTo(1113, 10));
    });

    test('un segment dégénéré ne fait pas diviser par zéro', () {
      // Google en produit, sur un point de passage répété.
      final projection = GeoCalcul.projeterSurSegment(fin, debut, debut);
      expect(projection.fraction, 0);
      expect(projection.distanceMetres, closeTo(1002, 10));
    });
  });

  group('Longueur d’un tracé', () {
    test('elle somme les segments', () {
      const trace = [
        lome,
        GeoPoint(6.1409, 1.2228),
        GeoPoint(6.1499, 1.2228),
      ];
      expect(GeoCalcul.longueurTrace(trace), closeTo(2004, 20));
    });

    test('un tracé d’un seul point est de longueur nulle', () {
      expect(GeoCalcul.longueurTrace(const [lome]), 0);
    });

    test('un tracé vide est de longueur nulle', () {
      expect(GeoCalcul.longueurTrace(const []), 0);
    });
  });
}
