import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/connectivity_service.dart';

/// Widget pour afficher l'indicateur de statut de connexion
class OfflineIndicator extends StatelessWidget {
  final bool showWhenOnline;
  final Color? backgroundColor;
  final Color? textColor;
  final EdgeInsetsGeometry? padding;
  final double? height;

  const OfflineIndicator({
    super.key,
    this.showWhenOnline = false,
    this.backgroundColor,
    this.textColor,
    this.padding,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivityService, child) {
        final isOnline = connectivityService.isOnline;

        // Ne pas afficher si en ligne et showWhenOnline est false
        if (isOnline && !showWhenOnline) {
          return const SizedBox.shrink();
        }

        // Déterminer les couleurs
        final bgColor = backgroundColor ??
            (isOnline ? Colors.green.shade700 : Colors.orange.shade700);
        final txtColor = textColor ?? Colors.white;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: height ?? 40,
          color: bgColor,
          child: SafeArea(
            bottom: false,
            child: Container(
              padding: padding ??
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Icon(
                          isOnline ? Icons.wifi : Icons.wifi_off,
                          color: txtColor,
                          size: 20,
                        ),
                      );
                    },
                  ),
                  if (!isOnline) ...[
                    const SizedBox(width: 8),
                    Consumer<ConnectivityService>(
                      builder: (context, service, child) {
                        final pendingCount =
                            _getPendingOperationsCount(context);
                        if (pendingCount > 0) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$pendingCount',
                              style: TextStyle(
                                color: txtColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Obtient le nombre d'opérations en attente
  int _getPendingOperationsCount(BuildContext context) {
    try {
      // Essayer d'obtenir le nombre depuis OfflineSyncService si disponible
      // Cette partie peut être étendue selon les besoins
      return 0; // Par défaut, retourner 0
    } catch (e) {
      return 0;
    }
  }
}

/// Widget pour afficher une bannière de statut de connexion en bas de l'écran
class OfflineBanner extends StatelessWidget {
  final Color? backgroundColor;
  final Color? textColor;
  final bool dismissible;

  const OfflineBanner({
    super.key,
    this.backgroundColor,
    this.textColor,
    this.dismissible = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivityService, child) {
        final isOnline = connectivityService.isOnline;

        // Ne pas afficher si en ligne
        if (isOnline) {
          return const SizedBox.shrink();
        }

        final bgColor = backgroundColor ?? Colors.orange.shade700;
        final txtColor = textColor ?? Colors.white;

        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Material(
              elevation: 8,
              color: bgColor,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi_off,
                      color: txtColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Mode hors ligne',
                            style: TextStyle(
                              color: txtColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Synchronisation en attente',
                            style: TextStyle(
                              color: txtColor.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (dismissible)
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: txtColor,
                          size: 20,
                        ),
                        onPressed: () {
                          // Optionnel : masquer temporairement
                        },
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
}

/// Widget pour afficher le statut de connexion dans l'AppBar
class ConnectivityStatusIcon extends StatelessWidget {
  final Color? onlineColor;
  final Color? offlineColor;
  final double? size;

  const ConnectivityStatusIcon({
    super.key,
    this.onlineColor,
    this.offlineColor,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivityService, child) {
        final isOnline = connectivityService.isOnline;
        final iconSize = size ?? 20;

        return Tooltip(
          message: isOnline
              ? 'En ligne - ${connectivityService.getConnectionTypeDescription()}'
              : 'Hors ligne - Mode offline',
          child: Icon(
            isOnline ? Icons.cloud_done : Icons.cloud_off,
            color: isOnline
                ? (onlineColor ?? Colors.green)
                : (offlineColor ?? Colors.orange),
            size: iconSize,
          ),
        );
      },
    );
  }
}
