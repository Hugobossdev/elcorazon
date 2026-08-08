import 'package:admin/models/order.dart';

/// Le nombre de commandes par jour sur une fenêtre glissante.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Ce comptage était enfermé dans le corps du widget qui dessine le graphe de
/// `advanced_order_management_screen.dart`. Rien ne pouvait en dire quoi que
/// ce soit — ni qu'il couvre bien sept jours, ni ce qu'il fait d'une commande
/// plus ancienne.
///
/// Les clés sont des dates `AAAA-MM-JJ` complétées par des zéros, pour que
/// l'ordre alphabétique soit l'ordre chronologique — c'est ce dont le graphe
/// se sert pour ranger ses barres.
Map<String, int> commandesParJour(
  List<Order> commandes, {
  int jours = 7,
  DateTime? maintenant,
}) {
  final fin = maintenant ?? DateTime.now();
  final parJour = <String, int>{};

  for (var i = jours - 1; i >= 0; i--) {
    parJour[_cle(fin.subtract(Duration(days: i)))] = 0;
  }

  for (final commande in commandes) {
    final jour = _cle(commande.orderTime);
    // Une commande hors fenêtre n'ouvre pas de colonne : le graphe en montre
    // sept, pas une de plus.
    if (parJour.containsKey(jour)) {
      parJour[jour] = parJour[jour]! + 1;
    }
  }

  return parJour;
}

String _cle(DateTime date) {
  final mois = date.month.toString().padLeft(2, '0');
  final jour = date.day.toString().padLeft(2, '0');
  return '${date.year}-$mois-$jour';
}
