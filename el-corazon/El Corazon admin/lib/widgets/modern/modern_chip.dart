import 'package:flutter/material.dart';

/// Chip moderne avec différentes variantes
class ModernChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool isSelected;
  final ModernChipVariant variant;

  const ModernChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.onTap,
    this.isSelected = false,
    this.variant = ModernChipVariant.default_,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.primary;

    Color backgroundColor;
    Color textColor;
    Color borderColor;

    switch (variant) {
      case ModernChipVariant.default_:
        backgroundColor = isSelected
            ? chipColor.withValues(alpha: 0.15)
            : theme.colorScheme.surfaceContainerHighest;
        textColor = isSelected ? chipColor : theme.colorScheme.onSurface;
        borderColor = isSelected
            ? chipColor.withValues(alpha: 0.5)
            : theme.colorScheme.outline.withValues(alpha: 0.1);
        break;
      case ModernChipVariant.filled:
        backgroundColor = chipColor;
        textColor = Colors.white;
        borderColor = chipColor;
        break;
      case ModernChipVariant.outlined:
        backgroundColor = Colors.transparent;
        textColor = chipColor;
        borderColor = chipColor;
        break;
    }

    Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            child: chip,
          ),
        ),
      );
    }

    return chip;
  }
}

enum ModernChipVariant { default_, filled, outlined }
