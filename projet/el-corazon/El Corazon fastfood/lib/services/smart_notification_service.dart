import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/services/push_notification_service.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/order_history_service.dart';
import 'package:elcora_fast/services/favorites_service.dart';
import 'package:elcora_fast/repositories/django_order_repository.dart';

/// Types de notifications intelligentes
enum SmartNotificationType {
  promotion, // Promotions personnalisées
  orderReminder, // Rappel de commande
  favoriteAvailable, // Article favori disponible
  newArrival, // Nouveaux articles
  orderStatus, // Statut de commande
  loyaltyReward, // Récompenses de fidélité
  abandonedCart, // Panier abandonné
}

/// Service de notifications push intelligentes avec personnalisation et segmentation
class SmartNotificationService extends ChangeNotifier {
  static final SmartNotificationService _instance =
      SmartNotificationService._internal();
  factory SmartNotificationService() => _instance;
  SmartNotificationService._internal();

  final PushNotificationService _pushNotificationService =
      PushNotificationService();
  final AppService _appService = AppService();

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialise le service de notifications intelligentes
  Future<void> initialize() async {
    if (_isInitialized) return;

    // S'assurer que le service de notifications push est initialisé
    if (!_pushNotificationService.isInitialized) {
      await _pushNotificationService.initialize();
    }

    _isInitialized = true;
    notifyListeners();
    debugPrint('✅ SmartNotificationService initialisé');
  }

  /// Envoie une notification personnalisée
  Future<void> sendPersonalizedNotification({
    required String userId,
    required SmartNotificationType type,
    Map<String, dynamic>? customData,
  }) async {
    try {
      // Analyser les préférences et l'historique de l'utilisateur
      final userPreferences = await _getUserPreferences(userId);
      final userHistory = await _getUserOrderHistory(userId);

      // Générer un message personnalisé
      final notificationContent = await _generatePersonalizedContent(
        userId: userId,
        type: type,
        userPreferences: userPreferences,
        userHistory: userHistory,
        customData: customData,
      );

      // Envoyer la notification via la méthode publique
      await _pushNotificationService.sendCustomNotification(
        title: notificationContent['title'] as String,
        body: notificationContent['body'] as String,
        payload: notificationContent['payload'] as String?,
        channelId: notificationContent['channelId'] as String? ?? 'marketing',
      );

      debugPrint(
        '✅ Notification personnalisée envoyée: ${notificationContent['title']}',
      );
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'envoi de notification personnalisée: $e');
    }
  }

  /// Génère le contenu personnalisé de la notification
  Future<Map<String, dynamic>> _generatePersonalizedContent({
    required String userId,
    required SmartNotificationType type,
    required Map<String, dynamic> userPreferences,
    required List<Order> userHistory,
    Map<String, dynamic>? customData,
  }) async {
    String title;
    String body;
    String? payload;
    String? channelId;

    switch (type) {
      case SmartNotificationType.promotion:
        final favoriteCategory =
            _getFavoriteCategory(userHistory, userPreferences);
        final categoryName = _getCategoryDisplayName(favoriteCategory);

        title = '🎉 Promotion Spéciale !';
        body = customData?['message'] as String? ??
            'Profitez d\'une promotion exclusive sur vos $categoryName préférés ! Découvrez nos offres spéciales maintenant.';
        payload = jsonEncode({
          'type': 'promotion',
          'categoryId': favoriteCategory,
          'userId': userId,
        });
        channelId = 'marketing';

        break;

      case SmartNotificationType.orderReminder:
        final lastOrderDate = _getLastOrderDate(userHistory);
        final daysSinceLastOrder =
            DateTime.now().difference(lastOrderDate).inDays;

        if (daysSinceLastOrder >= 7) {
          title = '👋 On vous attend !';
          body = customData?['message'] as String? ??
              'Cela fait $daysSinceLastOrder jours que vous ne nous avez pas visités. Passer une commande pour vos plats préférés !';
        } else {
          title = '🍽️ Envie d\'un bon repas ?';
          body = customData?['message'] as String? ??
              'N\'oubliez pas de commander vos plats préférés !';
        }

        payload = jsonEncode({
          'type': 'order_reminder',
          'userId': userId,
        });
        channelId = 'marketing';

        break;

      case SmartNotificationType.favoriteAvailable:
        final favoriteItem = await _getFavoriteItem(userId, userPreferences);
        if (favoriteItem != null) {
          title = '⭐ Votre favori est disponible !';
          body = customData?['message'] as String? ??
              '${favoriteItem.name} est de nouveau disponible. Commandez-le maintenant !';
          payload = jsonEncode({
            'type': 'favorite_available',
            'itemId': favoriteItem.id,
            'userId': userId,
          });
        } else {
          title = '⭐ Nouveaux articles disponibles !';
          body =
              'Découvrez nos nouveaux plats ajoutés spécialement pour vous !';
          payload = jsonEncode({
            'type': 'new_items',
            'userId': userId,
          });
        }
        channelId = 'marketing';

        break;

      case SmartNotificationType.newArrival:
        final preferredCategories = _getPreferredCategories(userHistory);
        final categoryName = preferredCategories.isNotEmpty
            ? _getCategoryDisplayName(preferredCategories.first)
            : 'nouveaux plats';

        title = '🆕 Nouveaux Arrivages !';
        body = customData?['message'] as String? ??
            'Découvrez nos nouveaux $categoryName fraîchement ajoutés au menu !';
        payload = jsonEncode({
          'type': 'new_arrival',
          'userId': userId,
        });
        channelId = 'marketing';

        break;

      case SmartNotificationType.orderStatus:
        final order = customData?['order'] as Order?;
        if (order != null) {
          title = _getOrderStatusTitle(order.status);
          body = customData?['message'] as String? ??
              _getOrderStatusMessage(order.status, order.id);
          payload = jsonEncode({
            'type': 'order_status',
            'orderId': order.id,
            'status': order.status.toString(),
            'userId': userId,
          });
          channelId = 'orders';
        } else {
          throw Exception('Order is required for orderStatus notification');
        }

        break;

      case SmartNotificationType.loyaltyReward:
        final loyaltyPoints = userPreferences['loyaltyPoints'] as int? ?? 0;
        final pointsNeeded = _getPointsNeededForNextReward(loyaltyPoints);

        title = '🎁 Récompense de Fidélité !';
        body = customData?['message'] as String? ??
            'Vous avez $loyaltyPoints points de fidélité ! Plus que $pointsNeeded points pour débloquer votre prochaine récompense.';
        payload = jsonEncode({
          'type': 'loyalty_reward',
          'userId': userId,
          'points': loyaltyPoints,
        });
        channelId = 'rewards';

        break;

      case SmartNotificationType.abandonedCart:
        final cartItems = customData?['cartItems'] as List? ?? [];
        final itemCount = cartItems.length;

        title = '🛒 Vous avez oublié quelque chose !';
        body = customData?['message'] as String? ??
            'Vous avez $itemCount article(s) dans votre panier. Finalisez votre commande maintenant !';
        payload = jsonEncode({
          'type': 'abandoned_cart',
          'userId': userId,
        });
        channelId = 'marketing';

        break;
    }

    return {
      'title': title,
      'body': body,
      'payload': payload,
      'channelId': channelId,
    };
  }

  /// Obtient les préférences de l'utilisateur
  Future<Map<String, dynamic>> _getUserPreferences(String userId) async {
    try {
      // Récupérer les préférences depuis AppService et autres sources
      final currentUser = _appService.currentUser;
      if (currentUser == null || currentUser.id != userId) {
        return {};
      }

      // Utiliser les services existants pour obtenir les préférences
      final favoritesService = FavoritesService();
      if (!favoritesService.isInitialized) {
        await favoritesService.initialize();
      }

      // Analyser les favoris pour déterminer les catégories préférées
      final favoriteCategories = <String>[];
      for (final favorite in favoritesService.favorites) {
        if (favorite.categoryId.isNotEmpty &&
            !favoriteCategories.contains(favorite.categoryId)) {
          favoriteCategories.add(favorite.categoryId);
        }
      }

      // Récupérer les préférences depuis le modèle User
      final userPreferences = currentUser.preferences ?? {};

      return {
        'loyaltyPoints': currentUser.loyaltyPoints,
        'favoriteCategories': favoriteCategories,
        'preferredDeliveryTime': userPreferences['preferredDeliveryTime'],
        'dietaryRestrictions': userPreferences['dietaryRestrictions'] is List
            ? List<String>.from(userPreferences['dietaryRestrictions'])
            : [],
      };
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des préférences: $e');
      return {};
    }
  }

  /// Obtient l'historique des commandes de l'utilisateur
  Future<List<Order>> _getUserOrderHistory(String userId) async {
    try {
      final orderRepository = DjangoOrderRepository();
      final orderHistoryService = OrderHistoryService(orderRepository);
      await orderHistoryService.loadOrders(userId);
      return orderHistoryService.orders;
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération de l\'historique: $e');
      return [];
    }
  }

  /// Détermine la catégorie préférée de l'utilisateur
  String? _getFavoriteCategory(
    List<Order> userHistory,
    Map<String, dynamic> preferences,
  ) {
    // Priorité aux préférences explicites
    final favoriteCategories =
        preferences['favoriteCategories'] as List<String>?;
    if (favoriteCategories != null && favoriteCategories.isNotEmpty) {
      return favoriteCategories.first;
    }

    // Sinon, analyser l'historique des commandes
    final categoryCount = <String, int>{};

    for (final order in userHistory) {
      for (final item in order.items) {
        final category = item.category;
        if (category.isNotEmpty) {
          categoryCount[category] = (categoryCount[category] ?? 0) + 1;
        }
      }
    }

    if (categoryCount.isEmpty) return null;

    // Retourner la catégorie la plus commandée
    final sortedCategories = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedCategories.first.key;
  }

  /// Obtient les catégories préférées
  List<String> _getPreferredCategories(List<Order> userHistory) {
    final categoryCount = <String, int>{};

    for (final order in userHistory) {
      for (final item in order.items) {
        final category = item.category;
        if (category.isNotEmpty) {
          categoryCount[category] = (categoryCount[category] ?? 0) + 1;
        }
      }
    }

    final sortedCategories = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedCategories.map((e) => e.key).toList();
  }

  /// Obtient le nom d'affichage d'une catégorie
  String _getCategoryDisplayName(String? categoryId) {
    if (categoryId == null) return 'plats';
    // Mapper les catégories aux noms d'affichage
    final categoryNames = {
      'pizza': 'pizzas',
      'burger': 'burgers',
      'pasta': 'pâtes',
      'salad': 'salades',
      'drink': 'boissons',
      'dessert': 'desserts',
    };
    return categoryNames[categoryId] ?? 'plats';
  }

  /// Obtient la date de la dernière commande
  DateTime _getLastOrderDate(List<Order> orders) {
    if (orders.isEmpty) {
      return DateTime.now().subtract(const Duration(days: 30));
    }

    final sortedOrders = List<Order>.from(orders)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return sortedOrders.first.createdAt;
  }

  /// Obtient l'article favori de l'utilisateur
  Future<MenuItem?> _getFavoriteItem(
    String userId,
    Map<String, dynamic> preferences,
  ) async {
    try {
      // Utiliser FavoritesService pour obtenir les favoris
      final favoritesService = FavoritesService();
      if (!favoritesService.isInitialized) {
        await favoritesService.initialize();
      }

      final favorites = favoritesService.favorites;
      if (favorites.isNotEmpty) {
        return favorites.first;
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des favoris: $e');
    }
    return null;
  }

  /// Obtient le titre selon le statut de la commande
  String _getOrderStatusTitle(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return '⏳ Commande en attente';
      case OrderStatus.confirmed:
        return '✅ Commande confirmée';
      case OrderStatus.preparing:
        return '👨‍🍳 Commande en préparation';
      case OrderStatus.ready:
        return '📦 Commande prête';
      case OrderStatus.pickedUp:
        return '🏃‍♂️ Commande récupérée';
      case OrderStatus.onTheWay:
        return '🛵 Commande en livraison';
      case OrderStatus.delivered:
        return '🎉 Commande livrée !';
      case OrderStatus.cancelled:
        return '❌ Commande annulée';
      case OrderStatus.refunded:
        return '💰 Commande remboursée';
      case OrderStatus.failed:
        return '⚠️ Commande échouée';
    }
  }

  /// Obtient le message selon le statut de la commande
  String _getOrderStatusMessage(OrderStatus status, String orderId) {
    switch (status) {
      case OrderStatus.pending:
        return 'Votre commande #${orderId.substring(0, 8)} est en attente de confirmation.';
      case OrderStatus.confirmed:
        return 'Votre commande #${orderId.substring(0, 8)} a été confirmée !';
      case OrderStatus.preparing:
        return 'Votre commande #${orderId.substring(0, 8)} est en cours de préparation.';
      case OrderStatus.ready:
        return 'Votre commande #${orderId.substring(0, 8)} est prête pour la livraison !';
      case OrderStatus.pickedUp:
        return 'Votre commande #${orderId.substring(0, 8)} a été récupérée par le livreur.';
      case OrderStatus.onTheWay:
        return 'Votre commande #${orderId.substring(0, 8)} est en route vers vous !';
      case OrderStatus.delivered:
        return 'Votre commande #${orderId.substring(0, 8)} a été livrée avec succès ! Bon appétit !';
      case OrderStatus.cancelled:
        return 'Votre commande #${orderId.substring(0, 8)} a été annulée.';
      case OrderStatus.refunded:
        return 'Votre commande #${orderId.substring(0, 8)} a été remboursée.';
      case OrderStatus.failed:
        return 'Votre commande #${orderId.substring(0, 8)} a échoué. Veuillez contacter le support.';
    }
  }

  /// Calcule les points nécessaires pour la prochaine récompense
  int _getPointsNeededForNextReward(int currentPoints) {
    // Niveaux de récompenses : 100, 500, 1000, 2500, 5000
    final rewardLevels = [100, 500, 1000, 2500, 5000];
    for (final level in rewardLevels) {
      if (currentPoints < level) {
        return level - currentPoints;
      }
    }
    return 0; // Tous les niveaux atteints
  }

  /// Envoie une notification segmentée à un groupe d'utilisateurs
  Future<void> sendSegmentedNotification({
    required List<String> userIds,
    required SmartNotificationType type,
    Map<String, dynamic>? customData,
  }) async {
    for (final userId in userIds) {
      await sendPersonalizedNotification(
        userId: userId,
        type: type,
        customData: customData,
      );
    }
  }
}
