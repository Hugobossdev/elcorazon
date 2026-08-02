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
  }) {
    return CartItem(
      id: 'ligne-1',
      menuItemId: 'article-1',
      name: 'Cheeseburger',
      price: prix,
      quantity: quantite,
      customizations: options,
    );
  }

  group('Total d’une ligne', () {
    test('prix multiplié par la quantité', () {
      expect(article(prix: 2500, quantite: 3).totalPrice, 7500);
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
      final sans = article(prix: 2500, quantite: 2);
      final avec = article(
        prix: 2500,
        quantite: 2,
        options: {'supplément': 'fromage'},
      );
      expect(avec.totalPrice, sans.totalPrice);
    });
  });

  group('Somme d’un panier', () {
    test('le sous-total additionne les lignes', () {
      final panier = [
        article(prix: 2500, quantite: 2),
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
