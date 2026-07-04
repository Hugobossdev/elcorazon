import 'package:flutter/foundation.dart';
import 'database_service.dart';

/// Service pour récupérer tous les détails des commandes avec leurs items de menu
class OrderDetailsService {
  final DatabaseService _databaseService = DatabaseService();

  /// Récupère tous les détails d'une commande spécifique
  /// 
  /// Retourne:
  /// - Informations de la commande (statut, prix, adresse, etc.)
  /// - Tous les items de la commande avec leurs détails
  /// - Informations sur les menu items (nom, catégorie, prix, image)
  /// - Informations sur l'utilisateur qui a passé la commande
  /// - Informations sur le livreur assigné (si applicable)
  /// - Personnalisations de chaque item
  Future<Map<String, dynamic>?> getOrderDetails(String orderId) async {
    try {
      return await _databaseService.getOrderDetailsWithMenuItems(orderId);
    } catch (e) {
      debugPrint('Erreur lors de la récupération des détails de commande: $e');
      rethrow;
    }
  }

  /// Récupère toutes les commandes avec tous leurs détails
  ///
  /// Retourne une liste de commandes avec tous leurs détails complets.
  Future<List<Map<String, dynamic>>> getAllOrdersWithDetails() async {
    try {
      return await _databaseService.getAllOrdersWithMenuDetails();
    } catch (e) {
      debugPrint('Erreur lors de la récupération des commandes: $e');
      rethrow;
    }
  }

  /// Récupère les statistiques détaillées sur les items de menu commandés
  /// 
  /// Retourne pour chaque item de menu:
  /// - Nombre total de commandes
  /// - Quantité totale commandée
  /// - Revenu total généré
  /// - Prix moyen
  /// - Informations sur la catégorie
  /// 
  /// Utile pour les analyses et rapports
  Future<List<Map<String, dynamic>>> getMenuItemsStatistics({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      return await _databaseService.getMenuItemsOrderStatistics(
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );
    } catch (e) {
      debugPrint('Erreur lors de la récupération des statistiques: $e');
      rethrow;
    }
  }

  /// Formate les détails d'une commande pour l'affichage
  /// 
  /// Extrait et organise les informations de manière lisible
  Map<String, dynamic> formatOrderDetails(Map<String, dynamic> orderData) {
    final orderItems = orderData['order_items'] as List<dynamic>? ?? [];
    
    // Extraire les informations principales
    final formatted = {
      'order_id': orderData['id'],
      'order_status': orderData['status'],
      'order_date': orderData['created_at'],
      'total_amount': orderData['total'],
      'subtotal': orderData['subtotal'],
      'delivery_fee': orderData['delivery_fee'],
      'discount': orderData['discount'] ?? 0.0,
      'delivery_address': orderData['delivery_address'],
      'payment_method': orderData['payment_method'],
      'payment_status': orderData['payment_status'],
      'customer': {
        'id': orderData['users']?['id'],
        'name': orderData['users']?['name'],
        'email': orderData['users']?['email'],
        'phone': orderData['users']?['phone'],
      },
      'delivery_person': orderData['delivery_person'] != null
          ? {
              'id': orderData['delivery_person']?['id'],
              'name': orderData['delivery_person']?['name'],
              'email': orderData['delivery_person']?['email'],
              'phone': orderData['delivery_person']?['phone'],
            }
          : null,
      'items': orderItems.map((item) {
        final menuItem = item['menu_items'];
        return {
          'item_id': item['id'],
          'menu_item_id': item['menu_item_id'],
          'name': item['menu_item_name'] ?? item['name'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
          'total_price': item['total_price'],
          'customizations': item['customizations'] ?? {},
          'notes': item['notes'],
          'menu_item_details': menuItem != null
              ? {
                  'id': menuItem['id'],
                  'name': menuItem['name'],
                  'description': menuItem['description'],
                  'base_price': menuItem['base_price'],
                  'image_url': menuItem['image_url'],
                  'category': menuItem['menu_categories'] != null
                      ? {
                          'name': menuItem['menu_categories']['name'],
                          'display_name':
                              menuItem['menu_categories']['display_name'],
                          'emoji': menuItem['menu_categories']['emoji'],
                        }
                      : null,
                }
              : null,
        };
      }).toList(),
      'items_count': orderItems.length,
      'total_items_quantity': orderItems.fold<int>(
        0,
        (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 0),
      ),
    };

    return formatted;
  }

  /// Récupère et formate les détails d'une commande
  /// 
  /// Combinaison de getOrderDetails et formatOrderDetails
  Future<Map<String, dynamic>?> getFormattedOrderDetails(String orderId) async {
    try {
      final orderData = await getOrderDetails(orderId);
      if (orderData == null) return null;
      return formatOrderDetails(orderData);
    } catch (e) {
      debugPrint('Erreur lors du formatage des détails: $e');
      rethrow;
    }
  }
}











