import 'package:flutter/material.dart';

/// Demande confirmation avant un geste qu'on ne défait pas d'un clic.
///
/// Rend `true` seulement si l'opérateur confirme ; fermer le dialogue, appuyer
/// sur Échap ou « Annuler » rendent `false`. Le bouton de confirmation porte le
/// verbe du geste ([action]) — « Supprimer », « Retirer » — et non « OK » :
/// on relit ce qu'on s'apprête à faire au moment de le faire.
Future<bool> confirmer(
  BuildContext context, {
  required String titre,
  required String message,
  String action = 'Supprimer',
}) async {
  final reponse = await showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(titre),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      );
    },
  );
  return reponse ?? false;
}
