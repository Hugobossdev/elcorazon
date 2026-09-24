import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/presentation/dialogues/assignation_livreur.dart';
import 'package:admin/services/driver_management_service.dart';
import 'package:admin/services/order_management_service.dart';

import 'aide_commande.dart';

/// Le dialogue d'affectation : qui il propose, et ce qu'il annonce.
///
/// ## Ce que ces cas ferment
///
/// Le dialogue lisait la flotte déjà chargée et la filtrait lui-même — en
/// ligne, dossier validé, pas déjà engagé. Il manquait la cuisine de la
/// commande et le périmètre de zone : un siège se voyait proposer un livreur de
/// Douala pour une commande de Lomé, et le serveur refusait ensuite en 409.
/// L'éligibilité vient désormais de `GET /delivery/couriers/available/{id}/`,
/// et rien n'est refiltré ici.
///
/// Trois mensonges d'affichage sont également épinglés, parce qu'ils se
/// réintroduisent facilement :
///
/// * un refus de lecture affiché comme une flotte vide — le superviseur
///   attendait alors un livreur que personne ne lui avait refusé ;
/// * le dialogue fermé **avant** la réponse du serveur, ce qui faisait perdre
///   la liste au moment précis où il fallait choisir quelqu'un d'autre ;
/// * « Course proposée » annoncée sans confirmation.
Map<String, dynamic> _livreurJson({
  required String id,
  required String nom,
  int? distanceM,
  int notes = 9,
  double moyenne = 4.8,
}) {
  return {
    'id': id,
    'full_name': nom,
    'email': '$id@elcorazon.test',
    'phone': '+22890000000',
    'restaurant': 'el-corazon-lome',
    'service_zones': const <dynamic>[],
    'verification_status': 'approved',
    'id_document': null,
    'licence_document': null,
    'vehicle_document': null,
    'verification_notes': '',
    'verified_at': null,
    'vehicle_type': 'motorcycle',
    'vehicle_plate': '',
    'is_online': true,
    'can_accept_orders': true,
    'last_location': null,
    'last_location_at': null,
    'distance_m': distanceM,
    'deliveries_completed': 12,
    'deliveries_cancelled': 0,
    'rating_average': '$moyenne',
    'rating_count': notes,
    'total_earnings': null,
    'created_at': '2026-09-01T10:00:00Z',
    'updated_at': '2026-09-07T10:00:00Z',
  };
}

eccore.CourierProfile _livreur({
  required String id,
  required String nom,
  int? distanceM,
  int notes = 9,
}) {
  return eccore.CourierProfile.fromJson(
    _livreurJson(id: id, nom: nom, distanceM: distanceM, notes: notes),
  );
}

/// La flotte, telle que le serveur la rend pour **une** commande.
class _FausseFlotte extends DriverManagementService {
  _FausseFlotte({this.eligibles = const [], this.refus});

  List<eccore.CourierProfile> eligibles;
  eccore.ApiException? refus;

  /// Les commandes pour lesquelles l'éligibilité a été demandée — une lecture
  /// par ouverture, et une de plus après un 409.
  final List<String> lectures = [];

  @override
  Future<List<eccore.CourierProfile>> availableForOrder(String orderId) async {
    lectures.add(orderId);
    final refuse = refus;
    if (refuse != null) throw refuse;
    return eligibles;
  }
}

class _FausseSupervision extends OrderManagementService {
  _FausseSupervision({this.refus});

  eccore.ApiException? refus;
  final List<String> propositions = [];

  @override
  Future<void> assignDriver(String orderId, String courierId) async {
    propositions.add('$orderId→$courierId');
    final refuse = refus;
    if (refuse != null) throw refuse;
  }
}

void main() {
  final commande = eccore.Order.fromJson(commandeJson(statut: 'ready'));

  Future<void> ouvrir(
    WidgetTester tester, {
    required _FausseFlotte flotte,
    required _FausseSupervision supervision,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => afficherAssignationLivreur(
                context: context,
                order: commande,
                orderService: supervision,
                driverService: flotte,
              ),
              child: const Text('Assigner'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Assigner'));
    await tester.pumpAndSettle();
  }

  group("L'éligibilité vient du serveur", () {
    testWidgets('un refus de lecture ne se lit pas comme une flotte vide', (tester) async {
      final flotte = _FausseFlotte(
        refus: const eccore.ApiException(
          status: 403,
          code: 'permission_denied',
          detail: 'Vous n’avez pas la permission « couriers.read ».',
        ),
      );

      await ouvrir(tester, flotte: flotte, supervision: _FausseSupervision());

      expect(find.textContaining('Accès refusé'), findsOneWidget);
      expect(find.textContaining('couriers.read'), findsOneWidget);
      // Le texte des cinq conditions dirait « aucun livreur ne convient »,
      // alors que la question n'a jamais été posée au serveur.
      expect(find.textContaining('Aucun livreur éligible'), findsNothing);
      // Et rien n'est proposable : le bouton reste inerte.
      final bouton = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Proposer la course'),
          matching: find.byWidgetPredicate((widget) => widget is ElevatedButton),
        ),
      );
      expect(bouton.onPressed, isNull);
    });

    testWidgets('aucun éligible : les conditions du serveur sont nommées', (tester) async {
      await ouvrir(
        tester,
        flotte: _FausseFlotte(),
        supervision: _FausseSupervision(),
      );

      expect(find.textContaining('Aucun livreur éligible'), findsOneWidget);
      // Trois des cinq conditions se corrigent depuis le back-office : les
      // nommer est la différence entre « attendre » et « agir ».
      expect(find.textContaining('Dossier validé'), findsOneWidget);
      expect(find.textContaining('Desservant la zone'), findsOneWidget);
      expect(find.textContaining('Pas déjà en course'), findsOneWidget);
      // L'ancien texte renvoyait vers un écran d'affectation manuelle qui
      // n'existe pas — ni comme écran, ni comme route.
      expect(find.textContaining('manuellement'), findsNothing);
    });

    testWidgets("l'ordre du serveur est conservé, distance comprise", (tester) async {
      final flotte = _FausseFlotte(
        eligibles: [
          _livreur(id: 'a', nom: 'Kofi Proche', distanceM: 350),
          _livreur(id: 'b', nom: 'Ama Loin', distanceM: 1240),
        ],
      );

      await ouvrir(tester, flotte: flotte, supervision: _FausseSupervision());

      expect(flotte.lectures, [commande.id]);
      expect(find.text('à 350 m'), findsOneWidget);
      expect(find.text('à 1,2 km'), findsOneWidget);
      // Le serveur trie par distance à la **cuisine** ; réordonner ici
      // reviendrait à trier sur une donnée qu'on n'a pas.
      final proche = tester.getTopLeft(find.text('Kofi Proche')).dy;
      final loin = tester.getTopLeft(find.text('Ama Loin')).dy;
      expect(proche, lessThan(loin));
    });

    testWidgets('une position inconnue ne vaut pas zéro mètre', (tester) async {
      // Un livreur qui vient d'ouvrir son application reste éligible, et le
      // serveur le place en fin de tri. Afficher « à 0 m » le mettrait sur le
      // pas de la porte.
      await ouvrir(
        tester,
        flotte: _FausseFlotte(eligibles: [_livreur(id: 'a', nom: 'Kodjo Neuf')]),
        supervision: _FausseSupervision(),
      );

      expect(find.text('Position inconnue'), findsOneWidget);
      expect(find.textContaining('0 m'), findsNothing);
    });

    testWidgets('un livreur sans note n’est pas noté 0,0', (tester) async {
      await ouvrir(
        tester,
        flotte: _FausseFlotte(
          eligibles: [_livreur(id: 'a', nom: 'Kodjo Neuf', notes: 0)],
        ),
        supervision: _FausseSupervision(),
      );

      expect(find.text('Pas encore noté'), findsOneWidget);
      expect(find.textContaining('0.0'), findsNothing);
      expect(find.textContaining('0,0'), findsNothing);
    });
  });

  group('La proposition attend le serveur', () {
    testWidgets('un refus garde le dialogue ouvert et relit la liste', (tester) async {
      final flotte = _FausseFlotte(
        eligibles: [
          _livreur(id: 'a', nom: 'Kofi Proche', distanceM: 350),
          _livreur(id: 'b', nom: 'Ama Loin', distanceM: 1240),
        ],
      );
      final supervision = _FausseSupervision(
        refus: const eccore.ApiException(
          status: 409,
          code: 'conflict',
          detail: 'Ce livreur porte déjà une course.',
        ),
      );

      await ouvrir(tester, flotte: flotte, supervision: supervision);
      await tester.tap(find.text('Kofi Proche'));
      await tester.pump();
      await tester.tap(find.text('Proposer la course'));
      await tester.pumpAndSettle();

      // Le dialogue se fermait avant la réponse : le superviseur lisait le
      // refus sur l'écran d'en dessous, sa liste perdue, alors qu'un 409 est
      // précisément le cas où il faut en choisir un autre tout de suite.
      expect(find.text('Assigner un livreur'), findsOneWidget);
      expect(find.textContaining('porte déjà une course'), findsOneWidget);
      // `skipOffstage: false` : sur la surface du test, le bandeau rétrécit la
      // liste au point que la seconde carte tombe hors du viewport. Ce qui est
      // vérifié ici est qu'elle est toujours proposable, pas qu'elle est
      // visible sans faire défiler.
      expect(find.text('Ama Loin', skipOffstage: false), findsOneWidget);
      // Et la liste est relue : celui que le serveur vient d'écarter n'a plus
      // à être proposé.
      expect(flotte.lectures.length, 2);
      // Rien n'a été annoncé.
      expect(find.textContaining('Course proposée'), findsNothing);
    });

    testWidgets('le succès est annoncé après confirmation, pas avant', (tester) async {
      final supervision = _FausseSupervision();

      await ouvrir(
        tester,
        flotte: _FausseFlotte(
          eligibles: [_livreur(id: 'a', nom: 'Kofi Proche', distanceM: 350)],
        ),
        supervision: supervision,
      );
      await tester.tap(find.text('Kofi Proche'));
      await tester.pump();
      await tester.tap(find.text('Proposer la course'));
      await tester.pumpAndSettle();

      expect(supervision.propositions, ['${commande.id}→a']);
      expect(find.text('Assigner un livreur'), findsNothing);
      // « Proposée », et non « assignée » : le livreur accepte ou refuse.
      expect(find.text('Course proposée à Kofi Proche'), findsOneWidget);
    });
  });
}
