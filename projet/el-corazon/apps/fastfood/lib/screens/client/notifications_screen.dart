import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/notification_database_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/presentation/genre_notification.dart';
import 'package:elcora_fast/services/design_enhancement_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcora_fast/widgets/loading_widget.dart' as etats;
import 'package:elcora_fast/navigation/app_router.dart';

/// Les notifications reçues, atteintes depuis la cloche de l'accueil.
///
/// ## Ce que la reprise Stitch change
///
/// L'écran portait une barre rouge, des puces de filtre dessinées à la main et
/// cinq couleurs de Material — vert, orange, bleu, gris, violet — pour
/// distinguer les genres. Aucune n'appartient à la palette El Corazón : sur le
/// blanc cassé chaud du fond, le bleu et le violet en particulier ne
/// ressemblaient à rien d'autre dans l'application.
///
/// Les genres gardent leur distinction, mais dans les rôles du thème : doré
/// pour les commandes, orange pour les livraisons, vert pour l'argent, neutre
/// pour le compte, rouge de marque pour les promotions.
///
/// ## Un filtre en moins
///
/// L'écran offrait un onglet « Non lues » **et** un interrupteur « Non lues
/// seulement ». Le second ne servait que sous le premier onglet, où il ne
/// changeait rien, et sous l'autre, où il le dupliquait. Les onglets suffisent.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  GenreNotification? _genreRetenu;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotifications());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    // Plus de garde sur l'utilisateur courant : la requête part avec le jeton
    // de session et le serveur cloisonne lui-même l'historique.
    await Provider.of<NotificationDatabaseService>(context, listen: false)
        .loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: GlassAppBar(
        title: 'Notifications',
        actions: [
          Consumer<NotificationDatabaseService>(
            builder: (context, service, child) {
              final nonLues = service.getUnreadNotifications().length;
              return GlassIconButton(
                icon: Icons.done_all_rounded,
                tooltip: 'Tout marquer comme lu',
                filled: false,
                badge: nonLues,
                // Rien à marquer : le geste reste sans effet, sans jouer la
                // confirmation. `GlassIconButton` n'accepte pas de rappel nul,
                // il ne peut donc pas se griser — la pastille de compte, elle,
                // disparaît, et dit déjà qu'il n'y a rien à faire.
                onPressed: nonLues == 0
                    ? () {}
                    : () {
                        service.markAllAsRead();
                        context.showSuccessMessage(
                          'Toutes les notifications sont marquées comme lues',
                        );
                      },
              );
            },
          ),
        ],
        bottom: SegmentedTabs(
          controller: _tabController,
          labels: const ['Toutes', 'Non lues'],
        ),
      ),
      body: Column(
        children: [
          _filtresParGenre(theme),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _liste(nonLuesSeulement: false),
                _liste(nonLuesSeulement: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filtresParGenre(ThemeData theme) {
    return SizedBox(
      height: 40 + DesignConstants.spacingM,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          DesignConstants.edgeMargin,
          0,
          DesignConstants.edgeMargin,
          DesignConstants.spacingM,
        ),
        children: [
          _puceDeFiltre(theme, null, 'Tous', Icons.notifications_none_rounded),
          for (final genre in GenreNotification.values) ...[
            const SizedBox(width: DesignConstants.spacingS),
            _puceDeFiltre(theme, genre, genre.libelle, _icone(genre)),
          ],
        ],
      ),
    );
  }

  Widget _puceDeFiltre(
    ThemeData theme,
    GenreNotification? genre,
    String libelle,
    IconData icone,
  ) {
    final retenu = _genreRetenu == genre;

    return InkWell(
      onTap: () => setState(() => _genreRetenu = retenu ? null : genre),
      borderRadius: BorderRadius.circular(DesignConstants.radiusXLarge),
      child: StatusChip(
        label: libelle,
        icon: icone,
        background:
            retenu ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHigh,
        foreground:
            retenu ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _liste({required bool nonLuesSeulement}) {
    return Consumer<NotificationDatabaseService>(
      builder: (context, service, child) {
        if (service.isLoading) {
          return const etats.PageLoadingWidget(
            message: 'Chargement des notifications…',
          );
        }

        // Le filtrage et le tri vivent dans `notificationsAAfficher` : c'est
        // là qu'est décrite la règle, et là qu'elle est éprouvée.
        final notifications = notificationsAAfficher(
          nonLuesSeulement
              ? service.getUnreadNotifications()
              : service.notifications,
          genre: _genreRetenu,
        );

        if (notifications.isEmpty) {
          return RefreshIndicator(
            onRefresh: _loadNotifications,
            child: LayoutBuilder(
              builder: (context, contraintes) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: contraintes.maxHeight),
                  child: etats.EmptyStateWidget(
                    title: nonLuesSeulement
                        ? 'Aucune notification non lue'
                        : 'Aucune notification',
                    message: nonLuesSeulement
                        ? 'Vous êtes à jour.'
                        : 'Vos alertes de commande et vos offres arriveront ici.',
                    icon: nonLuesSeulement
                        ? Icons.mark_email_read_outlined
                        : Icons.notifications_none_rounded,
                  ),
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadNotifications,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              DesignConstants.edgeMargin,
              0,
              DesignConstants.edgeMargin,
              DesignConstants.spacingXL,
            ),
            itemCount: notifications.length,
            itemBuilder: (context, index) =>
                _carte(notifications[index], service),
          ),
        );
      },
    );
  }

  Widget _carte(
    eccore.AppNotification notification,
    NotificationDatabaseService service,
  ) {
    final theme = Theme.of(context);
    final teintes = _teintesDuGenre(theme, notification.genre);

    return SectionCard(
      margin: const EdgeInsets.only(bottom: DesignConstants.spacingM),
      // Une notification lue s'efface d'un cran : elle reste consultable sans
      // réclamer l'attention que la nouvelle mérite.
      color: notification.isRead
          ? theme.colorScheme.surfaceContainerLow
          : theme.colorScheme.surfaceContainerLowest,
      onTap: () {
        if (!notification.isRead) service.markAsRead(notification.id);
        _navigateBasedOnNotification(notification);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: DesignConstants.avatarSizeMedium,
            height: DesignConstants.avatarSizeMedium,
            decoration: BoxDecoration(
              color: teintes.$1,
              borderRadius: DesignConstants.borderRadiusMedium,
            ),
            child: Icon(
              _icone(notification.genre),
              color: teintes.$2,
              size: DesignConstants.iconSizeMedium,
            ),
          ),
          const SizedBox(width: DesignConstants.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: AppTypography.titleLg(
                          color: theme.colorScheme.onSurface,
                        ).copyWith(
                          fontWeight: notification.isRead
                              ? FontWeight.w500
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: DesignConstants.spacingS),
                    Text(
                      _formatDateTime(notification.createdAt),
                      style: AppTypography.bodyMd(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignConstants.spacingXS),
                Text(
                  notification.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMd(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!notification.isRead) ...[
                  const SizedBox(height: DesignConstants.spacingS),
                  const StatusChip(
                    label: 'Nouveau',
                    icon: Icons.fiber_new_rounded,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _icone(GenreNotification genre) {
    switch (genre) {
      case GenreNotification.commande:
        return Icons.shopping_bag_outlined;
      case GenreNotification.livraison:
        return Icons.delivery_dining_rounded;
      case GenreNotification.paiement:
        return Icons.payments_outlined;
      case GenreNotification.compte:
        return Icons.person_outline_rounded;
      case GenreNotification.promotion:
        return Icons.local_offer_outlined;
    }
  }

  /// Fond et encre d'un genre — pris aux rôles du thème, jamais à la palette
  /// brute de Material.
  (Color, Color) _teintesDuGenre(ThemeData theme, GenreNotification genre) {
    switch (genre) {
      case GenreNotification.commande:
        return (
          theme.colorScheme.secondaryContainer,
          theme.colorScheme.onSecondaryContainer,
        );
      case GenreNotification.livraison:
        return (
          theme.colorScheme.tertiaryContainer,
          theme.colorScheme.onTertiaryContainer,
        );
      case GenreNotification.paiement:
        return (AppColors.successLight, AppColors.success);
      case GenreNotification.compte:
        return (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant,
        );
      case GenreNotification.promotion:
        return (
          theme.colorScheme.primaryContainer,
          theme.colorScheme.onPrimaryContainer,
        );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 0) return '${difference.inDays} j';
    if (difference.inHours > 0) return '${difference.inHours} h';
    if (difference.inMinutes > 0) return '${difference.inMinutes} min';
    return 'À l’instant';
  }

  /// Ouvre l'écran que la notification désigne.
  ///
  /// Deux choses empêchaient cette navigation d'aboutir, et aucune ne se
  /// voyait : la charge utile arrivait ici sous forme de `Map.toString()`, que
  /// `jsonDecode` refusait à chaque fois ; et la clé cherchée était `orderId`
  /// là où le serveur écrit `order`. Elle lit maintenant `data` directement.
  void _navigateBasedOnNotification(eccore.AppNotification notification) {
    final commande = notification.commandeVisee;

    switch (notification.genre) {
      case GenreNotification.commande:
      case GenreNotification.livraison:
        Navigator.of(context).pushNamed(
          commande == null ? AppRouter.orders : AppRouter.deliveryTracking,
          arguments: commande == null ? null : {'orderId': commande},
        );
      case GenreNotification.promotion:
        Navigator.of(context).pushNamed(AppRouter.menu);
      case GenreNotification.paiement:
      case GenreNotification.compte:
        // Rien à ouvrir : ces notifications se lisent, elles ne mènent pas
        // ailleurs.
        break;
    }
  }
}
