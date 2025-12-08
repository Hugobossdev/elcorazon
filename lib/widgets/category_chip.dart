import 'package:flutter/material.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';

class CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const CategoryChip({
    required this.label, required this.isSelected, required this.onTap, super.key,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: DesignConstants.animationNormal,
        margin: const EdgeInsets.only(right: DesignConstants.spacingS),
        padding: const EdgeInsets.symmetric(
          horizontal: DesignConstants.spacingM,
          vertical: DesignConstants.spacingS,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: DesignConstants.borderRadiusXLarge,
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.textSecondary.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? DesignConstants.shadowMedium
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryGrid extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const CategoryGrid({
    required this.categories, required this.selectedCategory, required this.onCategorySelected, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        height: 50,
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return CategoryChip(
              label: category,
              isSelected: selectedCategory == category,
              onTap: () => onCategorySelected(category),
              icon: _getCategoryIcon(category),
            );
          },
        ),
      ),
    );
  }

  IconData? _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'tout':
      case 'all':
        return Icons.grid_view;
      case 'burgers':
        return Icons.lunch_dining;
      case 'pizzas':
        return Icons.local_pizza;
      case 'boissons':
      case 'drinks':
        return Icons.local_drink;
      case 'desserts':
        return Icons.cake;
      case 'entrées':
      case 'appetizers':
        return Icons.restaurant;
      case 'plats':
      case 'main':
        return Icons.dinner_dining;
      case 'salades':
      case 'salads':
        return Icons.eco;
      case 'sandwichs':
      case 'sandwiches':
        return Icons.fastfood;
      default:
        return Icons.category;
    }
  }
}

// FilterChip widget for custom styling

class FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  const FilterChip({
    required this.label, required this.isSelected, required this.onTap, super.key,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: chipColor,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : chipColor,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isSelected ? Colors.white : chipColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
