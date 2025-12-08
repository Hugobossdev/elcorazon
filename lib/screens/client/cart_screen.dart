import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/wallet_service.dart';
import 'package:elcora_fast/models/cart_item.dart' as cart_item;
import 'package:elcora_fast/models/promo_code.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
// import '../../widgets/enhanced_animations.dart'; // Supprimé
import 'package:elcora_fast/services/design_enhancement_service.dart';
import 'package:elcora_fast/utils/price_formatter.dart';

/// Écran de panier
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Mon Panier'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Consumer<CartService>(
            builder: (context, cartService, child) {
              if (cartService.itemCount > 0) {
                return IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: () => _showClearCartDialog(context),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<CartService>(
        builder: (context, cartService, child) {
          final cartItems = cartService.items;

          if (cartItems.isEmpty) {
            return _buildEmptyCart(context);
          }

          return Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // Liste des articles du panier
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final items = cartService.items;
                            if (index >= items.length) {
                              return const SizedBox.shrink();
                            }

                            final cartItem = items[index];
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                12,
                              ),
                              child: DesignEnhancementService
                                  .createEnhancedCartItemCard(
                                name: cartItem.name,
                                description: 'Plat délicieux',
                                price: cartItem.price,
                                imageUrl: cartItem.imageUrl,
                                quantity: cartItem.quantity,
                                onIncrement: () {
                                  cartService.incrementItemQuantity(
                                    cartItem.menuItemId,
                                  );
                                },
                                onDecrement: () {
                                  cartService.decrementItemQuantity(
                                    cartItem.menuItemId,
                                  );
                                },
                                onRemove: () {
                                  _showDeleteItemDialog(
                                    context,
                                    cartItem,
                                    index,
                                    cartService,
                                  );
                                },
                                animationDelay:
                                    Duration(milliseconds: index * 100),
                              ),
                            );
                          },
                          childCount: cartService.items.length,
                        ),
                      ),
                    ),
                    // Suggestions
                    SliverToBoxAdapter(
                      child: _buildSuggestions(context, cartService),
                    ),
                  ],
                ),
              ),
              _buildCartSummary(context, cartService),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 120,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'Votre panier est vide',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ajoutez des plats délicieux à votre panier',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          DesignEnhancementService.createEnhancedButton(
            text: 'Découvrir le menu',
            icon: Icons.restaurant_menu,
            onPressed: () {
              context.goBack();
            },
            backgroundColor: AppColors.primary,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummary(BuildContext context, CartService cartService) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ligne de séparation décorative
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Résumé des prix
          _buildPriceSummary(cartService),
          const SizedBox(height: 20),

          // VIP Free Meal Toggle
          Consumer<WalletService>(
            builder: (context, walletService, child) {
              if (walletService.isEligibleForFreeMeal) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Repas gratuit VIP',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[800],
                              ),
                            ),
                            Text(
                              cartService.isFreeMealApplied
                                  ? 'Appliqué sur l\'article le plus cher'
                                  : 'Utiliser votre repas gratuit mensuel',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber[900],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: cartService.isFreeMealApplied,
                        onChanged: (value) => cartService.toggleFreeMeal(),
                        activeColor: Colors.amber,
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Codes promo
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openPromoCodes(context, cartService),
              icon: const Icon(Icons.local_offer_outlined),
              label: Text(
                cartService.promoCode != null
                    ? 'Modifier le code promo'
                    : 'Ajouter un code promo',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side:
                    BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Bouton de commande
          DesignEnhancementService.createEnhancedButton(
            text: 'Commander maintenant',
            icon: Icons.shopping_bag,
            onPressed: () {
              context.navigateToCheckout();
            },
            backgroundColor: AppColors.primary,
            isFullWidth: true,
          ),
          const SizedBox(height: 12),

          // Bouton continuer les achats
          DesignEnhancementService.createEnhancedButton(
            text: 'Continuer les achats',
            onPressed: () {
              context.goBack();
            },
            backgroundColor: AppColors.surface,
            textColor: AppColors.primary,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSummary(CartService cartService) {
    final subtotal = cartService.subtotal;
    final deliveryFee = cartService.deliveryFee;
    final discount = cartService.discount;
    final total = cartService.total;

    return Column(
      children: [
        _buildPriceRow(
          'Sous-total (${cartService.itemCount} article${cartService.itemCount > 1 ? 's' : ''})',
          subtotal,
        ),
        const SizedBox(height: 8),
        _buildPriceRow('Livraison', deliveryFee),
        if (discount > 0) ...[
          const SizedBox(height: 8),
          _buildPriceRow(
            'Remise${cartService.promoCode != null ? ' (${cartService.promoCode})' : ''}',
            -discount,
            isDiscount: true,
          ),
        ],
        const Divider(height: 20),
        _buildPriceRow(
          'Total',
          total,
          isTotal: true,
        ),
      ],
    );
  }

  void _openPromoCodes(BuildContext context, CartService cartService) {
    context.navigateToPromoCodes(
      cartService.subtotal + cartService.deliveryFee,
      (PromoCode promoCode, double discount) {
        cartService.applyPromoDiscount(
          code: promoCode.code,
          discount: discount,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Code ${promoCode.code} appliqué: -${discount.toStringAsFixed(0)} FCFA',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      },
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isTotal = false,
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          isDiscount
              ? '-${PriceFormatter.format(amount)}'
              : PriceFormatter.format(amount),
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isDiscount
                ? AppColors.success
                : isTotal
                    ? AppColors.primary
                    : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestions(BuildContext context, CartService cartService) {
    return Consumer<AppService>(
      builder: (context, appService, child) {
        // Récupérer les produits populaires non déjà dans le panier
        final cartItemIds = cartService.items.map((e) => e.menuItemId).toSet();
        final suggestions = appService.menuItems
            .where(
              (item) =>
                  !cartItemIds.contains(item.id) &&
                  item.isPopular &&
                  item.isAvailable,
            )
            .take(5)
            .toList();

        if (suggestions.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: AppColors.primary),
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
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final item = suggestions[index];
                    return Container(
                      width: 160,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                            child: Container(
                              height: 100,
                              width: double.infinity,
                              color: Colors.grey[200],
                              child: item.imageUrl != null
                                  ? Image.network(
                                      item.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.restaurant,
                                        color: Colors.grey[400],
                                      ),
                                    )
                                  : Icon(
                                      Icons.restaurant,
                                      color: Colors.grey[400],
                                    ),
                            ),
                          ),
                          // Info
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        PriceFormatter.format(item.price),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          cartService.addItem(item);
                                          context.showSuccessMessage(
                                            '${item.name} ajouté !',
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.add,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteItemDialog(
    BuildContext context,
    cart_item.CartItem cartItem,
    int index,
    CartService cartService,
  ) {
    context.showEnhancedDialog(
      title: 'Supprimer l\'article',
      content:
          'Êtes-vous sûr de vouloir supprimer "${cartItem.name}" de votre panier ?',
      confirmText: 'Supprimer',
      cancelText: 'Annuler',
      isDestructive: true,
      onConfirm: () {
        cartService.removeItem(index);
        context.showSuccessMessage('${cartItem.name} retiré du panier');
      },
      onCancel: () {},
    );
  }

  void _showClearCartDialog(BuildContext context) {
    context.showEnhancedDialog(
      title: 'Vider le panier',
      content:
          'Êtes-vous sûr de vouloir supprimer tous les articles de votre panier ?',
      confirmText: 'Vider',
      cancelText: 'Annuler',
      isDestructive: true,
      onConfirm: () {
        Provider.of<CartService>(context, listen: false).clear();
        context.showSuccessMessage('Panier vidé');
      },
      onCancel: () {
        context.showSuccessMessage('Action annulée');
      },
    );
  }
}
