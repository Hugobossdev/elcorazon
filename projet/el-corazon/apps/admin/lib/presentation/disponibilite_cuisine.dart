import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Ce que voit le client d'une cuisine **en service**, en une étiquette.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// La carte d'un établissement disait « En service » d'après son cycle de vie,
/// et « Commandes suspendues » d'après le seul drapeau du coup de feu. Deux cas
/// passaient donc inaperçus :
///
/// * une cuisine en service dont la **ville, la zone ou le pays** a été
///   désactivé — invisible de l'application cliente, configurée ici ;
/// * une cuisine en service **hors de ses horaires** — qui refuse toute
///   commande.
///
/// Le serveur rend désormais le verdict du juge que la commande consulte
/// (`unavailable_code`), et c'est lui qu'on affiche. Rend `null` quand un
/// client peut commander : rien à signaler.
///
/// La phrase complète (`unavailableReason`) accompagne l'étiquette en
/// infobulle ; l'étiquette, elle, doit tenir dans une pastille.
String? etiquetteDisponibiliteCuisine(eccore.ManagedRestaurant cuisine) {
  if (!cuisine.status.isPublished) return null;

  return switch (cuisine.unavailableCode) {
    '' => cuisine.acceptsOrders ? null : 'Commandes en pause',
    eccore.MotifIndisponibilite.cuisineNonPubliee => 'Invisible des clients',
    eccore.MotifIndisponibilite.cuisineFermee => 'Fermée (hors horaires)',
    eccore.MotifIndisponibilite.cuisineEnPause => 'Commandes en pause',
    eccore.MotifIndisponibilite.cuisineSuspendue => 'Suspendue',
    _ => 'Non commandable',
  };
}
