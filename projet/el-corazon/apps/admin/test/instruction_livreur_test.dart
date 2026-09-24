import 'dart:convert';

import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/driver_management_service.dart';
import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que lit l'opérateur quand le serveur refuse une décision sur un dossier.
///
/// ## Le défaut que cette suite ferme
///
/// `DriverManagementService._setVerification` rendait `false` sur toute
/// `ApiException` **sans conserver le refus** — contrairement à la correction
/// d'un dossier et aux zones, écrites juste au-dessus. Le formulaire affichait
/// donc « Modification refusée. », ou pire : le refus **précédent**, resté dans
/// `error`. Or le serveur dit pourquoi — un motif de suspension manquant, un
/// dossier jamais validé qu'on ne suspend pas, une pièce expirée.
const _canalStockage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _entetesJson = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _dossier({String statut = 'suspended'}) => {
      'id': 'livreur-1',
      'full_name': 'Kofi Livreur',
      'email': 'kofi@elcorazon.test',
      'phone': '+22890000000',
      'restaurant': 'el-corazon-lome',
      'verification_status': statut,
      'id_document': null,
      'licence_document': null,
      'vehicle_document': null,
      'verification_notes': 'Incident client.',
      'verified_at': '2026-09-20T10:00:00Z',
      'vehicle_type': 'motorcycle',
      'vehicle_plate': '',
      'is_online': false,
      'can_accept_orders': false,
      'last_location': null,
      'last_location_at': null,
      'deliveries_completed': 12,
      'deliveries_cancelled': 0,
      'rating_average': '4.8',
      'rating_count': 9,
      'total_earnings': null,
      'created_at': '2026-09-01T10:00:00Z',
      'updated_at': '2026-09-20T10:00:00Z',
    };

class _FauxServeur implements HttpClientAdapter {
  /// Le corps `problem+json` opposé à l'écriture, et son statut. Nul : elle
  /// aboutit.
  Map<String, dynamic>? refus;
  int statutRefus = 400;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final corps = refus;
    if (corps != null) {
      return ResponseBody.fromString(jsonEncode(corps), statutRefus, headers: _entetesJson);
    }
    return ResponseBody.fromString(jsonEncode(_dossier()), 200, headers: _entetesJson);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_canalStockage, (call) async => null);

  // Un seul conteneur pour tout le fichier : `AdminAuthService` est un
  // singleton d'application et garde celui de sa première construction.
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
  tearDownAll(conteneur.dispose);

  setUp(() {
    serveur.refus = null;
    serveur.statutRefus = 400;
  });

  test('un motif manquant se dit tel que le serveur l’écrit', () async {
    // Un refus de validation (400) : pas de phrase d'ensemble, la raison est
    // rangée sous le champ.
    serveur.refus = {
      'code': 'validation_error',
      'errors': {
        'notes': ['Dites au livreur pourquoi : il lira ce motif dans son application.'],
      },
    };
    final sut = DriverManagementService();

    final ok = await sut.suspendDriver('livreur-1', '');

    expect(ok, isFalse);
    expect(sut.error, 'Dites au livreur pourquoi : il lira ce motif dans son application.');
  });

  test('une transition impossible se dit, au lieu d’un « Modification refusée »', () async {
    serveur
      ..statutRefus = 409
      ..refus = {
        'code': 'illegal_transition',
        'detail': 'Un dossier en attente ne se suspend pas : validez-le d’abord.',
      };
    final sut = DriverManagementService();

    expect(await sut.suspendDriver('livreur-1', 'Incident client.'), isFalse);
    expect(sut.error, contains('ne se suspend pas'));
  });

  test('un succès efface le refus précédent', () async {
    // Sans cela, le prochain échec d'un autre geste afficherait ce message-ci.
    serveur.refus = {
      'code': 'validation_error',
      'errors': {
        'notes': ['Motif requis.'],
      },
    };
    final sut = DriverManagementService();
    await sut.suspendDriver('livreur-1', '');
    expect(sut.error, isNotNull);

    serveur.refus = null;
    final ok = await sut.suspendDriver('livreur-1', 'Incident client.');

    expect(ok, isTrue);
    expect(sut.error, isNull);
  });
}
