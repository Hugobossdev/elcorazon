import 'package:flutter/foundation.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/models/menu_item.dart';

/// Service amélioré pour le panier avec suggestions intelligentes
class EnhancedCartService {
  final CartService _cartService = CartService();
  final AppService _appService = AppService();

  /// Obtient des suggestions basées sur le contenu du panier
  Future<List<MenuItem>> getCartSuggestions({
    int limit = 3,
  }) async {
    try {
      final cartItems = _cartService.items;
      
      if (cartItems.isEmpty) {
        // Si le panier est vide, suggérer des plats populaires
        return await _getPopularItems(limit: limit);
      }

      // Analyser les catégories dans le panier
      final allMenuItems = _appService.menuItems;
      final categoryIds = cartItems
          .map((item) {
            final menuItem = allMenuItems.firstWhere(
              (mi) => mi.id == item.menuItemId,
              orElse: () => MenuItem(
                id: item.menuItemId,
                name: item.name,
                description: item.name,
                price: item.price,
                categoryId: '',
              ),
            );
            return menuItem.categoryId;
          })
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      // Obtenir des suggestions de la même catégorie
      final suggestions = await _getCategorySuggestions(
        categoryIds: categoryIds,
        excludeItemIds: cartItems.map((item) => item.menuItemId).toList(),
        limit: limit,
      );

        // Si pas assez de suggestions, compléter avec des plats populaires
        if (suggestions.length < limit) {
          final popularItems = await _getPopularItems(
            limit: limit - suggestions.length,
            excludeItemIds: [
              ...cartItems.map((item) => item.menuItemId),
              ...suggestions.map((item) => item.id),
            ],
          );
          suggestions.addAll(popularItems);
        }

      return suggestions.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting cart suggestions: $e');
      return [];
    }
  }

  /// Obtient des plats populaires
  Future<List<MenuItem>> _getPopularItems({
    int limit = 5,
    List<String> excludeItemIds = const [],
  }) async {
    try {
      final allItems = _appService.menuItems;
      
      return allItems
          .where((item) => 
              item.isPopular && 
              !excludeItemIds.contains(item.id) &&
              item.isAvailable,)
          .take(limit)
          .toList();
    } catch (e) {
      debugPrint('Error getting popular items: $e');
      return [];
    }
  }

  /// Obtient des suggestions par catégorie
  Future<List<MenuItem>> _getCategorySuggestions({
    required List<String> categoryIds,
    List<String> excludeItemIds = const [],
    int limit = 5,
  }) async {
    try {
      final allItems = _appService.menuItems;
      
      return allItems
          .where((item) => 
              categoryIds.contains(item.categoryId) &&
              !excludeItemIds.contains(item.id) &&
              item.isAvailable,)
          .take(limit)
          .toList();
    } catch (e) {
      debugPrint('Error getting category suggestions: $e');
      return [];
    }
  }

  /// Vérifie si le panier peut bénéficier d'une promotion
  Future<Map<String, dynamic>?> checkPromotionEligibility() async {
    try {
      final subtotal = _cartService.subtotal;
      final itemCount = _cartService.itemCount;

      // Promotion: 10% de réduction pour commandes > 5000 FCFA
      if (subtotal >= 5000 && itemCount >= 2) {
        return {
          'type': 'discount',
          'discount': subtotal * 0.1,
          'message': 'Réduction de 10% appliquée !',
          'code': 'AUTO10',
        };
      }

      // Promotion: Livraison gratuite pour commandes > 10000 FCFA
      if (subtotal >= 10000) {
        return {
          'type': 'free_delivery',
          'discount': _cartService.deliveryFee,
          'message': 'Livraison gratuite !',
        };
      }

      return null;
    } catch (e) {
      debugPrint('Error checking promotion eligibility: $e');
      return null;
    }
  }

  /// Valide le panier avant checkout
  Future<Map<String, dynamic>> validateCart() async {
    final errors = <String>[];
    final warnings = <String>[];

    try {
      // Vérifier si le panier est vide
      if (_cartService.isEmpty) {
        errors.add('Votre panier est vide');
      }

      // Vérifier la disponibilité des items
      final allMenuItems = _appService.menuItems;
      for (final item in _cartService.items) {
        final menuItem = allMenuItems.firstWhere(
          (mi) => mi.id == item.menuItemId,
          orElse: () => MenuItem(
            id: item.menuItemId,
            name: item.name,
            description: item.name,
            price: item.price,
            categoryId: '',
          ),
        );

        if (!menuItem.isAvailable) {
          errors.add('${menuItem.name} n\'est plus disponible');
        }

        final availableQuantity = menuItem.availableQuantity;
        if (item.quantity > availableQuantity) {
          errors.add(
            'Quantité demandée pour ${menuItem.name} dépasse le stock disponible',
          );
        }
      }

      // Vérifier le montant minimum
      if (_cartService.subtotal < 1000) {
        warnings.add('Montant minimum de commande: 1000 FCFA');
      }

      // Vérifier les promotions disponibles
      final promotion = await checkPromotionEligibility();
      if (promotion != null) {
        warnings.add(promotion['message'] as String);
      }

      return {
        'isValid': errors.isEmpty,
        'errors': errors,
        'warnings': warnings,
        'promotion': promotion,
      };
    } catch (e) {
      debugPrint('Error validating cart: $e');
      return {
        'isValid': false,
        'errors': ['Erreur lors de la validation du panier'],
        'warnings': [],
        'promotion': null,
      };
    }
  }

  /// Obtient un résumé intelligent du panier
  Map<String, dynamic> getCartSummary() {
    final items = _cartService.items;
    final allMenuItems = _appService.menuItems;
    final categories = items
        .map((item) {
          final menuItem = allMenuItems.firstWhere(
            (mi) => mi.id == item.menuItemId,
            orElse: () => MenuItem(
              id: item.menuItemId,
              name: item.name,
              description: item.name,
              price: item.price,
              categoryId: '',
            ),
          );
          return menuItem.categoryId;
        })
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;

    return {
      'itemCount': _cartService.itemCount,
      'uniqueItems': items.length,
      'categories': categories,
      'subtotal': _cartService.subtotal,
      'deliveryFee': _cartService.deliveryFee,
      'discount': _cartService.discount,
      'total': _cartService.total,
      'estimatedTime': _estimatePreparationTime(),
    };
  }

  /// Estime le temps de préparation
  Duration _estimatePreparationTime() {
    final items = _cartService.items;
    if (items.isEmpty) return const Duration();

      final allMenuItems = _appService.menuItems;
      final prepTimes = items.map((item) {
        final menuItem = allMenuItems.firstWhere(
        (mi) => mi.id == item.menuItemId,
        orElse: () => MenuItem(
          id: item.menuItemId,
          name: item.name,
          description: item.name,
          price: item.price,
          categoryId: '',
        ),
      );
      return menuItem.preparationTime;
    }).toList();

    final maxPrepTime = prepTimes.reduce((a, b) => a > b ? a : b);

    // Ajouter 5 minutes par item supplémentaire
    final additionalTime = (items.length - 1) * 5;

    return Duration(minutes: maxPrepTime + additionalTime);
  }
}

