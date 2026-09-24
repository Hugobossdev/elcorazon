import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:admin/presentation/commande.dart';
import 'package:admin/presentation/statut_commande.dart';

/// La vue Kanban des commandes — cahier des charges §4.2.4.
///
/// ## Une colonne par étape du service, pas une règle nouvelle
///
/// Le cahier des charges cite quatre colonnes à titre d'exemple (« En attente,
/// En préparation, En livraison, Livré »). Regrouper `confirmée` avec l'une ou
/// `prête` avec l'autre aurait été une décision d'exploitation prise dans un
/// écran. Les colonnes sont donc **celles des onglets de la supervision** — les
/// étapes que le serveur connaît — et seules `récupérée` et `en route` se
/// partagent une colonne, comme elles partagent déjà l'onglet « En livraison ».
///
/// ## Ce qu'une colonne contient
///
/// Les étapes en cours, **les plus anciennes d'abord** : c'est l'ordre dans
/// lequel on les traite, et une commande qui attend depuis quarante minutes ne
/// doit pas se trouver sous celles qui viennent d'arriver.
///
/// Les livrées **du jour seulement**, les plus récentes d'abord. La fenêtre de
/// supervision couvre un an : sans cette borne, la dernière colonne
/// contiendrait un an de livraisons.
enum ColonneTableau {
  enAttente('En attente', {StatutCommande.enAttente}),
  confirmees('Confirmées', {StatutCommande.confirmee}),
  enPreparation('En préparation', {StatutCommande.enPreparation}),
  pretes('Prêtes', {StatutCommande.prete}),
  enLivraison('En livraison', {StatutCommande.recuperee, StatutCommande.enRoute}),
  livreesDuJour('Livrées aujourd’hui', {StatutCommande.livree});

  const ColonneTableau(this.libelle, this.statuts);

  final String libelle;
  final Set<StatutCommande> statuts;
}

/// Répartit les commandes entre les colonnes du tableau.
///
/// Les commandes annulées n'y figurent pas : elles ne sont plus à traiter, et
/// l'onglet de supervision les retrouve par la recherche.
Map<ColonneTableau, List<eccore.Order>> repartirSurLeTableau(
  Iterable<eccore.Order> commandes, {
  DateTime? maintenant,
}) {
  final aujourdHui = (maintenant ?? DateTime.now()).toLocal();
  bool livreeAujourdHui(eccore.Order commande) {
    final livree = commande.deliveredAt?.toLocal();
    return livree != null &&
        livree.year == aujourdHui.year &&
        livree.month == aujourdHui.month &&
        livree.day == aujourdHui.day;
  }

  final colonnes = {for (final colonne in ColonneTableau.values) colonne: <eccore.Order>[]};
  for (final commande in commandes) {
    for (final colonne in ColonneTableau.values) {
      if (!colonne.statuts.contains(commande.statut)) continue;
      if (colonne == ColonneTableau.livreesDuJour && !livreeAujourdHui(commande)) break;
      colonnes[colonne]!.add(commande);
      break;
    }
  }

  for (final entree in colonnes.entries) {
    if (entree.key == ColonneTableau.livreesDuJour) {
      entree.value.sort((a, b) => b.deliveredAt!.compareTo(a.deliveredAt!));
    } else {
      entree.value.sort((a, b) => a.placedAt.compareTo(b.placedAt));
    }
  }
  return colonnes;
}

/// Combien de cartes une colonne affiche avant de renvoyer à l'onglet.
///
/// Un tableau sert à voir le service d'un coup d'œil ; au-delà, une liste
/// paginée et filtrable le fait mieux, et des centaines de cartes rendraient
/// l'écran lent à défiler.
const plafondParColonne = 50;
