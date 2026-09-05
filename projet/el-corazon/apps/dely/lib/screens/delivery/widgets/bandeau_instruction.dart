import 'package:elcorazon_core/elcorazon_core.dart' show Manoeuvre;
import 'package:flutter/material.dart';

/// L'instruction en cours, telle qu'un livreur la lit **en conduisant**.
///
/// ## Ce qui décide de la mise en forme
///
/// Le coup d'œil. Un livreur regarde ce bandeau une demi-seconde, guidon en
/// main, à contre-jour. Trois choses en découlent :
///
/// * la **flèche** avant le texte — une forme se reconnaît sans être lue ;
/// * la **distance** en gros, isolée du reste : c'est la seule valeur qui
///   change en continu et la seule qu'on relit ;
/// * un fond opaque et contrasté, parce que la carte défile dessous.
///
/// Le texte, lui, est déjà rédigé : il vient de `MoteurDeNavigation`, dans la
/// langue du guidage. Ce widget ne compose aucune phrase — c'est ce qui fait
/// qu'une instruction affichée est exactement celle qui est prononcée.
class BandeauInstruction extends StatelessWidget {
  const BandeauInstruction({
    required this.instruction,
    required this.manoeuvre,
    required this.distanceMetres,
    this.instructionSuivante,
    super.key,
  });

  final String instruction;
  final Manoeuvre? manoeuvre;

  /// Distance avant la manœuvre, ou `null` quand l'itinéraire n'a pas de
  /// manœuvres à annoncer — un repli en ligne droite, par exemple.
  final double? distanceMetres;

  final String? instructionSuivante;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suivante = instructionSuivante;

    return Material(
      color: theme.colorScheme.primary,
      borderRadius: BorderRadius.circular(16),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  iconeDeManoeuvre(manoeuvre),
                  size: 44,
                  color: theme.colorScheme.onPrimary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (distanceMetres != null)
                        Text(
                          distanceLisible(distanceMetres!),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                      Text(
                        instruction,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (suivante != null) ...[
              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.subdirectory_arrow_right,
                    size: 16,
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Puis $suivante',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimary.withValues(alpha: 0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// La flèche d'une manœuvre.
///
/// Une icône par geste, et la boussole quand Google n'annonce pas de manœuvre —
/// jamais une flèche de virage choisie au hasard : une flèche à droite là où
/// rien n'a été affirmé enverrait le livreur dans la mauvaise rue aussi
/// sûrement qu'une phrase inventée.
IconData iconeDeManoeuvre(Manoeuvre? manoeuvre) => switch (manoeuvre) {
      Manoeuvre.aGauche => Icons.turn_left,
      Manoeuvre.aDroite => Icons.turn_right,
      Manoeuvre.legerementAGauche => Icons.turn_slight_left,
      Manoeuvre.legerementADroite => Icons.turn_slight_right,
      Manoeuvre.serreAGauche => Icons.turn_sharp_left,
      Manoeuvre.serreADroite => Icons.turn_sharp_right,
      Manoeuvre.demiTour => Icons.u_turn_right,
      Manoeuvre.rondPoint => Icons.roundabout_right,
      Manoeuvre.bretelleAGauche => Icons.ramp_left,
      Manoeuvre.bretelleADroite => Icons.ramp_right,
      Manoeuvre.insertion => Icons.merge,
      Manoeuvre.fourcheAGauche => Icons.fork_left,
      Manoeuvre.fourcheADroite => Icons.fork_right,
      Manoeuvre.bac => Icons.directions_boat,
      Manoeuvre.toutDroit => Icons.straight,
      Manoeuvre.aucune || null => Icons.navigation,
    };

/// « 850 m », « 3,4 km » — la distance telle qu'elle s'affiche.
///
/// Les mêmes seuils que la distance **prononcée** (`PhrasesNavigation`), mais
/// pas le même arrondi : l'œil supporte « 320 m » là où l'oreille perdrait le
/// début de la phrase. La dizaine partout sous le kilomètre — aucun récepteur
/// grand public ne vaut mieux, et afficher « 327 m » promettrait une précision
/// qu'on n'a pas.
String distanceLisible(double metres) {
  if (metres >= 1000) {
    return '${(metres / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }
  return '${(metres / 10).round() * 10} m';
}
