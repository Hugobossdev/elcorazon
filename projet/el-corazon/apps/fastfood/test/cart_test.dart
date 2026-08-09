import 'package:elcora_fast/models/cart_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// Panier — ce que l'écran calcule pour l'afficher.
///
/// Le total qui **fait foi** est celui du serveur : il applique la promotion,
/// les frais de zone et le minimum de commande (invariant C1). Les calculs
/// testés ici ne servent qu'à afficher une ligne pendant la composition, et
/// c'est précisément pour cela qu'ils doivent rester justes : un écart visible
/// entre le panier et l'addition finale se lit comme une erreur de facturation.
void main() {
  CartItem article({
    double prix = 2500,
    int quantite = 1,
    Map<String, dynamic> options = const {},
    List<String> identifiantsOptions = const [],
  }) {
    return CartItem(
      id: 'ligne-1',
      menuItemId: 'article-1',
      name: 'Cheeseburger',
      price: prix,
      quantity: quantite,
      customizations: options,
      selectedOptionIds: identifiantsOptions,
    );
  }

  group('Total d’une ligne', () {
    test('prix multiplié par la quantité', () {
      expect(article(quantite: 3).totalPrice, 7500);
    });

    test('une quantité nulle ne coûte rien', () {
      expect(article(quantite: 0).totalPrice, 0);
    });

    test('les francs CFA n’ont pas de décimale à perdre', () {
      // 1 250 × 7 = 8 750. Un arrondi flottant intermédiaire décalerait
      // l'affichage d'un franc, ce qui se voit sur une addition.
      expect(article(prix: 1250, quantite: 7).totalPrice, 8750);
    });
  });

  group('Options de personnalisation', () {
    test('un article sans option ne porte pas de personnalisation', () {
      // `customization` rend `null` plutôt qu'une carte vide : l'écran teste
      // la nullité pour décider d'afficher ou non le bloc d'options.
      expect(article().customization, isNull);
    });

    test('un article avec options les expose', () {
      final avec = article(options: {'cuisson': 'à point'});
      expect(avec.customization, isNotNull);
      expect(avec.customization!['cuisson'], 'à point');
    });

    test('les options ne changent pas le prix de la ligne côté client', () {
      // C1 : le supplément d'une option est un prix, et un prix se décide au
      // serveur. Le calculer ici donnerait un second montant, différent de
      // celui facturé.
      final sans = article(quantite: 2);
      final avec = article(
        quantite: 2,
        options: {'supplément': 'fromage'},
      );
      expect(avec.totalPrice, sans.totalPrice);
    });
  });

  group('Options structurées d’une ligne', () {
    test('les identifiants d’options survivent à un aller-retour de stockage', () {
      // Le panier est relu du stockage local au démarrage : perdre les
      // options y ferait repartir un gâteau sur mesure avec sa seule recette
      // de base, et facturer ce prix-là.
      final compose = article(
        options: {'Forme': 'Cœur', 'note': 'Pour Jade'},
        identifiantsOptions: const ['opt-coeur', 'opt-vanille'],
      );

      final relu = CartItem.fromMap(compose.toMap());

      expect(relu.selectedOptionIds, ['opt-coeur', 'opt-vanille']);
      expect(relu, equals(compose));
    });

    test('un panier écrit avant les options se relit sans options', () {
      // Compatibilité descendante : `selected_option_ids` est absent des
      // paniers sérialisés par les versions antérieures.
      final ancien = {
        'id': 'ligne-1',
        'menu_item_id': 'article-1',
        'name': 'Cheeseburger',
        'price': 2500.0,
        'quantity': 1,
        'image_url': null,
        'customizations': <String, dynamic>{},
      };

      expect(CartItem.fromMap(ancien).selectedOptionIds, isEmpty);
    });

    test('deux lignes ne diffèrent que par leurs options', () {
      final coeur = article(identifiantsOptions: const ['opt-coeur']);
      final carre = article(identifiantsOptions: const ['opt-carre']);

      expect(coeur, isNot(equals(carre)));
    });
  });

  group('Note envoyée au serveur', () {
    test('sans option structurée, tout est aplati et trié', () {
      // Déterminisme : `CartService._identical_line` (serveur) compare les
      // notes pour fusionner deux lignes identiques. Un ordre instable y
      // créerait une ligne de plus à chaque resynchronisation.
      final avec = article(options: {'cuisson': 'à point', 'boisson': 'cola'});

      expect(avec.remoteNotes, 'boisson: cola, cuisson: à point');
    });

    test('avec options structurées, seul le texte libre part', () {
      // Les libellés sont déjà stockés par le serveur sous forme d'options :
      // les répéter faisait déborder les 500 caractères de `CartLine.notes`,
      // et le refus emportait la ligne entière.
      final gateau = article(
        options: {
          'Forme': 'Cœur',
          'Saveur': 'Vanille',
          'note': 'Retrait le 12/08 à 10:00',
        },
        identifiantsOptions: const ['opt-coeur', 'opt-vanille'],
      );

      expect(gateau.remoteNotes, 'Retrait le 12/08 à 10:00');
    });

    test('une note trop longue est tronquée, pas refusée', () {
      final bavard = article(
        options: {'note': 'a' * 900},
        identifiantsOptions: const ['opt-coeur'],
      );

      expect(bavard.remoteNotes.length, CartItem.maxNotesLength);
    });

    test('une ligne sans personnalisation n’a pas de note', () {
      expect(article().remoteNotes, isEmpty);
    });
  });

  group('Somme d’un panier', () {
    test('le sous-total additionne les lignes', () {
      final panier = [
        article(quantite: 2),
        article(prix: 1000, quantite: 3),
      ];
      final sousTotal = panier.fold<double>(0, (s, l) => s + l.totalPrice);
      expect(sousTotal, 8000);
    });

    test('un panier vide vaut zéro, pas null', () {
      final sousTotal = <CartItem>[].fold<double>(0, (s, l) => s + l.totalPrice);
      expect(sousTotal, 0);
    });
  });
}
