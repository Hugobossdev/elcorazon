/// Ce qu'un poste de cuisine a besoin de savoir d'une commande.
///
/// ## Pourquoi ce fichier n'est pas dans l'écran
///
/// Trois règles décident de tout ce qu'affiche le KDS : dans quelle colonne
/// tombe une commande, laquelle passe avant, et laquelle est en retard. Écrites
/// dans le `build`, elles ne se testent qu'en montant un widget et en lisant des
/// pixels — c'est exactement ce qui est arrivé à `ancienneteCommande`, extraite
/// d'un écran pour la même raison.
///
/// ## Ce que ce module ne fait pas
///
/// Il ne rejoue **jamais** la machine à états. Les boutons se déduisent de
/// `Order.allowedTransitions`, que le serveur calcule et rend sur chaque
/// commande. Recomposer la table côté client est le défaut que `Course` a déjà
/// corrigé dans Dely : trois écrans, trois `switch`, trois trous différents.
library;

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

import 'package:admin/presentation/statut_commande.dart';

/// Les quatre colonnes du poste, dans l'ordre du service.
///
/// Elles regroupent des **statuts serveur** ; elles n'en inventent aucun. La
/// dernière réunit tout ce qui a quitté la cuisine — le repas est parti, ce
/// qu'il devient ensuite regarde la livraison, pas le cuisinier.
enum ColonneCuisine {
  confirmees(
    'Confirmées',
    Icons.receipt_long_outlined,
    {StatutCommande.confirmee},
  ),
  preparation(
    'En préparation',
    Icons.local_fire_department_outlined,
    {StatutCommande.enPreparation},
  ),
  pretes(
    'Prêtes',
    Icons.check_circle_outline,
    {StatutCommande.prete},
  ),
  remises(
    'Remises',
    Icons.delivery_dining_outlined,
    {StatutCommande.recuperee, StatutCommande.enRoute, StatutCommande.livree},
  );

  const ColonneCuisine(this.titre, this.icone, this.statuts);

  final String titre;
  final IconData icone;

  /// Les statuts que cette colonne accueille.
  final Set<StatutCommande> statuts;

  /// La colonne où tombe [statut], ou `null` s'il n'a rien à faire au poste.
  ///
  /// `pending` et `cancelled` n'ont pas de colonne, et c'est délibéré : une
  /// commande non confirmée n'est pas encore à préparer — le paiement n'est
  /// pas encaissé — et une commande annulée doit **disparaître** de l'écran.
  /// L'y laisser ferait préparer un repas que personne ne viendra chercher.
  static ColonneCuisine? pour(StatutCommande statut) {
    for (final colonne in ColonneCuisine.values) {
      if (colonne.statuts.contains(statut)) return colonne;
    }
    return null;
  }
}

/// Une commande telle que le poste la lit.
///
/// Enveloppe plutôt que copie : les écrans montrent la commande du socle, et
/// ce que le poste calcule en propre — sa colonne, son retard — est dérivé ici
/// une fois plutôt que recalculé à chaque `build`.
@immutable
class CommandeEnCuisine {
  const CommandeEnCuisine({
    required this.commande,
    required this.colonne,
    required this.enRetard,
    required this.attente,
  });

  final eccore.Order commande;
  final ColonneCuisine colonne;

  /// La cuisine a dépassé le temps qui lui était imparti.
  final bool enRetard;

  /// Depuis combien de temps la commande attend.
  final Duration attente;

  String get reference => commande.reference;
  List<eccore.OrderLine> get lignes => commande.lines;

  /// Les étapes que le serveur autorise depuis l'état courant.
  ///
  /// **La source des boutons.** La machine à états n'est pas rejouée ici.
  List<String> get transitionsAutorisees => commande.allowedTransitions;

  /// L'étape suivante du parcours cuisine, ou `null` s'il n'y en a pas.
  ///
  /// Ne propose que ce qui fait **avancer** la préparation. L'annulation en est
  /// exclue : elle a son propre geste, avec sa confirmation et son motif, et ne
  /// doit jamais tomber sous un bouton « suivant » qu'on presse à la chaîne.
  StatutCommande? get etapeSuivante {
    for (final etape in const [
      StatutCommande.enPreparation,
      StatutCommande.prete,
      StatutCommande.recuperee,
    ]) {
      if (transitionsAutorisees.contains(etape.versServeur)) return etape;
    }
    return null;
  }
}

/// Le temps qu'une commande peut passer en cuisine avant d'être en retard.
///
/// Fondé sur le délai de préparation déclaré par l'établissement
/// (`default_preparation_minutes`), et non sur `estimatedDeliveryAt` : celui-ci
/// inclut le trajet du livreur, et une cuisine qui s'y fierait ne se saurait en
/// retard qu'une fois le client déjà en train d'attendre chez lui.
///
/// Pas de score, pas de pondération : un seuil, franchi ou non. Le poste sert à
/// voir d'un coup d'œil quoi prendre ensuite, pas à classer finement.
Duration delaiDePreparation(int minutesDeclarees) =>
    Duration(minutes: minutesDeclarees > 0 ? minutesDeclarees : 15);

/// Compose ce que le poste affiche, colonne par colonne.
///
/// ## Le tri, et pourquoi il est unique
///
/// **La plus ancienne d'abord**, partout. C'est la seule priorité qui tienne en
/// cuisine : une commande qui attend depuis vingt minutes passe avant celle qui
/// vient d'arriver, quel que soit son montant ou son contenu. Toute autre règle
/// — les grosses commandes d'abord, les proches d'abord — produit des
/// commandes oubliées au fond de la file.
///
/// [maintenant] est injectable pour que le retard se teste sans attendre.
Map<ColonneCuisine, List<CommandeEnCuisine>> composerLePoste(
  List<eccore.Order> commandes, {
  required int minutesDePreparation,
  DateTime? maintenant,
}) {
  final instant = maintenant ?? DateTime.now();
  final seuil = delaiDePreparation(minutesDePreparation);

  final poste = <ColonneCuisine, List<CommandeEnCuisine>>{
    for (final colonne in ColonneCuisine.values) colonne: <CommandeEnCuisine>[],
  };

  for (final commande in commandes) {
    final colonne = ColonneCuisine.pour(
      StatutCommande.depuisServeur(commande.status),
    );
    if (colonne == null) continue;

    final attente = instant.difference(commande.placedAt);
    poste[colonne]!.add(
      CommandeEnCuisine(
        commande: commande,
        colonne: colonne,
        // Une commande déjà remise n'est plus en retard : la cuisine a fini
        // son travail, et la peindre en rouge indéfiniment noierait celles qui
        // attendent encore quelque chose.
        enRetard: colonne != ColonneCuisine.remises && attente > seuil,
        attente: attente,
      ),
    );
  }

  for (final file in poste.values) {
    file.sort((a, b) => a.commande.placedAt.compareTo(b.commande.placedAt));
  }
  return poste;
}
