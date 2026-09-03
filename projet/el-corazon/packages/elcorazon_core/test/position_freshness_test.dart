import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Une carte qui ment sur la fraîcheur de ses points est pire qu'une carte
/// vide : on ne cherche pas un livreur dont on croit savoir où il est. Ces
/// tests fixent la frontière entre « en direct », « en retard » et « perdu ».
void main() {
  final maintenant = DateTime.utc(2026, 9, 3, 12);

  FraicheurPosition depuis(Duration age) =>
      FraicheurPosition.depuis(maintenant.subtract(age), maintenant: maintenant);

  group('FraicheurPosition', () {
    test('un relevé de la seconde est en direct', () {
      expect(depuis(const Duration(seconds: 1)), FraicheurPosition.fraiche);
      expect(depuis(const Duration(seconds: 1)).estEnDirect, isTrue);
    });

    test('un relevé de 59 s est encore en direct', () {
      // La cadence nominale est de 10 s, le battement d'un livreur immobile de
      // 30 s : sous la minute, le silence s'explique.
      expect(depuis(const Duration(seconds: 59)), FraicheurPosition.fraiche);
    });

    test('à 60 s exactement, le relevé passe en retard', () {
      expect(depuis(const Duration(seconds: 60)), FraicheurPosition.retardee);
      expect(depuis(const Duration(seconds: 60)).estEnDirect, isFalse);
    });

    test('à 5 min exactement, la position est perdue', () {
      expect(depuis(const Duration(minutes: 5)), FraicheurPosition.perdue);
    });

    test('une demi-heure de silence est une position perdue', () {
      expect(depuis(const Duration(minutes: 30)), FraicheurPosition.perdue);
    });

    test('un horodatage en avance sur nous reste frais', () {
      // L'horloge du téléphone du livreur n'est pas la nôtre : quelques
      // secondes d'avance sont courantes. Les compter comme un retard
      // afficherait « position perdue » sur un suivi qui marche.
      expect(
        FraicheurPosition.depuis(
          maintenant.add(const Duration(seconds: 20)),
          maintenant: maintenant,
        ),
        FraicheurPosition.fraiche,
      );
    });
  });

  group('ageLisible', () {
    String age(Duration ecoule) =>
        ageLisible(maintenant.subtract(ecoule), maintenant: maintenant);

    test('sous 5 s, « à l’instant » plutôt qu’un décompte', () {
      expect(age(const Duration(seconds: 2)), 'à l’instant');
    });

    test('en secondes sous la minute', () {
      expect(age(const Duration(seconds: 8)), 'il y a 8 s');
    });

    test('en minutes sous l’heure', () {
      expect(age(const Duration(minutes: 5)), 'il y a 5 min');
      expect(age(const Duration(seconds: 90)), 'il y a 1 min');
    });

    test('en heures sous le jour', () {
      expect(age(const Duration(hours: 3)), 'il y a 3 h');
    });

    test('en jours au-delà', () {
      expect(age(const Duration(days: 2)), 'il y a 2 j');
    });

    test('un horodatage en avance se lit « à l’instant »', () {
      expect(
        ageLisible(
          maintenant.add(const Duration(seconds: 30)),
          maintenant: maintenant,
        ),
        'à l’instant',
      );
    });
  });
}
