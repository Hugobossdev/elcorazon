import 'package:flutter/material.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/services/enhanced_cart_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/services/cart_service.dart';

/// Widget pour afficher les suggestions intelligentes du panier
class CartSuggestionsWidget extends StatefulWidget {
  final int limit;

  const CartSuggestionsWidget({
    super.key,
    this.limit = 3,
  });

  @override
  State<CartSuggestionsWidget> createState() => _CartSuggestionsWidgetState();
}

class _CartSuggestionsWidgetState extends State<CartSuggestionsWidget> {
  final EnhancedCartService _cartService = EnhancedCartService();
  List<MenuItem> _suggestions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _isLoading = true);
    
    try {
      final suggestions = await _cartService.getCartSuggestions(
        limit: widget.limit,
      );
      
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Suggestions pour vous',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final item = _suggestions[index];
                return _buildSuggestionCard(context, item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(BuildContext context, MenuItem item) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () {
            // Ajouter au panier directement depuis les suggestions
            final cartService = CartService();
            cartService.addItem(item);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${item.name} ajouté au panier'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Image.network(
                  item.imageUrl ?? '',
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 100,
                      color: AppColors.surface,
                      child: const Icon(Icons.restaurant, size: 40),
                    );
                  },
                ),
              ),
              // Contenu
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.price} FCFA',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

