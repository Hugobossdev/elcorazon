import 'package:flutter/material.dart';
import '../../theme/modern_theme.dart';

/// AppBar moderne amélioré avec recherche et actions
class EnhancedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showSearch;
  final String? searchHint;
  final ValueChanged<String>? onSearchChanged;
  final String? searchQuery;

  const EnhancedAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showSearch = false,
    this.searchHint,
    this.onSearchChanged,
    this.searchQuery,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 20);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              if (leading != null) leading!,
              if (leading != null) const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (showSearch) ...[
                      const SizedBox(height: 8),
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.1,
                            ),
                          ),
                        ),
                        child: TextField(
                          onChanged: onSearchChanged,
                          controller: searchQuery != null
                              ? TextEditingController(text: searchQuery)
                              : null,
                          decoration: InputDecoration(
                            hintText: searchHint ?? 'Rechercher...',
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            suffixIcon:
                                searchQuery != null && searchQuery!.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear_rounded,
                                      size: 20,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                    onPressed: () => onSearchChanged?.call(''),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (actions != null) ...[const SizedBox(width: 16), ...actions!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge de notification moderne
class NotificationBadge extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const NotificationBadge({super.key, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: onTap,
          tooltip: '$count notifications',
        ),
        if (count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: ModernTheme.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
