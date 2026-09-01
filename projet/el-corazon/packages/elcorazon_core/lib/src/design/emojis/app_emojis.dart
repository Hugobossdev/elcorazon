/// Le registre des assets emojis El Corazón — source unique de vérité.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// L'interface portait des emojis Unicode en dur : `Text('🍔')`, `'🍽️'` en
/// repli de catégorie, `'📱'` sur un moyen de paiement. Trois défauts, dans
/// cet ordre de gravité :
///
/// 1. **Le rendu ne nous appartient pas.** Un emoji Unicode est dessiné par la
///    police système. Le même écran ne montre pas la même chose sur un Pixel,
///    un iPhone et un Samsung d'entrée de gamme — et sur les Android anciens
///    encore courants à Lomé, un glyphe récent s'affiche en tofu (carré vide).
/// 2. **Les chemins se dispersent.** Un emoji écrit à quinze endroits se
///    corrige à quinze endroits.
/// 3. **Rien n'est accessible.** Un `Text('🎉')` se lit « party popper » à
///    voix haute, en anglais, au milieu d'une phrase française.
///
/// Ce registre répond aux trois : un token par illustration, nommé une fois.
///
/// Ce que ce fichier n'est pas
/// ---------------------------
///
/// Ce ne sont **pas les icônes fonctionnelles**. Navigation, panier, retour,
/// recherche, paiement, localisation, réglages restent des `IconData` du
/// design system — ils portent une action, pas une illustration. Ce ne sont
/// pas non plus **les photos produits** : le catalogue montre le plat, et un
/// emoji ne le remplace jamais. Ce registre couvre le troisième registre
/// seulement — illustrer une catégorie, un état, une émotion.
///
/// Voir [AppEmoji] pour le rendu, et `assets/emojis/README.md` pour le
/// contrat graphique des fichiers.
library;

import 'package:flutter/material.dart';

/// Une illustration du pack, avec de quoi la rendre en toutes circonstances.
///
/// Le token porte trois choses, et c'est ce triplet qui fait sa valeur :
///
/// * [asset] — le chemin du SVG ;
/// * [repli] — l'icône du design system à montrer **tant que le SVG n'est pas
///   embarqué**. Le pack se dessine en plusieurs fois ; sans ce repli, chaque
///   asset manquant serait un carré rouge en debug et un trou en production.
///   Ce n'est pas un pis-aller : c'est ce qui permet de migrer l'interface
///   avant que les trente illustrations n'existent ;
/// * [libelle] — ce qu'un lecteur d'écran doit prononcer, en français.
@immutable
final class AppEmojiToken {
  const AppEmojiToken({
    required this.asset,
    required this.repli,
    required this.libelle,
  });

  /// Le chemin embarqué, tel que déclaré dans `pubspec.yaml`.
  final String asset;

  /// L'icône du design system servie tant que [asset] n'est pas embarqué.
  final IconData repli;

  /// Le libellé d'accessibilité par défaut.
  final String libelle;

  @override
  String toString() => 'AppEmojiToken($asset)';
}

/// Les trente illustrations du pack El Corazón.
///
/// Le nom du fichier est la clé : renommer un SVG sans toucher ici le rend
/// invisible — [AppEmoji] retombe alors silencieusement sur le repli.
abstract final class AppEmojis {
  // ------------------------------------------------------------------- food

  static const burger = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/food/burger.svg',
    repli: Icons.lunch_dining_rounded,
    libelle: 'Burger',
  );
  static const pizza = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/food/pizza.svg',
    repli: Icons.local_pizza_rounded,
    libelle: 'Pizza',
  );
  static const donut = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/food/donut.svg',
    repli: Icons.donut_large_rounded,
    libelle: 'Beignet',
  );
  static const cake = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/food/cake.svg',
    repli: Icons.cake_rounded,
    libelle: 'Gâteau',
  );
  static const iceCream = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/food/ice_cream.svg',
    repli: Icons.icecream_rounded,
    libelle: 'Glace',
  );
  static const samosa = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/food/samosa.svg',
    repli: Icons.tapas_rounded,
    libelle: 'Samoussa',
  );
  static const pastel = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/food/pastel.svg',
    repli: Icons.bakery_dining_rounded,
    libelle: 'Pastel',
  );
  static const chicken = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/food/chicken.svg',
    repli: Icons.kebab_dining_rounded,
    libelle: 'Poulet',
  );
  static const fries = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/food/fries.svg',
    repli: Icons.fastfood_rounded,
    libelle: 'Frites',
  );
  static const drink = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/food/drink.svg',
    repli: Icons.local_drink_rounded,
    libelle: 'Boisson',
  );

  // ------------------------------------------------------------------ order

  static const cart = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/order/cart.svg',
    repli: Icons.shopping_cart_rounded,
    libelle: 'Panier',
  );
  static const newOrder = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/order/new_order.svg',
    repli: Icons.receipt_long_rounded,
    libelle: 'Nouvelle commande',
  );
  static const orderConfirmed = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/order/order_confirmed.svg',
    repli: Icons.check_circle_rounded,
    libelle: 'Commande confirmée',
  );
  static const preparing = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/order/preparing.svg',
    repli: Icons.soup_kitchen_rounded,
    libelle: 'Commande en préparation',
  );
  static const orderReady = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/order/order_ready.svg',
    repli: Icons.inventory_2_rounded,
    libelle: 'Commande prête',
  );
  static const orderCompleted = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/order/order_completed.svg',
    repli: Icons.task_alt_rounded,
    libelle: 'Commande terminée',
  );

  // --------------------------------------------------------------- delivery

  static const courier = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/delivery/courier.svg',
    repli: Icons.delivery_dining_rounded,
    libelle: 'Livreur',
  );
  static const scooter = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/delivery/scooter.svg',
    repli: Icons.two_wheeler_rounded,
    libelle: 'Scooter',
  );
  static const location = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/delivery/location.svg',
    repli: Icons.location_on_rounded,
    libelle: 'Position',
  );
  static const delivery = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/delivery/delivery.svg',
    repli: Icons.local_shipping_rounded,
    libelle: 'Livraison en cours',
  );
  static const delivered = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/delivery/delivered.svg',
    repli: Icons.where_to_vote_rounded,
    libelle: 'Commande livrée',
  );

  // --------------------------------------------------------------------- ux

  static const heart = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/ux/heart.svg',
    repli: Icons.favorite_rounded,
    libelle: 'Coup de cœur',
  );
  static const favorite = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/ux/favorite.svg',
    repli: Icons.bookmark_rounded,
    libelle: 'Favori',
  );
  static const success = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/ux/success.svg',
    repli: Icons.check_circle_rounded,
    libelle: 'Succès',
  );
  static const error = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/ux/error.svg',
    repli: Icons.error_rounded,
    libelle: 'Erreur',
  );
  static const warning = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/ux/warning.svg',
    repli: Icons.warning_rounded,
    libelle: 'Attention',
  );
  static const gift = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/ux/gift.svg',
    repli: Icons.card_giftcard_rounded,
    libelle: 'Cadeau',
  );
  static const promotion = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/ux/promotion.svg',
    repli: Icons.local_offer_rounded,
    libelle: 'Promotion',
  );
  static const star = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/ux/star.svg',
    repli: Icons.star_rounded,
    libelle: 'Étoile',
  );
  static const celebration = AppEmojiToken(
    asset: 'packages/elcorazon_core/assets/emojis/ux/celebration.svg',
    repli: Icons.celebration_rounded,
    libelle: 'Félicitations',
  );

  // ------------------------------------------------------------ inventaires

  /// Le pack, rangé par famille — ce que la galerie de relecture parcourt.
  ///
  /// L'ordre est celui du `README.md` du dossier d'assets : c'est celui dans
  /// lequel les illustrations se comparent.
  static const Map<String, List<AppEmojiToken>> parFamille = {
    'Food': [
      burger,
      pizza,
      donut,
      cake,
      iceCream,
      samosa,
      pastel,
      chicken,
      fries,
      drink,
    ],
    'Order': [
      cart,
      newOrder,
      orderConfirmed,
      preparing,
      orderReady,
      orderCompleted,
    ],
    'Delivery': [courier, scooter, location, delivery, delivered],
    'UX': [
      heart,
      favorite,
      success,
      error,
      warning,
      gift,
      promotion,
      star,
      celebration,
    ],
  };

  /// Les trente, à plat.
  static List<AppEmojiToken> get toutes => [
        for (final famille in parFamille.values) ...famille,
      ];
}

/// L'illustration d'une catégorie du catalogue, ou `null`.
///
/// ## Pourquoi le slug, et pas l'emoji du serveur
///
/// `eccore.Category` porte bien un champ `emoji`, alimenté par
/// l'établissement depuis l'admin Django. Ce champ **reste** : c'est une
/// donnée métier, il est persisté, mis en cache et lu par l'application
/// d'administration. Mais il ne pilote plus le rendu client : le serveur n'a
/// pas à décider du dessin. Il nomme la catégorie, le client choisit
/// l'illustration.
///
///     serveur → slug → mapping → AppEmojis
///
/// et non `serveur → "🍔"`.
///
/// ## Pourquoi `null` plutôt qu'un repli
///
/// « Salades » et « Spécialités Togolaises » n'ont aucune illustration dans le
/// pack, et aucune des trente ne les représente honnêtement. L'ancien code
/// posait `'🍽️'` sur tout ce qu'il ne savait pas nommer — une assiette vide
/// devant un plat togolais dit moins que rien. Une catégorie sans
/// illustration affiche son seul intitulé, ce qui est correct.
AppEmojiToken? emojiDeCategorie(String slug) {
  // Les slugs du serveur sont en minuscules à tirets (`seed_full_catalog`),
  // mais un établissement peut en saisir d'autres depuis l'admin : on
  // normalise plutôt que de supposer.
  final cle = slug.trim().toLowerCase().replaceAll('_', '-');

  return switch (cle) {
    'burgers' || 'burger' => AppEmojis.burger,
    'pizzas' || 'pizza' => AppEmojis.pizza,
    'grillades' || 'poulet' || 'chicken' => AppEmojis.chicken,
    'accompagnements' || 'frites' || 'sides' => AppEmojis.fries,
    'boissons' || 'boisson' || 'drinks' || 'drink' => AppEmojis.drink,
    'desserts' || 'dessert' || 'patisseries' || 'patisserie' => AppEmojis.cake,
    'gateaux' || 'gateau' || 'cakes' => AppEmojis.cake,
    'glaces' || 'glace' || 'ice-cream' => AppEmojis.iceCream,
    'beignets' || 'beignet' || 'donuts' => AppEmojis.donut,
    'samoussas' || 'samossas' || 'samosas' => AppEmojis.samosa,
    'pastels' || 'pastel' => AppEmojis.pastel,
    _ => null,
  };
}
