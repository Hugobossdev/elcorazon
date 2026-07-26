import 'package:flutter/material.dart';
import 'package:elcora_fast/models/address.dart';
import 'package:elcora_fast/models/delivery_fee_breakdown.dart';
import 'package:elcora_fast/services/delivery_fee_service.dart';
import 'package:elcora_fast/utils/price_formatter.dart';

/// Widget pour prévisualiser les frais de livraison d'une adresse
class DeliveryFeePreview extends StatefulWidget {
  final Address address;
  final bool compact;
  final double orderSubtotal;
  final bool isVip;

  const DeliveryFeePreview({
    required this.address,
    super.key,
    this.compact = false,
    this.orderSubtotal = 0.0,
    this.isVip = false,
  });

  @override
  State<DeliveryFeePreview> createState() => _DeliveryFeePreviewState();
}

class _DeliveryFeePreviewState extends State<DeliveryFeePreview> {
  final DeliveryFeeService _deliveryFeeService = DeliveryFeeService();
  DeliveryFeeBreakdown? _cachedBreakdown;

  @override
  void initState() {
    super.initState();
    _loadBreakdown();
  }

  @override
  void didUpdateWidget(DeliveryFeePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address.id != widget.address.id ||
        oldWidget.orderSubtotal != widget.orderSubtotal) {
      _loadBreakdown();
    }
  }

  Future<void> _loadBreakdown() async {
    if (widget.address.latitude == null || widget.address.longitude == null) {
      return;
    }

    final breakdown =
        await _deliveryFeeService.calculateDetailedDeliveryFeeFromAddress(
      address: widget.address,
      orderSubtotal: widget.orderSubtotal,
      isVip: widget.isVip,
    );

    if (mounted) {
      setState(() {
        _cachedBreakdown = breakdown;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.address.latitude == null || widget.address.longitude == null) {
      return _buildNoCoordinates();
    }

    if (_cachedBreakdown == null) {
      return _buildLoading();
    }

    final breakdown = _cachedBreakdown!;

    if (!breakdown.isInServiceableZone) {
      return _buildNotServiceable(breakdown);
    }

    if (breakdown.isFreeDelivery) {
      return _buildFreeDelivery(breakdown);
    }

    return widget.compact
        ? _buildCompact(breakdown)
        : _buildExpanded(breakdown);
  }

  Widget _buildNoCoordinates() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 6),
          Text(
            'Position GPS manquante',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange.shade900,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'Calcul en cours...',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildNotServiceable(DeliveryFeeBreakdown breakdown) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cancel, size: 16, color: Colors.red.shade700),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Hors zone (${breakdown.distance.toStringAsFixed(1)} km)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeDelivery(DeliveryFeeBreakdown breakdown) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.card_giftcard, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 6),
          Text(
            'Livraison gratuite 🎉',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade900,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(DeliveryFeeBreakdown breakdown) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 6),
          Icon(Icons.straighten, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            '${breakdown.distance.toStringAsFixed(1)} km',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Icon(Icons.payments, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            PriceFormatter.format(breakdown.totalFee),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpanded(DeliveryFeeBreakdown breakdown) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Zone desservie',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            icon: Icons.straighten,
            label: 'Distance',
            value: '${breakdown.distance.toStringAsFixed(1)} km',
            theme: theme,
          ),
          const SizedBox(height: 4),
          _buildInfoRow(
            icon: Icons.payments,
            label: 'Frais de livraison',
            value: PriceFormatter.format(breakdown.totalFee),
            theme: theme,
            bold: true,
          ),
          if (breakdown.estimatedDeliveryTime != null) ...[
            const SizedBox(height: 4),
            _buildInfoRow(
              icon: Icons.schedule,
              label: 'Temps estimé',
              value: '~${breakdown.estimatedDeliveryTime} min',
              theme: theme,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    bool bold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: bold ? theme.colorScheme.primary : Colors.black87,
          ),
        ),
      ],
    );
  }
}
