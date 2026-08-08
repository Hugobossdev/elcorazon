import 'package:flutter/material.dart';

import 'package:admin/models/order.dart';

/// L'icône d'un statut de commande.
IconData iconeDeStatut(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return Icons.pending;
    case OrderStatus.confirmed:
      return Icons.check_circle_outline;
    case OrderStatus.preparing:
      return Icons.restaurant;
    case OrderStatus.ready:
      return Icons.check_circle_outline;
    case OrderStatus.pickedUp:
      return Icons.shopping_bag;
    case OrderStatus.onTheWay:
      return Icons.directions_bike;
    case OrderStatus.delivered:
      return Icons.check_circle;
    case OrderStatus.cancelled:
      return Icons.cancel;
    case OrderStatus.refunded:
      return Icons.payment;
    case OrderStatus.failed:
      return Icons.error;
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
Color couleurDeStatutFixe(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return Colors.orange;
    case OrderStatus.confirmed:
      return Colors.blue;
    case OrderStatus.preparing:
      return Colors.purple;
    case OrderStatus.ready:
      return Colors.green;
    case OrderStatus.pickedUp:
      return Colors.teal;
    case OrderStatus.onTheWay:
      return Colors.indigo;
    case OrderStatus.delivered:
      return Colors.green;
    case OrderStatus.cancelled:
      return Colors.red;
    case OrderStatus.refunded:
      return Colors.grey;
    case OrderStatus.failed:
      return Colors.brown;
  }
}

