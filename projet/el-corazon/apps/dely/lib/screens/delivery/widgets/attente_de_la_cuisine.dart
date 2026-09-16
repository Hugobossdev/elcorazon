import 'package:flutter/material.dart';

/// « La cuisine n'a pas fini » — dit à la place du bouton de retrait.
///
/// ## Pourquoi un encart, et pas un bouton grisé
///
/// `allowed_transitions` est calculé sur la seule machine de la **course** :
/// « récupérée » y figure dès l'acceptation, quelle que soit l'avancée de la
/// préparation. L'écran proposait donc au livreur de déclarer qu'il avait pris
/// un repas encore en cuisine — et le serveur l'acceptait, laissant la commande
/// bloquée en préparation pendant que la course allait jusqu'à « livrée ».
///
/// Le serveur refuse désormais ce geste. Un bouton grisé serait une deuxième
/// erreur : le livreur, debout au comptoir, n'aurait aucun moyen de savoir s'il
/// attend la cuisine, s'il a perdu le réseau ou si l'application est bloquée.
/// L'encart nomme l'attente, et il disparaît de lui-même au rechargement
/// suivant — la file se recharge à chaque événement et toutes les trente
/// secondes.
class AttenteDeLaCuisine extends StatelessWidget {
  const AttenteDeLaCuisine({super.key, this.dense = false});

  /// Forme courte, pour une carte de liste où l'encart remplace un bouton.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      label: 'En attente de la cuisine. Le retrait s’ouvrira dès que la '
          'commande sera prête.',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(dense ? 10 : 14),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.soup_kitchen_outlined,
                size: dense ? 18 : 20,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dense
                      ? 'En cuisine'
                      : 'La cuisine prépare encore cette commande. Le retrait '
                          's’ouvrira dès qu’elle sera prête.',
                  style: TextStyle(
                    color: scheme.onSecondaryContainer,
                    fontSize: dense ? 12 : 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
