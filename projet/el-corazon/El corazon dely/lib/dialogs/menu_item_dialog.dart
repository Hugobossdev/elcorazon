import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/menu_item.dart';
import '../../services/cart_service.dart';
import '../../widgets/custom_button.dart';

class MenuItemDialog extends StatefulWidget {
  final MenuItem menuItem;

  const MenuItemDialog({
    super.key,
    required this.menuItem,
  });

  @override
  State<MenuItemDialog> createState() => _MenuItemDialogState();
}

class _MenuItemDialogState extends State<MenuItemDialog> {
  int _quantity = 1;
  final List<String> _selectedCustomizations = [];
  final TextEditingController _instructionsController = TextEditingController();

  // Sample customization options
  final Map<String, List<String>> _customizationOptions = {
    'Taille': ['Petit', 'Moyen', 'Grand'],
    'Extras': ['Fromage supplémentaire', 'Bacon', 'Avocat', 'Oignons'],
    'Sauce': ['Ketchup', 'Mayonnaise', 'Moutarde', 'Sauce piquante'],
    'Cuisson': ['Saignant', 'À point', 'Bien cuit'],
  };

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  void _addToCart() {
    final cartService = context.read<CartService>();

    cartService.addItem(
      widget.menuItem,
      quantity: _quantity,
      customization: _selectedCustomizations.isNotEmpty
          ? Map.fromEntries(
              _selectedCustomizations.map((e) => MapEntry(e, true)))
          : null,
    );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.menuItem.name} ajouté au panier'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Voir le panier',
          onPressed: () {
            // Navigate to cart
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalPrice = widget.menuItem.price * _quantity;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with image
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: Stack(
                children: [
                  // Image
                  if (widget.menuItem.imageUrl?.isNotEmpty == true)
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Image.network(
                        widget.menuItem.imageUrl!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderImage(theme);
                        },
                      ),
                    )
                  else
                    _buildPlaceholderImage(theme),

                  // Close button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                  // Price badge
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.menuItem.price.toStringAsFixed(0)} FCFA',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and description
                    Text(
                      widget.menuItem.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (widget.menuItem.description.isNotEmpty)
                      Text(
                        widget.menuItem.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Customizations
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Quantity selector
                            Text(
                              'Quantité',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildQuantitySelector(theme),

                            const SizedBox(height: 20),

                            // Customization options
                            ..._customizationOptions.entries.map(
                              (entry) => _buildCustomizationSection(
                                  entry.key, entry.value, theme),
                            ),

                            const SizedBox(height: 16),

                            // Special instructions
                            Text(
                              'Instructions spéciales',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _instructionsController,
                              decoration: InputDecoration(
                                hintText: 'Ajoutez vos préférences...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer with add to cart button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: CustomButton(
                text:
                    'Ajouter au panier - ${totalPrice.toStringAsFixed(0)} FCFA',
                onPressed: _addToCart,
                icon: Icons.add_shopping_cart,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.restaurant,
        size: 64,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildQuantitySelector(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: _quantity > 1
                ? () {
                    setState(() {
                      _quantity--;
                    });
                  }
                : null,
            icon: const Icon(Icons.remove),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _quantity.toString(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _quantity++;
              });
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomizationSection(
      String title, List<String> options, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = _selectedCustomizations.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    // For single selection categories like size or cooking level
                    if (title == 'Taille' || title == 'Cuisson') {
                      _selectedCustomizations.removeWhere(
                        (item) => options.contains(item),
                      );
                    }
                    _selectedCustomizations.add(option);
                  } else {
                    _selectedCustomizations.remove(option);
                  }
                });
              },
              selectedColor: theme.primaryColor.withValues(alpha: 0.2),
              checkmarkColor: theme.primaryColor,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// Helper function to show the dialog
Future<void> showMenuItemDialog(BuildContext context, MenuItem menuItem) {
  return showDialog(
    context: context,
    builder: (context) => MenuItemDialog(menuItem: menuItem),
  );
}
