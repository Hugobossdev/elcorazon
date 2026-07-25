import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';
import 'delivery_assignment_service.dart';

/// Service pour coordonner les livraisons, gérer les zones et les priorités
class DeliveryCoordinationService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final DeliveryAssignmentService _assignmentService = DeliveryAssignmentService();
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Récupère toutes les commandes qui nécessitent une livraison (prêtes, en cours)
  Future<List<Map<String, dynamic>>> getOrdersNeedingDelivery() async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _supabase
          .from('orders')
          .select('*, order_items(*), users(name, phone)')
          .inFilter('status', ['ready', 'preparing', 'confirmed'])
          .isFilter('delivery_person_id', null)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting orders needing delivery: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Tente d'assigner automatiquement une commande prête
  Future<bool> autoAssignReadyOrder(String orderId) async {
    return await _assignmentService.autoAssignDelivery(orderId) != null;
  }

  /// Traite le flux complet d'une commande vers la livraison
  Future<void> processOrderToDelivery(String orderId) async {
    try {
      // 1. Marquer comme prête
      await _supabase.from('orders').update({
        'status': 'ready',
        'ready_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      // 2. Tenter l'auto-assignation
      final assignedDriverId = await _assignmentService.autoAssignDelivery(orderId);
      
      if (assignedDriverId != null) {
        debugPrint('Order $orderId auto-assigned to $assignedDriverId');
      } else {
        // Notifier les admins qu'une commande est prête mais sans livreur
        _notifyAdminsOfUnassignedOrder(orderId);
      }
    } catch (e) {
      debugPrint('Error processing order to delivery: $e');
    }
  }

  /// Notifie les admins d'une commande non assignée
  Future<void> _notifyAdminsOfUnassignedOrder(String orderId) async {
    // Implémentation de la notification admin
    // Pourrait utiliser une table 'admin_notifications'
  }

  /// Tableau de bord de coordination (vue d'ensemble)
  Future<Map<String, dynamic>> getDeliveryDashboard() async {
    try {
      final activeDeliveries = await _supabase
          .from('orders')
          .select('id')
          .inFilter('status', ['on_the_way', 'picked_up']);
          
      final pendingAssignments = await _supabase
          .from('orders')
          .select('id')
          .eq('status', 'ready')
          .isFilter('delivery_person_id', null);
          
      final availableDrivers = await _assignmentService.getOnlineDeliveryPersons();
      
      return {
        'active_deliveries_count': activeDeliveries.length,
        'pending_assignments_count': pendingAssignments.length,
        'available_drivers_count': availableDrivers.length,
      };
    } catch (e) {
      return {
        'active_deliveries_count': 0,
        'pending_assignments_count': 0,
        'available_drivers_count': 0,
      };
    }
  }
  
  /// Mettre à jour le statut d'une commande avec notifications
  Future<bool> updateOrderStatusWithNotifications(
    String orderId, 
    OrderStatus status,
    {String? message}
  ) async {
    try {
      final statusStr = status.toString().split('.').last;
      
      await _supabase.from('orders').update({
        'status': statusStr,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      // Envoyer notification au client
      await _sendStatusUpdateNotification(orderId, status, message);
      
      return true;
    } catch (e) {
      debugPrint('Error updating status: $e');
      return false;
    }
  }

  /// Envoyer notification de changement de statut
  Future<void> _sendStatusUpdateNotification(
    String orderId, 
    OrderStatus status,
    String? customMessage
  ) async {
    try {
      final order = await _supabase
          .from('orders')
          .select('user_id')
          .eq('id', orderId)
          .single();
          
      final userId = order['user_id'];
      
      String title = 'Mise à jour de votre commande';
      String body = customMessage ?? 'Le statut de votre commande a changé : ${status.displayName}';
      
      if (status == OrderStatus.onTheWay) {
        body = 'Votre commande est en route ! Suivez le livreur.';
      } else if (status == OrderStatus.delivered) {
        body = 'Bon appétit ! Votre commande a été livrée.';
      }

      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': body,
        'type': 'order_status_${status.toString().split('.').last}',
        'data': {'order_id': orderId},
      });
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  /// Récupérer les commandes en retard
  Future<List<Map<String, dynamic>>> getDelayedOrders() async {
    try {
      final now = DateTime.now();
      // Commandes "en cours" depuis plus de 45 minutes
      final threshold = now.subtract(const Duration(minutes: 45)).toIso8601String();
      
      final response = await _supabase
          .from('orders')
          .select('*, users(name, phone), drivers:delivery_person_id(name, phone)')
          .lt('created_at', threshold)
          .inFilter('status', ['confirmed', 'preparing', 'ready', 'picked_up', 'on_the_way']);
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Optimiser les assignations (batch job)
  Future<void> optimizeDeliveryAssignments() async {
    // Logique complexe d'optimisation (TSP, clustering, etc.)
    // Pourrait être déclenché périodiquement
  }
}
