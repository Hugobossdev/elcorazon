import 'package:flutter/material.dart';

import 'package:admin/presentation/statut_commande.dart';

/// L'icône d'un statut de commande.
IconData iconeDeStatut(StatutCommande status) {
  switch (status) {
    case StatutCommande.enAttente:
      return Icons.pending;
    case StatutCommande.confirmee:
      return Icons.check_circle_outline;
    case StatutCommande.enPreparation:
      return Icons.restaurant;
    case StatutCommande.prete:
      return Icons.check_circle_outline;
    case StatutCommande.recuperee:
      return Icons.shopping_bag;
    case StatutCommande.enRoute:
      return Icons.directions_bike;
    case StatutCommande.livree:
      return Icons.check_circle;
    case StatutCommande.annulee:
      return Icons.cancel;
  }
}

/// La couleur d'un statut **sur cet écran-là**.
///
/// Ces couleurs sont des `Colors.orange`, `Colors.blue`, `Colors.purple`
/// écrits en dur : elles ne viennent ni du `ColorScheme` ni des jetons du
/// back-office, et ne changent donc pas en thème sombre.
///
/// Il existe deux autres correspondances statut → couleur dans le produit —
/// `couleurDeStatut` (jetons du thème) et celle du tableau de bord (palette
/// `ModernTheme`) — et les trois rendent des couleurs différentes. Les unifier
/// changerait ce que voient les utilisateurs : c'est une décision de
/// conception que le plan de refactoring ne porte pas.
Color couleurDeStatutFixe(StatutCommande status) {
  switch (status) {
    case StatutCommande.enAttente:
      return Colors.orange;
    case StatutCommande.confirmee:
      return Colors.blue;
    case StatutCommande.enPreparation:
      return Colors.purple;
    case StatutCommande.prete:
      return Colors.green;
    case StatutCommande.recuperee:
      return Colors.teal;
    case StatutCommande.enRoute:
      return Colors.indigo;
    case StatutCommande.livree:
      return Colors.green;
    case StatutCommande.annulee:
      return Colors.red;
  }
}

