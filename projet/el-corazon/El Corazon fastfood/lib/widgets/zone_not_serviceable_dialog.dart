import 'package:flutter/material.dart';

/// Dialogue affiché quand aucune zone ne couvre l'adresse choisie.
///
/// Il annonçait auparavant une distance et un maximum — tous deux calculés sur
/// le téléphone, à vol d'oiseau, depuis une position de restaurant en dur. Le
/// serveur ne refuse pas sur une distance : il refuse parce qu'aucun contour
/// de zone ne couvre le point. Dire « 12,4 km, maximum 25 km » à un client
/// qu'on vient de refuser était une explication fausse d'un refus juste.
class ZoneNotServiceableDialog extends StatelessWidget {
  final VoidCallback? onChooseAnotherAddress;
  final VoidCallback? onViewServiceableZones;

  const ZoneNotServiceableDialog({
    super.key,
    this.onChooseAnotherAddress,
    this.onViewServiceableZones,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade700,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Zone Non Desservie',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Désolé, nous ne livrons pas encore à cette adresse.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Astuce : Choisissez une adresse plus proche du restaurant pour bénéficier de la livraison.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (onViewServiceableZones != null)
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onViewServiceableZones!();
            },
            icon: const Icon(Icons.map),
            label: const Text('Voir les zones'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed:
              onChooseAnotherAddress ?? () => Navigator.of(context).pop(),
          icon: const Icon(Icons.location_searching),
          label: const Text('Choisir une autre adresse'),
        ),
      ],
    );
  }

  /// Méthode statique pour afficher le dialog facilement
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onChooseAnotherAddress,
    VoidCallback? onViewServiceableZones,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ZoneNotServiceableDialog(
        onChooseAnotherAddress: onChooseAnotherAddress,
        onViewServiceableZones: onViewServiceableZones,
      ),
    );
  }
}
