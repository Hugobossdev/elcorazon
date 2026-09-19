import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les comptes du personnel, depuis le back-office.
///
/// Le serveur savait créer un compte et le rattacher à un établissement, une
/// ville ou un marché depuis l'origine (`StaffViewSet`). Le dépôt n'exposait
/// que la liste, les rôles et l'activation : ouvrir un compte d'opérateur
/// passait par `django-admin`, et l'écran de cuisine renvoyait vers « un
/// responsable du siège » qui n'avait aucun écran pour le faire.
const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _membreJson({
  List<String> restaurants = const [],
  List<String> countries = const [],
  List<String> cities = const [],
}) {
  return {
    'id': 'staff-1',
    'email': 'awa@elcorazon.com',
    'full_name': 'Awa K.',
    'phone': null,
    'is_active': true,
    'roles': ['role-operateur'],
    'restaurants': restaurants,
    'countries': countries,
    'cities': cities,
    'permissions': ['orders.read'],
    'last_seen_at': null,
    'created_at': '2026-09-18T08:00:00Z',
    'updated_at': '2026-09-18T08:00:00Z',
  };
}

class _FakeServer implements HttpClientAdapter {
  final List<String> requests = [];
  final List<Map<String, dynamic>> bodies = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.path}');
    final corps = Map<String, dynamic>.from(options.data as Map? ?? const {});
    bodies.add(corps);

    return ResponseBody.fromString(
      jsonEncode(
        _membreJson(
          restaurants: List<String>.from(corps['restaurants'] as List? ?? const []),
          countries: List<String>.from(corps['countries'] as List? ?? const []),
          cities: List<String>.from(corps['cities'] as List? ?? const []),
        ),
      ),
      options.method == 'POST' ? 201 : 200,
      headers: _jsonHeaders,
    );
  }
}

AdministrationRepository _depot(_FakeServer server) {
  return AdministrationRepository(
    apiClient: ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: server,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  group('Ouvrir un compte', () {
    test('envoie identité, rôles et périmètre en une requête', () async {
      final server = _FakeServer();

      final membre = await _depot(server).createStaff(
        email: 'awa@elcorazon.com',
        fullName: 'Awa K.',
        password: 'motdepasse-solide',
        roleIds: const ['role-operateur'],
        restaurantSlugs: const ['el-corazon-lome'],
      );

      expect(server.requests.single, contains('POST'));
      expect(server.requests.single, endsWith('/restaurants/staff/'));
      final corps = server.bodies.single;
      expect(corps['password'], 'motdepasse-solide');
      expect(corps['roles'], ['role-operateur']);
      expect(corps['restaurants'], ['el-corazon-lome']);
      expect(membre.restaurantSlugs, ['el-corazon-lome']);
    });

    test('ne dicte jamais le type de compte au serveur', () async {
      // Accepté du corps, il permettrait de fabriquer un livreur validé
      // depuis l'écran des rôles.
      final server = _FakeServer();

      await _depot(server).createStaff(
        email: 'awa@elcorazon.com',
        fullName: 'Awa K.',
        password: 'motdepasse-solide',
      );

      expect(server.bodies.single.containsKey('user_type'), isFalse);
    });

    test('un téléphone vide n’est pas envoyé comme une chaîne vide', () async {
      final server = _FakeServer();

      await _depot(server).createStaff(
        email: 'awa@elcorazon.com',
        fullName: 'Awa K.',
        password: 'motdepasse-solide',
        phone: '',
      );

      expect(server.bodies.single.containsKey('phone'), isFalse);
    });
  });

  group('Le périmètre', () {
    test('part en bloc : établissements, villes et marchés ensemble', () async {
      final server = _FakeServer();

      final membre = await _depot(server).updateStaffScope(
        staffId: 'staff-1',
        restaurantSlugs: const [],
        countryCodes: const ['TG'],
        citySlugs: const ['abidjan'],
      );

      expect(server.requests.single, 'PATCH /restaurants/staff/staff-1/');
      expect(server.bodies.single.keys, containsAll(['restaurants', 'countries', 'cities']));
      // Une liste vide est envoyée, pas omise : c'est elle qui retire un
      // rattachement.
      expect(server.bodies.single['restaurants'], isEmpty);
      expect(membre.countryCodes, ['TG']);
      expect(membre.citySlugs, ['abidjan']);
    });

    test('un compte rattaché à rien se signale', () {
      expect(StaffMember.fromJson(_membreJson()).sansPerimetre, isTrue);
      expect(StaffMember.fromJson(_membreJson(cities: ['lome'])).sansPerimetre, isFalse);
    });

    test('le siège n’est pas « rattaché à rien » : il voit tout', () {
      // Les deux n'ont aucun rattachement ; l'un voit l'enseigne entière,
      // l'autre rien. Les confondre, c'est annoncer une panne qui n'existe
      // pas — ou taire une qui existe.
      final siege = StaffMember.fromJson(_membreJson()..['is_superuser'] = true);

      expect(siege.isSuperuser, isTrue);
      expect(siege.sansPerimetre, isFalse);
    });

    test('une réponse sans pays ni villes se lit comme des listes vides', () {
      // Un serveur antérieur aux périmètres de marché ne les rend pas.
      final json = _membreJson()
        ..remove('countries')
        ..remove('cities');

      final membre = StaffMember.fromJson(json);

      expect(membre.countryCodes, isEmpty);
      expect(membre.citySlugs, isEmpty);
    });
  });

  test('le mot de passe se change seul, sans toucher au reste', () async {
    final server = _FakeServer();

    await _depot(server).setStaffPassword(staffId: 'staff-1', password: 'nouveau-solide');

    expect(server.bodies.single, {'password': 'nouveau-solide'});
  });
}
