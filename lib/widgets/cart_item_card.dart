import 'package:flutter/material.dart';
import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/utils/price_formatter.dart';

class CartItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQuantityChanged;

  const CartItemCard({
    required this.item, required this.onRemove, required this.onQuantityChanged, super.key,
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
              child: (item.imageUrl?.isNotEmpty == true)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        item.imageUrl!,
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
                    item.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Customizations
                  if (item.customization != null &&
                      item.customization!.isNotEmpty) ...[
                    Text(
                      item.customization!.entries
                          .map((e) => '${e.key}: ${e.value}')
                          .join(', '),
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

                  // Price
                  Text(
                    PriceFormatter.format(item.price),
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
                  PriceFormatter.format(item.totalPrice),
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
    required this.items, super.key,
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
              PriceFormatter.format(subtotal),
              theme,
            ),

            // Delivery fee
            if (deliveryFee > 0)
              _buildSummaryRow(
                'Frais de livraison',
                PriceFormatter.format(deliveryFee),
                theme,
              ),

            // Tax
            if (tax > 0)
              _buildSummaryRow(
                'TVA',
                PriceFormatter.format(tax),
                theme,
              ),

            // Discount
            if (discount > 0)
              _buildSummaryRow(
                'Remise',
                '-${PriceFormatter.format(discount)}',
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
                  PriceFormatter.format(total),
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
      {Color? color,}) {
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
