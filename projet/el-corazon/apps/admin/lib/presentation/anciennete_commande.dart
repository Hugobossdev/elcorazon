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
