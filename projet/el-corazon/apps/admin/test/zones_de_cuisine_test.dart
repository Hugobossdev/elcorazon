import 'package:admin/screens/admin/reseau/brouillon_de_zone.dart';
import 'package:admin/screens/admin/reseau/zones_de_cuisine_screen.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Zones propres à une cuisine (lot 1) : le brouillon qu'on dessine, et
/// l'écran qui liste, bascule et supprime.

const _p1 = eccore.GeoPoint(6.10, 1.20);
const _p2 = eccore.GeoPoint(6.10, 1.26);
const _p3 = eccore.GeoPoint(6.16, 1.26);

eccore.ManagedRestaurant _cuisine() => const eccore.ManagedRestaurant(
      id: 'id-lome',
      name: 'El Corazón Lomé',
      slug: 'el-corazon-lome',
      zoneId: 'z',
      address: '',
      latitude: 6.13,
      longitude: 1.22,
      currency: 'XOF',
      timezone: 'Africa/Lome',
      status: eccore.RestaurantLifecycle.active,
      isActive: true,
      acceptsOrders: true,
      defaultPreparationMinutes: 20,
      countryIsoCode: 'TG',
      cityName: 'Lomé',
      citySlug: 'lome',
    );

eccore.DeliveryZone _zone(String id, String nom, {bool active = true}) =>
    eccore.DeliveryZone.fromJson({
      'id': id,
      'city': 'ville-1',
      'restaurant': 'el-corazon-lome',
      'name': nom,
      'shape': 'circle',
      'center': {'lat': 6.13, 'lon': 1.22},
      'radius_meters': 3000,
      'base_fee': {'amount': '500', 'currency': 'XOF'},
      'fee_per_km': {'amount': '0', 'currency': 'XOF'},
      'max_distance_km': '10.00',
      'estimated_delivery_minutes': 30,
      'is_active': active,
    });

class _Depot implements eccore.RestaurantZoneRepository {
  _Depot(this.zones);

  List<eccore.DeliveryZone> zones;
  final List<String> actions = [];
  Object? refusDeSuppression;
  Object? echecDeLecture;

  @override
  eccore.ApiClient get apiClient => throw UnimplementedError();

  @override
  Future<List<eccore.DeliveryZone>> zonesDe(String restaurantSlug) async {
    if (echecDeLecture != null) throw echecDeLecture!;
    return List.of(zones);
  }

  @override
  Future<eccore.DeliveryZone> creer({
    required String restaurantSlug,
    required String cityId,
    required String nom,
    required eccore.FormeDeZone forme,
    required eccore.Money forfait,
    required eccore.Money parKm,
    required double distanceMaxKm,
    required int dureeEstimeeMinutes,
  }) async =>
      throw UnimplementedError();

  @override
  Future<eccore.DeliveryZone> modifier(
    String zoneId, {
    String? nom,
    eccore.FormeDeZone? forme,
    eccore.Money? forfait,
    eccore.Money? parKm,
    double? distanceMaxKm,
    int? dureeEstimeeMinutes,
    bool? active,
  }) async {
    actions.add('modifier $zoneId active=$active');
    zones = [
      for (final z in zones)
        z.id == zoneId ? _zone(z.id, z.name, active: active ?? z.isActive) : z,
    ];
    return zones.firstWhere((z) => z.id == zoneId);
  }

  @override
  Future<void> supprimer(String zoneId) async {
    actions.add('supprimer $zoneId');
    if (refusDeSuppression != null) throw refusDeSuppression!;
    zones.removeWhere((z) => z.id == zoneId);
  }
}

const _canalStockage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_canalStockage, (call) async => null);

  group('Le brouillon', () {
    test('un polygone s’enregistre à partir de trois sommets', () {
      final brouillon = BrouillonDeZone.polygone()
        ..toucher(_p1)
        ..toucher(_p2);

      expect(brouillon.estEnregistrable, isFalse);
      expect(brouillon.manque, 'Encore 1 sommet pour fermer la zone.');
      expect(brouillon.forme, isNull);

      brouillon.toucher(_p3);
      expect(brouillon.estEnregistrable, isTrue);
      expect((brouillon.forme! as eccore.ZonePolygonale).sommets, [_p1, _p2, _p3]);
    });

    test('annuler, déplacer, retirer', () {
      final brouillon = BrouillonDeZone.polygone([_p1, _p2, _p3])
        ..deplacerSommet(0, _p3)
        ..retirerSommet(1)
        ..annulerDernier();

      expect(brouillon.sommets, [_p3]);
    });

    test('changer d’outil abandonne le tracé de l’autre', () {
      final brouillon = BrouillonDeZone.polygone([_p1, _p2, _p3])..basculer(versCercle: true);

      expect(brouillon.estCercle, isTrue);
      expect(brouillon.sommets, isEmpty);
      expect(brouillon.manque, 'Touchez la carte pour placer le centre.');

      brouillon.toucher(_p1);
      final forme = brouillon.forme! as eccore.ZoneCirculaire;
      expect(forme.centre, _p1);
    });

    test('le rayon reste dans les bornes que le serveur accepte', () {
      final brouillon = BrouillonDeZone.cercle(centre: _p1)..changerRayon(90000);
      expect(brouillon.rayonMetres, BrouillonDeZone.rayonMax);

      brouillon.changerRayon(10);
      expect(brouillon.rayonMetres, BrouillonDeZone.rayonMin);
    });

    test('une zone circulaire se rouvre en cercle, pas en polygone', () {
      final brouillon = BrouillonDeZone.depuisZone(_zone('z1', 'Bè'));

      expect(brouillon.estCercle, isTrue);
      expect(brouillon.centre, const eccore.GeoPoint(6.13, 1.22));
      expect(brouillon.rayonMetres, 3000);
    });
  });

  group('L’écran des zones', () {
    Future<void> monter(WidgetTester tester, _Depot depot) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZonesDeCuisineScreen(
            etablissement: _cuisine(),
            depot: depot,
            resoudreVille: (_) async => 'ville-1',
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('aucune zone : l’écran le dit, et comment en créer', (tester) async {
      await monter(tester, _Depot([]));

      expect(find.textContaining('Aucune zone propre'), findsOneWidget);
      expect(find.text('Nouvelle zone'), findsOneWidget);
    });

    testWidgets('les zones s’affichent avec leur forme et leur forfait', (tester) async {
      await monter(tester, _Depot([_zone('z1', 'Bè'), _zone('z2', 'Tokoin', active: false)]));

      expect(find.text('Bè'), findsOneWidget);
      expect(find.textContaining('cercle de 3.0 km'), findsNWidgets(2));
      expect(find.textContaining('désactivée'), findsOneWidget);
    });

    testWidgets('désactiver passe par le serveur', (tester) async {
      final depot = _Depot([_zone('z1', 'Bè')]);
      await monter(tester, depot);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(depot.actions, ['modifier z1 active=false']);
      expect(find.textContaining('désactivée'), findsOneWidget);
    });

    testWidgets('une suppression refusée (409) montre la phrase du serveur', (tester) async {
      final depot = _Depot([_zone('z1', 'Bè')])
        ..refusDeSuppression = const eccore.ApiException(
          status: 409,
          code: 'business_rule_violation',
          detail: 'La zone « Bè » porte l’établissement « El Corazón Lomé » : '
              'rattachez-le à une autre zone avant de la supprimer.',
        );
      await monter(tester, depot);

      await tester.tap(find.byTooltip('Actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer').last);
      await tester.pumpAndSettle();
      // Confirmation avant une action destructive.
      expect(find.text('Supprimer la zone ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(depot.actions, ['supprimer z1']);
      expect(find.textContaining('rattachez-le à une autre zone'), findsOneWidget);
      expect(find.text('Bè'), findsOneWidget, reason: 'la zone est toujours là');
    });

    testWidgets('un échec de lecture propose de réessayer', (tester) async {
      await monter(
        tester,
        _Depot([])
          ..echecDeLecture = const eccore.ApiException(
            status: 503,
            code: 'x',
            detail: 'Service indisponible.',
          ),
      );

      expect(find.text('Réessayer'), findsOneWidget);
    });
  });
}
