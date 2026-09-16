import 'package:admin/presentation/disponibilite_cuisine.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Une cuisine configurée ici et introuvable côté client est un bug
/// fonctionnel. La carte du réseau disait « En service » dans les deux cas
/// qu'elle ne voyait pas — un marché fermé qui rend la cuisine invisible, et
/// des horaires qui la ferment. Ces tests gardent l'étiquette qui les montre.
void main() {
  eccore.ManagedRestaurant cuisine({
    eccore.RestaurantLifecycle status = eccore.RestaurantLifecycle.active,
    bool acceptsOrders = true,
    String unavailableCode = '',
  }) {
    return eccore.ManagedRestaurant(
      id: 'c1',
      name: 'El Corazón Lomé',
      slug: 'el-corazon-lome',
      zoneId: 'zone-1',
      address: 'Boulevard du 13 Janvier',
      latitude: 6.13,
      longitude: 1.22,
      currency: 'XOF',
      timezone: 'Africa/Lome',
      status: status,
      isActive: status.isPublished,
      acceptsOrders: acceptsOrders,
      defaultPreparationMinutes: 20,
      unavailableCode: unavailableCode,
    );
  }

  test('commandable : rien à signaler', () {
    expect(etiquetteDisponibiliteCuisine(cuisine()), isNull);
    expect(cuisine().canOrderNow, isTrue);
  });

  test('en service mais invisible : le marché est fermé', () {
    final invisible = cuisine(unavailableCode: eccore.MotifIndisponibilite.cuisineNonPubliee);

    expect(etiquetteDisponibiliteCuisine(invisible), 'Invisible des clients');
    expect(invisible.canOrderNow, isFalse);
  });

  test('en service mais fermée', () {
    expect(
      etiquetteDisponibiliteCuisine(
        cuisine(unavailableCode: eccore.MotifIndisponibilite.cuisineFermee),
      ),
      'Fermée (hors horaires)',
    );
  });

  test('en pause, par le verdict ou par le seul drapeau d’un serveur antérieur', () {
    expect(
      etiquetteDisponibiliteCuisine(
        cuisine(acceptsOrders: false, unavailableCode: eccore.MotifIndisponibilite.cuisineEnPause),
      ),
      'Commandes en pause',
    );
    expect(etiquetteDisponibiliteCuisine(cuisine(acceptsOrders: false)), 'Commandes en pause');
  });

  test('pas encore en service : le cycle de vie parle déjà', () {
    expect(
      etiquetteDisponibiliteCuisine(
        cuisine(
          status: eccore.RestaurantLifecycle.configuring,
          unavailableCode: eccore.MotifIndisponibilite.cuisineNonPubliee,
        ),
      ),
      isNull,
    );
  });

  test('le verdict se lit dans la réponse du serveur', () {
    final lue = eccore.ManagedRestaurant.fromJson({
      'id': 'c1',
      'name': 'El Corazón Lomé',
      'slug': 'el-corazon-lome',
      'zone': 'zone-1',
      'location': {'lat': 6.13, 'lon': 1.22},
      'currency': 'XOF',
      'timezone': 'Africa/Lome',
      'status': 'active',
      'is_active': true,
      'accepts_orders': true,
      'default_preparation_minutes': 20,
      'unavailable_code': 'kitchen_closed',
      'unavailable_reason': 'La cuisine El Corazón Lomé est fermée pour le moment.',
    });

    expect(lue.canOrderNow, isFalse);
    expect(lue.unavailableReason, contains('fermée'));
    expect(etiquetteDisponibiliteCuisine(lue), 'Fermée (hors horaires)');
  });
}
