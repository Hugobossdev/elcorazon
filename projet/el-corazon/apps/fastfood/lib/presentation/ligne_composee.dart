import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Ce que la fiche d'un plat rend quand l'ajout ne va pas au panier
/// personnel — le panier collaboratif, qui a son propre point d'entrée.
///
/// La fiche ne transmettait que l'article, la quantité et les **libellés**.
/// Le panier du groupe partait donc sans identifiants d'options, et le
/// serveur refusait tout plat dont un groupe exige un choix ; il refuserait
/// de même tout plat à tailles (lot 2), faute de taille. Tout ce dont le
/// serveur tire le prix voyage désormais avec la ligne.
typedef LigneComposee = ({
  eccore.MenuItem article,
  int quantite,
  Map<String, dynamic> libelles,
  List<String> optionIds,
  eccore.Variante? taille,
});

/// Reçoit une ligne composée par la fiche.
typedef AjoutDeLigne = void Function(LigneComposee ligne);
