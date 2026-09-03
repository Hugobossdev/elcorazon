import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les réglages de cadence décident de ce qu'une course coûte en batterie et
/// en réseau. Ils viennent d'un `.env` saisi à la main : la question n'est donc
/// pas seulement « lit-on la bonne valeur ? », mais « que fait-on d'une valeur
/// absurde ? ».
void main() {
  group('TrackingSettings — lecture de l’environnement', () {
    test('un environnement vide rend les valeurs par défaut', () {
      final reglages = TrackingSettings.depuisEnvironnement(const {});

      expect(reglages.emissionInterval, const Duration(seconds: 10));
      expect(reglages.distanceFilterMeters, 25);
      expect(reglages.heartbeatInterval, const Duration(seconds: 30));
      expect(reglages.retryInterval, const Duration(seconds: 30));
      expect(reglages.accuracy, TrackingAccuracy.haute);
      expect(reglages.avertissement, isNull);
    });

    test('les valeurs déclarées sont reprises', () {
      final reglages = TrackingSettings.depuisEnvironnement(const {
        'TRACKING_INTERVAL_SECONDS': '15',
        'TRACKING_MINIMUM_DISTANCE_METERS': '40',
        'TRACKING_HEARTBEAT_SECONDS': '45',
        'TRACKING_RETRY_SECONDS': '20',
        'TRACKING_ACCURACY': 'moyenne',
      });

      expect(reglages.emissionInterval, const Duration(seconds: 15));
      expect(reglages.distanceFilterMeters, 40);
      expect(reglages.heartbeatInterval, const Duration(seconds: 45));
      expect(reglages.retryInterval, const Duration(seconds: 20));
      expect(reglages.accuracy, TrackingAccuracy.moyenne);
    });

    test('une valeur illisible retombe sur le défaut, sans lever', () {
      // Un `.env` mal saisi ne doit pas couper le suivi d'un livreur en course.
      final reglages = TrackingSettings.depuisEnvironnement(const {
        'TRACKING_INTERVAL_SECONDS': 'dix',
        'TRACKING_MINIMUM_DISTANCE_METERS': '',
        'TRACKING_ACCURACY': 'ultra',
      });

      expect(reglages.emissionInterval, const Duration(seconds: 10));
      expect(reglages.distanceFilterMeters, 25);
      expect(reglages.accuracy, TrackingAccuracy.haute);
    });

    test('zéro et négatif sont refusés comme intervalles', () {
      // `Duration(seconds: 0)` ferait tourner l'émission en boucle serrée.
      final reglages = TrackingSettings.depuisEnvironnement(const {
        'TRACKING_INTERVAL_SECONDS': '0',
        'TRACKING_HEARTBEAT_SECONDS': '-5',
      });

      expect(reglages.emissionInterval, const Duration(seconds: 10));
      expect(reglages.heartbeatInterval, const Duration(seconds: 30));
    });

    test('les espaces autour de la valeur ne la rendent pas illisible', () {
      final reglages = TrackingSettings.depuisEnvironnement(const {
        'TRACKING_INTERVAL_SECONDS': ' 12 ',
        'TRACKING_ACCURACY': ' Haute ',
      });

      expect(reglages.emissionInterval, const Duration(seconds: 12));
      expect(reglages.accuracy, TrackingAccuracy.haute);
    });
  });

  group('TrackingSettings — avertissements', () {
    test('une cadence sous 5 s est signalée sans être corrigée', () {
      // Signalée, pas appliquée : c'est un réglage d'exploitation, et le
      // refuser couperait le suivi au lieu de le rendre bavard.
      final reglages = TrackingSettings.depuisEnvironnement(const {
        'TRACKING_INTERVAL_SECONDS': '2',
      });

      expect(reglages.emissionInterval, const Duration(seconds: 2));
      expect(reglages.avertissement, contains('TrackingPingThrottle'));
    });

    test('un filtre au-delà du seuil serveur est signalé', () {
      final reglages = TrackingSettings.depuisEnvironnement(const {
        'TRACKING_MINIMUM_DISTANCE_METERS': '250',
      });

      expect(reglages.avertissement, contains('100 m'));
    });

    test('une distance négative est signalée', () {
      final reglages = TrackingSettings.depuisEnvironnement(const {
        'TRACKING_MINIMUM_DISTANCE_METERS': '-1',
      });

      expect(reglages.avertissement, isNotNull);
    });

    test('un réglage nominal n’avertit de rien', () {
      const reglages = TrackingSettings();
      expect(reglages.avertissement, isNull);
    });
  });

  group('TrackingSettings.copyWith', () {
    test('ne change que ce qu’on lui passe', () {
      const base = TrackingSettings();
      final modifie = base.copyWith(distanceFilterMeters: 50);

      expect(modifie.distanceFilterMeters, 50);
      expect(modifie.emissionInterval, base.emissionInterval);
      expect(modifie.accuracy, base.accuracy);
    });
  });
}
