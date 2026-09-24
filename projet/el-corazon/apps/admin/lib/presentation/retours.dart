import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

import 'package:admin/presentation/echec.dart';

/// Annonces de résultat, communes aux écrans du back-office.
///
/// Un succès ne s'annonce qu'**après** confirmation du serveur ; un refus
/// s'annonce avec sa nature et la phrase du serveur ([Echec]).

/// Exécute une bascule actif/inactif et **dit** un refus : elle ignorait le
/// résultat, et une désactivation refusée laissait croire qu'elle avait eu
/// lieu.
Future<void> basculerAvecRetour(BuildContext context, Future<void> Function() geste) async {
  try {
    await geste();
  } on eccore.ApiException catch (e) {
    if (context.mounted) annoncerEchec(context, Echec.de(e));
  }
}

void annoncer(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

void annoncerEchec(BuildContext context, Echec echec) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('${echec.nature.titre} — ${echec.message}'),
      backgroundColor: scheme.error,
    ),
  );
}

/// Date lisible, pour une pastille ou un bouton de sélection.
String dateCourte(DateTime date) {
  final local = date.toLocal();
  String deux(int v) => v.toString().padLeft(2, '0');
  return '${deux(local.day)}/${deux(local.month)}/${local.year} ${deux(local.hour)}:${deux(local.minute)}';
}
