import 'package:flutter/material.dart';

import 'package:admin/presentation/statut_commande.dart';
import 'package:admin/ui/ui.dart';

/// La couleur qui signale un statut de commande.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Cette correspondance était une méthode privée de
/// `advanced_order_management_screen.dart`, recopiée à l'identique dans le
/// widget qui en avait besoin. Elle est ici pour que l'onglet des statistiques,
/// sorti de l'écran, la partage plutôt que d'en garder une copie.
///
/// Attention : **trois** correspondances de ce nom coexistent dans le
/// back-office, et elles ne rendent pas les mêmes couleurs.
/// `admin_dashboard_screen.dart` passe par la palette statique `ModernTheme`,
/// et `order_management_screen.dart` par des `Colors.orange`/`Colors.blue`
/// écrits en dur, aveugles au thème sombre. Les unifier changerait ce que
/// voient les utilisateurs sur ces deux écrans : c'est une décision de
/// conception, pas de refactoring, et le plan n'en dit rien.
Color couleurDeStatut(StatutCommande statut, ColorScheme scheme) {
  final sem = AdminColorTokens.semantic(scheme);

  switch (statut) {
    case StatutCommande.enAttente:
      return sem.warning;
    case StatutCommande.confirmee:
      return sem.info;
    case StatutCommande.enPreparation:
      return scheme.tertiary;
    case StatutCommande.prete:
      return sem.success;
    case StatutCommande.recuperee:
      return scheme.secondary;
    case StatutCommande.enRoute:
      return scheme.primary;
    case StatutCommande.livree:
      return sem.success;
    case StatutCommande.annulee:
      return sem.danger;
  }
}
