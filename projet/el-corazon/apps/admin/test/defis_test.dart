import 'package:admin/screens/admin/gamification/challenges.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'expiration d'un défi, dans l'onglet « Défis » du back-office.
///
/// La règle vivait dans le corps d'une carte et tirait deux fois sur
/// l'horloge ; elle est atteignable depuis que l'écran de 1 744 lignes a été
/// découpé.
void main() {
  final maintenant = DateTime(2026, 8, 8, 14, 30);

  Map<String, dynamic> defi(Object? fin) => {'title': 'Dix commandes', 'end_date': fin};

  group('Expiration', () {
    test('une date passée expire', () {
      expect(defiExpire(defi('2026-08-07T12:00:00Z'), maintenant: maintenant),
          isTrue,);
    });

    test('une date à venir n’expire pas', () {
      expect(defiExpire(defi('2026-08-09T12:00:00Z'), maintenant: maintenant),
          isFalse,);
    });

    test('sans date de fin, un défi n’expire pas', () {
      // Le code prenait `DateTime.now()` comme date de fin, puis la comparait
      // à un second `DateTime.now()` pris juste après : le défi s'affichait
      // expiré par course entre deux appels à l'horloge.
      expect(defiExpire(defi(null), maintenant: maintenant), isFalse);
      expect(defiExpire(const {}, maintenant: maintenant), isFalse);
    });

    test('une date illisible n’expire pas non plus', () {
      // `DateTime.parse` levait ; `tryParse` rend `null`, et un défi dont on
      // ne sait pas quand il finit ne peut pas être déclaré fini.
      expect(defiExpire(defi('bientôt'), maintenant: maintenant), isFalse);
    });
  });

  group('Date de fin', () {
    test('est rendue quand elle est lisible', () {
      expect(dateDeFinDefi(defi('2026-08-09T12:00:00Z')),
          DateTime.parse('2026-08-09T12:00:00Z'),);
    });

    test('est absente quand le défi n’en a pas', () {
      // La carte affichait « Fin: » suivi de la date du jour.
      expect(dateDeFinDefi(defi(null)), isNull);
      expect(dateDeFinDefi(defi('bientôt')), isNull);
    });
  });
}
