import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le point d'enlèvement — d'où part le repas — sur la commande du client.
///
/// La carte de suivi montre trois repères ; elle n'en tenait que deux, et
/// suppléait le troisième par une constante d'application désignant le premier
/// établissement. `OrderSerializer.restaurant_location` le rend désormais, mais
/// **facultativement** : un serveur antérieur à ce champ doit continuer d'être
/// lu, une carte à deux repères valant mieux qu'un écran de suivi qui refuse
/// de s'ouvrir.
Map<String, dynamic> _commande({Map<String, dynamic>? restaurantLocation}) {
  return {
    'id': 'order-1',
    'reference': 'EC000001',
    'restaurant': 'el-corazon-lome',
    'restaurant_name': 'El Corazón',
    if (restaurantLocation != null) 'restaurant_location': restaurantLocation,
    'status': 'on_the_way',
    'allowed_transitions': ['delivered'],
    'subtotal': {'amount': '2500', 'currency': 'XOF'},
    'delivery_fee': {'amount': '500', 'currency': 'XOF'},
    'discount': {'amount': '0', 'currency': 'XOF'},
    'total': {'amount': '3000', 'currency': 'XOF'},
    'payment_method': 'cash',
    'delivery_address_line': 'Rue des Cocotiers',
    'delivery_landmark': '',
    'delivery_location': {'lat': 6.1319, 'lon': 1.2255},
    'recipient_name': 'Cliente',
    'recipient_phone': '+22890000000',
    'placed_at': '2026-09-03T12:00:00Z',
    'created_at': '2026-09-03T12:00:00Z',
    'updated_at': '2026-09-03T12:00:00Z',
  };
}

void main() {
  group('Order.restaurantLocation', () {
    test('le point du restaurant est lu quand le serveur le rend', () {
      final order = Order.fromJson(
        _commande(restaurantLocation: {'lat': 6.1375, 'lon': 1.2123}),
      );

      expect(order.restaurantLatitude, 6.1375);
      expect(order.restaurantLongitude, 1.2123);
    });

    test('son absence n’empêche pas de lire la commande', () {
      final order = Order.fromJson(_commande());

      expect(order.restaurantLatitude, isNull);
      expect(order.restaurantLongitude, isNull);
      // Le reste reste intact : c'est tout l'intérêt de le rendre facultatif.
      expect(order.deliveryLatitude, 6.1319);
      expect(order.reference, 'EC000001');
    });

    test('le point de livraison, lui, reste obligatoire', () {
      // Il est figé à la commande côté serveur : une commande sans lui serait
      // une commande qu'aucun livreur ne pourrait desservir.
      final sansLivraison = _commande()..remove('delivery_location');
      expect(() => Order.fromJson(sansLivraison), throwsA(anything));
    });

    test('un entier est accepté comme coordonnée', () {
      // JSON n'a qu'un type numérique : une latitude ronde arrive en `int`, et
      // un `as double` lèverait au fond du parsing d'une liste de commandes.
      final order = Order.fromJson(
        _commande(restaurantLocation: {'lat': 6, 'lon': 1}),
      );

      expect(order.restaurantLatitude, 6.0);
      expect(order.restaurantLongitude, 1.0);
    });
  });
}
