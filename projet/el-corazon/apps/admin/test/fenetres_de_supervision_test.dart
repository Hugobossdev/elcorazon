import 'dart:convert';

import 'package:admin/presentation/statut_commande.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/order_management_service.dart';
import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'aide_commande.dart';

/// Les données dont chaque écran du back-office dépend — et qui les charge.
///
/// ## Le défaut que cette suite ferme
///
/// Cinq écrans lisent la **fenêtre agrégée** des commandes : le poste de
/// cuisine, les livraisons actives, la carte temps réel, l'historique d'un
/// livreur et ses statistiques. Aucun des cinq ne la demandait.
///
/// `ensureWindowLoaded()` n'avait qu'un seul appelant — un onglet de la
/// supervision — et `refresh()` ne rechargeait la fenêtre que si elle avait
/// **déjà** été lue. Ouvrir « Livraisons actives » en premier affichait donc
/// « Aucune livraison active » sur un service en cours, sans erreur, sans
/// indicateur, et son bouton « Recharger » ne rechargeait rien.
///
/// Ce qui est vérifié ici est la cause commune aux cinq écrans : le contrat du
/// service. Les écrans, eux, déclarent leur dépendance en appelant
/// `ensureWindowLoaded()` à l'ouverture.
const _canalStockage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _entetesJson = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

/// Sert la supervision, les compteurs et le poste de cuisine.
class _FauxServeur implements HttpClientAdapter {
  /// Les commandes de la fenêtre agrégée (`/orders/manage/`).
  List<Map<String, dynamic>> commandes = const [];

  /// Les files de production, par slug d'établissement.
  Map<String, List<Map<String, dynamic>>> cuisine = const {};

  /// Le serveur répond 503 à tout — la panne, pas le service calme.
  bool enPanne = false;

  void reinitialiser() {
    commandes = const [];
    cuisine = const {};
    enPanne = false;
    chemins.clear();
    parametres.clear();
  }

  final List<String> chemins = [];
  final List<Map<String, dynamic>> parametres = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    chemins.add(options.path);
    parametres.add(Map<String, dynamic>.from(options.queryParameters));

    if (enPanne) {
      return ResponseBody.fromString(
        jsonEncode({'detail': 'Le service est momentanément indisponible.'}),
        503,
        headers: _entetesJson,
      );
    }

    if (options.path.contains('/orders/manage/kitchen/')) {
      final slug = options.queryParameters['restaurant'] as String? ?? '';
      return _page(cuisine[slug] ?? const []);
    }
    if (options.path.contains('/orders/manage/counts/')) {
      return _json(<String, int>{});
    }
    return _page(_filtrees(options.queryParameters));
  }

  /// Le filtre de statut, **appliqué** — comme le serveur l'applique.
  ///
  /// La fenêtre agrégée est faite de deux lectures disjointes : ce qui est en
  /// cours, et ce qui s'est terminé depuis vingt-quatre heures. Un faux serveur
  /// qui rend les mêmes commandes aux deux les faisait compter double, ce qui
  /// n'arrive pas en production et masquait ici la seule chose que ces cas
  /// vérifient : le contenu de la fenêtre.
  List<Map<String, dynamic>> _filtrees(Map<String, dynamic> parametres) {
    final demandes = (parametres['status__in'] as String?)?.split(',') ??
        (parametres['status'] as String?)?.split(',');
    if (demandes == null || demandes.isEmpty) return commandes;
    return [
      for (final commande in commandes)
        if (demandes.contains(commande['status'])) commande,
    ];
  }

  ResponseBody _page(List<Map<String, dynamic>> lignes) =>
      _json({'count': lignes.length, 'next': null, 'previous': null, 'results': lignes});

  ResponseBody _json(Object corps) =>
      ResponseBody.fromString(jsonEncode(corps), 200, headers: _entetesJson);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_canalStockage, (call) async => null);

  // Un seul faux serveur et un seul conteneur pour tout le fichier :
  // `AdminAuthService` est un singleton d'application et garde le conteneur de
  // sa **première** construction. En créer un par test laisserait le service
  // lire un conteneur déjà disposé.
  final serveur = _FauxServeur();
  final conteneur = ProviderContainer(
    overrides: [
      eccore.apiClientProvider.overrideWithValue(
        eccore.ApiClient(
          baseUrl: 'https://exemple.test/api/v1',
          tokenStorage: eccore.TokenStorage(),
          testAdapter: serveur,
        ),
      ),
    ],
  );
  AdminAuthService(conteneur);

  setUp(serveur.reinitialiser);
  tearDownAll(conteneur.dispose);

  OrderManagementService service({
    List<Map<String, dynamic>> commandes = const [],
    Map<String, List<Map<String, dynamic>>> cuisine = const {},
    bool enPanne = false,
  }) {
    serveur
      ..commandes = commandes
      ..cuisine = cuisine
      ..enPanne = enPanne;
    return OrderManagementService();
  }

  group('La fenêtre agrégée', () {
    test('un écran qui la demande la reçoit', () async {
      final sut = service(commandes: [commandeJson(statut: 'ready')]);

      await sut.ensureWindowLoaded();

      expect(sut.allOrders, hasLength(1));
      expect(sut.fenetreChargee, isTrue);
      expect(sut.erreurFenetre, isNull);
    });

    test('vide sans erreur reste un service calme', () async {
      // « Aucune livraison active » est alors la bonne phrase.
      final sut = service();

      await sut.ensureWindowLoaded();

      expect(sut.allOrders, isEmpty);
      expect(sut.fenetreChargee, isTrue);
      expect(sut.erreurFenetre, isNull);
    });

    test('une panne se dit, au lieu de passer pour un service calme', () async {
      final sut = service(enPanne: true);

      await sut.ensureWindowLoaded();

      expect(sut.allOrders, isEmpty);
      expect(sut.erreurFenetre, isNotNull);
      // Le motif vient du serveur, pas d'un nom de classe Dart.
      expect(sut.erreurFenetre, contains('serveur'));
    });

    test('rafraîchir recharge la fenêtre même si elle n’a jamais abouti', () async {
      // Le cœur du défaut : `refresh()` ne relisait que ce qui avait déjà été
      // lu, donc le bouton « Recharger » d'un écran en panne ne rechargeait
      // rien.
      final sut = service(commandes: [commandeJson()], enPanne: true);
      await sut.ensureWindowLoaded();
      expect(sut.erreurFenetre, isNotNull);

      serveur.enPanne = false;
      await sut.refresh();

      expect(sut.allOrders, hasLength(1));
      expect(sut.erreurFenetre, isNull);
    });

    test('une panne passagère n’efface pas ce qui est affiché', () async {
      // En plein service, une liste qui se vide sur une coupure de trois
      // secondes fait disparaître des commandes réelles sous les yeux de
      // l'opérateur.
      final sut = service(commandes: [commandeJson()]);
      await sut.ensureWindowLoaded();

      serveur.enPanne = true;
      await sut.rechargerLaFenetre();

      expect(sut.allOrders, hasLength(1));
      expect(sut.erreurFenetre, isNotNull);
    });
  });

  group('Un refus du serveur remonte jusqu’à l’écran', () {
    test('un changement de statut refusé lève, avec le motif', () async {
      // Il rendait `false`, en ne gardant que le code dans le journal : un 403
      // sans `orders.update_status`, un 409 « cette commande est déjà partie »
      // et une coupure réseau donnaient la même phrase — « Erreur lors du
      // changement de statut » — qui n'indique aucun geste à faire.
      final sut = service(enPanne: true);

      await expectLater(
        sut.updateOrderStatus('commande-1', StatutCommande.prete),
        throwsA(isA<eccore.ApiException>()),
      );
    });

    test('une annulation refusée lève aussi', () async {
      // L'écran devinait le motif : « permission « orders.cancel », ou commande
      // trop avancée » — là où le serveur avait écrit laquelle des deux.
      final sut = service(enPanne: true);

      await expectLater(
        sut.cancelOrder('commande-1', 'motif'),
        throwsA(isA<eccore.ApiException>()),
      );
    });
  });

  group('Le poste de cuisine', () {
    test('lit la file d’une cuisine, pas la fenêtre de supervision', () async {
      final sut = service(
        commandes: [commandeJson(id: 'supervision')],
        cuisine: {
          'el-corazon-lome': [
            commandeCuisineJson(
              id: 'cuisine',
              lignes: [ligneCuisineJson(options: ['Fort'])],
            ),
          ],
        },
      );

      await sut.chargerLePoste('el-corazon-lome');

      expect(sut.poste, hasLength(1));
      expect(sut.poste.single.id, 'cuisine');
      // Les plats sont là — c'est ce que la forme de liste ne portait pas.
      expect(sut.poste.single.lines.single.itemName, 'Poulet braisé');
      expect(sut.poste.single.lines.single.options, ['Fort']);
      // L'établissement voyage jusqu'au serveur : l'isolement est sa règle.
      expect(serveur.parametres.last['restaurant'], 'el-corazon-lome');
    });

    test('changer de cuisine ne laisse pas les commandes de l’autre', () async {
      final sut = service(
        cuisine: {
          'el-corazon-lome': [commandeCuisineJson(id: 'lome')],
          'el-corazon-abidjan': [commandeCuisineJson(id: 'abidjan')],
        },
      );
      await sut.chargerLePoste('el-corazon-lome');

      await sut.chargerLePoste('el-corazon-abidjan');

      expect(sut.poste.map((c) => c.id), ['abidjan']);
    });

    test('une panne se dit et garde la file précédente', () async {
      final sut = service(
        cuisine: {
          'el-corazon-lome': [commandeCuisineJson(id: 'lome')],
        },
      );
      await sut.chargerLePoste('el-corazon-lome');

      serveur.enPanne = true;
      await sut.chargerLePoste('el-corazon-lome');

      expect(sut.poste, hasLength(1));
      expect(sut.erreurPoste, isNotNull);
    });

    test('un poste vide n’est pas une panne', () async {
      final sut = service();

      await sut.chargerLePoste('el-corazon-lome');

      expect(sut.poste, isEmpty);
      expect(sut.erreurPoste, isNull);
    });
  });
}
