import 'package:admin/screens/admin/gamification/challenges.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Où en est un défi, dans l'onglet « Défis » du back-office.
///
/// La version précédente de ce test fabriquait un défi avec la clé `end_date`
/// — celle que l'écran lisait, et qu'aucune réponse du serveur ne portait
/// (`ends_at`). Le test passait, l'écran n'affichait jamais un défi terminé.
/// Le défi est désormais le modèle du socle, lu depuis le JSON du serveur.
eccore.ManagedChallenge _defi({required String debut, required String fin}) =>
    eccore.ManagedChallenge.fromJson({
      'id': 'd1',
      'title': 'Dix commandes',
      'description': '',
      'challenge_type': 'weekly',
      'condition_type': 'orders_count',
      'target_value': 10,
      'reward_points': 100,
      'starts_at': debut,
      'ends_at': fin,
      'is_active': true,
    });

void main() {
  final maintenant = DateTime.utc(2026, 8, 8, 14, 30);

  test('une fin passée : terminé', () {
    final defi = _defi(debut: '2026-08-01T00:00:00Z', fin: '2026-08-07T12:00:00Z');
    expect(etatDuDefi(defi, maintenant: maintenant), 'Terminé');
  });

  test('dans la fenêtre : en cours', () {
    final defi = _defi(debut: '2026-08-01T00:00:00Z', fin: '2026-08-09T12:00:00Z');
    expect(etatDuDefi(defi, maintenant: maintenant), 'En cours');
  });

  test('un début à venir : à venir', () {
    final defi = _defi(debut: '2026-08-10T00:00:00Z', fin: '2026-08-17T00:00:00Z');
    expect(etatDuDefi(defi, maintenant: maintenant), 'À venir');
  });

  test('la seconde de fin est déjà terminée', () {
    final defi = _defi(debut: '2026-08-01T00:00:00Z', fin: '2026-08-08T14:30:00Z');
    expect(etatDuDefi(defi, maintenant: maintenant), 'Terminé');
  });
}
