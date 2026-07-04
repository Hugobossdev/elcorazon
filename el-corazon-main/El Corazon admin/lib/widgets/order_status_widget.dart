import 'package:flutter/material.dart';
import '../models/order.dart';

class OrderStatusWidget extends StatelessWidget {
  final OrderStatus status;
  final bool showActions;
  final Function(OrderStatus)? onStatusChanged;
  final bool isCompact;

  const OrderStatusWidget({
    super.key,
    required this.status,
    this.showActions = false,
    this.onStatusChanged,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactStatus(context);
    } else {
      return _buildFullStatus(context);
    }
  }

  Widget _buildCompactStatus(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status.emoji,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullStatus(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                status.emoji,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              Text(
                status.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (showActions && onStatusChanged != null) ...[
          const SizedBox(height: 8),
          _buildStatusActions(context),
        ],
      ],
    );
  }

  Widget _buildStatusActions(BuildContext context) {
    final nextStatuses = status.nextPossibleStatuses;

    if (nextStatuses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: nextStatuses.map((nextStatus) {
        return Container(
          constraints: const BoxConstraints(
            minHeight: 36,
            minWidth: 80,
          ),
          child: ElevatedButton(
            onPressed: () => onStatusChanged!(nextStatus),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getStatusColor(context, nextStatus),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '→ ${nextStatus.displayName}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getStatusColor(BuildContext context, [OrderStatus? statusToCheck]) {
    final statusToUse = statusToCheck ?? status;
    final colorHex = statusToUse.colorHex;

    // Convertir hex en Color
    final colorValue = int.parse(colorHex.replaceAll('#', '0xFF'));
    return Color(colorValue);
  }
}

class OrderStatusChip extends StatelessWidget {
  final OrderStatus status;
  final VoidCallback? onTap;

  const OrderStatusChip({
    super.key,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: Utiliser Material + InkWell au lieu de GestureDetector
    // pour garantir que le hit testing se fait après le layout
    // Material garantit que le widget a une taille avant le hit test
    return Material(
      color: Colors.transparent,
      child: InkWell(
        // Callback appelé après que le widget soit complètement rendu
        onTap: onTap,
        // BorderRadius pour l'effet de splash
        borderRadius: BorderRadius.circular(16),
        child: Container(
          // Container garantit une taille définie avec padding et contraintes
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          constraints: const BoxConstraints(
            minHeight: 32,
            minWidth: 60,
          ),
          decoration: BoxDecoration(
            color: _getStatusColor(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _getStatusColor(context).withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            // mainAxisSize.min pour que la Row prenne seulement l'espace nécessaire
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                status.emoji,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 6),
              Text(
                status.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(BuildContext context) {
    final colorHex = status.colorHex;
    final colorValue = int.parse(colorHex.replaceAll('#', '0xFF'));
    return Color(colorValue);
  }
}

class OrderStatusTimeline extends StatelessWidget {
  final OrderStatus currentStatus;
  final List<OrderStatusUpdate> statusHistory;

  const OrderStatusTimeline({
    super.key,
    required this.currentStatus,
    required this.statusHistory,
  });

  @override
  Widget build(BuildContext context) {
    final allStatuses = [
      OrderStatus.pending,
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.pickedUp,
      OrderStatus.onTheWay,
      OrderStatus.delivered,
    ];

    return Column(
      children: allStatuses.map((status) {
        final isCompleted = _isStatusCompleted(status);
        final isCurrent = status == currentStatus;
        final isActive = status.isActive;

        return _buildTimelineItem(
          context,
          status,
          isCompleted,
          isCurrent,
          isActive,
        );
      }).toList(),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    OrderStatus status,
    bool isCompleted,
    bool isCurrent,
    bool isActive,
  ) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted || isCurrent
                ? _getStatusColor(context, status)
                : Colors.grey[300],
            border: Border.all(
              color: isCurrent
                  ? _getStatusColor(context, status)
                  : Colors.grey[400]!,
              width: 2,
            ),
          ),
          child: isCompleted || isCurrent
              ? Icon(
                  isCompleted ? Icons.check : Icons.radio_button_checked,
                  color: Colors.white,
                  size: 12,
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.displayName,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCompleted || isCurrent
                      ? _getStatusColor(context, status)
                      : Colors.grey[600],
                ),
              ),
              if (isCurrent && isActive)
                Text(
                  'En cours...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isStatusCompleted(OrderStatus status) {
    // Logique pour déterminer si un statut est complété
    // basée sur l'historique des statuts
    return statusHistory.any((update) => update.status == status);
  }

  Color _getStatusColor(BuildContext context, OrderStatus status) {
    final colorHex = status.colorHex;
    final colorValue = int.parse(colorHex.replaceAll('#', '0xFF'));
    return Color(colorValue);
  }
}
