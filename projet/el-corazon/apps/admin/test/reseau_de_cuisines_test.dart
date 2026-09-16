import 'package:admin/presentation/filtres_geographiques.dart';
import 'package:admin/presentation/filtres_supervision.dart';
import 'package:admin/screens/admin/fermetures_exceptionnelles.dart';
import 'package:admin/screens/admin/reseau/activite_reseau.dart';
import 'package:admin/services/delivery_zone_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le réseau vu du back-office : filtres hiérarchiques, structure chiffrée,
/// fermetures exceptionnelles.

eccore.ManagedRestaurant _cuisine(
  String slug, {
  required String pays,
  required String ville,
  required String villeSlug,
  bool enService = true,
  String motif = '',
}) => eccore.ManagedRestaurant(
  id: 'id-$slug',
  name: slug,
  slug: slug,
  zoneId: 'z',
  address: '',
  latitude: 0,
  longitude: 0,
  currency: 'XOF',
  timezone: 'UTC',
  status: enService ? eccore.RestaurantLifecycle.active : eccore.RestaurantLifecycle.draft,
  isActive: enService,
  acceptsOrders: true,
  defaultPreparationMinutes: 20,
  countryIsoCode: pays,
  cityName: ville,
  citySlug: villeSlug,
  unavailableCode: motif,
);

DeliveryZone _zone(String id, String nom, String cityId) => DeliveryZone(
  id: id,
  cityId: cityId,
  name: nom,
  polygon: const [],
  deliveryFee: 500,
  feePerKm: 0,
  estimatedTimeMinutes: 30,
  isActive: true,
  currency: 'XOF',
);

class _DepotFermetures implements eccore.ManagedKitchenClosureRepository {
  final List<eccore.KitchenClosure> fermetures = [];
  final List<String> supprimees = [];

  @override
  eccore.ApiClient get apiClient => throw UnimplementedError();

  @override
  Future<List<eccore.KitchenClosure>> list({
    required String restaurantId,
    bool upcomingOnly = true,
  }) async => List.of(fermetures);

  @override
  Future<eccore.KitchenClosure> create({
    required String restaurantId,
    required DateTime debut,
    required DateTime fin,
    String reason = '',
  }) async => throw UnimplementedError();

  @override
  Future<void> delete(String closureId) async {
    supprimees.add(closureId);
    fermetures.removeWhere((f) => f.id == closureId);
  }
}

void main() {
  final cuisines = [
    _cuisine('lome', pays: 'TG', ville: 'Lomé', villeSlug: 'lome'),
    _cuisine('cocody', pays: 'CI', ville: 'Abidjan', villeSlug: 'abidjan'),
    _cuisine('plateau', pays: 'CI', ville: 'Abidjan', villeSlug: 'abidjan', motif: 'kitchen_closed'),
    _cuisine('bouake', pays: 'CI', ville: 'Bouaké', villeSlug: 'bouake', enService: false),
  ];

  group('les filtres géographiques de la supervision', () {
    test('chaque étage ne propose que ce que le précédent contient', () {
      expect(OptionsGeographiques.pays(cuisines).map((o) => o.valeur), ['CI', 'TG']);
      expect(
        OptionsGeographiques.villes(cuisines, paysIso: 'CI').map((o) => o.libelle),
        ['Abidjan', 'Bouaké'],
      );
      final zones = [_zone('z1', 'Cocody', 'c-abj'), _zone('z2', 'Tokoin', 'c-lome')];
      String nom(String id) => id == 'c-abj' ? 'Abidjan' : 'Lomé';
      expect(OptionsGeographiques.zones(zones, nom, nomVille: 'Abidjan').single.libelle, 'Cocody');
      expect(OptionsGeographiques.zones(zones, nom), isEmpty);
    });

    test('changer de pays efface la ville et la zone ; changer de ville, la zone', () {
      const filtres = FiltresCommandes(paysIso: 'CI', villeSlug: 'abidjan', zoneId: 'z1');

      final autrePays = filtres.copyWith(paysIso: 'TG');
      expect((autrePays.paysIso, autrePays.villeSlug, autrePays.zoneId), ('TG', null, null));

      final autreVille = filtres.copyWith(villeSlug: 'bouake');
      expect((autreVille.paysIso, autreVille.villeSlug, autreVille.zoneId), ('CI', 'bouake', null));

      final memeVille = filtres.copyWith(fenetre: FenetreCommandes.septJours);
      expect(memeVille.zoneId, 'z1');

      expect(filtres.nombreActifs, 3);
      expect(filtres.memeRequeteQue(filtres.copyWith(zoneId: 'z2')), isFalse);
    });
  });

  test('la structure du réseau se compte sur le verdict du serveur', () {
    final resume = ResumeReseau.depuis(
      pays: const [],
      villes: const [],
      zones: [_zone('z1', 'Cocody', 'c')],
      cuisines: cuisines,
    );

    expect(resume.cuisines, 4);
    expect(resume.enService, 3);
    expect(resume.commandables, 2);
    expect(resume.fermees, 1);
    expect(resume.zones, 1);
  });

  testWidgets('une fermeture en cours se lit, et s’annule', (tester) async {
    final depot = _DepotFermetures()
      ..fermetures.add(
        eccore.KitchenClosure(
          id: 'f1',
          restaurantId: 'r1',
          startsAt: DateTime.now().subtract(const Duration(hours: 1)),
          endsAt: DateTime.now().add(const Duration(hours: 2)),
          reason: 'coupure de gaz',
          isCurrent: true,
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FermeturesExceptionnelles(restaurantId: 'r1', nomCuisine: 'Cocody', depot: depot),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('En cours · coupure de gaz'), findsOneWidget);

    await tester.tap(find.byTooltip('Annuler cette fermeture'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler la fermeture'));
    await tester.pumpAndSettle();

    expect(depot.supprimees, ['f1']);
    expect(find.text('Aucune fermeture à venir.'), findsOneWidget);
  });
}
