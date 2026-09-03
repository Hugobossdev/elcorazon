import 'package:admin/services/dashboard_realtime_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// La lecture du canal temps réel.
///
/// Le canal existait côté serveur depuis l'origine et aucune application ne s'y
/// connectait. Ce qui est vérifié ici est la **traduction** — ce que le service
/// fait d'une trame — parce que c'est la partie qui décide si l'écran se met à
/// jour correctement ou affiche autre chose que ce qui s'est passé.
///
/// La connexion elle-même est vérifiée côté serveur
/// (`tests/restaurants/test_dashboard_websocket.py`, huit cas : authentification,
/// refus d'un client, cloisonnement, réception d'un changement de statut).
eccore.RealtimeEvent _evenement(String type, Map<String, dynamic> charge) =>
    eccore.RealtimeEvent.fromJson({'seq': 1, 'type': type, ...charge});

void main() {
  late DashboardRealtimeService service;

  setUp(() => service = DashboardRealtimeService.pourTests());
  tearDown(() => service.dispose());

  group('Un changement de statut', () {
    test('est traduit en commande à relire', () async {
      final recus = <ChangementDeStatut>[];
      service.changements.listen(recus.add);

      service.traiterPourTests(
        _evenement('order.status', {
          'order': 'commande-1',
          'reference': 'EC000042',
          'from_status': 'confirmed',
          'status': 'preparing',
          'reason': '',
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(recus, hasLength(1));
      expect(recus.single.orderId, 'commande-1');
      expect(recus.single.reference, 'EC000042');
      expect(recus.single.depuis, 'confirmed');
      expect(recus.single.vers, 'preparing');
    });

    test('sans identifiant de commande, rien n’est émis', () async {
      // Une trame incomplète ne doit pas faire relire « null » ni rompre le
      // flux : le canal continue, l'événement est ignoré.
      final recus = <ChangementDeStatut>[];
      service.changements.listen(recus.add);

      service.traiterPourTests(_evenement('order.status', {'reference': 'EC1'}));
      await Future<void>.delayed(Duration.zero);

      expect(recus, isEmpty);
    });

    test('un motif d’annulation est transporté', () async {
      final recus = <ChangementDeStatut>[];
      service.changements.listen(recus.add);

      service.traiterPourTests(
        _evenement('order.status', {
          'order': 'commande-2',
          'status': 'cancelled',
          'reason': 'Rupture de stock en cuisine',
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(recus.single.motif, 'Rupture de stock en cuisine');
    });

    test('un type inconnu n’émet rien et ne lève pas', () {
      // Le serveur peut diffuser un type que cette version ne connaît pas
      // encore. L'ignorer vaut mieux que fermer le canal.
      expect(
        () => service.traiterPourTests(_evenement('quelque.chose', const {})),
        returnsNormally,
      );
    });
  });

  group('Un trou dans le journal', () {
    test('demande un rechargement', () async {
      // `realtime.gap` signifie que le client a été absent plus longtemps que
      // le journal du serveur : ce qu'il affiche est incomplet, et aucun
      // événement ultérieur ne le corrigera.
      var rechargements = 0;
      service.reconnexions.listen((_) => rechargements++);

      service.traiterPourTests(
        _evenement('realtime.gap', {'from_seq': 3, 'next_seq': 60}),
      );
      await Future<void>.delayed(Duration.zero);

      expect(rechargements, 1);
    });
  });

  group('L’état affiché', () {
    test('part de « fermé » — jamais de « connecté » par optimisme', () {
      // Une pastille verte sur un canal qui n'est pas ouvert est pire que pas
      // de pastille : elle fait croire qu'on verra les changements arriver.
      expect(service.etat, EtatTempsReel.ferme);
    });

    test('compte les événements reçus', () {
      service
        ..traiterPourTests(
          _evenement('order.status', {'order': 'a', 'status': 'ready'}),
        )
        ..traiterPourTests(
          _evenement('order.status', {'order': 'b', 'status': 'ready'}),
        );

      expect(service.evenementsRecus, 2);
      expect(service.dernierEvenement, isNotNull);
    });

    test('n’a pas de dernier événement tant qu’il n’en est arrivé aucun', () {
      // `null` est l'état normal d'un service calme, pas un défaut à signaler.
      expect(service.dernierEvenement, isNull);
    });
  });
}
