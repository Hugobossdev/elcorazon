import 'package:flutter/material.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/navigation/app_router.dart';

class MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onTap;
  final VoidCallback? onAddToCart;
  final bool showAddButton;
  final int quantity;
  final bool isGridView;
  final VoidCallback? onReviewsTap;
  final VoidCallback? onFavoriteTap;
  final bool isFavorite;

  const MenuItemCard({
    required this.item, required this.onTap, super.key,
    this.onAddToCart,
    this.showAddButton = true,
    this.quantity = 0,
    this.isGridView = false,
    this.onReviewsTap,
    this.onFavoriteTap,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360 || screenHeight < 640;

    return Card(
      elevation: DesignConstants.elevationLow,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: DesignConstants.borderRadiusLarge,
      ),
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: DesignConstants.borderRadiusLarge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: DesignConstants.borderRadiusLarge.topLeft,
                      ),
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                    child: (item.imageUrl?.isNotEmpty == true)
                        ? Hero(
                            tag: item.id.isNotEmpty
                                ? 'menu_item_${item.id}'
                                : UniqueKey().toString(),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: Image.network(
                                item.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildPlaceholderImage(theme);
                                },
                              ),
                            ),
                          )
                        : _buildPlaceholderImage(theme),
                  ),
                ),

                // Content
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen
                          ? (isGridView ? 10 : 12)
                          : (isGridView ? 12 : 14),
                      vertical: isSmallScreen
                          ? (isGridView ? 10 : 12)
                          : (isGridView ? 12 : 14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title and description
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                                fontSize: isSmallScreen
                                    ? (isGridView ? 12 : 13)
                                    : (isGridView ? 13 : null),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: isSmallScreen ? 2 : 3),
                            if (item.description.isNotEmpty)
                              Text(
                                item.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: isSmallScreen
                                      ? (isGridView ? 9 : 10)
                                      : (isGridView ? 10 : 11),
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                                maxLines: isSmallScreen && isGridView ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (onReviewsTap != null || item.rating > 0)
                              Padding(
                                padding:
                                    EdgeInsets.only(top: isSmallScreen ? 3 : 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: onReviewsTap ??
                                          () {
                                            Navigator.of(context).pushNamed(
                                              AppRouter.productReviews,
                                              arguments: {'menuItem': item},
                                            );
                                          },
                                      child: Icon(
                                        Icons.star_outline,
                                        size: isSmallScreen
                                            ? (isGridView ? 10 : 12)
                                            : (isGridView ? 12 : 14),
                                        color: item.rating > 0
                                            ? Colors.amber
                                            : Colors.grey,
                                      ),
                                    ),
                                    if (item.rating > 0) ...[
                                      SizedBox(width: isSmallScreen ? 2 : 4),
                                      Text(
                                        item.rating.toStringAsFixed(1),
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          fontSize: isSmallScreen
                                              ? (isGridView ? 9 : 10)
                                              : (isGridView ? 10 : 11),
                                          color: Colors.amber,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                        SizedBox(
                            height: isSmallScreen
                                ? (isGridView ? 4 : 6)
                                : (isGridView ? 6 : 8),),
                        // Price and add button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                formatPrice(item.price),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isSmallScreen ? 13 : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (showAddButton)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (quantity > 0) ...[
                                    Container(
                                      decoration: BoxDecoration(
                                        color: theme.primaryColor,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: () {
                                              // Decrement quantity
                                            },
                                            icon: Icon(
                                              Icons.remove,
                                              color: Colors.white,
                                              size: isSmallScreen ? 14 : 16,
                                            ),
                                            constraints: BoxConstraints(
                                              minWidth: isSmallScreen ? 24 : 28,
                                              minHeight:
                                                  isSmallScreen ? 24 : 28,
                                            ),
                                            padding: EdgeInsets.zero,
                                          ),
                                          Text(
                                            quantity.toString(),
                                            style: theme.textTheme.labelLarge
                                                ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize:
                                                  isSmallScreen ? 12 : null,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: onAddToCart,
                                            icon: Icon(
                                              Icons.add,
                                              color: Colors.white,
                                              size: isSmallScreen ? 14 : 16,
                                            ),
                                            constraints: BoxConstraints(
                                              minWidth: isSmallScreen ? 24 : 28,
                                              minHeight:
                                                  isSmallScreen ? 24 : 28,
                                            ),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    IconButton(
                                      onPressed: onAddToCart,
                                      icon: Container(
                                        padding: EdgeInsets.all(
                                            isSmallScreen ? 5 : 6,),
                                        decoration: BoxDecoration(
                                          color: theme.primaryColor,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.add,
                                          color: Colors.white,
                                          size: isSmallScreen ? 14 : 16,
                                        ),
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: BoxConstraints(
                                        minWidth: isSmallScreen ? 32 : 36,
                                        minHeight: isSmallScreen ? 32 : 36,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bouton favori en overlay
          if (onFavoriteTap != null)
            Positioned(
              top: isSmallScreen ? 6 : 8,
              right: isSmallScreen ? 6 : 8,
              child: GestureDetector(
                onTap: onFavoriteTap,
                child: Container(
                  padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.grey,
                    size: isSmallScreen ? 18 : 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      child: Icon(
        Icons.restaurant,
        size: 48,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class MenuItemListCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onTap;
  final VoidCallback? onAddToCart;
  final int quantity;

  const MenuItemListCard({
    required this.item, required this.onTap, super.key,
    this.onAddToCart,
    this.quantity = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                child: (item.imageUrl?.isNotEmpty == true)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.restaurant,
                              size: 32,
                              color: theme.colorScheme.onSurfaceVariant,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.restaurant,
                        size: 32,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
              ),

              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (item.description.isNotEmpty)
                      Text(
                        item.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      formatPrice(item.price),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Add button
              if (quantity > 0) ...[
                Container(
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          // Decrement quantity
                        },
                        icon: const Icon(
                          Icons.remove,
                          color: Colors.white,
                          size: 18,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                      Text(
                        quantity.toString(),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: onAddToCart,
                        icon: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 18,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                IconButton(
                  onPressed: onAddToCart,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
