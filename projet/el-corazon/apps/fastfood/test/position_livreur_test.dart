import 'package:elcora_fast/models/position_livreur.dart';
import 'package:flutter_test/flutter_test.dart';

/// Relevés de position reçus par le canal de suivi.
///
/// Ce point de passage portait le bug qui figeait le livreur sur la carte : le
/// service produisait un `DateTime` dans une carte non typée, l'écran le
/// relisait comme une `String`, et la conversion levait **à chaque position
/// reçue** — au fond d'un écouteur asynchrone, donc sans que rien ne paraisse.
/// Le repère restait sur la position initiale pendant toute la livraison.
///
/// Le type nommé rend cette faute impossible. Ces cas gardent l'autre moitié
/// du contrat : ce que l'application fait d'une trame incomplète.
void main() {
  group('Trame complète', () {
    test('les coordonnées et l\'horodatage sont relus', () {
      final position = PositionLivreur.depuisDiffusion('commande-1', {
        'lat': 6.1725,
        'lon': 1.2314,
        'recorded_at': '2026-08-18T14:32:10.000Z',
      });

      expect(position, isNotNull);
      expect(position!.commandeId, 'commande-1');
      expect(position.latitude, 6.1725);
      expect(position.longitude, 1.2314);
      expect(position.releveeA, DateTime.parse('2026-08-18T14:32:10.000Z'));
    });

    test('des coordonnées entières restent lisibles', () {
      // JSON ne distingue pas 6 de 6.0 : `as double` levait sur un entier,
      // ce qui aurait fait perdre la position dès qu'un relevé tombait pile.
      final position = PositionLivreur.depuisDiffusion('commande-1', {
        'lat': 6,
        'lon': 1,
        'recorded_at': '2026-08-18T14:32:10.000Z',
      });

      expect(position, isNotNull);
      expect(position!.latitude, 6.0);
      expect(position.longitude, 1.0);
    });
  });

  group('Trame incomplète', () {
    test('sans latitude, le relevé est écarté au lieu de lever', () {
      final position = PositionLivreur.depuisDiffusion('commande-1', {
        'lon': 1.2314,
        'recorded_at': '2026-08-18T14:32:10.000Z',
      });

      expect(position, isNull);
    });

    test('sans horodatage non plus', () {
      final position = PositionLivreur.depuisDiffusion('commande-1', {
        'lat': 6.1725,
        'lon': 1.2314,
      });

      expect(position, isNull);
    });

    test('une date illisible écarte le relevé, elle ne l\'interrompt pas', () {
      // Un relevé perdu n'est pas grave : le suivant arrive quelques secondes
      // plus tard. Une exception, elle, remonterait dans un écouteur où
      // personne ne la rattrape.
      final position = PositionLivreur.depuisDiffusion('commande-1', {
        'lat': 6.1725,
        'lon': 1.2314,
        'recorded_at': 'hier après-midi',
      });

      expect(position, isNull);
    });
  });

  group('Vitesse', () {
    test('les m/s deviennent des km/h', () {
      final position = PositionLivreur(
        commandeId: 'commande-1',
        latitude: 6.1725,
        longitude: 1.2314,
        releveeA: DateTime(2026, 8, 18),
        vitesseMetresParSeconde: 10,
      );

      expect(position.vitesseKmH, closeTo(36, 0.001));
    });

    test('une vitesse absente reste absente, elle ne devient pas zéro', () {
      // Zéro est une vitesse — celle d'un livreur à l'arrêt. L'ignorer
      // reviendrait à afficher « 0 km/h » là où on ne sait simplement pas.
      final position = PositionLivreur(
        commandeId: 'commande-1',
        latitude: 6.1725,
        longitude: 1.2314,
        releveeA: DateTime(2026, 8, 18),
      );

      expect(position.vitesseKmH, isNull);
    });

    test('un livreur à l\'arrêt rapporte bien zéro', () {
      final position = PositionLivreur(
        commandeId: 'commande-1',
        latitude: 6.1725,
        longitude: 1.2314,
        releveeA: DateTime(2026, 8, 18),
        vitesseMetresParSeconde: 0,
      );

      expect(position.vitesseKmH, 0);
    });
  });
}
