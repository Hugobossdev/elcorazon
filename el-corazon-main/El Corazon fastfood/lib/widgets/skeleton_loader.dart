import 'dart:async';

import 'package:flutter/material.dart';

/// Widget de skeleton loader pour améliorer l'UX pendant le chargement
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const SkeletonLoader({
    required this.width,
    required this.height,
    super.key,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    unawaited(_controller.repeat());

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = widget.baseColor ??
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
    final highlightColor = widget.highlightColor ??
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(-1.0 - _animation.value * 2, 0.0),
              end: Alignment(1.0 + _animation.value * 2, 0.0),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [
                0.0,
                0.5,
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton loader pour les cartes de menu
class MenuItemSkeleton extends StatelessWidget {
  const MenuItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            SkeletonLoader(
              width: 80,
              height: 80,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: double.infinity, height: 16),
                  SizedBox(height: 8),
                  SkeletonLoader(width: 150, height: 12),
                  SizedBox(height: 8),
                  SkeletonLoader(width: 100, height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader pour les listes
class ListSkeletonLoader extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const ListSkeletonLoader({
    required this.itemBuilder,
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}

/// Skeleton loader pour les grilles
class GridSkeletonLoader extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final double childAspectRatio;

  const GridSkeletonLoader({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.75,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return const Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SkeletonLoader(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(width: double.infinity, height: 14),
                    SizedBox(height: 8),
                    SkeletonLoader(width: 100, height: 12),
                    SizedBox(height: 8),
                    SkeletonLoader(width: 80, height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
