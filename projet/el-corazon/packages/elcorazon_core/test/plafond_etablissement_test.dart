import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le plafond de validation des pertes, sur la fiche d'établissement.
///
/// Trois écritures distinctes, et c'est ce que ces cas verrouillent : **ne pas
/// toucher** au plafond, le **fixer**, le **retirer**. Confondre la première et
/// la troisième — un seul paramètre nullable — ferait, à chaque correction d'un
/// numéro de téléphone, repasser toute perte par une validation.

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

Map<String, dynamic> _fiche({Map<String, String>? plafond}) => {
      'id': 'rest-1',
      'name': 'El Corazón — Lomé',
      'slug': 'el-corazon-lome',
      'description': '',
      'zone': 'zone-1',
      'address': 'Lomé',
      'location': {'lat': 6.13, 'lon': 1.22},
      'phone': '+22890000000',
      'email': null,
      'cover_image': null,
      'currency': 'XOF',
      'timezone': 'Africa/Lome',
      'status': 'active',
      'configuration_gaps': <String>[],
      'is_active': true,
      'accepts_orders': true,
      'default_preparation_minutes': 20,
      'stock_adjustment_ceiling': plafond,
    };

class _Serveur implements HttpClientAdapter {
  final List<RequestOptions> requetes = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requetes.add(options);
    return ResponseBody.fromString(
      jsonEncode(_fiche(plafond: {'amount': '5000', 'currency': 'XOF'})),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Serveur serveur;
  late ManagedRestaurantRepository depot;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
    serveur = _Serveur();
    depot = ManagedRestaurantRepository(
      apiClient: ApiClient(
        baseUrl: 'http://test.local/api/v1',
        tokenStorage: TokenStorage(),
        testAdapter: serveur,
      ),
    );
  });

  test('la fiche relit le plafond, ou son absence', () {
    final avec = ManagedRestaurant.fromJson(_fiche(plafond: {'amount': '5000', 'currency': 'XOF'}));
    final sans = ManagedRestaurant.fromJson(_fiche());

    expect(avec.stockAdjustmentCeiling?.amountMinor, 5000);
    expect(sans.stockAdjustmentCeiling, isNull);
  });

  test('une correction de fiche ne touche pas au plafond', () async {
    await depot.update(slug: 'el-corazon-lome', phone: '+22890000001');

    final corps = serveur.requetes.single.data as Map<String, dynamic>;
    expect(corps.containsKey('stock_adjustment_ceiling'), isFalse);
  });

  test('fixer le plafond l’envoie en unités mineures', () async {
    await depot.update(
      slug: 'el-corazon-lome',
      stockAdjustmentCeiling: const Money(amountMinor: 5000, currency: 'XOF'),
    );

    final corps = serveur.requetes.single.data as Map<String, dynamic>;
    expect(corps['stock_adjustment_ceiling'], {'amount': '5000', 'currency': 'XOF'});
  });

  test('retirer le plafond envoie un nul explicite', () async {
    await depot.update(slug: 'el-corazon-lome', clearStockAdjustmentCeiling: true);

    final corps = serveur.requetes.single.data as Map<String, dynamic>;
    expect(corps.containsKey('stock_adjustment_ceiling'), isTrue);
    expect(corps['stock_adjustment_ceiling'], isNull);
  });
}
