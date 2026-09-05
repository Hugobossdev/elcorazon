import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les étapes d'itinéraire, telles que Google les rend.
///
/// Elles étaient jetées : `DirectionsRepository` ne lisait que le tracé
/// d'ensemble et la distance totale. C'est la raison pour laquelle aucune
/// instruction de navigation n'était possible — pas un choix d'implémentation,
/// une donnée qu'on recevait et qu'on ne regardait pas.
///
/// Ce qui est vérifié ici est ce qui **s'entend** plutôt que de se voir : une
/// balise laissée dans une instruction est prononcée par le moteur de synthèse,
/// et une manœuvre mal traduite envoie le livreur à gauche.
void main() {
  List<GeoPoint> aucunTrace(String _) => const [];

  group('Nettoyage du texte de Google', () {
    test('les balises disparaissent', () {
      expect(
        RouteStep.texteSansBalises('Prendre <b>Rue de la Paix</b>'),
        'Prendre Rue de la Paix',
      );
    });

    test('deux instructions collées par un div sont séparées', () {
      // Sans espace de remplacement, « Continuer<div>Prendre » donnerait
      // « ContinuerPrendre », qu'un moteur de synthèse prononce comme un seul
      // mot.
      expect(
        RouteStep.texteSansBalises(
          'Continuer<div style="font-size:0.9em">Prendre à droite</div>',
        ),
        'Continuer Prendre à droite',
      );
    });

    test('les entités HTML retrouvent leurs caractères', () {
      expect(
        RouteStep.texteSansBalises('Rue Alpha &amp; Oméga&nbsp;: tourner'),
        'Rue Alpha & Oméga : tourner',
      );
      expect(RouteStep.texteSansBalises('L&#39;avenue'), "L'avenue");
    });

    test('un texte sans balise passe intact', () {
      expect(RouteStep.texteSansBalises('Tourner à droite'), 'Tourner à droite');
    });

    test('un texte vide reste vide', () {
      expect(RouteStep.texteSansBalises(''), '');
    });
  });

  group('Manœuvres', () {
    test('chaque valeur de Google trouve sa traduction', () {
      expect(Manoeuvre.depuisGoogle('turn-right'), Manoeuvre.aDroite);
      expect(Manoeuvre.depuisGoogle('turn-left'), Manoeuvre.aGauche);
      expect(Manoeuvre.depuisGoogle('turn-slight-left'), Manoeuvre.legerementAGauche);
      expect(Manoeuvre.depuisGoogle('turn-sharp-right'), Manoeuvre.serreADroite);
      expect(Manoeuvre.depuisGoogle('straight'), Manoeuvre.toutDroit);
      expect(Manoeuvre.depuisGoogle('merge'), Manoeuvre.insertion);
      expect(Manoeuvre.depuisGoogle('ferry-train'), Manoeuvre.bac);
    });

    test('les deux demi-tours sont le même geste', () {
      expect(Manoeuvre.depuisGoogle('uturn-left'), Manoeuvre.demiTour);
      expect(Manoeuvre.depuisGoogle('uturn-right'), Manoeuvre.demiTour);
    });

    test('une manœuvre inconnue ne fait pas échouer la lecture', () {
      // Google en ajoute. Un itinéraire perdu pour une valeur nouvelle coûte
      // plus cher que l'instruction textuelle, qui reste juste.
      expect(Manoeuvre.depuisGoogle('teleport'), Manoeuvre.aucune);
      expect(Manoeuvre.depuisGoogle(null), Manoeuvre.aucune);
    });
  });

  group('Lecture d’une étape', () {
    Map<String, dynamic> etapeJson({String? manoeuvre}) => {
          'distance': {'value': 210},
          'duration': {'value': 45},
          'start_location': {'lat': 6.1319, 'lng': 1.2228},
          'end_location': {'lat': 6.1409, 'lng': 1.2228},
          'html_instructions': 'Prendre <b>Rue de la Paix</b>',
          if (manoeuvre != null) 'maneuver': manoeuvre,
          'polyline': {'points': '_p~iF~ps|U'},
        };

    test('elle porte ses mesures, ses points et son geste', () {
      final etape = RouteStep.fromJson(
        etapeJson(manoeuvre: 'turn-right'),
        decoder: aucunTrace,
      );

      expect(etape.distanceMeters, 210);
      expect(etape.durationSeconds, 45);
      expect(etape.start, const GeoPoint(6.1319, 1.2228));
      expect(etape.end, const GeoPoint(6.1409, 1.2228));
      expect(etape.instruction, 'Prendre Rue de la Paix');
      expect(etape.manoeuvre, Manoeuvre.aDroite);
    });

    test('une étape sans manœuvre est lisible — Google n’en met pas partout', () {
      // La première étape d'un trajet et les continuations n'en portent pas.
      // Ce n'est pas une anomalie.
      final etape = RouteStep.fromJson(etapeJson(), decoder: aucunTrace);
      expect(etape.manoeuvre, Manoeuvre.aucune);
      expect(etape.instruction, isNotEmpty);
    });

    test('le tracé de l’étape passe par le décodeur du dépôt', () {
      var appels = 0;
      final etape = RouteStep.fromJson(
        etapeJson(),
        decoder: (_) {
          appels++;
          return const [GeoPoint(1, 2)];
        },
      );
      expect(appels, 1);
      expect(etape.polylinePoints, const [GeoPoint(1, 2)]);
    });

    test('une étape sans tracé ne fait pas appeler le décodeur', () {
      final json = etapeJson()..remove('polyline');
      final etape = RouteStep.fromJson(
        json,
        decoder: (_) => throw StateError('ne doit pas être appelé'),
      );
      expect(etape.polylinePoints, isEmpty);
    });

    test('une mesure absente vaut zéro plutôt que de lever', () {
      final json = etapeJson()..remove('duration');
      final etape = RouteStep.fromJson(json, decoder: aucunTrace);
      expect(etape.durationSeconds, 0);
      expect(etape.distanceMeters, 210);
    });
  });
}
