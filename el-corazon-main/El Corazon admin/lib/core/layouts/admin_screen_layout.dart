import 'package:flutter/material.dart';
import '../constants/admin_constants.dart';

/// Layout de base pour tous les écrans admin
/// Garantit des contraintes de taille appropriées
class AdminScreenLayout extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showAppBar;

  const AdminScreenLayout({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.showAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar && title != null
          ? AppBar(
              title: Text(title!),
              actions: actions,
              elevation: 0,
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SafeArea(
            child: Container(
              width: double.infinity,
              height: constraints.maxHeight,
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
                minWidth: constraints.maxWidth,
              ),
              child: child,
            ),
          );
        },
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Container avec scroll pour les écrans admin
class AdminScrollableContent extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Future<void> Function()? onRefresh;

  const AdminScrollableContent({
    super.key,
    required this.child,
    this.padding,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = SingleChildScrollView(
      padding: padding ?? const EdgeInsets.all(AdminConstants.spacingMD),
      physics: const AlwaysScrollableScrollPhysics(),
      child: child,
    );

    if (onRefresh != null) {
      return RefreshIndicator(
        onRefresh: onRefresh!,
        child: content,
      );
    }

    return content;
  }
}

/// Grid layout responsive pour les écrans admin
class AdminResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int crossAxisCountMobile;
  final int crossAxisCountTablet;
  final int crossAxisCountDesktop;
  final double childAspectRatio;
  final double spacing;

  const AdminResponsiveGrid({
    super.key,
    required this.children,
    this.crossAxisCountMobile = 1,
    this.crossAxisCountTablet = 2,
    this.crossAxisCountDesktop = 3,
    this.childAspectRatio = 1.2,
    this.spacing = AdminConstants.spacingMD,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        if (constraints.maxWidth < 600) {
          crossAxisCount = crossAxisCountMobile;
        } else if (constraints.maxWidth < 1200) {
          crossAxisCount = crossAxisCountTablet;
        } else {
          crossAxisCount = crossAxisCountDesktop;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

/// Section avec titre pour organiser le contenu
class AdminSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  const AdminSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: padding ?? const EdgeInsets.symmetric(
            horizontal: AdminConstants.spacingMD,
            vertical: AdminConstants.spacingSM,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        child,
      ],
    );
  }
}




