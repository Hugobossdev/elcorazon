import 'package:flutter/material.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/presentation/frais_de_livraison.dart';
import 'package:elcora_fast/services/delivery_fee_service.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

/// Livre-t-on à cette adresse, et à quel barème ?
///
/// La question est posée au serveur (`/geography/zones/resolve/`), pas
/// résolue sur le téléphone. Ce qui est montré ici est le **forfait de base**
/// de la zone : dans une liste d'adresses, aucun panier n'est en jeu, et le
/// prix définitif dépend de la distance et du montant commandé. Le devis exact
/// vient à la commande.
class DeliveryFeePreview extends StatefulWidget {
  final eccore.Address address;
  final bool compact;

  const DeliveryFeePreview({
    required this.address,
    super.key,
    this.compact = false,
  });

  @override
  State<DeliveryFeePreview> createState() => _DeliveryFeePreviewState();
}

class _DeliveryFeePreviewState extends State<DeliveryFeePreview> {
  final DeliveryFeeService _deliveryFeeService = DeliveryFeeService();
  FraisDeLivraison? _cachedBreakdown;

  @override
  void initState() {
    super.initState();
    _loadBreakdown();
  }

  @override
  void didUpdateWidget(DeliveryFeePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address.id != widget.address.id) {
      _loadBreakdown();
    }
  }

  Future<void> _loadBreakdown() async {
    try {
      final breakdown = await _deliveryFeeService.breakdownForPoint(
        latitude: widget.address.latitude,
        longitude: widget.address.longitude,
      );

      if (mounted) {
        setState(() {
          _cachedBreakdown = breakdown;
        });
      }
    } catch (e) {
      // Serveur injoignable : la vignette reste sur son indicateur de
      // chargement plutôt que d'annoncer un prix qu'on ne connaît pas.
      Journal.trace('DeliveryFeePreview: barème indisponible — $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedBreakdown == null) {
      return _buildLoading();
    }

    final breakdown = _cachedBreakdown!;

    if (!breakdown.isInServiceableZone) {
      return _buildNotServiceable();
    }

    if (breakdown.isFreeDelivery) {
      return _buildFreeDelivery(breakdown);
    }

    return widget.compact
        ? _buildCompact(breakdown)
        : _buildExpanded(breakdown);
  }

  // L'état « Position GPS manquante » n'existe plus : une `eccore.Address` porte
  // toujours son point.

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

  Widget _buildNotServiceable() {
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
              'Hors zone de livraison',
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

  Widget _buildFreeDelivery(FraisDeLivraison breakdown) {
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

  Widget _buildCompact(FraisDeLivraison breakdown) {
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
          Icon(Icons.payments, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            'dès ${PriceFormatter.format(breakdown.totalFee)}',
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

  Widget _buildExpanded(FraisDeLivraison breakdown) {
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
          if (breakdown.zoneName != null) ...[
            _buildInfoRow(
              icon: Icons.map_outlined,
              label: 'Zone',
              value: breakdown.zoneName!,
              theme: theme,
            ),
            const SizedBox(height: 4),
          ],
          _buildInfoRow(
            icon: Icons.payments,
            label: 'Livraison à partir de',
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
