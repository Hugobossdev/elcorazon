import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/supabase/supabase_config.dart';
import 'package:elcora_fast/repositories/order_repository.dart';

/// Implémentation Supabase du OrderRepository
class SupabaseOrderRepository implements OrderRepository {
  final SupabaseClient _supabase = SupabaseConfig.client;

  @override
  Future<Order> createOrder(Order order) async {
    try {
      final orderData = order.toMap();
      // Convertir les order items pour la base de données
      orderData['order_items'] = order.items
          .map((item) => {
                'menu_item_id': item.menuItemId,
                'menu_item_name': item.menuItemName,
                'quantity': item.quantity,
                'unit_price': item.unitPrice,
                'total_price': item.totalPrice,
                'customizations': item.customizations,
              },)
          .toList();

      final response = await _supabase
          .from('orders')
          .insert(orderData)
          .select()
          .single();

      return Order.fromMap(response);
    } catch (e) {
      debugPrint('❌ Error in SupabaseOrderRepository.createOrder: $e');
      throw Exception('Erreur lors de la création de la commande: $e');
    }
  }

  @override
  Future<Order?> getOrderById(String orderId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('''
            *,
            order_items(*)
          ''')
          .eq('id', orderId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Order.fromMap(response);
    } catch (e) {
      debugPrint('❌ Error in SupabaseOrderRepository.getOrderById: $e');
      if (e is PostgrestException && e.code == 'PGRST116') {
        return null; // Order not found
      }
      throw Exception('Erreur lors de la récupération de la commande: $e');
    }
  }

  @override
  Future<List<Order>> getUserOrders(String userId, {String? status}) async {
    try {
      var queryBuilder = _supabase
          .from('orders')
          .select('''
            *,
            order_items(*)
          ''')
          .eq('user_id', userId);

      if (status != null && status.isNotEmpty) {
        queryBuilder = queryBuilder.eq('status', status);
      }

      final response = await queryBuilder.order('created_at', ascending: false);

      final orders = (response as List<dynamic>)
          .map((data) => Order.fromMap(data as Map<String, dynamic>))
          .toList();

      return orders;
    } catch (e) {
      debugPrint('❌ Error in SupabaseOrderRepository.getUserOrders: $e');
      throw Exception('Erreur lors de la récupération des commandes: $e');
    }
  }

  @override
  Future<Order> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      final response = await _supabase
          .from('orders')
          .update({'status': status.toString().split('.').last})
          .eq('id', orderId)
          .select()
          .single();

      return Order.fromMap(response);
    } catch (e) {
      debugPrint('❌ Error in SupabaseOrderRepository.updateOrderStatus: $e');
      throw Exception('Erreur lors de la mise à jour du statut: $e');
    }
  }

  @override
  Stream<List<Order>> watchUserOrders(String userId) {
    // Implémentation basique avec polling
    // Pour une vraie implémentation temps réel, utiliser Supabase Realtime
    return Stream.periodic(const Duration(seconds: 30), (_) => null)
        .asyncMap((_) => getUserOrders(userId));
  }
}

