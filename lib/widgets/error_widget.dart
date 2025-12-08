import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/error_handler_service.dart';

/// Widget pour afficher les erreurs de l'application
class AppErrorWidget extends StatelessWidget {
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final bool showDetails;

  const AppErrorWidget({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ErrorHandlerService>(
      builder: (context, errorHandler, child) {
        if (!errorHandler.hasErrors && message == null) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            border: Border.all(color: Colors.red.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title ?? 'Erreur',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (onRetry != null)
                    IconButton(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Réessayer',
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                message ?? _getLatestErrorMessage(errorHandler),
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 14,
                ),
              ),
              if (showDetails && errorHandler.hasErrors) ...[
                const SizedBox(height: 12),
                _buildErrorDetails(errorHandler),
              ],
            ],
          ),
        );
      },
    );
  }

  String _getLatestErrorMessage(ErrorHandlerService errorHandler) {
    if (errorHandler.errors.isEmpty) return 'Une erreur inattendue s\'est produite';
    
    final latestError = errorHandler.errors.last;
    return latestError.message;
  }

  Widget _buildErrorDetails(ErrorHandlerService errorHandler) {
    return ExpansionTile(
      title: const Text('Détails de l\'erreur'),
      children: errorHandler.errors.map((error) {
        return ListTile(
          title: Text(error.message),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (error.code != null) Text('Code: ${error.code}'),
              Text('Heure: ${_formatDateTime(error.timestamp)}'),
              if (error.details != null) Text('Détails: ${error.details}'),
            ],
          ),
          trailing: IconButton(
            onPressed: () => errorHandler.clearError(error.id),
            icon: const Icon(Icons.close),
            tooltip: 'Fermer cette erreur',
          ),
        );
      }).toList(),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Widget pour afficher un état d'erreur avec option de retry
class ErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData? icon;
  final String? retryText;

  const ErrorStateWidget({
    required this.message, super.key,
    this.onRetry,
    this.icon,
    this.retryText,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.error_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryText ?? 'Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget pour afficher les erreurs de réseau
class NetworkErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const NetworkErrorWidget({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorStateWidget(
      message: 'Problème de connexion réseau.\nVérifiez votre connexion internet.',
      onRetry: onRetry,
      icon: Icons.wifi_off,
      retryText: 'Réessayer',
    );
  }
}

/// Widget pour afficher les erreurs de chargement
class LoadingErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const LoadingErrorWidget({
    required this.message, super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorStateWidget(
      message: message,
      onRetry: onRetry,
      icon: Icons.cloud_off,
      retryText: 'Recharger',
    );
  }
}

