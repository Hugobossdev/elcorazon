import 'package:flutter/material.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:elcora_fast/services/design_enhancement_service.dart';

/// Une ligne de commande qu'on cherche à remettre au panier.
typedef LigneAReprendre = ({
  String menuItemId,
  String nom,
  int quantite,
  Map<String, String> options,
});

/// Ce qui peut être repris, et ce qui ne le peut pas.
typedef TriDeLaReprise = ({
  List<({eccore.MenuItem article, LigneAReprendre ligne})> retenues,
  List<String> indisponibles,
});

/// Départage les lignes d'une commande passée entre reprenables et perdues.
///
/// ## Pourquoi cette fonction est pure
///
/// Elle **décide**, elle n'agit pas : c'est `CartService` qui dépose ensuite
/// les lignes retenues. Séparer les deux permet d'éprouver la règle sans
/// construire un panier — lequel exige, dans cette application, un client HTTP
/// et une session.
///
/// ## La règle
///
/// Un article doit exister **au catalogue d'aujourd'hui** et y être
/// disponible. Le panier serveur ne connaît que le catalogue ; une ligne
/// inventée est refusée, et disparaît à la synchronisation suivante sans que
/// personne ne le dise.
///
/// Les articles écartés sont **nommés**. C'est le point important : l'écran
/// d'historique collectait déjà cette liste et ne la montrait jamais. On
/// recommandait cinq plats, deux avaient quitté la carte, et le message
/// annonçait « 3 articles ajoutés » sans un mot des deux autres.
TriDeLaReprise trierLaReprise(
  List<LigneAReprendre> lignes,
  List<eccore.MenuItem> catalogue,
) {
  final retenues = <({eccore.MenuItem article, LigneAReprendre ligne})>[];
  final indisponibles = <String>[];

  for (final ligne in lignes) {
    final article =
        catalogue.where((item) => item.id == ligne.menuItemId).firstOrNull;

    if (article == null || !article.isAvailable) {
      indisponibles.add(ligne.nom);
      continue;
    }

    retenues.add((article: article, ligne: ligne));
  }

  return (retenues: retenues, indisponibles: indisponibles);
}

/// Ce qu'on dit au client après avoir remis une commande au panier.
///
/// ## Le défaut que ce fichier corrige
///
/// L'écran d'historique collectait la liste des articles **retirés de la
/// carte** — ceux qu'on ne peut pas recommander, parce que le panier serveur
/// ne connaît que le catalogue du jour — et ne la montrait **jamais**. On
/// recommandait cinq plats, deux avaient disparu de la carte, et le message
/// annonçait « 3 articles ajoutés » sans un mot des deux autres.
///
/// Le client s'en apercevait au règlement, en comptant son addition. Ou pas
/// du tout.
///
/// ## Pourquoi c'est ici
///
/// Deux écrans reposent une commande au panier — l'historique et l'onglet
/// « Commandes ». Le message doit être le même : c'est la même opération, et
/// deux formulations divergentes sur un sujet d'argent finissent par se
/// contredire.
void annoncerLaReprise(
  BuildContext context,
  ({int ajoutes, List<String> indisponibles}) resultat,
) {
  final ajoutes = resultat.ajoutes;
  final absents = resultat.indisponibles;

  if (ajoutes == 0) {
    context.showErrorMessage(
      absents.isEmpty
          ? 'Aucun article n’a pu être remis au panier.'
          : 'Ces plats ne sont plus à la carte : ${absents.join(', ')}.',
    );
    return;
  }

  final debut = ajoutes == 1
      ? '1 article remis au panier'
      : '$ajoutes articles remis au panier';

  if (absents.isEmpty) {
    context.showSuccessMessage('$debut.');
    return;
  }

  // Une reprise partielle n'est pas une réussite franche : elle se dit en
  // entier, avec ce qui manque nommé. Le client saura quoi remplacer.
  context.showErrorMessage(
    '$debut. Plus à la carte : ${absents.join(', ')}.',
  );
}
