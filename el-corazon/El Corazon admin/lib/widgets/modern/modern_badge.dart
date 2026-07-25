import 'package:flutter/material.dart';

/// Badge moderne pour afficher des notifications ou des compteurs
class ModernBadge extends StatelessWidget {
  final String? text;
  final int? count;
  final Color? color;
  final ModernBadgeSize size;
  final ModernBadgeVariant variant;
  final Widget? child;

  const ModernBadge({
    super.key,
    this.text,
    this.count,
    this.color,
    this.size = ModernBadgeSize.medium,
    this.variant = ModernBadgeVariant.filled,
    this.child,
  }) : assert(text != null || count != null || child != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor = color ?? theme.colorScheme.primary;
    final badgeSize = _getSize();
    final fontSize = _getFontSize();

    Widget content;
    
    if (child != null) {
      content = child!;
    } else if (count != null) {
      content = Text(
        count! > 99 ? '99+' : count.toString(),
        style: TextStyle(
          color: variant == ModernBadgeVariant.filled
              ? Colors.white
              : badgeColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      );
    } else {
      content = Text(
        text!,
        style: TextStyle(
          color: variant == ModernBadgeVariant.filled
              ? Colors.white
              : badgeColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size == ModernBadgeSize.small ? 6 : 8,
        vertical: size == ModernBadgeSize.small ? 2 : 4,
      ),
      constraints: BoxConstraints(
        minWidth: badgeSize,
        minHeight: badgeSize,
      ),
      decoration: BoxDecoration(
        color: variant == ModernBadgeVariant.filled
            ? badgeColor
            : badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(badgeSize / 2),
        border: variant == ModernBadgeVariant.outlined
            ? Border.all(color: badgeColor, width: 1.5)
            : null,
      ),
      alignment: Alignment.center,
      child: content,
    );
  }

  double _getSize() {
    switch (size) {
      case ModernBadgeSize.small:
        return 16;
      case ModernBadgeSize.medium:
        return 20;
      case ModernBadgeSize.large:
        return 24;
    }
  }

  double _getFontSize() {
    switch (size) {
      case ModernBadgeSize.small:
        return 10;
      case ModernBadgeSize.medium:
        return 12;
      case ModernBadgeSize.large:
        return 14;
    }
  }
}

enum ModernBadgeSize {
  small,
  medium,
  large,
}

enum ModernBadgeVariant {
  filled,
  outlined,
  transparent,
}



