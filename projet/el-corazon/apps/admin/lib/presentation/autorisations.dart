import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/services/admin_auth_service.dart';

/// Ce que l'interface **présente** au compte connecté — ADR-005.
///
/// ## Pourquoi un point unique
///
/// Quatorze écrans consultaient `AdminAuthService.can` avant d'offrir un
/// geste ; une quarantaine ne le faisaient pas. Un Opérateur voyait « Créer un
/// article », « Suspendre », « Nouvelle promotion » ; il remplissait le
/// formulaire, et le serveur le refusait en 403 à l'envoi. Les raccourcis du
/// tableau de bord contournaient même le filtre de la barre latérale.
///
/// **Rien ici n'est une sécurité.** Le serveur vérifie chaque permission sur
/// chaque route, et c'est lui qui refuse. Masquer un bouton n'accorde ni ne
/// retire rien : l'interface cesse seulement de promettre ce que le serveur
/// refusera.
///
/// Les chaînes sont celles du registre serveur
/// (`apps/accounts/permissions.py`), reprises telles quelles.
/// `tools/contrat_vocabulaire.py` vérifie en CI que chacune y figure : une
/// faute de frappe masquerait un bouton pour tout le monde, en silence.
extension Autorisations on BuildContext {
  /// Le compte porte-t-il [permission] ? **À appeler dans `build`** : la
  /// réponse suit la session (déconnexion, changement de rôle).
  bool peut(String permission) => watch<AdminAuthService>().can(permission);

  /// Au moins une des [permissions].
  bool peutUne(List<String> permissions) {
    final auth = watch<AdminAuthService>();
    return permissions.any(auth.can);
  }

  /// Le compte voit-il l'enseigne entière (superutilisateur) ? Ce qui ne
  /// relève d'aucun établissement — pays, ville, zone municipale, code ou
  /// récompense nationaux, campagne — lui est réservé côté serveur
  /// (`assert_unscoped`), quelle que soit la permission.
  bool get estSiege => watch<AdminAuthService>().estSiege;

  /// Ouvrir, fermer ou tarifer une zone municipale : `restaurants.write`
  /// **et** le siège. Une zone n'appartient à aucun établissement
  /// (`geography/backoffice.py`, `assert_unscoped`) : un gérant muni de
  /// `restaurants.write` récolterait un 403 à chaque bascule.
  bool get peutReglerLesZones => peut('restaurants.write') && estSiege;
}

/// N'affiche [child] que si le compte porte [permission] — sinon [sinon],
/// rien par défaut.
///
/// Pour un geste isolé (un bouton, une entrée de menu). Pour une liste de
/// gestes, lire `context.peut` une fois dans `build`.
class SiAutorise extends StatelessWidget {
  const SiAutorise({
    required this.permission,
    required this.child,
    this.sinon = const SizedBox.shrink(),
    super.key,
  });

  final String permission;
  final Widget child;
  final Widget sinon;

  @override
  Widget build(BuildContext context) => context.peut(permission) ? child : sinon;
}
