import 'package:flutter/material.dart';
import 'package:elcora_fast/navigation/navigation_service.dart';
import 'package:elcora_fast/navigation/app_router.dart';
import 'package:elcora_fast/widgets/navigation_error_handler.dart';
import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/presentation/paiement_partage.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

/// Helper pour faciliter la navigation entre les écrans
class NavigationHelper {
  /// Naviguer vers le panier
  static Future<void> navigateToCart(BuildContext context) async {
    try {
      await NavigationService.pushNamedWithArgs(context, AppRouter.cart);
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors de la navigation vers le panier: $e',
        null,
      );
    }
  }

  /// Naviguer vers le menu
  static Future<void> navigateToMenu(BuildContext context) async {
    try {
      await NavigationService.pushNamedWithArgs(context, AppRouter.menu);
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors de la navigation vers le menu: $e',
        null,
      );
    }
  }

  /// Naviguer vers les commandes
  static Future<void> navigateToOrders(BuildContext context) async {
    try {
      await NavigationService.pushNamedWithArgs(context, AppRouter.orders);
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors de la navigation vers les commandes: $e',
        null,
      );
    }
  }

  /// Naviguer vers le profil
  static Future<void> navigateToProfile(BuildContext context) async {
    try {
      await NavigationService.pushNamedWithArgs(context, AppRouter.profile);
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors de la navigation vers le profil: $e',
        null,
      );
    }
  }

  /// Naviguer vers le checkout
  static Future<void> navigateToCheckout(
    BuildContext context, {
    String? existingOrderId,
    List<CartItem>? items,
    double? total,
  }) async {
    try {
      await NavigationService.pushNamedWithArgs(
        context,
        AppRouter.checkout,
        arguments: {
          'existingOrderId': existingOrderId,
          'items': items,
          'total': total,
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors de la navigation vers le checkout: $e',
        null,
      );
    }
  }

  /// Naviguer vers la personnalisation d'item
  static Future<void> navigateToItemCustomization(
    BuildContext context,
    dynamic item, {
    Function(eccore.MenuItem, int, Map<String, dynamic>)? onAddToCart,
  }) async {
    try {
      await NavigationService.pushNamedWithArgs(
        context,
        AppRouter.itemCustomization,
        arguments: {
          'item': item,
          'onAddToCart': onAddToCart,
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors de la navigation vers la personnalisation: $e',
        null,
      );
    }
  }

  /// Naviguer vers le suivi de livraison
  static Future<void> navigateToDeliveryTracking(
    BuildContext context,
    String orderId,
  ) async {
    // Valider l'ID avant la navigation
    if (orderId.isEmpty) {
      Journal.trace('⚠️ Cannot navigate to delivery tracking: orderId is empty');
      return;
    }
    try {
      await NavigationService.pushNamedWithArgs(
        context,
        AppRouter.deliveryTracking,
        arguments: {'orderId': orderId},
      );
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors de la navigation vers le suivi: $e',
        null,
      );
    }
  }

  /// Naviguer vers les récompenses
  static Future<void> navigateToRewards(BuildContext context) async {
    try {
      await NavigationService.pushNamedWithArgs(context, AppRouter.rewards);
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors de la navigation vers les récompenses: $e',
        null,
      );
    }
  }

  /// Naviguer vers la commande de gâteaux
  static Future<void> navigateToCakeOrder(BuildContext context) async {
    try {
      await NavigationService.pushNamedWithArgs(context, AppRouter.cakeOrder);
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors de la navigation vers les gâteaux personnalisés: $e',
        null,
      );
    }
  }

  /// Naviguer vers les notifications
  static Future<void> navigateToNotifications(BuildContext context) async {
    try {
      await NavigationService.pushNamedWithArgs(
        context,
        AppRouter.notifications,
      );
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors de la navigation vers les notifications: $e',
        null,
      );
    }
  }

  /// Naviguer vers la gestion des adresses
  static Future<void> navigateToAddressManagement(BuildContext context) async {
    try {
      await NavigationService.pushNamedWithArgs(
        context,
        AppRouter.addressManagement,
      );
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors de la navigation vers la gestion des adresses: $e',
        null,
      );
    }
  }

  /// Naviguer vers les commandes groupées
  static Future<void> navigateToGroupOrder(BuildContext context) async {
    try {
      await NavigationService.pushNamedWithArgs(context, AppRouter.groupOrder);
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors de la navigation vers les commandes groupées: $e',
        null,
      );
    }
  }

  /// Naviguer vers les détails de commande
  static Future<void> navigateToOrderDetails(
    BuildContext context,
    dynamic order,
  ) async {
    try {
      await NavigationService.pushNamedWithArgs(
        context,
        AppRouter.orderDetails,
        arguments: {'order': order},
      );
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors de la navigation vers les détails de commande: $e',
        null,
      );
    }
  }

  /// Naviguer vers le paiement
  static Future<void> navigateToPayment(
    BuildContext context, {
    required String orderId,
  }) async {
    try {
      await NavigationService.pushNamedWithArgs(
        context,
        AppRouter.payment,
        arguments: {'orderId': orderId},
      );
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors de la navigation vers le paiement: $e',
        null,
      );
    }
  }

  /// Naviguer vers les codes promo
  static Future<void> navigateToPromoCodes(
    BuildContext context,
    String? addressId,
    void Function(String code, double remise) onPromoCodeApplied,
  ) async {
    try {
      await NavigationService.pushNamedWithArgs(
        context,
        AppRouter.promoCodes,
        arguments: {
          'addressId': addressId,
          'onPromoCodeApplied': onPromoCodeApplied,
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors de la navigation vers les codes promo: $e',
        null,
      );
    }
  }

  /// Naviguer vers les avis produit
  static Future<void> navigateToProductReviews(
    BuildContext context,
    eccore.MenuItem menuItem,
  ) async {
    try {
      await NavigationService.pushNamedWithArgs(
        context,
        AppRouter.productReviews,
        arguments: {'menuItem': menuItem},
      );
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors de la navigation vers les avis: $e',
        null,
      );
    }
  }

  /// Naviguer vers le paiement partagé
  static Future<void> navigateToSharedPayment(
    BuildContext context, {
    required String groupId,
    required String orderId,
    required double totalAmount,
    required List<ConviveDuPartage> participants,
  }) async {
    try {
      await NavigationService.pushNamedWithArgs(
        context,
        AppRouter.sharedPayment,
        arguments: {
          'groupId': groupId,
          'orderId': orderId,
          'totalAmount': totalAmount,
          'participants': participants,
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors de la navigation vers le paiement partagé: $e',
        null,
      );
    }
  }

  /// Naviguer vers le statut de paiement groupé
  static Future<void> navigateToGroupPaymentStatus(
    BuildContext context, {
    required String groupId,
    required String orderId,
  }) async {
    try {
      await NavigationService.pushNamedWithArgs(
        context,
        AppRouter.groupPaymentStatus,
        arguments: {
          'groupId': groupId,
          'orderId': orderId,
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors de la navigation vers le statut de paiement: $e',
        null,
      );
    }
  }

  /// Retourner à l'écran précédent
  static void goBack(BuildContext context, [dynamic result]) {
    try {
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors du retour: $e',
        null,
      );
    }
  }

  /// Naviguer vers la recherche avancée
  static Future<void> navigateToAdvancedSearch(BuildContext context) async {
    try {
      await NavigationService.pushNamedWithArgs(
        context,
        AppRouter.advancedSearch,
      );
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors de la navigation vers la recherche avancée: $e',
        null,
      );
    }
  }

  /// Naviguer vers les commandes améliorées
  static Future<void> navigateToEnhancedOrders(BuildContext context) async {
    try {
      await NavigationService.pushNamedWithArgs(
        context,
        AppRouter.enhancedOrders,
      );
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors de la navigation vers les commandes améliorées: $e',
        null,
      );
    }
  }


  /// Retourner à l'accueil
  static Future<void> goToHome(BuildContext context, eccore.User? user) async {
    try {
      if (user != null) {
        NavigationService.navigateBasedOnRole(context, user);
      } else {
        NavigationService.navigateToAuth(context);
      }
    } catch (e) {
      if (!context.mounted) return;
      NavigationErrorHandler.handleNavigationError(
        context,
        'Erreur lors de la navigation vers l\'accueil: $e',
        user,
      );
    }
  }
}

/// Extension pour faciliter l'utilisation du NavigationHelper
extension NavigationHelperExtension on BuildContext {
  /// Naviguer vers le panier
  Future<void> navigateToCart() => NavigationHelper.navigateToCart(this);

  /// Naviguer vers le menu
  Future<void> navigateToMenu() => NavigationHelper.navigateToMenu(this);

  /// Naviguer vers les commandes
  Future<void> navigateToOrders() => NavigationHelper.navigateToOrders(this);

  /// Naviguer vers le profil
  Future<void> navigateToProfile() => NavigationHelper.navigateToProfile(this);

  /// Naviguer vers le checkout
  Future<void> navigateToCheckout({
    String? existingOrderId,
    List<CartItem>? items,
    double? total,
  }) =>
      NavigationHelper.navigateToCheckout(
        this,
        existingOrderId: existingOrderId,
        items: items,
        total: total,
      );

  /// Naviguer vers la personnalisation d'item
  Future<void> navigateToItemCustomization(
    dynamic item, {
    Function(eccore.MenuItem, int, Map<String, dynamic>)? onAddToCart,
  }) =>
      NavigationHelper.navigateToItemCustomization(
        this,
        item,
        onAddToCart: onAddToCart,
      );

  /// Naviguer vers le suivi de livraison
  Future<void> navigateToDeliveryTracking(String orderId) =>
      NavigationHelper.navigateToDeliveryTracking(this, orderId);

  /// Naviguer vers le portefeuille

  /// Naviguer vers les récompenses
  Future<void> navigateToRewards() => NavigationHelper.navigateToRewards(this);

  /// Naviguer vers les gâteaux personnalisés
  Future<void> navigateToCakeOrder() =>
      NavigationHelper.navigateToCakeOrder(this);

  /// Naviguer vers les notifications
  Future<void> navigateToNotifications() =>
      NavigationHelper.navigateToNotifications(this);

  /// Naviguer vers la gestion des adresses
  Future<void> navigateToAddressManagement() =>
      NavigationHelper.navigateToAddressManagement(this);

  /// Naviguer vers les commandes groupées
  Future<void> navigateToGroupOrder() =>
      NavigationHelper.navigateToGroupOrder(this);

  /// Naviguer vers les détails de commande
  Future<void> navigateToOrderDetails(dynamic order) =>
      NavigationHelper.navigateToOrderDetails(this, order);

  /// Naviguer vers le paiement
  Future<void> navigateToPayment({required String orderId}) =>
      NavigationHelper.navigateToPayment(this, orderId: orderId);

  /// Naviguer vers les codes promo
  Future<void> navigateToPromoCodes(
    String? addressId,
    void Function(String code, double remise) onPromoCodeApplied,
  ) =>
      NavigationHelper.navigateToPromoCodes(
        this,
        addressId,
        onPromoCodeApplied,
      );

  /// Naviguer vers les avis produit
  Future<void> navigateToProductReviews(eccore.MenuItem menuItem) =>
      NavigationHelper.navigateToProductReviews(this, menuItem);

  /// Naviguer vers le paiement partagé
  Future<void> navigateToSharedPayment({
    required String groupId,
    required String orderId,
    required double totalAmount,
    required List<ConviveDuPartage> participants,
  }) =>
      NavigationHelper.navigateToSharedPayment(
        this,
        groupId: groupId,
        orderId: orderId,
        totalAmount: totalAmount,
        participants: participants,
      );

  /// Naviguer vers le statut de paiement groupé
  Future<void> navigateToGroupPaymentStatus({
    required String groupId,
    required String orderId,
  }) =>
      NavigationHelper.navigateToGroupPaymentStatus(
        this,
        groupId: groupId,
        orderId: orderId,
      );

  /// Retourner à l'écran précédent
  void goBack([dynamic result]) => NavigationHelper.goBack(this, result);

  /// Naviguer vers la recherche avancée
  Future<void> navigateToAdvancedSearch() =>
      NavigationHelper.navigateToAdvancedSearch(this);

  /// Naviguer vers les commandes améliorées
  Future<void> navigateToEnhancedOrders() =>
      NavigationHelper.navigateToEnhancedOrders(this);

  /// Retourner à l'accueil
  Future<void> goToHome(eccore.User? user) => NavigationHelper.goToHome(this, user);
}
