import 'package:flutter/material.dart';
import 'package:elcora_fast/models/promo_code.dart';

class PromoCodeDisplay extends StatelessWidget {
  final PromoCode promoCode;
  final double discountAmount;
  final bool isFreeDelivery;
  final VoidCallback? onRemove;

  const PromoCodeDisplay({
    required this.promoCode, required this.discountAmount, required this.isFreeDelivery, super.key,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_offer,
            color: Colors.green,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promoCode.code,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                ),
                Text(
                  promoCode.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (isFreeDelivery)
                  Text(
                    'Livraison gratuite appliquée',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                  )
                else if (discountAmount > 0)
                  Text(
                    'Réduction de ${discountAmount.toInt()} FCFA',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                  ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close),
              color: Colors.green,
            ),
        ],
      ),
    );
  }
}
