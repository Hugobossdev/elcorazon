import 'package:flutter/material.dart';
import 'package:elcora_fast/models/address.dart';
import 'package:elcora_fast/widgets/delivery_fee_preview.dart';

/// Card moderne pour afficher une adresse avec expansion et actions
class AddressCard extends StatefulWidget {
  final Address address;
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
    this.isSelected = false,
    this.showDeliveryInfo = true,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onToggleFavorite,
    this.onSetDefault,
  });

  @override
  State<AddressCard> createState() => _AddressCardState();
}

class _AddressCardState extends State<AddressCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Color _getAddressTypeColor(AddressType type) {
    switch (type) {
      case AddressType.home:
        return Colors.green;
      case AddressType.work:
        return Colors.blue;
      case AddressType.other:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(widget.address.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) => _confirmDelete(context),
      onDismissed: (direction) => widget.onDelete?.call(),
      background: _buildDismissBackground(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isSelected
                ? theme.colorScheme.primary
                : Colors.grey.shade300,
            width: widget.isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: widget.isSelected ? 0.15 : 0.08),
              blurRadius: widget.isSelected ? 8 : 4,
              offset: Offset(0, widget.isSelected ? 4 : 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap ?? _toggleExpand,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(theme),
                  _buildAddressInfo(theme),
                  _buildStatusBadges(theme),
                  _buildExpandedContent(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Icône du type
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getAddressTypeColor(widget.address.type)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                widget.address.type.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Nom de l'adresse
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.address.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.address.isFavorite) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.star,
                        color: Colors.amber.shade600,
                        size: 18,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.address.type.displayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _getAddressTypeColor(widget.address.type),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Badges
          if (widget.address.isDefault)
            _buildBadge(
              'Défaut',
              Colors.green,
              theme,
            ),
          if (widget.isSelected)
            _buildBadge(
              'Sélectionnée',
              theme.colorScheme.primary,
              theme,
            ),

          // Menu
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 12),
                    Text('Modifier'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'favorite',
                child: Row(
                  children: [
                    Icon(
                      widget.address.isFavorite
                          ? Icons.star
                          : Icons.star_border,
                      size: 20,
                      color: Colors.amber.shade600,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.address.isFavorite
                          ? 'Retirer des favoris'
                          : 'Ajouter aux favoris',
                    ),
                  ],
                ),
              ),
              if (!widget.address.isDefault)
                const PopupMenuItem(
                  value: 'default',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 20),
                      SizedBox(width: 12),
                      Text('Définir par défaut'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Supprimer', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressInfo(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.address.fullAddress,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadges(ThemeData theme) {
    if (!widget.showDeliveryInfo) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: DeliveryFeePreview(
        address: widget.address,
        compact: !_isExpanded,
      ),
    );
  }

  Widget _buildExpandedContent(ThemeData theme) {
    return SizeTransition(
      sizeFactor: _expandAnimation,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 12),

            // Informations détaillées
            if (widget.address.latitude != null &&
                widget.address.longitude != null)
              _buildDetailRow(
                icon: Icons.gps_fixed,
                label: 'Coordonnées',
                value:
                    '${widget.address.latitude!.toStringAsFixed(5)}, ${widget.address.longitude!.toStringAsFixed(5)}',
                theme: theme,
              ),

            const SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.location_city,
              label: 'Ville',
              value: widget.address.city,
              theme: theme,
            ),

            if (widget.address.postalCode.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildDetailRow(
                icon: Icons.markunread_mailbox,
                label: 'Code postal',
                value: widget.address.postalCode,
                theme: theme,
              ),
            ],

            const SizedBox(height: 16),

            // Preview détaillé des frais
            if (widget.showDeliveryInfo)
              DeliveryFeePreview(
                address: widget.address,
              ),

            const SizedBox(height: 16),

            // Actions rapides
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildActionChip(
                  label: 'Modifier',
                  icon: Icons.edit,
                  onTap: widget.onEdit,
                  theme: theme,
                ),
                if (!widget.address.isDefault)
                  _buildActionChip(
                    label: 'Par défaut',
                    icon: Icons.check_circle,
                    onTap: widget.onSetDefault,
                    theme: theme,
                  ),
                _buildActionChip(
                  label: widget.address.isFavorite ? 'Favori ★' : 'Favori ☆',
                  icon: widget.address.isFavorite
                      ? Icons.star
                      : Icons.star_border,
                  onTap: widget.onToggleFavorite,
                  theme: theme,
                  color: Colors.amber.shade600,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionChip({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    required ThemeData theme,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: (color ?? theme.colorScheme.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (color ?? theme.colorScheme.primary).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: color ?? theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color ?? theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete, color: Colors.white, size: 32),
          SizedBox(height: 4),
          Text(
            'Supprimer',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer l\'adresse'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "${widget.address.name}" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        widget.onEdit?.call();
        break;
      case 'favorite':
        widget.onToggleFavorite?.call();
        break;
      case 'default':
        widget.onSetDefault?.call();
        break;
      case 'delete':
        widget.onDelete?.call();
        break;
    }
  }
}
