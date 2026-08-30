import 'package:flutter/material.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/navigation/app_router.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/widgets/design/design.dart';

/// Une commande, telle qu'elle se lit dans la liste « Mes commandes ».
///
/// ## Ce qui a changé avec le design Stitch
///
/// La carte portait un liseré de deux pixels de la couleur du statut, et cette
/// couleur venait de la palette **de Material** : orange, bleu, violet, vert,
/// rouge, gris — six teintes qui n'appartiennent à aucun jeton du design
/// system, et qui juraient toutes avec le blanc cassé chaud du fond.
///
/// `DESIGN.md` dit ce qu'il faut à la place : « Status Chips — small, 8px
/// radius chips for *Prep*, *On the way* and *Delivered*, using Tertiary and
/// Secondary colors to denote progress. » Le statut est donc une **puce**, la
/// carte redevient neutre, et la progression se lit dans la teinte de la puce
/// plutôt que dans un contour qui cerclait toute la commande de rouge dès
/// qu'un livreur s'en emparait.
class DeliveryStatusCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onTap;

  const DeliveryStatusCard({
    required this.order,
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final apparence = _AspectDuStatut.pour(order.status, theme);

    return SectionCard(
      margin: const EdgeInsets.only(bottom: DesignConstants.spacingM),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: DesignConstants.avatarSizeMedium,
                height: DesignConstants.avatarSizeMedium,
                decoration: BoxDecoration(
                  color: apparence.fond,
                  borderRadius: DesignConstants.borderRadiusMedium,
                ),
                child: Icon(
                  apparence.icone,
                  color: apparence.encre,
                  size: DesignConstants.iconSizeMedium,
                ),
              ),
              const SizedBox(width: DesignConstants.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commande ${_reference(order.id)}',
                      style: AppTypography.titleLg(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: DesignConstants.spacingXS),
                    StatusChip(
                      label: apparence.libelle,
                      background: apparence.fond,
                      foreground: apparence.encre,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DesignConstants.spacingS),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    PriceFormatter.format(order.total),
                    style: AppTypography.priceDisplay(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(order.createdAt),
                    style: AppTypography.bodyMd(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (order.deliveryAddress.isNotEmpty) ...[
            const SizedBox(height: DesignConstants.spacingM),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: DesignConstants.iconSizeSmall,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: DesignConstants.spacingS),
                Expanded(
                  child: Text(
                    order.deliveryAddress,
                    style: AppTypography.bodyMd(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_estEnLivraison(order.status)) ...[
            const SizedBox(height: DesignConstants.spacingS),
            _lienDeFin(
              context,
              label: 'Suivre la livraison',
              icon: Icons.navigation_rounded,
              onPressed: onTap,
            ),
          ] else if (order.status == OrderStatus.delivered) ...[
            const SizedBox(height: DesignConstants.spacingS),
            _lienDeFin(
              context,
              label: 'Évaluer la livraison',
              icon: Icons.star_outline_rounded,
              onPressed: () => Navigator.of(context).pushNamed(
                AppRouter.driverRating,
                arguments: {
                  'orderId': order.id,
                  'driverId': order.deliveryPersonId ?? '',
                  // Le nom du livreur n'est pas porté par `Order` : l'écran
                  // d'évaluation le complète depuis la course. Voir
                  // `docs/UI_REDESIGN_ISSUES.md`, ISSUE-006.
                  'driverName': null,
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _lienDeFin(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: ActionButton(
        label: label,
        emphasis: ActionEmphasis.text,
        trailingIcon: icon,
        expand: false,
        height: 40,
        onPressed: onPressed,
      ),
    );
  }

  /// Les huit premiers caractères de l'identifiant, précédés d'un dièse.
  ///
  /// `substring(0, 8)` levait sur un identifiant plus court — un cas rare mais
  /// qui faisait tomber toute la liste, pas seulement la ligne fautive.
  String _reference(String id) {
    if (id.isEmpty) return '#—';
    return '#${id.length <= 8 ? id : id.substring(0, 8)}'.toUpperCase();
  }

  bool _estEnLivraison(OrderStatus statut) =>
      statut == OrderStatus.pickedUp || statut == OrderStatus.onTheWay;

  String _formatDate(DateTime date) {
    final jour = date.day.toString().padLeft(2, '0');
    final mois = date.month.toString().padLeft(2, '0');
    return '$jour/$mois';
  }
}

/// La teinte, l'icône et le mot d'un statut — tous pris à la palette.
///
/// La progression va du neutre (en attente) au doré (pris en charge), puis à
/// l'orange de la tertiaire (en cuisine, en route), et se referme sur le vert
/// de `success` ou le rouge d'`error`. Aucune de ces teintes n'est inventée :
/// ce sont les rôles Material 3 du thème, plus les deux états — succès, erreur
/// — que `AppColors` ajoute pour les puces de commande.
class _AspectDuStatut {
  const _AspectDuStatut({
    required this.libelle,
    required this.icone,
    required this.fond,
    required this.encre,
  });

  final String libelle;
  final IconData icone;
  final Color fond;
  final Color encre;

  static _AspectDuStatut pour(OrderStatus statut, ThemeData theme) {
    final schema = theme.colorScheme;

    switch (statut) {
      case OrderStatus.pending:
        return _AspectDuStatut(
          libelle: 'En attente',
          icone: Icons.schedule_rounded,
          fond: schema.surfaceContainerHighest,
          encre: schema.onSurfaceVariant,
        );
      case OrderStatus.confirmed:
        return _AspectDuStatut(
          libelle: 'Confirmée',
          icone: Icons.check_circle_outline_rounded,
          fond: schema.secondaryContainer,
          encre: schema.onSecondaryContainer,
        );
      case OrderStatus.preparing:
        return _AspectDuStatut(
          libelle: 'En préparation',
          icone: Icons.local_fire_department_rounded,
          fond: schema.tertiaryContainer,
          encre: schema.onTertiaryContainer,
        );
      case OrderStatus.ready:
        return _AspectDuStatut(
          libelle: 'Prête',
          icone: Icons.inventory_2_outlined,
          fond: schema.secondaryContainer,
          encre: schema.onSecondaryContainer,
        );
      case OrderStatus.pickedUp:
        return _AspectDuStatut(
          libelle: 'Récupérée',
          icone: Icons.delivery_dining_rounded,
          fond: schema.tertiaryContainer,
          encre: schema.onTertiaryContainer,
        );
      case OrderStatus.onTheWay:
        return _AspectDuStatut(
          libelle: 'En route',
          icone: Icons.two_wheeler_rounded,
          fond: schema.primaryContainer,
          encre: schema.onPrimaryContainer,
        );
      case OrderStatus.delivered:
        return const _AspectDuStatut(
          libelle: 'Livrée',
          icone: Icons.task_alt_rounded,
          fond: AppColors.successLight,
          encre: AppColors.success,
        );
      case OrderStatus.cancelled:
        return _AspectDuStatut(
          libelle: 'Annulée',
          icone: Icons.cancel_outlined,
          fond: schema.errorContainer,
          encre: schema.onErrorContainer,
        );
      case OrderStatus.refunded:
        return _AspectDuStatut(
          libelle: 'Remboursée',
          icone: Icons.replay_rounded,
          fond: schema.surfaceContainerHighest,
          encre: schema.onSurfaceVariant,
        );
      case OrderStatus.failed:
        return _AspectDuStatut(
          libelle: 'Échouée',
          icone: Icons.error_outline_rounded,
          fond: schema.errorContainer,
          encre: schema.onErrorContainer,
        );
    }
  }
}
