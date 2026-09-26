import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/presentation/catalogue.dart';
import 'package:elcora_fast/presentation/reprise_de_commande.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Tailles d'un plat (lot 2) — Petite, Moyenne, Grande.
///
/// Une taille **remplace** le prix du plat, les options s'ajoutent par-dessus,
/// et le serveur exige d'en retenir une dès que le plat en a. Ces cas tiennent
/// ce que le client voit et ce que le panier transmet : le bon prix annoncé,
/// la taille nommée sur chaque ligne, et une commande passée reprise dans sa
/// taille — ou nommée si celle-ci n'est plus servie.
void main() {
  const xof = 'XOF';

  eccore.Variante taille(String id, String nom, int prix, {bool dispo = true}) =>
      eccore.Variante(
        id: id,
        name: nom,
        price: eccore.Money(amountMinor: prix, currency: xof),
        isAvailable: dispo,
      );

  eccore.MenuItem pizza({List<eccore.Variante> tailles = const []}) {
    return eccore.MenuItem(
      id: 'pizza',
      restaurantSlug: 'el-corazon-lome',
      categorySlug: 'pizzas',
      categoryName: 'Pizzas',
      name: 'Pizza Reine',
      slug: 'pizza-reine',
      description: '',
      image: null,
      price: const eccore.Money(amountMinor: 2000, currency: xof),
      preparationMinutes: 15,
      allergens: const [],
      dietaryTags: const [],
      isAvailable: true,
      isPopular: false,
      vipExclusive: false,
      ratingAverage: 0,
      ratingCount: 0,
      sortOrder: 0,
      variants: tailles,
    );
  }

  final lesTrois = [
    taille('p', 'Petite', 2500),
    taille('m', 'Moyenne', 3000),
    taille('g', 'Grande', 3500, dispo: false),
  ];

  LigneAReprendre ligne({String taille = ''}) => (
        menuItemId: 'pizza',
        nom: 'Pizza Reine',
        quantite: 2,
        options: const <String, String>{},
        taille: taille,
      );

  group('Prix annoncé', () {
    test('un plat sans tailles annonce son prix', () {
      expect(pizza().libellePrix, pizza().price.format());
    });

    test('un plat à tailles annonce la moins chère, jamais son prix de base', () {
      final libelle = pizza(tailles: lesTrois).libellePrix;

      expect(libelle, startsWith('Dès '));
      expect(libelle, contains(lesTrois.first.price.format()));
      expect(libelle, isNot(contains(pizza().price.format())));
    });
  });

  group('Reprise d’une commande', () {
    test('la taille commandée est retrouvée par son nom', () {
      final tri = trierLaReprise(
        [ligne(taille: 'Moyenne')],
        [pizza(tailles: lesTrois)],
      );

      expect(tri.retenues.single.taille?.id, 'm');
      expect(tri.indisponibles, isEmpty);
    });

    test('une taille épuisée ou retirée est nommée, pas remplacée', () {
      final tri = trierLaReprise(
        [ligne(taille: 'Grande'), ligne(taille: 'Familiale')],
        [pizza(tailles: lesTrois)],
      );

      expect(tri.retenues, isEmpty);
      expect(tri.indisponibles, [
        'Pizza Reine (Grande)',
        'Pizza Reine (Familiale)',
      ]);
    });

    test('un plat devenu à tailles ne se reprend pas sans taille', () {
      final tri = trierLaReprise([ligne()], [pizza(tailles: lesTrois)]);

      expect(tri.retenues, isEmpty);
      expect(tri.indisponibles, ['Pizza Reine']);
    });

    test('un plat sans tailles se reprend sans taille', () {
      final tri = trierLaReprise([ligne(taille: 'Grande')], [pizza()]);

      expect(tri.retenues.single.taille, isNull);
    });
  });

  group('Ligne du panier', () {
    CartItem ligneDuPanier({String? id, String nom = ''}) => CartItem(
          id: 'l1',
          menuItemId: 'pizza',
          name: 'Pizza Reine',
          price: 3000,
          quantity: 1,
          variantId: id,
          variantName: nom,
        );

    test('la taille fait partie du nom affiché', () {
      expect(ligneDuPanier(id: 'm', nom: 'Moyenne').nomAffiche, 'Pizza Reine · Moyenne');
      expect(ligneDuPanier().nomAffiche, 'Pizza Reine');
    });

    test('la taille survit à la sauvegarde locale', () {
      final relue = CartItem.fromMap(ligneDuPanier(id: 'm', nom: 'Moyenne').toMap());

      expect(relue.variantId, 'm');
      expect(relue.variantName, 'Moyenne');
    });

    test('un panier écrit avant les tailles se relit sans taille', () {
      final ancien = ligneDuPanier().toMap()
        ..remove('variant_id')
        ..remove('variant_name');

      final relue = CartItem.fromMap(ancien);
      expect(relue.variantId, isNull);
      expect(relue.variantName, '');
    });

    test('deux tailles du même plat ne sont pas la même ligne', () {
      expect(
        ligneDuPanier(id: 'p', nom: 'Petite'),
        isNot(ligneDuPanier(id: 'g', nom: 'Grande')),
      );
    });
  });

  test('une ligne de commande nomme la taille figée par le serveur', () {
    final commande = Order.fromMap({
      'id': 'c1',
      'order_items': [
        {
          'menu_item_id': 'pizza',
          'name': 'Pizza Reine',
          'quantity': 1,
          'unit_price': 3000,
          'total_price': 3000,
          'variant_name': 'Moyenne',
        },
      ],
    });

    expect(commande.items.single.nomAffiche, 'Pizza Reine · Moyenne');
  });
}
