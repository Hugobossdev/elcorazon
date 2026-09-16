import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'inventaire et les recettes, côté socle.
///
/// Ce que ces cas verrouillent : la quantité ne passe jamais par un `double` ;
/// les écritures de valeur portent la clé d'idempotence que **l'écran** fournit ;
/// une déclaration dit si elle est écrite ou en attente ; et les formes JSON du
/// serveur se relisent sans perte.

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _quantite(String amount, [String unit = 'g', String dimension = 'mass']) =>
    {'amount': amount, 'unit': unit, 'dimension': dimension};

Map<String, dynamic> _ligneDeStock() => {
      'id': 'stock-1',
      'restaurant': 'el-corazon-lome',
      'restaurant_name': 'El Corazón',
      'ingredient': 'ing-1',
      'ingredient_name': 'Bœuf',
      'ingredient_slug': 'boeuf',
      'dimension': 'mass',
      'on_hand': _quantite('10000'),
      'reserved': _quantite('400'),
      'available': _quantite('9600'),
      'low_stock_threshold': _quantite('12000'),
      'is_low': true,
      'unit_cost': {'amount': '4000', 'currency': 'XOF'},
      'cost_unit': 'kg',
      'stock_value': {'amount': '40000', 'currency': 'XOF'},
      'created_at': '2026-09-13T10:00:00Z',
      'updated_at': '2026-09-13T10:00:00Z',
    };

Map<String, dynamic> _mouvement() => {
      'id': 'mvt-1',
      'stock_item': 'stock-1',
      'restaurant': 'el-corazon-lome',
      'ingredient_name': 'Bœuf',
      'kind': 'receipt',
      'quantity': _quantite('5000'),
      'unit_cost': {'amount': '2400', 'currency': 'XOF'},
      'value': {'amount': '12000', 'currency': 'XOF'},
      'actor': {'id': 'u-1', 'full_name': 'Kossi'},
      'reason': '',
      'reference': 'BL-42',
      'created_at': '2026-09-13T10:00:00Z',
    };

Map<String, dynamic> _demande({String status = 'pending'}) => {
      'id': 'dem-1',
      'stock_item': 'stock-1',
      'restaurant': 'el-corazon-lome',
      'ingredient_name': 'Bœuf',
      'kind': 'waste',
      'quantity': _quantite('-2000'),
      'reason': 'Chaîne du froid rompue',
      'estimated_value': {'amount': '8000', 'currency': 'XOF'},
      'status': status,
      'requested_by': {'id': 'u-1', 'full_name': 'Kossi'},
      'decided_by': status == 'pending' ? null : {'id': 'u-2', 'full_name': 'Ama'},
      'decided_at': null,
      'decision_note': '',
      'movement': null,
      'created_at': '2026-09-13T10:00:00Z',
    };

Map<String, dynamic> _recette() => {
      'id': 'rec-1',
      'menu_item': 'item-1',
      'option': null,
      'target_name': 'Burger Corazón',
      'restaurant': 'el-corazon-lome',
      'notes': '',
      'lines': [
        {
          'id': 'l-1',
          'ingredient': 'ing-1',
          'ingredient_name': 'Oignon',
          'ingredient_slug': 'oignon',
          'quantity': _quantite('20'),
        },
      ],
      'created_at': '2026-09-13T10:00:00Z',
      'updated_at': '2026-09-13T10:00:00Z',
    };

Map<String, dynamic> _page(List<Map<String, dynamic>> lignes, {String? next}) =>
    {'count': lignes.length, 'next': next, 'previous': null, 'results': lignes};

class _FauxServeur implements HttpClientAdapter {
  final List<RequestOptions> requetes = [];

  /// Réponse du prochain appel, par fin de chemin.
  final Map<String, (int, Object)> reponses = {};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requetes.add(options);
    for (final entree in reponses.entries) {
      if (options.uri.toString().contains(entree.key)) {
        final (statut, corps) = entree.value;
        return ResponseBody.fromString(jsonEncode(corps), statut, headers: _jsonHeaders);
      }
    }
    throw UnimplementedError('Route non simulée : ${options.method} ${options.uri}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FauxServeur serveur;
  late ApiClient client;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
    serveur = _FauxServeur();
    client = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: serveur,
    );
  });

  group('Quantity — jamais un double', () {
    test('la saisie accepte la virgule et garde la chaîne exacte', () {
      final quantite = Quantity.saisie(' 1,5 ', 'kg');

      expect(quantite.toJson(), {'amount': '1.5', 'unit': 'kg'});
    });

    test('ce qui n’est pas un nombre est refusé avant l’envoi', () {
      expect(() => Quantity.saisie('beaucoup', 'kg'), throwsFormatException);
      expect(() => Quantity.saisie('1.5.2', 'kg'), throwsFormatException);
      expect(() => Quantity.saisie('2', 'livre'), throwsFormatException);
    });

    test('au-delà de mille grammes, l’écran lit des kilogrammes', () {
      expect(Quantity.fromJson(_quantite('12500')).label, '12,5 kg');
      expect(Quantity.fromJson(_quantite('1000')).label, '1 kg');
      expect(Quantity.fromJson(_quantite('250')).label, '250 g');
      expect(Quantity.fromJson(_quantite('-2000')).label, '-2 kg');
      expect(Quantity.fromJson(_quantite('1500', 'ml', 'volume')).label, '1,5 l');
    });

    test('les unités se comptent au singulier et au pluriel', () {
      expect(Quantity.fromJson(_quantite('1', 'unit', 'count')).label, '1 unité');
      expect(Quantity.fromJson(_quantite('0.5', 'unit', 'count')).label, '0,5 unités');
      expect(Quantity.fromJson(_quantite('12', 'unit', 'count')).label, '12 unités');
    });

    test('le signe et le zéro se lisent sans calcul', () {
      expect(Quantity.fromJson(_quantite('-20')).isNegative, isTrue);
      expect(Quantity.fromJson(_quantite('0')).isZero, isTrue);
      expect(Quantity.fromJson(_quantite('0.000')).isZero, isTrue);
      expect(Quantity.fromJson(_quantite('20')).isZero, isFalse);
    });
  });

  group('ManagedInventoryRepository', () {
    late ManagedInventoryRepository depot;

    setUp(() => depot = ManagedInventoryRepository(apiClient: client));

    test('une ligne de stock se relit entière — coût au kilogramme compris', () async {
      serveur.reponses['/inventory/manage/stock/'] = (200, _page([_ligneDeStock()]));

      final lignes = await depot.stockLines(restaurantSlug: 'el-corazon-lome', lowOnly: true);

      final requete = serveur.requetes.single;
      expect(requete.queryParameters['restaurant__slug'], 'el-corazon-lome');
      expect(requete.queryParameters['low'], true);
      final ligne = lignes.single;
      expect(ligne.available.label, '9,6 kg');
      expect(ligne.isLow, isTrue);
      expect((ligne.unitCost?.amountMinor, ligne.unitCost?.currency), (4000, 'XOF'));
      expect(ligne.costUnit, 'kg');
      expect(ligne.lowStockThreshold?.label, '12 kg');
    });

    test('une réception porte la clé fournie par l’écran, et le prix du lot', () async {
      serveur.reponses['/receive/'] = (201, _mouvement());

      final mouvement = await depot.receive(
        stockLineId: 'stock-1',
        quantity: Quantity.saisie('5', 'kg'),
        totalCost: const Money(amountMinor: 12000, currency: 'XOF'),
        reference: 'BL-42',
        idempotencyKey: 'tentative-1',
      );

      final requete = serveur.requetes.single;
      expect(requete.method, 'POST');
      expect(requete.headers['Idempotency-Key'], 'tentative-1');
      expect(requete.data, {
        'quantity': {'amount': '5', 'unit': 'kg'},
        'total_cost': {'amount': '12000', 'currency': 'XOF'},
        'reference': 'BL-42',
      });
      expect((mouvement.value?.amountMinor, mouvement.value?.currency), (12000, 'XOF'));
      expect(mouvement.actorName, 'Kossi');
    });

    test('une perte au-delà du plafond se lit « en attente », sans mouvement', () async {
      serveur.reponses['/waste/'] = (
        202,
        {'outcome': 'pending_approval', 'movement': null, 'request': _demande()},
      );

      final declaration = await depot.declareWaste(
        stockLineId: 'stock-1',
        quantity: Quantity.saisie('2', 'kg'),
        reason: 'Chaîne du froid rompue',
        idempotencyKey: 'tentative-2',
      );

      expect(declaration.isPendingApproval, isTrue);
      expect(declaration.request?.estimatedValue?.amountMinor, 8000);
      expect(declaration.request?.quantity.label, '-2 kg');
      expect(serveur.requetes.single.headers['Idempotency-Key'], 'tentative-2');
    });

    test('un comptage envoie ce qui est sur l’étagère, pas l’écart', () async {
      serveur.reponses['/adjust/'] = (
        201,
        {'outcome': 'applied', 'movement': _mouvement(), 'request': null},
      );

      final declaration = await depot.declareCount(
        stockLineId: 'stock-1',
        counted: Quantity.saisie('9,5', 'kg'),
        reason: 'Inventaire du soir',
        idempotencyKey: 'tentative-3',
      );

      expect(serveur.requetes.single.data, {
        'counted': {'amount': '9.5', 'unit': 'kg'},
        'reason': 'Inventaire du soir',
      });
      expect(declaration.isPendingApproval, isFalse);
    });

    test('le journal suit l’URL du curseur rendue par le serveur', () async {
      const suivante = 'http://test.local/api/v1/inventory/manage/movements/?cursor=abc';
      serveur.reponses['cursor=abc'] = (200, _page([_mouvement()]));
      serveur.reponses['/inventory/manage/movements/'] =
          (200, _page([_mouvement()], next: suivante));

      final premiere = await depot.movements(stockLineId: 'stock-1');
      final seconde = await depot.movements(stockLineId: 'stock-1', next: premiere.next);

      expect(premiere.hasNext, isTrue);
      expect(seconde.hasNext, isFalse);
      expect(serveur.requetes.last.uri.toString(), suivante);
    });

    test('la file de validation et les deux décisions', () async {
      serveur.reponses['/approve/'] = (200, _demande(status: 'approved'));
      serveur.reponses['/reject/'] = (200, _demande(status: 'rejected'));
      serveur.reponses['/adjustment-requests/'] = (200, _page([_demande()]));

      final file = await depot.adjustmentRequests(restaurantSlug: 'el-corazon-lome');
      final validee = await depot.approve('dem-1', note: 'Relevé joint');
      final refusee = await depot.reject('dem-1', note: 'Recompter');

      expect(file.single.isPending, isTrue);
      expect(file.single.requestedById, 'u-1');
      expect(serveur.requetes.first.queryParameters['status'], 'pending');
      expect(validee.decidedByName, 'Ama');
      expect(refusee.status, 'rejected');
      expect(serveur.requetes.last.data, {'note': 'Recompter'});
    });

    test('le référentiel se lit et s’écrit sans dimension modifiable', () async {
      final ingredient = {
        'id': 'ing-1',
        'name': 'Huile',
        'slug': 'huile',
        'description': '',
        'dimension': 'volume',
        'allergens': ['arachide'],
        'is_active': true,
      };
      serveur.reponses['/ingredients/ing-1/'] = (200, {...ingredient, 'is_active': false});
      serveur.reponses['/ingredients/'] = (201, ingredient);

      final cree = await depot.createIngredient(name: 'Huile', slug: 'huile', dimension: 'volume');
      final retire = await depot.updateIngredient('ing-1', isActive: false);

      expect(cree.allergens, ['arachide']);
      expect(retire.isActive, isFalse);
      expect(serveur.requetes.last.data, {'is_active': false});
    });

    test('ouvrir une ligne et fixer son seuil', () async {
      serveur.reponses['/stock/stock-1/'] = (200, _ligneDeStock());
      serveur.reponses['/inventory/manage/stock/'] = (201, _ligneDeStock());

      await depot.openStockLine(restaurantSlug: 'el-corazon-lome', ingredientId: 'ing-1');
      await depot.setLowStockThreshold('stock-1', null);

      expect(serveur.requetes.first.data, {'restaurant': 'el-corazon-lome', 'ingredient': 'ing-1'});
      expect(serveur.requetes.last.data, {'low_stock_threshold': null});
    });
  });

  group('ManagedRecipeRepository', () {
    late ManagedRecipeRepository depot;

    setUp(() => depot = ManagedRecipeRepository(apiClient: client));

    test('une recette se crée, se compose et se relit', () async {
      serveur.reponses['/lines/ing-1/'] = (200, {..._recette(), 'lines': <Object>[]});
      serveur.reponses['/rec-1/lines/'] = (200, _recette());
      serveur.reponses['/production/manage/recipes/'] = (201, _recette());

      final recette = await depot.create(menuItemId: 'item-1');
      final composee = await depot.setLine(
        recipeId: recette.id,
        ingredientId: 'ing-1',
        quantity: Quantity.saisie('20', 'g'),
      );
      final videe = await depot.removeLine(recipeId: recette.id, ingredientId: 'ing-1');

      expect(serveur.requetes.first.data, {'menu_item': 'item-1', 'notes': ''});
      expect(composee.lines.single.quantity.label, '20 g');
      expect(serveur.requetes.last.method, 'DELETE');
      expect(videe.lines, isEmpty);
    });

    test('la couverture dit ce qu’il reste à saisir', () async {
      serveur.reponses['/coverage/'] = (
        200,
        {
          'restaurant': 'el-corazon-lome',
          'items_total': 4,
          'items_with_recipe': 3,
          'missing': [
            {'id': 'item-9', 'name': 'Frites', 'slug': 'frites', 'category': 'Accompagnements'},
          ],
        },
      );

      final couverture = await depot.coverage(restaurantSlug: 'el-corazon-lome');

      expect(couverture.ratio, 0.75);
      expect(couverture.isComplete, isFalse);
      expect(couverture.missing.single.name, 'Frites');
    });

    test('les recettes d’une cuisine se lisent par son slug', () async {
      serveur.reponses['/production/manage/recipes/'] = (200, _page([_recette()]));

      final recettes = await depot.recipes(restaurantSlug: 'el-corazon-lome');

      expect(serveur.requetes.single.queryParameters['restaurant'], 'el-corazon-lome');
      expect(recettes.single.menuItemId, 'item-1');
    });
  });
}
