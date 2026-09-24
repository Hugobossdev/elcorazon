import 'package:admin/presentation/programmation_campagne.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que l'écran des campagnes dit de leur état, et comment il date un envoi.
eccore.Campaign _campagne(String statut) => eccore.Campaign.fromJson({
      'id': 'c-1',
      'title': 'Titre',
      'body': 'Corps',
      'audience': 'all_customers',
      'status': statut,
      'scheduled_at': statut == 'scheduled' ? '2026-09-21T18:00:00Z' : null,
      'created_at': '2026-09-20T08:00:00Z',
      'updated_at': '2026-09-20T08:00:00Z',
    });

void main() {
  group('Le libellé d’état', () {
    test('une campagne programmée ne se dit plus « Brouillon »', () {
      // L'écran ne connaissait que deux états : tout ce qui n'était pas
      // envoyé était un brouillon, y compris ce qui partirait à 18 h.
      expect(libelleStatutCampagne(_campagne('scheduled')), 'Programmée');
      expect(libelleStatutCampagne(_campagne('draft')), 'Brouillon');
      expect(libelleStatutCampagne(_campagne('sent')), 'Envoyée');
    });

    test('un état inconnu se montre tel quel', () {
      expect(libelleStatutCampagne(_campagne('archived')), 'archived');
    });
  });

  group('L’instant d’envoi', () {
    final maintenant = DateTime(2026, 9, 21, 16, 40);

    test('se compose du jour et de l’heure saisis', () {
      final instant = instantDeProgrammation(
        DateTime(2026, 9, 21),
        const TimeOfDay(hour: 18, minute: 30),
        maintenant: maintenant,
      );

      expect(instant, DateTime(2026, 9, 21, 18, 30));
    });

    test('une heure déjà passée est refusée avant tout appel', () {
      final instant = instantDeProgrammation(
        DateTime(2026, 9, 21),
        const TimeOfDay(hour: 9, minute: 0),
        maintenant: maintenant,
      );

      expect(instant, isNull);
    });

    test('l’instant présent n’est pas « à venir »', () {
      expect(
        instantDeProgrammation(
          DateTime(2026, 9, 21),
          const TimeOfDay(hour: 16, minute: 40),
          maintenant: maintenant,
        ),
        isNull,
      );
    });
  });

  group('L’instant proposé', () {
    test('laisse au moins trente minutes, à l’heure pleine', () {
      final propose = instantPropose(maintenant: DateTime(2026, 9, 21, 16, 40));

      expect(propose, DateTime(2026, 9, 21, 18));
    });

    test('tombe le lendemain à l’approche de minuit — et le dit par sa date', () {
      // À 23 h 40, une heure proposée seule (« 01:00 ») aurait été placée
      // aujourd'hui, donc déjà passée.
      final propose = instantPropose(maintenant: DateTime(2026, 9, 21, 23, 40));

      expect(propose, DateTime(2026, 9, 22, 1));
    });
  });

  test('l’heure d’envoi se lit en jour et heure du poste', () {
    final local = DateTime(2026, 9, 21, 18, 5);

    expect(dateHeureDEnvoi(local), 'le 21/09/2026 à 18:05');
  });
}
