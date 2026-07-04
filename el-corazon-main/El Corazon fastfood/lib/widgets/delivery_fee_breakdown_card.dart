import 'package:flutter/material.dart';
import 'package:elcora_fast/models/delivery_fee_breakdown.dart';
import 'package:elcora_fast/utils/price_formatter.dart';

/// Widget affichant la décomposition détaillée des frais de livraison
class DeliveryFeeBreakdownCard extends StatelessWidget {
  final DeliveryFeeBreakdown breakdown;
  final bool showTitle;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const DeliveryFeeBreakdownCard({
    required this.breakdown,
    super.key,
    this.showTitle = true,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Si la livraison est gratuite
    if (breakdown.isFreeDelivery) {
      return _buildFreeDeliveryCard(context, theme);
    }

    // Si la zone n'est pas desservie
    if (!breakdown.isInServiceableZone) {
      return _buildNotServiceableCard(context, theme);
    }

    // Affichage normal avec décomposition
    return Card(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTitle) ...[
              Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Détails de Livraison',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.shade300),
              const SizedBox(height: 12),
            ],

            // Distance
            _buildInfoRow(
              context,
              icon: Icons.straighten,
              label: 'Distance',
              value: '${breakdown.distance.toStringAsFixed(1)} km',
              iconColor: Colors.blue,
            ),

            const SizedBox(height: 8),

            // Frais de base
            _buildFeeRow(
              context,
              label: 'Frais de base',
              amount: breakdown.baseFee,
            ),

            const SizedBox(height: 8),

            // Frais de distance
            _buildFeeRow(
              context,
              label:
                  'Distance (${breakdown.distance.toStringAsFixed(1)} × 200)',
              amount: breakdown.distanceFee,
            ),

            // Frais de zone si applicable
            if (breakdown.zoneFee > 0) ...[
              const SizedBox(height: 8),
              _buildFeeRow(
                context,
                label: 'Zone ${breakdown.zoneName ?? "spéciale"}',
                amount: breakdown.zoneFee,
              ),
            ],

            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade300),
            const SizedBox(height: 12),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  PriceFormatter.format(breakdown.totalFee),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),

            // Temps estimé
            if (breakdown.estimatedDeliveryTime != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                context,
                icon: Icons.schedule,
                label: 'Temps estimé',
                value: '~${breakdown.estimatedDeliveryTime} min',
                iconColor: Colors.orange,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFreeDeliveryCard(BuildContext context, ThemeData theme) {
    return Card(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.card_giftcard,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Livraison Gratuite ! 🎉',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    breakdown.freeDeliveryReason ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '0 FCFA',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotServiceableCard(BuildContext context, ThemeData theme) {
    return Card(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_amber,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zone Non Desservie',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Distance: ${breakdown.distance.toStringAsFixed(1)} km',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeRow(
    BuildContext context, {
    required String label,
    required double amount,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade700,
              ),
        ),
        Text(
          PriceFormatter.format(amount),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? iconColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: iconColor ?? Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
