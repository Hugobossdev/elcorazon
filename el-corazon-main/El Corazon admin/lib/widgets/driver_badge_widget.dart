import 'package:flutter/material.dart';
import '../../models/driver_badge.dart';

class DriverBadgeWidget extends StatelessWidget {
  final DriverBadge badge;
  final bool isEarned;

  const DriverBadgeWidget({
    super.key,
    required this.badge,
    this.isEarned = true,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: badge.description ?? badge.name,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isEarned
              ? Colors.amber.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEarned ? Colors.amber : Colors.grey.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge.iconUrl != null)
              Image.network(badge.iconUrl!, width: 40, height: 40)
            else
              Icon(
                Icons.emoji_events,
                size: 40,
                color: isEarned ? Colors.amber : Colors.grey,
              ),
            const SizedBox(height: 4),
            Text(
              badge.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isEarned ? Colors.black87 : Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (isEarned && badge.earnedAt != null)
              Text(
                'Obtenu le ${_formatDate(badge.earnedAt!)}',
                style: TextStyle(fontSize: 10, color: Colors.grey[700]),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
