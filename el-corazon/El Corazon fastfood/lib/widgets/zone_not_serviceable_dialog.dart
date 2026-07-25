import 'package:flutter/material.dart';
import 'package:elcora_fast/models/delivery_fee_breakdown.dart';
import 'package:elcora_fast/config/delivery_config.dart';

/// Dialog affiché lorsqu'une zone n'est pas desservie
class ZoneNotServiceableDialog extends StatelessWidget {
  final DeliveryFeeBreakdown breakdown;
  final VoidCallback? onChooseAnotherAddress;
  final VoidCallback? onViewServiceableZones;

  const ZoneNotServiceableDialog({
    required this.breakdown,
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
            DeliveryConfig.notServiceableMessage,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  context,
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: '${breakdown.distance.toStringAsFixed(1)} km',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  context,
                  icon: Icons.location_on,
                  label: 'Distance maximale',
                  value: '${DeliveryConfig.maxDeliveryDistance.toInt()} km',
                  valueColor: Colors.red,
                ),
              ],
            ),
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

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
        ),
      ],
    );
  }

  /// Méthode statique pour afficher le dialog facilement
  static Future<void> show(
    BuildContext context, {
    required DeliveryFeeBreakdown breakdown,
    VoidCallback? onChooseAnotherAddress,
    VoidCallback? onViewServiceableZones,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ZoneNotServiceableDialog(
        breakdown: breakdown,
        onChooseAnotherAddress: onChooseAnotherAddress,
        onViewServiceableZones: onViewServiceableZones,
      ),
    );
  }
}
