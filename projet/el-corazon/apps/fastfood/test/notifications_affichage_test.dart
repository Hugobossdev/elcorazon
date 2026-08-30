import 'package:elcora_fast/presentation/genre_notification.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Ce que l'écran de notifications retient et dans quel ordre.
///
/// Le tri se faisait en place, dans le `build`, sur la liste que rend
/// `NotificationDatabaseService` — une `List.unmodifiable`. Trier cette
/// liste-là lève `Unsupported operation: sort`, et l'écran affichait le bandeau
/// rouge d'erreur à la place des notifications.
///
/// Le défaut ne se produisait que dans un cas sur quatre — onglet « Toutes »,
/// filtre « Tous », bascule éteinte —, c'est-à-dire exactement à l'ouverture de
/// l'écran. Dès qu'un filtre s'appliquait, le `.where(…).toList()` produisait
/// une copie et le tri passait : trois chemins sur quatre fonctionnaient, ce
/// qui a longtemps masqué la cause.
void main() {
  eccore.AppNotification notification({
    required String id,
    required String kind,
    required DateTime quand,
    bool lue = false,
  }) {
    return eccore.AppNotification(
      id: id,
      kind: kind,
      title: 'Titre $id',
      body: 'Corps $id',
      data: const {},
      isRead: lue,
      createdAt: quand,
    );
  }

  group('Liste non modifiable', () {
    test('une liste non modifiable est acceptée sans lever', () {
      // Le cas exact qui cassait l'écran : aucun filtre, et la liste que rend
      // le service tel quel.
      final duService = List<eccore.AppNotification>.unmodifiable([
        notification(
          id: '1',
          kind: 'order_status',
          quand: DateTime(2026, 8, 18, 10),
        ),
        notification(
          id: '2',
          kind: 'payment',
          quand: DateTime(2026, 8, 18, 12),
        ),
      ]);

      final affichees = notificationsAAfficher(duService);

      expect(affichees.map((n) => n.id), ['2', '1']);
    });

    test('la liste d\'origine n\'est pas réordonnée', () {
      final origine = [
        notification(
          id: '1',
          kind: 'order_status',
          quand: DateTime(2026, 8, 18, 10),
        ),
        notification(
          id: '2',
          kind: 'payment',
          quand: DateTime(2026, 8, 18, 12),
        ),
      ];

      notificationsAAfficher(origine);

      expect(origine.map((n) => n.id), ['1', '2']);
    });
  });

  group('Ordre', () {
    test('la plus récente vient en premier', () {
      final affichees = notificationsAAfficher([
        notification(
          id: 'ancienne',
          kind: 'account',
          quand: DateTime(2026, 8, 16),
        ),
        notification(
          id: 'recente',
          kind: 'account',
          quand: DateTime(2026, 8, 18),
        ),
        notification(
          id: 'intermediaire',
          kind: 'account',
          quand: DateTime(2026, 8, 17),
        ),
      ]);

      expect(
        affichees.map((n) => n.id),
        ['recente', 'intermediaire', 'ancienne'],
      );
    });
  });

  group('Filtres', () {
    final lot = [
      notification(
        id: 'commande',
        kind: 'order_status',
        quand: DateTime(2026, 8, 18, 9),
      ),
      notification(
        id: 'paiement-lu',
        kind: 'payment',
        quand: DateTime(2026, 8, 18, 10),
        lue: true,
      ),
      notification(
        id: 'promo',
        kind: 'marketing',
        quand: DateTime(2026, 8, 18, 11),
      ),
    ];

    test('sans critère, tout est retenu', () {
      expect(notificationsAAfficher(lot).length, 3);
    });

    test('le genre restreint à sa catégorie', () {
      final affichees = notificationsAAfficher(
        lot,
        genre: GenreNotification.commande,
      );

      expect(affichees.map((n) => n.id), ['commande']);
    });

    test('« non lues seulement » écarte celles qui sont lues', () {
      final affichees = notificationsAAfficher(lot, nonLuesSeulement: true);

      expect(affichees.map((n) => n.id), ['promo', 'commande']);
    });

    test('les deux critères se cumulent', () {
      final affichees = notificationsAAfficher(
        lot,
        genre: GenreNotification.paiement,
        nonLuesSeulement: true,
      );

      expect(affichees, isEmpty);
    });

    test('un genre inconnu du serveur retombe sur « Compte »', () {
      // `depuisServeur` range l'inconnu dans `compte` plutôt que de le faire
      // disparaître d'une liste qu'on consulte pour ne rien manquer.
      final affichees = notificationsAAfficher(
        [
          notification(
            id: 'inconnue',
            kind: 'genre_qui_nexiste_pas_encore',
            quand: DateTime(2026, 8, 18),
          ),
        ],
        genre: GenreNotification.compte,
      );

      expect(affichees.map((n) => n.id), ['inconnue']);
    });
  });

  group('Le regroupement par journee', () {
    // La maquette separe « Today » et « Yesterday ». Sans ces intertitres, une
    // liste de trente alertes n'a plus de repere : « il y a 3 h » se confond
    // avec « il y a 3 jours » des qu'on fait defiler.

    eccore.AppNotification a(DateTime creee, {String titre = 'Alerte'}) {
      return eccore.AppNotification(
        id: creee.toIso8601String(),
        kind: 'order_status',
        title: titre,
        body: '',
        data: const {},
        isRead: false,
        createdAt: creee,
      );
    }

    final maintenant = DateTime(2026, 8, 30, 10, 0);

    test('une liste vide ne produit aucun paquet', () {
      expect(grouperParJour(const [], maintenant: maintenant), isEmpty);
    });

    test('les notifications du jour tombent sous « Aujourd’hui »', () {
      final paquets = grouperParJour(
        [a(DateTime(2026, 8, 30, 9)), a(DateTime(2026, 8, 30, 2))],
        maintenant: maintenant,
      );

      expect(paquets.length, 1);
      expect(paquets.first.libelle, 'Aujourd’hui');
      expect(paquets.first.notifications.length, 2);
    });

    test('le regroupement suit la journee civile, pas 24 heures', () {
      // A 1 h du matin, une notification de 23 h la veille appartient a
      // « Hier » — meme si elle date de deux heures. C'est ainsi qu'on lit un
      // journal.
      final paquets = grouperParJour(
        [a(DateTime(2026, 8, 29, 23))],
        maintenant: DateTime(2026, 8, 30, 1),
      );

      expect(paquets.single.libelle, 'Hier');
    });

    test('les journees sont rangees de la plus recente a la plus ancienne', () {
      final paquets = grouperParJour(
        [
          a(DateTime(2026, 8, 28, 12)),
          a(DateTime(2026, 8, 30, 8)),
          a(DateTime(2026, 8, 29, 15)),
        ],
        maintenant: maintenant,
      );

      expect(
        paquets.map((p) => p.libelle).toList(),
        ['Aujourd’hui', 'Hier', '28/08'],
      );
    });

    test('aucune notification ne se perd au passage', () {
      final source = [
        a(DateTime(2026, 8, 30, 8)),
        a(DateTime(2026, 8, 29, 15)),
        a(DateTime(2026, 8, 29, 9)),
        a(DateTime(2026, 7, 2, 9)),
      ];
      final paquets = grouperParJour(source, maintenant: maintenant);
      final total = paquets.fold<int>(0, (n, p) => n + p.notifications.length);

      expect(total, source.length);
    });

    test('au-dela de l’annee la date porte son millesime', () {
      final paquets = grouperParJour(
        [a(DateTime(2025, 3, 4, 9))],
        maintenant: maintenant,
      );

      expect(paquets.single.libelle, '04/03/2025');
    });
  });
}
