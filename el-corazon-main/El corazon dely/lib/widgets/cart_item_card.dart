import 'package:flutter/material.dart';
import '../../models/menu_item.dart';

class CartItem {
  final MenuItem menuItem;
  int quantity;
  List<String> customizations;
  List<String>? specialInstructions;

  CartItem({
    required this.menuItem,
    this.quantity = 1,
    this.customizations = const [],
    this.specialInstructions,
  });

  double get totalPrice => menuItem.price * quantity;
}

class CartItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQuantityChanged;

  const CartItemCard({
    super.key,
    required this.item,
    required this.onRemove,
    required this.onQuantityChanged,
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Image
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: (item.menuItem.imageUrl?.isNotEmpty == true)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        item.menuItem.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.restaurant,
                            size: 24,
                            color: theme.colorScheme.onSurfaceVariant,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.restaurant,
                      size: 24,
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
                    item.menuItem.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Customizations
                  if (item.customizations.isNotEmpty) ...[
                    Text(
                      item.customizations.join(', '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Special instructions
                  if (item.specialInstructions != null &&
                      item.specialInstructions!.isNotEmpty) ...[
                    Text(
                      'Note: ${item.specialInstructions!.join(', ')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.primaryColor,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Price
                  Text(
                    '${item.menuItem.price.toStringAsFixed(0)} FCFA',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Quantity controls and remove
            Column(
              children: [
                // Remove button
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Quantity controls
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (item.quantity > 1) {
                            onQuantityChanged(item.quantity - 1);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.remove,
                            size: 16,
                            color: item.quantity > 1
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          item.quantity.toString(),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onQuantityChanged(item.quantity + 1),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.add,
                            size: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Total price
                Text(
                  '${item.totalPrice.toStringAsFixed(0)} FCFA',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CartSummary extends StatelessWidget {
  final List<CartItem> items;
  final double deliveryFee;
  final double discount;
  final double tax;

  const CartSummary({
    super.key,
    required this.items,
    this.deliveryFee = 0,
    this.discount = 0,
    this.tax = 0,
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.totalPrice);
  double get total => subtotal + deliveryFee + tax - discount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Résumé de la commande',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            // Subtotal
            _buildSummaryRow(
              'Sous-total',
              '${subtotal.toStringAsFixed(0)} FCFA',
              theme,
            ),

            // Delivery fee
            if (deliveryFee > 0)
              _buildSummaryRow(
                'Frais de livraison',
                '${deliveryFee.toStringAsFixed(0)} FCFA',
                theme,
              ),

            // Tax
            if (tax > 0)
              _buildSummaryRow(
                'TVA',
                '${tax.toStringAsFixed(0)} FCFA',
                theme,
              ),

            // Discount
            if (discount > 0)
              _buildSummaryRow(
                'Remise',
                '-${discount.toStringAsFixed(0)} FCFA',
                theme,
                color: Colors.green,
              ),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${total.toStringAsFixed(0)} FCFA',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, ThemeData theme,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color ?? theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
