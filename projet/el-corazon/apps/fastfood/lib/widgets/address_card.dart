import 'package:flutter/material.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/presentation/adresse.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/delivery_fee_preview.dart';
import 'package:elcora_fast/widgets/design/design.dart';

/// Une adresse du carnet, telle que la maquette `address_management` la pose.
///
/// ## Ce que la maquette montre
///
/// Une tuile d'icône teintée par le **type** (maison, travail, autre), le
/// libellé avec sa puce « Par défaut », l'adresse sur deux lignes, puis le
/// téléphone du destinataire et les consignes de livraison quand ils
/// existent — tous deux portés par `eccore.Address` et jusqu'ici jamais
/// montrés sur la carte. Un menu à droite pour les actions.
///
/// ## Ce qui a changé, et pourquoi
///
/// La version précédente était une carte **dépliante** : un `AnimationController`,
/// une `SizeTransition`, et derrière le pli les coordonnées GPS à cinq
/// décimales, la ville, le « code postal » — qui était en réalité `line2` — et
/// trois puces d'action. Cela faisait 591 lignes pour montrer, en deux gestes,
/// des informations qu'on ne relit jamais : personne ne vérifie une latitude
/// avant de se faire livrer.
///
/// Les actions passent dans un menu, comme la maquette le dessine. Le contenu
/// dépliant disparaît, à l'exception de l'aperçu des frais, qui lui répond à
/// une vraie question — « combien pour cette adresse ? ».
///
/// **L'API publique est inchangée** : les deux écrans qui l'utilisent
/// (`address_management_screen`, `address_selector_screen`) n'ont pas eu à
/// bouger.
class AddressCard extends StatelessWidget {
  final eccore.Address address;

  /// Le favori est une préférence d'appareil, tenue par `AddressService`.
  /// L'entité du socle ne le porte pas : la carte le reçoit.
  final bool isFavorite;

  final bool isSelected;
  final bool showDeliveryInfo;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onSetDefault;

  const AddressCard({
    required this.address,
    super.key,
    this.isFavorite = false,
    this.isSelected = false,
    this.showDeliveryInfo = true,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onToggleFavorite,
    this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = address.type;

    final carte = SectionCard(
      margin: const EdgeInsets.only(bottom: DesignConstants.spacingM),
      onTap: onTap,
      // La sélection se lit au liseré, pas à un fond teinté : sur une liste,
      // un fond coloré fait ressortir la carte au point qu'on ne lit plus les
      // autres.
      borderColor: isSelected ? theme.colorScheme.primary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tuileDeType(type),
              const SizedBox(width: DesignConstants.spacingM),
              Expanded(child: _intitule(theme, type)),
              if (_aDesActions) _menu(context),
            ],
          ),
          const SizedBox(height: DesignConstants.spacingS),
          _lignesDAdresse(theme),
          if (_complements(theme).isNotEmpty) ...[
            const SizedBox(height: DesignConstants.spacingS),
            ..._complements(theme),
          ],
          if (showDeliveryInfo) ...[
            const SizedBox(height: DesignConstants.spacingM),
            DeliveryFeePreview(address: address, compact: true),
          ],
        ],
      ),
    );

    if (onDelete == null) return carte;

    return Dismissible(
      key: ValueKey(address.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmerSuppression(context),
      onDismissed: (_) => onDelete?.call(),
      background: _fondDeSuppression(theme),
      child: carte,
    );
  }

  bool get _aDesActions =>
      onEdit != null || onDelete != null || onSetDefault != null ||
      onToggleFavorite != null;

  Widget _tuileDeType(TypeAdresse type) {
    return Container(
      width: DesignConstants.avatarSizeMedium,
      height: DesignConstants.avatarSizeMedium,
      decoration: BoxDecoration(
        color: type.fond,
        borderRadius: DesignConstants.borderRadiusMedium,
      ),
      child: Icon(
        type.icone,
        color: type.encre,
        size: DesignConstants.iconSizeMedium,
      ),
    );
  }

  Widget _intitule(ThemeData theme, TypeAdresse type) {
    final libelle = address.label.isEmpty ? type.libelle : address.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleLg(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (isFavorite) ...[
              const SizedBox(width: DesignConstants.spacingXS),
              const Icon(
                Icons.star_rounded,
                size: DesignConstants.iconSizeSmall,
                color: AppColors.secondary,
              ),
            ],
          ],
        ),
        if (address.isDefault) ...[
          const SizedBox(height: DesignConstants.spacingXS),
          const StatusChip(label: 'Par défaut', icon: Icons.check_rounded),
        ],
      ],
    );
  }

  Widget _lignesDAdresse(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          address.uneLigne,
          style: AppTypography.bodyMd(color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: 2),
        Text(
          address.villeOu('—'),
          style: AppTypography.bodyMd(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Téléphone et consignes : deux champs que `Address` porte depuis toujours
  /// et que la carte ne montrait pas. La maquette les place ici, et c'est le
  /// bon endroit — ce sont les deux choses qu'on relit avant de valider une
  /// livraison.
  List<Widget> _complements(ThemeData theme) {
    Widget ligne(IconData icone, String texte) {
      return Padding(
        padding: const EdgeInsets.only(top: DesignConstants.spacingXS),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icone,
              size: DesignConstants.iconSizeSmall,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: DesignConstants.spacingS),
            Expanded(
              child: Text(
                texte,
                style: AppTypography.bodyMd(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return [
      if (address.recipientPhone.isNotEmpty)
        ligne(Icons.call_outlined, address.recipientPhone),
      if (address.deliveryInstructions.isNotEmpty)
        ligne(
          Icons.integration_instructions_outlined,
          address.deliveryInstructions,
        ),
    ];
  }

  Widget _menu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      tooltip: 'Actions sur cette adresse',
      onSelected: (valeur) {
        switch (valeur) {
          case 'edit':
            onEdit?.call();
          case 'default':
            onSetDefault?.call();
          case 'favorite':
            onToggleFavorite?.call();
          case 'delete':
            _confirmerSuppression(context).then((confirme) {
              if (confirme ?? false) onDelete?.call();
            });
        }
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Modifier'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        // Une adresse déjà par défaut n'a pas à proposer de le devenir.
        if (onSetDefault != null && !address.isDefault)
          const PopupMenuItem(
            value: 'default',
            child: ListTile(
              leading: Icon(Icons.check_circle_outline),
              title: Text('Définir par défaut'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (onToggleFavorite != null)
          PopupMenuItem(
            value: 'favorite',
            child: ListTile(
              leading: Icon(
                isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              ),
              title: Text(isFavorite ? 'Retirer des favoris' : 'Mettre en favori'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text('Supprimer'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  Widget _fondDeSuppression(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: DesignConstants.spacingM),
      padding: const EdgeInsets.symmetric(
        horizontal: DesignConstants.spacingL,
      ),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: DesignConstants.borderRadiusLarge,
      ),
      child: Icon(
        Icons.delete_outline_rounded,
        color: theme.colorScheme.onErrorContainer,
      ),
    );
  }

  /// Une suppression se confirme, et le message nomme l'adresse.
  ///
  /// « Voulez-vous supprimer cette adresse ? » sur une liste de cinq laisse
  /// douter de laquelle il s'agit — surtout après un balayage, geste qu'on
  /// déclenche parfois sans le vouloir.
  Future<bool?> _confirmerSuppression(BuildContext context) {
    final libelle =
        address.label.isEmpty ? address.type.libelle : address.label;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l’adresse'),
        content: Text('« $libelle » sera retirée de votre carnet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
