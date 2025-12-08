import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/alert_service.dart';

/// Widget pour afficher les messages d'alerte en haut de l'écran
class AlertBanner extends StatelessWidget {
  final bool dismissible;
  final EdgeInsets? margin;

  const AlertBanner({
    super.key,
    this.dismissible = true,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AlertService>(
      builder: (context, alertService, child) {
        if (!alertService.hasAlerts) {
          return const SizedBox.shrink();
        }

        final alert = alertService.alerts.first;
        final colors = _getColorsForType(alert.type);

        return Container(
          margin: margin ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors['background'],
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: colors['background']!.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: dismissible ? () => alertService.removeAlert(alert.id) : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      alert.icon,
                      color: colors['foreground'],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (alert.title.isNotEmpty) ...[
                            Text(
                              alert.title,
                              style: TextStyle(
                                color: colors['foreground'],
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            alert.message,
                            style: TextStyle(
                              color: colors['foreground'],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (dismissible)
                      IconButton(
                        onPressed: () => alertService.removeAlert(alert.id),
                        icon: Icon(
                          Icons.close,
                          color: colors['foreground'],
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Map<String, Color> _getColorsForType(AlertType type) {
    switch (type) {
      case AlertType.success:
        return {
          'background': Colors.green.shade600,
          'foreground': Colors.white,
        };
      case AlertType.error:
        return {
          'background': Colors.red.shade600,
          'foreground': Colors.white,
        };
      case AlertType.warning:
        return {
          'background': Colors.orange.shade600,
          'foreground': Colors.white,
        };
      case AlertType.info:
        return {
          'background': Colors.blue.shade600,
          'foreground': Colors.white,
        };
    }
  }
}

/// Widget pour afficher une liste de messages d'alerte
class AlertList extends StatelessWidget {
  final EdgeInsets? margin;
  final bool dismissible;

  const AlertList({
    super.key,
    this.margin,
    this.dismissible = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AlertService>(
      builder: (context, alertService, child) {
        if (!alertService.hasAlerts) {
          return const SizedBox.shrink();
        }

        return Column(
          children: alertService.alerts.map((alert) {
            return _AlertItem(
              alert: alert,
              dismissible: dismissible,
              margin: margin,
            );
          }).toList(),
        );
      },
    );
  }
}

class _AlertItem extends StatelessWidget {
  final AlertMessage alert;
  final bool dismissible;
  final EdgeInsets? margin;

  const _AlertItem({
    required this.alert,
    this.dismissible = true,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getColorsForType(alert.type);

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors['background'],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors['background']!.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: dismissible
              ? () => AlertService().removeAlert(alert.id)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  alert.icon,
                  color: colors['foreground'],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (alert.title.isNotEmpty) ...[
                        Text(
                          alert.title,
                          style: TextStyle(
                            color: colors['foreground'],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        alert.message,
                        style: TextStyle(
                          color: colors['foreground'],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (dismissible)
                  IconButton(
                    onPressed: () => AlertService().removeAlert(alert.id),
                    icon: Icon(
                      Icons.close,
                      color: colors['foreground'],
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, Color> _getColorsForType(AlertType type) {
    switch (type) {
      case AlertType.success:
        return {
          'background': Colors.green.shade600,
          'foreground': Colors.white,
        };
      case AlertType.error:
        return {
          'background': Colors.red.shade600,
          'foreground': Colors.white,
        };
      case AlertType.warning:
        return {
          'background': Colors.orange.shade600,
          'foreground': Colors.white,
        };
      case AlertType.info:
        return {
          'background': Colors.blue.shade600,
          'foreground': Colors.white,
        };
    }
  }
}

