/// La règle de prix d'une ligne, en un seul endroit.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Le montant d'une ligne personnalisée se calculait à trois endroits, et les
/// trois ne tombaient pas d'accord :
///
/// * la barre d'ajout de la fiche produit lisait
///   `ItemCustomization.totalPriceModifier`, un champ que seul
///   `finishCustomization` renseignait — c'est-à-dire jamais pendant la
///   composition. Elle annonçait donc le prix nu du plat, options comprises ou
///   non ;
/// * `CartItem.totalPrice` faisait `price * quantity` sur un `price` qui ne
///   portait que le tarif catalogue : les suppléments disparaissaient au
///   passage au panier ;
/// * `CartService.subtotal` cumulait ces lignes amputées, puis le devis du
///   serveur remplaçait le total sans jamais toucher au sous-total affiché.
///
/// Le client voyait donc trois montants différents pour un même plat entre la
/// fiche, le panier et l'addition. La règle est maintenant écrite ici, une
/// fois, et les trois s'y adressent.
///
/// Où est la règle qui fait foi
/// ----------------------------
///
/// Côté serveur, dans `price_selection` (`backend/apps/carts/services.py`) :
///
/// ```python
/// unit = line.menu_item.price
/// for option in options:
///     unit += option.price_delta
/// total = unit * line.quantity
/// ```
///
/// Ce fichier en est le reflet, terme pour terme. Quand les deux divergeront,
/// c'est celui-ci qui aura tort.
///
/// Ce que cette règle n'est pas
/// ----------------------------
///
/// Elle **n'établit aucun prix**. Le serveur relit les options au catalogue et
/// chiffre lui-même la ligne (invariant C1, ADR-007) ; c'est son `unit_price`
/// qui est facturé, et `CartService._fromRemoteLine` le repose sur la ligne dès
/// la première synchronisation. Ce qui est calculé ici sert à **montrer**, pendant
/// la composition et jusqu'à ce que le serveur ait répondu, le montant que le
/// client s'apprête à engager. Un écran qui n'affiche rien plutôt qu'une
/// estimation ne protège personne : il laisse découvrir le supplément à
/// l'addition.
library;

/// Prix d'un exemplaire, suppléments d'options compris.
///
/// [supplementOptions] est la **somme déjà faite** des options retenues. Le
/// séparer du prix de base est ce qui empêche le double comptage : une ligne
/// dont le prix intègre déjà ses options — celle que rend le serveur — porte un
/// supplément nul, et repasser par ici ne la renchérit pas.
double prixUnitairePersonnalise({
  required double prixDeBase,
  required double supplementOptions,
}) {
  return prixDeBase + supplementOptions;
}

/// Total d'une ligne : le prix unitaire personnalisé, multiplié par la
/// quantité.
///
/// Les options sont multipliées **avec** le plat, et non ajoutées une seule
/// fois à côté : trois burgers à 5 000 avec 1 000 de suppléments coûtent
/// 18 000, pas 16 000.
double totalDeLigne({
  required double prixDeBase,
  required double supplementOptions,
  required int quantite,
}) {
  return prixUnitairePersonnalise(
        prixDeBase: prixDeBase,
        supplementOptions: supplementOptions,
      ) *
      quantite;
}

/// Cumul des lignes d'un panier.
double sousTotalDuPanier(Iterable<double> totauxDeLigne) {
  return totauxDeLigne.fold(0.0, (somme, total) => somme + total);
}
