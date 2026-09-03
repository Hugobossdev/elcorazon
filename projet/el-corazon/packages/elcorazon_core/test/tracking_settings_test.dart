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
      expect(reglages.avertissements, isEmpty);
    });
  });

  group('TrackingSettings — bornes hautes', () {
    // Seules les valeurs trop petites étaient signalées : elles coûtent
    // visiblement (batterie, quota, 429). Les trop grandes ne coûtent rien et
    // cassent tout en silence — c'est ce que ce groupe protège.

    test('une cadence au-delà du seuil de retard est signalée', () {
      // `TRACKING_INTERVAL_SECONDS=600` est la faute de frappe naturelle pour
      // 60. Le livreur émet alors toutes les dix minutes, le back-office le
      // déclare « position figée » en permanence, et rien n'apparaissait dans
      // les journaux : on cherchait la panne côté réseau ou GPS.
      final reglages = TrackingSettings.depuisEnvironnement(const {
        'TRACKING_INTERVAL_SECONDS': '600',
      });

      expect(reglages.emissionInterval, const Duration(seconds: 600));
      expect(
        reglages.avertissements.join(),
        contains('position figée'),
      );
    });

    test('une cadence de 60 s exactement ne déclenche pas la borne haute', () {
      // La frontière est celle du back-office (`FraicheurPosition.seuilRetard`) :
      // les deux doivent s'accorder, sans quoi une flotte parfaitement suivie
      // s'affiche en rouge sur la carte de supervision.
      //
      // Le battement, lui, proteste — et il a raison : relever l'émission sans
      // relever le battement laisse ce dernier sous la bride, donc inerte.
      // C'est exactement le genre de réglage à moitié fait qu'on veut voir.
      final reglages = TrackingSettings.depuisEnvironnement(const {
        'TRACKING_INTERVAL_SECONDS': '60',
      });

      expect(
        reglages.avertissements.where((a) => a.contains('position figée')),
        isEmpty,
      );

      final coherent = reglages.copyWith(
        heartbeatInterval: const Duration(seconds: 120),
      );
      expect(coherent.avertissements, isEmpty);
    });

    test('un battement plus court que l’émission est signalé', () {
      // Il passe par la même bride que les relevés du capteur : plus court que
      // l'émission, il est intégralement écarté. Le réglage a l'air actif et
      // ne fait rien.
      final reglages = TrackingSettings.depuisEnvironnement(const {
        'TRACKING_INTERVAL_SECONDS': '60',
        'TRACKING_HEARTBEAT_SECONDS': '10',
      });

      expect(
        reglages.avertissements.join(),
        contains('écarté par la bride'),
      );
    });

    test('un battement au-delà du seuil de perte est signalé', () {
      final reglages = TrackingSettings.depuisEnvironnement(const {
        'TRACKING_HEARTBEAT_SECONDS': '600',
      });

      expect(
        reglages.avertissements.join(),
        contains('position figée'),
      );
    });

    test('une reprise trop espacée est signalée', () {
      // Un livreur qui rallume son GPS en cours de course ne doit pas attendre
      // dix minutes avant d'être suivi de nouveau.
      final reglages = TrackingSettings.depuisEnvironnement(const {
        'TRACKING_RETRY_SECONDS': '600',
      });

      expect(
        reglages.avertissements.join(),
        contains('TRACKING_RETRY_SECONDS'),
      );
    });

    test('plusieurs anomalies sont toutes rendues', () {
      // `avertissement` n'en montrait qu'une : corriger la première laissait
      // découvrir la suivante au redémarrage d'après.
      final reglages = TrackingSettings.depuisEnvironnement(const {
        'TRACKING_INTERVAL_SECONDS': '600',
        'TRACKING_MINIMUM_DISTANCE_METERS': '500',
        'TRACKING_RETRY_SECONDS': '900',
      });

      // Quatre, et non trois : le battement resté à sa valeur par défaut (30 s)
      // passe sous une émission portée à 600 s, ce qui le rend inerte. C'est
      // une anomalie que l'exploitant n'a pas saisie lui-même, et c'est
      // précisément pourquoi il faut la lui dire.
      expect(reglages.avertissements.length, 4);
      expect(reglages.avertissement, reglages.avertissements.first);
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
