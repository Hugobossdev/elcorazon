/// Depuis combien de temps une commande est passée, en une poignée de
/// caractères.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Cette règle était une méthode privée de
/// `advanced_order_management_screen.dart` qui lisait l'horloge elle-même :
/// aucun test ne pouvait en dire quoi que ce soit. [maintenant] est là pour
/// cela, et pour cela seulement — les appels d'écran ne le passent pas.
///
/// La forme est celle d'une colonne de tableau, pas d'une phrase : `12min`,
/// `3h`, puis `24/12` au-delà d'une journée. Un opérateur balaie une liste ; il
/// lui faut un repère court, pas « il y a environ trois heures ».
String ancienneteCommande(DateTime passeeLe, {DateTime? maintenant}) {
  final ecart = (maintenant ?? DateTime.now()).difference(passeeLe);

  if (ecart.inMinutes < 60) {
    return '${ecart.inMinutes}min';
  } else if (ecart.inHours < 24) {
    return '${ecart.inHours}h';
  } else {
    return '${passeeLe.day}/${passeeLe.month}';
  }
}

/// L'heure à laquelle la commande a été passée — `18:45`.
///
/// Complète [ancienneteCommande] plutôt que de la remplacer : les deux
/// répondent à des questions différentes. « 3h » dit depuis combien de temps
/// elle attend, « 18:45 » dit à quel moment du service elle est tombée. Un
/// opérateur qui reprend un poste a besoin du second ; celui qui surveille un
/// coup de feu a besoin du premier.
///
/// En heure **locale** : l'API horodate en UTC, et « 18:45 » affiché en UTC
/// décale d'une heure toute lecture faite depuis Lomé.
String heureCommande(DateTime passeeLe) {
  final locale = passeeLe.toLocal();
  final heures = locale.hour.toString().padLeft(2, '0');
  final minutes = locale.minute.toString().padLeft(2, '0');
  return '$heures:$minutes';
}
