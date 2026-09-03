import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:admin/services/notification_center_service.dart';
import 'package:admin/ui/admin_color_tokens.dart';

/// Centre de notifications du back-office.
///
/// ## Ce que cette boîte montrait
///
/// Elle **recomposait** ses lignes à chaque ouverture à partir de la liste de
/// commandes déjà à l'écran : « N commandes en attente », puis les trois
/// dernières commandes présentées comme des « nouvelles commandes ». Ce
/// n'étaient pas des événements mais une seconde lecture de l'état courant, et
/// cela se voyait : rien n'apparaissait tant que l'écran n'avait pas rechargé,
/// une annulation de la nuit ne laissait aucune trace, et « lu » n'existait
/// pas — la liste revenait identique à chaque fois. Les deux entrées portaient
/// d'ailleurs un `action` vide, avec un chevron qui promettait une destination.
///
/// Elle lit désormais `/api/v1/notifications/`, que le serveur produit depuis
/// toujours et que le back-office était la seule des trois applications à
/// ignorer. Le tri, la persistance et surtout **le filtrage des destinataires**
/// viennent de là : chacun ne voit que ce qui concerne son établissement et ses
/// permissions (`staff_to_alert`).
class NotificationsDialog extends StatefulWidget {
  const NotificationsDialog({super.key});

  @override
  State<NotificationsDialog> createState() => _NotificationsDialogState();
}

class _NotificationsDialogState extends State<NotificationsDialog> {
  @override
  void initState() {
    super.initState();
    // Après la première frame : `context.read` avant celle-ci lirait un arbre
    // de providers pas encore monté.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<NotificationCenterService>().refresh());
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.9).clamp(400.0, 600.0);
    final dialogHeight = (screenSize.height * 0.8).clamp(400.0, 700.0);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  // IMPORTANT: Material + InkWell + Container avec taille explicite pour éviter l'erreur de hit testing
                  Material(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.close,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Contenu - Liste des notifications
            Expanded(
              child: Consumer<NotificationCenterService>(
                builder: (context, centre, child) {
                  final notifications = centre.notifications;

                  if (centre.isLoading && notifications.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (centre.error != null && notifications.isEmpty) {
                    return _messageCentre(
                      context,
                      icone: Icons.cloud_off,
                      titre: 'Notifications indisponibles',
                      detail: centre.error!,
                      action: () => unawaited(centre.refresh()),
                    );
                  }

                  if (notifications.isEmpty) {
                    final scheme = Theme.of(context).colorScheme;
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off,
                            size: 64,
                            color:
                                scheme.onSurfaceVariant.withValues(alpha: 0.55),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune notification',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Vous serez notifié des nouvelles commandes et événements',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant
                                          .withValues(alpha: 0.8),
                                    ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _buildNotificationItem(context, notification);
                    },
                  );
                },
              ),
            ),
            // Footer avec actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                    ),
                    child: TextButton.icon(
                      onPressed: () => unawaited(
                        context.read<NotificationCenterService>().markAllRead(),
                      ),
                      icon: const Icon(Icons.done_all),
                      label: const Text('Tout marquer comme lu'),
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Fermer'),
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

  /// Un état vide ou en erreur, présenté de la même façon.
  Widget _messageCentre(
    BuildContext context, {
    required IconData icone,
    required String titre,
    required String detail,
    VoidCallback? action,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 64, color: scheme.onSurfaceVariant.withValues(alpha: 0.55)),
            const SizedBox(height: 16),
            Text(
              titre,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: action,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Apparence d'après le `kind` du serveur — la seule clé qui fasse foi.
  ///
  /// Les valeurs sont celles de `NotificationKind`. Un genre inconnu de cette
  /// version de l'application prend l'apparence neutre plutôt que de disparaître :
  /// une notification qu'on ne sait pas décorer se lit quand même.
  (IconData, Color) _apparence(BuildContext context, String kind) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = AdminColorTokens.semantic(scheme);
    return switch (kind) {
      'order_status' => (Icons.shopping_cart, tokens.info),
      'payment' => (Icons.credit_card_off, tokens.danger),
      'delivery_offer' => (Icons.delivery_dining, tokens.warning),
      'account' => (Icons.person, tokens.success),
      'marketing' => (Icons.campaign, scheme.primary),
      _ => (Icons.notifications, scheme.primary),
    };
  }

  Widget _buildNotificationItem(
    BuildContext context,
    eccore.AppNotification notification,
  ) {
    final timeAgo = _formatTimeAgo(notification.createdAt);
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = _apparence(context, notification.kind);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: notification.isRead ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        child: ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          title: Text(
            notification.title,
            style: TextStyle(
              // Le gras distingue le non-lu. C'est la seule chose que « lu »
              // change à l'écran, et c'est suffisant : masquer les lues
              // priverait de l'historique, qui est tout l'intérêt d'une
              // notification persistante.
              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
              fontSize: 14,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notification.body,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                timeAgo,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          trailing: notification.isRead
              ? null
              : Icon(Icons.circle, size: 10, color: color),
          onTap: () => unawaited(
            context.read<NotificationCenterService>().markRead(notification.id),
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }
}
