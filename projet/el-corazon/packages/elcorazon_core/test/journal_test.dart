import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Journal de mise au point — ce qu'il écrit, et surtout où.
///
/// Le point vérifié n'est pas le format du message mais la **condition** :
/// `debugPrint`, que ce journal remplace, s'exécute en production et y écrivait
/// des adresses de livraison complètes. Les tests s'exécutant en mode debug,
/// on ne peut pas observer directement le silence en production ; ce qui se
/// teste, c'est que l'écriture passe bien par la porte unique — et un test
/// d'architecture interdit qu'on la contourne.
void main() {
  late List<String> ecrites;
  late DebugPrintCallback originale;

  setUp(() {
    ecrites = [];
    originale = debugPrint;
    debugPrint = (message, {wrapWidth}) => ecrites.add(message ?? '');
  });

  tearDown(() => debugPrint = originale);

  group('En mode debug', () {
    test('la trace est écrite', () {
      Journal.trace('itinéraire recalculé');
      expect(ecrites, ['itinéraire recalculé']);
    });

    test('la trace différée est composée puis écrite', () {
      var compositions = 0;
      Journal.traceDifferee(() {
        compositions++;
        return 'réponse en 3 pages';
      });

      expect(ecrites, ['réponse en 3 pages']);
      expect(compositions, 1);
    });

    test('l’ordre des écritures est celui des appels', () {
      Journal.trace('un');
      Journal.trace('deux');
      Journal.traceDifferee(() => 'trois');
      expect(ecrites, ['un', 'deux', 'trois']);
    });
  });

  group('Le seuil', () {
    test('est le mode debug, pas l’absence de mode release', () {
      // `kProfileMode` est le cas qui distingue les deux : un build de
      // profilage n'est ni debug ni release. Écrire sur la sortie standard y
      // fausserait la mesure — d'où `kDebugMode` et non `!kReleaseMode`.
      expect(kDebugMode, isTrue, reason: 'les tests tournent en mode debug');
      expect(kDebugMode && kProfileMode, isFalse);
    });
  });
}
