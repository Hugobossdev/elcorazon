import 'package:elcora_fast/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les coordonnées de la commande, côté client.
///
/// Elles étaient absentes de ce modèle : l'adaptateur les jetait, et l'écran de
/// suivi **re-géocodait la ligne d'adresse** pour retrouver un point que le
/// serveur avait déjà figé au moment de commander. Un aller vers Google à
/// chaque ouverture, pour une valeur moins juste — et quand il échouait, une
/// carte sans destination : ni repère client, ni tracé, ni distance, ni alerte
/// de proximité.
Order _commande({
  double? latitude = 6.1319,
  double? longitude = 1.2255,
  double? restaurantLat = 6.1375,
  double? restaurantLon = 1.2123,
}) {
  return Order(
    id: 'order-1',
    userId: 'user-1',
    items: const [],
    subtotal: 2500,
    total: 3000,
    deliveryAddress: 'Rue des Cocotiers',
    deliveryLatitude: latitude,
    deliveryLongitude: longitude,
    restaurantLatitude: restaurantLat,
    restaurantLongitude: restaurantLon,
    paymentMethod: PaymentMethod.cash,
    orderTime: DateTime.utc(2026, 9, 3, 12),
    createdAt: DateTime.utc(2026, 9, 3, 12),
  );
}

void main() {
  group('Order — coordonnées', () {
    test('les quatre coordonnées sont portées par la commande', () {
      final order = _commande();

      expect(order.deliveryLatitude, 6.1319);
      expect(order.deliveryLongitude, 1.2255);
      expect(order.restaurantLatitude, 6.1375);
      expect(order.restaurantLongitude, 1.2123);
    });

    test('elles sont nulles pour une commande construite sans elles', () {
      // Le parcours hors ligne construit des commandes sans coordonnées :
      // l'écran de suivi retombe alors sur le géocodage de l'adresse.
      final order = _commande(
        latitude: null,
        longitude: null,
        restaurantLat: null,
        restaurantLon: null,
      );

      expect(order.deliveryLatitude, isNull);
      expect(order.restaurantLatitude, isNull);
    });

    test('copyWith les conserve quand on n’y touche pas', () {
      // Le piège de `copyWith` : un champ ajouté au modèle mais oublié ici se
      // perd au premier changement de statut, sans qu'aucun test ne l'attrape.
      // La carte perdait alors sa destination en cours de livraison.
      final apres = _commande().copyWith(status: OrderStatus.onTheWay);

      expect(apres.status, OrderStatus.onTheWay);
      expect(apres.deliveryLatitude, 6.1319);
      expect(apres.deliveryLongitude, 1.2255);
      expect(apres.restaurantLatitude, 6.1375);
      expect(apres.restaurantLongitude, 1.2123);
    });

    test('copyWith remplace bien les coordonnées quand on les passe', () {
      final apres = _commande().copyWith(
        deliveryLatitude: 6.2,
        deliveryLongitude: 1.3,
      );

      expect(apres.deliveryLatitude, 6.2);
      expect(apres.deliveryLongitude, 1.3);
      // Celles du restaurant, elles, n'ont pas bougé.
      expect(apres.restaurantLatitude, 6.1375);
    });
  });
}
