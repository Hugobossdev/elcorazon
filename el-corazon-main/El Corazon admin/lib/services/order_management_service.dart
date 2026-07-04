import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';
import '../utils/price_formatter.dart';
import 'socket_service.dart';

class OrderManagementService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Order> _allOrders = [];
  bool _isLoading = false;

  List<Order> get allOrders => _allOrders;
  bool get isLoading => _isLoading;

  OrderManagementService() {
    // Defer initial load until after first frame to avoid notifying during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllOrders();
      _setupSocketListeners();
    });
  }

  void _setupSocketListeners() {
    final socketService = SocketService();

    socketService.onNewOrder((data) {
      debugPrint('🔔 OrderManagementService: New order received via socket');
      refresh();
    });

    socketService.onOrderUpdate((data) {
      debugPrint('🔔 OrderManagementService: Order update received via socket');
      // If data contains ID, we could optimize, but refresh() is safer for now
      refresh();
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    // Defer notifications to avoid setState/markNeedsBuild during build
    Future.microtask(() => notifyListeners());
  }

  /// Charger toutes les commandes
  Future<void> _loadAllOrders() async {
    _setLoading(true);
    try {
      debugPrint('🔍 OrderManagementService: Chargement des commandes...');

      // Essayer d'abord avec la relation foreign key
      PostgrestList response;
      try {
        response = await _supabase
            .from('orders')
            .select('*, order_items(*), users!orders_user_id_fkey(name, email)')
            .order('created_at', ascending: false);

        debugPrint(
            '📦 OrderManagementService: ${response.length} commande(s) récupérée(s) de la base (avec relation users)');
      } catch (e) {
        // Si la relation échoue, essayer sans la relation users
        debugPrint(
            '⚠️ Erreur avec relation users, tentative sans relation: $e');
        try {
          response = await _supabase
              .from('orders')
              .select('*, order_items(*)')
              .order('created_at', ascending: false);

          debugPrint(
              '📦 OrderManagementService: ${response.length} commande(s) récupérée(s) de la base (sans relation users)');
        } catch (e2) {
          debugPrint('❌ Erreur lors de la récupération des commandes: $e2');
          rethrow;
        }
      }

      if (response.isEmpty) {
        debugPrint('⚠️ Aucune commande trouvée dans la base de données');
        _allOrders = [];
        Future.microtask(() => notifyListeners());
        return;
      }

      final List<Order> parsedOrders = [];

      for (var orderData in response) {
        try {
          // Log les order_items avant parsing (mode debug uniquement)
          if (orderData['order_items'] != null) {
            final items = orderData['order_items'];
            if (items is List && items.isNotEmpty) {
              final firstItem = items.first;
              if (firstItem is Map<String, dynamic>) {
                final itemName = firstItem['name']?.toString() ??
                    firstItem['menu_item_name']?.toString() ??
                    'Inconnu';
                final itemId = firstItem['id']?.toString() ??
                    firstItem['menu_item_id']?.toString() ??
                    'N/A';
                debugPrint(
                    '📋 Commande ${orderData['id']?.toString().substring(0, 8) ?? 'unknown'}: ${items.length} article(s) - Premier: $itemName (ID: ${itemId.substring(0, 8)}...)');
              } else {
                debugPrint(
                    '📋 Commande ${orderData['id']?.toString().substring(0, 8) ?? 'unknown'}: ${items.length} article(s) trouvé(s)');
              }
            } else {
              debugPrint(
                  '⚠️ Commande ${orderData['id']?.toString().substring(0, 8) ?? 'unknown'}: order_items n\'est pas une liste valide');
            }
          } else {
            debugPrint(
                '⚠️ Commande ${orderData['id']?.toString().substring(0, 8) ?? 'unknown'}: Aucun order_items trouvé');
          }

          final order = Order.fromMap(orderData);
          parsedOrders.add(order);
          debugPrint(
              '✅ Commande parsée: ${order.id.substring(0, 8)} - ${order.status.displayName} - ${order.items.length} article(s)');
        } catch (e) {
          debugPrint(
              '❌ Erreur parsing commande ${orderData['id'] ?? 'unknown'}: $e');
          debugPrint(
              '   Données: ${orderData.toString().substring(0, 300)}...');
          // Continuer avec les autres commandes au lieu de tout échouer
        }
      }

      _allOrders = parsedOrders;
      debugPrint(
          '📊 OrderManagementService: ${_allOrders.length}/${response.length} commande(s) chargée(s) avec succès');

      // Notifier les listeners
      Future.microtask(() => notifyListeners());
    } catch (e) {
      debugPrint('❌ OrderManagementService: Erreur chargement commandes: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      _allOrders = [];
      Future.microtask(() => notifyListeners());
    } finally {
      _setLoading(false);
    }
  }

  /// Mettre à jour le statut d'une commande
  Future<bool> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    try {
      debugPrint(
          '🔄 Mise à jour du statut de la commande $orderId vers ${newStatus.displayName}');

      // Mettre à jour dans la base de données
      final statusString = newStatus.dbValue;
      await _supabase.from('orders').update({
        'status': statusString,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      debugPrint('✅ Statut mis à jour dans la base de données: $statusString');

      // Mettre à jour l'état local immédiatement pour feedback rapide
      final index = _allOrders.indexWhere((order) => order.id == orderId);
      if (index != -1) {
        _allOrders[index] = _allOrders[index].copyWith(status: newStatus);
        debugPrint(
            '✅ État local mis à jour pour la commande à l\'index $index');
      } else {
        debugPrint('⚠️ Commande $orderId non trouvée dans la liste locale');
      }

      // Notifier les listeners IMMÉDIATEMENT pour rafraîchir l'interface
      Future.microtask(() => notifyListeners());
      debugPrint('✅ Listeners notifiés (microtask)');

      // Recharger la commande spécifique depuis la base de données en arrière-plan
      // pour s'assurer de la cohérence (sans bloquer l'interface)
      _refreshSingleOrder(orderId).catchError((e) {
        debugPrint('⚠️ Erreur lors du rechargement de la commande: $e');
      });

      return true;
    } catch (e) {
      debugPrint('❌ Erreur lors de la mise à jour du statut: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Recharger une commande spécifique depuis la base de données
  Future<void> _refreshSingleOrder(String orderId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('*, order_items(*), users!orders_user_id_fkey(name, email)')
          .eq('id', orderId)
          .single();

      final updatedOrder = Order.fromMap(response);

      final index = _allOrders.indexWhere((order) => order.id == orderId);
      if (index != -1) {
        _allOrders[index] = updatedOrder;
        debugPrint('✅ Commande rechargée depuis la base de données');
        Future.microtask(() => notifyListeners());
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors du rechargement de la commande $orderId: $e');
      // En cas d'erreur, on recharge toutes les commandes
      await _loadAllOrders();
    }
  }

  /// Confirmer une commande
  Future<bool> confirmOrder(String orderId) async {
    return await updateOrderStatus(orderId, OrderStatus.confirmed);
  }

  /// Commencer la préparation d'une commande
  Future<bool> startPreparingOrder(String orderId) async {
    return await updateOrderStatus(orderId, OrderStatus.preparing);
  }

  /// Marquer une commande comme prête
  Future<bool> markOrderReady(String orderId) async {
    return await updateOrderStatus(orderId, OrderStatus.ready);
  }

  /// Marquer une commande comme récupérée
  Future<bool> markOrderPickedUp(String orderId) async {
    return await updateOrderStatus(orderId, OrderStatus.pickedUp);
  }

  /// Marquer une commande comme en route
  Future<bool> markOrderOnTheWay(String orderId) async {
    return await updateOrderStatus(orderId, OrderStatus.onTheWay);
  }

  /// Marquer une commande comme livrée
  Future<bool> markOrderDelivered(String orderId) async {
    return await updateOrderStatus(orderId, OrderStatus.delivered);
  }

  /// Annuler une commande
  Future<bool> cancelOrderStatus(String orderId) async {
    return await updateOrderStatus(orderId, OrderStatus.cancelled);
  }

  /// Marquer une commande comme échouée
  Future<bool> markOrderFailed(String orderId) async {
    return await updateOrderStatus(orderId, OrderStatus.failed);
  }

  /// Accepter une commande
  Future<bool> acceptOrder(String orderId) async {
    return await updateOrderStatus(orderId, OrderStatus.confirmed);
  }

  /// Refuser une commande
  Future<bool> rejectOrder(String orderId, {String? reason}) async {
    try {
      _setLoading(true);

      // Mettre à jour le statut
      await updateOrderStatus(orderId, OrderStatus.cancelled);

      // Ajouter une note si une raison est fournie
      if (reason != null && reason.isNotEmpty) {
        await addInternalNote(orderId, 'Commande refusée: $reason');
      }

      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('Error rejecting order: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Rembourser une commande
  Future<bool> refundOrder(String orderId) async {
    return await updateOrderStatus(orderId, OrderStatus.refunded);
  }

  /// Traiter un remboursement
  Future<bool> processRefund(String orderId, double amount) async {
    try {
      _setLoading(true);

      // Dans une vraie application, cela impliquerait l'appel à une API de passerelle de paiement
      // Pour l'instant, on va juste logger et mettre à jour le statut dans la DB
      debugPrint(
          'Processing refund of ${PriceFormatter.format(amount)} for order $orderId');

      await _supabase.from('orders').update({
        'is_refunded': true,
        'refund_amount': amount,
        'refunded_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      // Mise à jour locale des commandes (les propriétés isRefunded et refundAmount ne sont pas définies dans le modèle Order)
      // final index = _allOrders.indexWhere((order) => order.id == orderId);
      // if (index != -1) {
      //   _allOrders[index] = _allOrders[index].copyWith(
      //     isRefunded: true,
      //     refundAmount: amount,
      //   );
      // }

      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('Error processing refund: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Annuler une commande
  Future<bool> cancelOrder(String orderId, String reason) async {
    try {
      _setLoading(true);

      await _supabase.from('orders').update({
        'status': OrderStatus.cancelled.dbValue,
        'cancellation_reason': reason,
        'cancelled_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      // Mise à jour locale des commandes (la propriété cancellationReason n'est pas définie dans le modèle Order)
      // final index = _allOrders.indexWhere((order) => order.id == orderId);
      // if (index != -1) {
      //   _allOrders[index] = _allOrders[index].copyWith(
      //     status: OrderStatus.cancelled,
      //     cancellationReason: reason,
      //   );
      // }

      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Assigner un livreur à une commande
  /// IMPORTANT: driverId doit être le user_id depuis la table users, pas l'id du driver
  Future<bool> assignDriver(String orderId, String driverId) async {
    try {
      _setLoading(true);

      // Vérifier que driverId est un user_id valide dans users
      // Si driverId est l'id du driver (depuis la table drivers), récupérer le user_id correspondant
      String? userId;

      // Si driverId ressemble à un UUID de driver (pas de user_id), récupérer le user_id
      try {
        // Chercher le driver par id pour obtenir user_id
        final driverResponse = await _supabase
            .from('drivers')
            .select('user_id')
            .eq('id', driverId)
            .maybeSingle();

        if (driverResponse != null && driverResponse['user_id'] != null) {
          // Si on a trouvé le driver, son user_id correspond à l'id dans la table users
          userId = driverResponse['user_id'] as String;
          debugPrint('🔄 Driver ID $driverId -> User ID $userId');
        } else {
          // Vérifier que driverId est un user_id valide dans users
          final userCheck = await _supabase
              .from('users')
              .select('id, role')
              .eq('id', driverId)
              .maybeSingle();

          if (userCheck == null) {
            throw Exception(
                'L\'ID fourni ($driverId) n\'existe ni dans la table drivers ni dans la table users.');
          }

          final userRole = userCheck['role'] as String?;
          if (userRole != 'delivery') {
            debugPrint(
                '⚠️ L\'utilisateur $driverId n\'a pas le rôle \'delivery\', mais est: $userRole');
          }

          userId = userCheck['id'] as String;
          debugPrint('✅ User ID $userId validé (role: $userRole)');
        }
      } catch (e) {
        debugPrint('❌ Erreur lors de la récupération du user_id: $e');
        _setLoading(false);
        rethrow;
      }

      // userId devrait toujours être défini à ce stade (sinon une exception aurait été levée)
      // Dart peut analyser que userId n'est jamais null ici grâce au flux de contrôle
      final finalUserId = userId;

      // Utiliser userId (qui devrait être le user_id de la table users)
      await _supabase.from('orders').update({
        'delivery_person_id': finalUserId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      // Mettre à jour l'état local immédiatement
      final index = _allOrders.indexWhere((order) => order.id == orderId);
      if (index != -1) {
        _allOrders[index] = _allOrders[index].copyWith(
          deliveryPersonId: finalUserId,
        );
        Future.microtask(() => notifyListeners());
      }

      debugPrint(
          '✅ Livreur (user_id: $finalUserId) assigné à la commande $orderId');

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error assigning driver: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Ajouter une note interne à une commande
  Future<bool> addInternalNote(String orderId, String note) async {
    try {
      await _supabase.from('order_status_updates').insert({
        'order_id': orderId,
        'status': 'note',
        'notes': note,
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      debugPrint('Error adding internal note: $e');
      return false;
    }
  }

  /// Filtrer les commandes par date
  List<Order> filterByDateRange(DateTime startDate, DateTime endDate) {
    return _allOrders.where((order) {
      return order.orderTime
              .isAfter(startDate.subtract(const Duration(days: 1))) &&
          order.orderTime.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  /// Obtenir les commandes en attente
  List<Order> getPendingOrders() {
    return _allOrders
        .where((order) => order.status == OrderStatus.pending)
        .toList();
  }

  /// Obtenir les commandes par statut (filtre en mémoire)
  List<Order> getOrdersByStatus(OrderStatus status) {
    return _allOrders.where((order) => order.status == status).toList();
  }

  /// Charger les commandes par statut directement depuis la base de données
  /// Utilise la valeur dbValue (snake_case) pour garantir la cohérence avec la DB
  Future<List<Order>> loadOrdersByStatusFromDB(OrderStatus status) async {
    try {
      final statusDbValue = status.dbValue;
      debugPrint('🔍 Chargement des commandes avec statut: $statusDbValue');

      final response = await _supabase
          .from('orders')
          .select('*, order_items(*), users!orders_user_id_fkey(name, email)')
          .eq('status', statusDbValue)
          .order('created_at', ascending: false);

      final List<Order> orders = [];
      for (var orderData in response) {
        try {
          final order = Order.fromMap(orderData);
          orders.add(order);
        } catch (e) {
          debugPrint('❌ Erreur parsing commande ${orderData['id']}: $e');
        }
      }

      debugPrint(
          '✅ ${orders.length} commande(s) chargée(s) avec statut $statusDbValue');
      return orders;
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement des commandes par statut: $e');
      return [];
    }
  }

  /// Charger les commandes récentes directement depuis la base de données
  /// Limite le nombre de commandes retournées
  Future<List<Order>> loadRecentOrdersFromDB({int limit = 5}) async {
    try {
      debugPrint('🔍 Chargement des $limit commandes les plus récentes...');

      final response = await _supabase
          .from('orders')
          .select('*, order_items(*), users!orders_user_id_fkey(name, email)')
          .order('created_at', ascending: false)
          .limit(limit);

      final List<Order> orders = [];
      for (var orderData in response) {
        try {
          final order = Order.fromMap(orderData);
          orders.add(order);
        } catch (e) {
          debugPrint('❌ Erreur parsing commande ${orderData['id']}: $e');
        }
      }

      debugPrint('✅ ${orders.length} commande(s) récente(s) chargée(s)');
      return orders;
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement des commandes récentes: $e');
      return [];
    }
  }

  /// Obtenir les commandes d'aujourd'hui
  List<Order> getTodayOrders() {
    final today = DateTime.now();
    return _allOrders
        .where((order) =>
            order.orderTime.year == today.year &&
            order.orderTime.month == today.month &&
            order.orderTime.day == today.day)
        .toList();
  }

  /// Obtenir les commandes de cette semaine
  List<Order> getThisWeekOrders() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return _allOrders
        .where((order) =>
            order.orderTime.isAfter(startOfWeek) &&
            order.orderTime.isBefore(endOfWeek))
        .toList();
  }

  /// Obtenir les commandes de ce mois
  List<Order> getThisMonthOrders() {
    final now = DateTime.now();
    return _allOrders
        .where((order) =>
            order.orderTime.year == now.year &&
            order.orderTime.month == now.month)
        .toList();
  }

  /// Rechercher des commandes
  List<Order> searchOrders(String query) {
    if (query.isEmpty) return _allOrders;

    return _allOrders
        .where((order) =>
            order.id.toLowerCase().contains(query.toLowerCase()) ||
            // (order.userName?.toLowerCase().contains(query.toLowerCase()) ?? // userName n'est pas défini dans le modèle Order
            //         false) ||
            order.deliveryAddress.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  /// Obtenir les statistiques des commandes
  Map<String, dynamic> getOrderStats() {
    final totalOrders = _allOrders.length;
    final pendingOrders =
        _allOrders.where((o) => o.status == OrderStatus.pending).length;
    final confirmedOrders =
        _allOrders.where((o) => o.status == OrderStatus.confirmed).length;
    final preparingOrders =
        _allOrders.where((o) => o.status == OrderStatus.preparing).length;
    final readyOrders =
        _allOrders.where((o) => o.status == OrderStatus.ready).length;
    final pickedUpOrders =
        _allOrders.where((o) => o.status == OrderStatus.pickedUp).length;
    final onTheWayOrders =
        _allOrders.where((o) => o.status == OrderStatus.onTheWay).length;
    final deliveredOrders =
        _allOrders.where((o) => o.status == OrderStatus.delivered).length;
    final cancelledOrders =
        _allOrders.where((o) => o.status == OrderStatus.cancelled).length;
    final refundedOrders =
        _allOrders.where((o) => o.status == OrderStatus.refunded).length;
    final failedOrders =
        _allOrders.where((o) => o.status == OrderStatus.failed).length;

    final totalRevenue = _allOrders
        .where((o) => o.status == OrderStatus.delivered)
        .fold(
            0.0,
            (sum, order) =>
                sum +
                (order.total.isNaN || order.total.isInfinite
                    ? 0.0
                    : order.total));

    final averageOrderValue =
        deliveredOrders > 0 ? totalRevenue / deliveredOrders : 0.0;

    return {
      'total_orders': totalOrders,
      'pending_orders': pendingOrders,
      'confirmed_orders': confirmedOrders,
      'preparing_orders': preparingOrders,
      'ready_orders': readyOrders,
      'picked_up_orders': pickedUpOrders,
      'on_the_way_orders': onTheWayOrders,
      'delivered_orders': deliveredOrders,
      'cancelled_orders': cancelledOrders,
      'refunded_orders': refundedOrders,
      'failed_orders': failedOrders,
      'total_revenue':
          totalRevenue.isNaN || totalRevenue.isInfinite ? 0.0 : totalRevenue,
      'average_order_value':
          averageOrderValue.isNaN || averageOrderValue.isInfinite
              ? 0.0
              : averageOrderValue,
    };
  }

  /// Recharger les données (méthode publique)
  Future<void> refresh() async {
    debugPrint('🔄 Rafraîchissement manuel des commandes...');
    await _loadAllOrders();
  }

  /// Mettre à jour une commande
  Future<bool> updateOrder(String orderId, Map<String, dynamic> updates) async {
    try {
      _setLoading(true);

      updates['updated_at'] = DateTime.now().toIso8601String();
      await _supabase.from('orders').update(updates).eq('id', orderId);

      // Recharger les données
      await refresh();

      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('Error updating order: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Envoyer une notification à un client
  Future<bool> sendNotificationToCustomer(
      String orderId, String message) async {
    try {
      final order = _allOrders.firstWhere((o) => o.id == orderId);

      await _supabase.from('notifications').insert({
        'user_id': order.userId,
        'title': 'Mise à jour de commande',
        'message': message,
        'type': 'order_update',
        'data': {'order_id': orderId},
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      debugPrint('Error sending notification: $e');
      return false;
    }
  }

  /// Obtenir les commandes nécessitant une attention
  List<Order> getOrdersNeedingAttention() {
    final now = DateTime.now();
    return _allOrders.where((order) {
      // Commandes en attente depuis plus de 30 minutes
      if (order.status == OrderStatus.pending) {
        final timeDiff = now.difference(order.orderTime);
        if (timeDiff.inMinutes > 30) return true;
      }

      // Commandes annulées avec remboursement nécessaire
      if (order.status == OrderStatus.cancelled &&
          order.paymentMethod != PaymentMethod.cash) {
        return true;
      }

      return false;
    }).toList();
  }

  /// Obtenir les commandes programmées
  List<Order> getScheduledOrders() {
    final now = DateTime.now();
    return _allOrders.where((order) {
      return order.estimatedDeliveryTime != null &&
          order.estimatedDeliveryTime!.isAfter(now);
    }).toList();
  }

  /// Obtenir les commandes en retard
  List<Order> getDelayedOrders() {
    final now = DateTime.now();
    return _allOrders.where((order) {
      if (order.estimatedDeliveryTime == null) return false;
      if (order.status == OrderStatus.delivered) return false;
      if (order.status == OrderStatus.cancelled) return false;

      return now.isAfter(order.estimatedDeliveryTime!);
    }).toList();
  }

  /// Cloner une commande pour une nouvelle commande
  Future<bool> cloneOrder(String orderId) async {
    try {
      final originalOrder = _allOrders.firstWhere((o) => o.id == orderId);

      // Créer une nouvelle commande basée sur l'originale
      final newOrderData = {
        'user_id': originalOrder.userId,
        'subtotal': originalOrder.subtotal,
        'delivery_fee': originalOrder.deliveryFee,
        'total': originalOrder.total,
        'status': 'pending',
        'delivery_address': originalOrder.deliveryAddress,
        'delivery_notes': originalOrder.deliveryNotes,
        'promo_code': originalOrder.promoCode,
        'discount': originalOrder.discount,
        'payment_method':
            originalOrder.paymentMethod.toString().split('.').last,
        'special_instructions': originalOrder.specialInstructions,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('orders').insert(newOrderData).select().single();

      await refresh();
      return true;
    } catch (e) {
      debugPrint('Error cloning order: $e');
      return false;
    }
  }

  /// Archiver les anciennes commandes
  Future<bool> archiveOldOrders({int daysOld = 90}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

      final oldOrders = _allOrders.where((order) {
        return order.orderTime.isBefore(cutoffDate) &&
            (order.status == OrderStatus.delivered ||
                order.status == OrderStatus.cancelled);
      }).toList();

      debugPrint('Archiving ${oldOrders.length} old orders');

      // Dans un vrai système, on pourrait déplacer ces commandes vers une table d'archive
      // Pour l'instant, on les laisse dans la base mais on les filtre dans l'interface

      return true;
    } catch (e) {
      debugPrint('Error archiving orders: $e');
      return false;
    }
  }

  /// Obtenir le résumé journalier
  Map<String, dynamic> getDailySummary(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final dayOrders = filterByDateRange(dayStart, dayEnd);

    final deliveredOrders =
        dayOrders.where((o) => o.status == OrderStatus.delivered);
    final revenue =
        deliveredOrders.fold(0.0, (sum, order) => sum + order.total);
    final avgOrderValue =
        deliveredOrders.isNotEmpty ? revenue / deliveredOrders.length : 0.0;

    final statusBreakdown = <String, int>{};
    for (final order in dayOrders) {
      final statusName = order.status.displayName;
      statusBreakdown[statusName] = (statusBreakdown[statusName] ?? 0) + 1;
    }

    return {
      'date': date.toIso8601String(),
      'total_orders': dayOrders.length,
      'completed_orders': deliveredOrders.length,
      'revenue': revenue,
      'average_order_value': avgOrderValue,
      'status_breakdown': statusBreakdown,
    };
  }

  /// Obtenir les tendances de commandes
  Map<String, dynamic> getOrderTrends({int days = 7}) {
    final List<Map<String, dynamic>> trends = [];
    final now = DateTime.now();

    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final summary = getDailySummary(date);
      trends.add(summary);
    }

    // Calculer les tendances
    final firstDay = trends.first;
    final lastDay = trends.last;

    final orderGrowth = lastDay['total_orders'] - firstDay['total_orders'];
    final revenueGrowth = lastDay['revenue'] - firstDay['revenue'];

    final orderGrowthPercent = firstDay['total_orders'] > 0
        ? (orderGrowth / firstDay['total_orders']) * 100
        : 0.0;

    final revenueGrowthPercent = firstDay['revenue'] > 0
        ? (revenueGrowth / firstDay['revenue']) * 100
        : 0.0;

    return {
      'trends': trends,
      'order_growth': orderGrowth,
      'revenue_growth': revenueGrowth,
      'order_growth_percent': orderGrowthPercent,
      'revenue_growth_percent': revenueGrowthPercent,
      'period_days': days,
    };
  }

  /// Obtenir les heures de pointe
  Map<String, dynamic> getPeakHours() {
    final hourCounts = <int, int>{};

    for (final order in _allOrders) {
      final hour = order.orderTime.hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }

    int peakHour = 0;
    int maxOrders = 0;

    hourCounts.forEach((hour, count) {
      if (count > maxOrders) {
        maxOrders = count;
        peakHour = hour;
      }
    });

    return {
      'peak_hour': peakHour,
      'peak_orders': maxOrders,
      'hour_distribution': hourCounts,
    };
  }

  /// Obtenir les meilleurs clients
  List<Map<String, dynamic>> getTopCustomers({int limit = 10}) {
    final customerOrders = <String, List<Order>>{};

    for (final order in _allOrders) {
      if (order.status == OrderStatus.delivered) {
        customerOrders.putIfAbsent(order.userId, () => []).add(order);
      }
    }

    final customerStats = customerOrders.entries.map((entry) {
      final orders = entry.value;
      final totalSpent = orders.fold(0.0, (sum, order) => sum + order.total);

      return {
        'user_id': entry.key,
        'order_count': orders.length,
        'total_spent': totalSpent,
        'average_order_value': totalSpent / orders.length,
        'last_order_date': orders.last.orderTime.toIso8601String(),
      };
    }).toList();

    customerStats.sort((a, b) =>
        (b['total_spent'] as double).compareTo(a['total_spent'] as double));

    return customerStats.take(limit).toList();
  }

  /// Obtenir les produits les plus commandés
  Map<String, dynamic> getMostOrderedItems({int limit = 10}) {
    final itemCounts = <String, int>{};

    for (final order in _allOrders) {
      for (final item in order.items) {
        itemCounts[item.name] = (itemCounts[item.name] ?? 0) + item.quantity;
      }
    }

    final sortedItems = itemCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'top_items': sortedItems
          .take(limit)
          .map((e) => {
                'name': e.key,
                'quantity': e.value,
              })
          .toList(),
    };
  }

  /// Marquer une commande comme importante
  Future<bool> markOrderAsImportant(String orderId, bool important) async {
    try {
      await addInternalNote(
          orderId,
          important
              ? 'Commande marquée comme importante'
              : 'Commande non importante');
      return true;
    } catch (e) {
      debugPrint('Error marking order as important: $e');
      return false;
    }
  }

  /// Obtenir les prévisions de revenus
  Map<String, dynamic> getRevenueForecast({int daysAhead = 30}) {
    final stats = getOrderStats();
    final currentDailyAvg = stats['average_order_value'] as double;

    // Estimer les revenus futurs basés sur la moyenne actuelle
    final forecastedRevenue = currentDailyAvg * daysAhead;

    final growthRate = 0.05; // 5% de croissance estimée
    final optimistic = forecastedRevenue * (1 + growthRate);
    final pessimistic = forecastedRevenue * (1 - growthRate);

    return {
      'forecasted_revenue': forecastedRevenue,
      'optimistic_revenue': optimistic,
      'pessimistic_revenue': pessimistic,
      'days_ahead': daysAhead,
      'growth_rate': growthRate,
    };
  }

  /// Vérifier les anomalies dans les commandes
  List<Map<String, dynamic>> detectAnomalies() {
    final anomalies = <Map<String, dynamic>>[];

    // Vérifier les commandes avec des montants anormalement élevés
    final avgOrderValue = _allOrders.isNotEmpty
        ? _allOrders.fold(0.0, (sum, order) => sum + order.total) /
            _allOrders.length
        : 0.0;

    final highThreshold = avgOrderValue * 5; // 5x la moyenne

    for (final order in _allOrders) {
      if (order.total > highThreshold) {
        anomalies.add({
          'order_id': order.id,
          'type': 'high_amount',
          'message':
              'Montant anormalement élevé: ${PriceFormatter.format(order.total)}',
          'severity': 'medium',
        });
      }

      // Vérifier les commandes en attente depuis trop longtemps
      final timeDiff = DateTime.now().difference(order.orderTime);
      if (order.status == OrderStatus.pending && timeDiff.inHours > 2) {
        anomalies.add({
          'order_id': order.id,
          'type': 'stuck_order',
          'message': 'Commande en attente depuis ${timeDiff.inHours} heures',
          'severity': 'high',
        });
      }
    }

    return anomalies;
  }

  /// Synchroniser avec la base de données
  Future<void> syncWithDatabase() async {
    await refresh();
    debugPrint('Order data synchronized with database');
  }

  /// Obtenir les statistiques de livraison
  Map<String, dynamic> getDeliveryStats() {
    final deliveredOrders = _allOrders
        .where((o) =>
            o.status == OrderStatus.delivered &&
            o.estimatedDeliveryTime != null)
        .toList();

    if (deliveredOrders.isEmpty) {
      return {
        'on_time_rate': 0.0,
        'average_delivery_time': 0.0,
        'fastest_delivery': 0.0,
        'slowest_delivery': 0.0,
      };
    }

    double totalDeliveryTime = 0.0;
    double fastestDelivery = double.infinity;
    double slowestDelivery = 0.0;
    int onTimeCount = 0;

    for (final order in deliveredOrders) {
      final deliveryTime = order.estimatedDeliveryTime!
          .difference(order.orderTime)
          .inMinutes
          .toDouble();
      totalDeliveryTime += deliveryTime;

      if (deliveryTime < fastestDelivery) fastestDelivery = deliveryTime;
      if (deliveryTime > slowestDelivery) slowestDelivery = deliveryTime;

      // Considérer à l'heure si livré dans les 60 minutes
      if (deliveryTime <= 60) onTimeCount++;
    }

    final avgDeliveryTime = totalDeliveryTime / deliveredOrders.length;
    final onTimeRate = (onTimeCount / deliveredOrders.length) * 100;

    return {
      'on_time_rate': onTimeRate,
      'average_delivery_time': avgDeliveryTime,
      'fastest_delivery':
          fastestDelivery == double.infinity ? 0.0 : fastestDelivery,
      'slowest_delivery': slowestDelivery,
    };
  }

  /// Obtenir les statistiques de performance
  Map<String, dynamic> getPerformanceStats() {
    final deliveryStats = getDeliveryStats();

    // Calculer le taux de livraison à l'heure (normalisé entre 0 et 1)
    final onTimeDeliveryRate =
        (deliveryStats['on_time_rate'] as num?)?.toDouble() ?? 0.0;
    final normalizedOnTimeRate = onTimeDeliveryRate / 100.0;

    // Calculer la satisfaction client (basée sur le taux de livraison à l'heure et les commandes annulées)
    final stats = getOrderStats();
    final totalOrders = stats['total_orders'] as int? ?? 0;
    final cancelledOrders = stats['cancelled_orders'] as int? ?? 0;
    final satisfactionBase =
        totalOrders > 0 ? 1.0 - (cancelledOrders / totalOrders) : 1.0;
    final customerSatisfaction =
        (satisfactionBase * 0.7 + normalizedOnTimeRate * 0.3) *
            5.0; // Échelle de 0 à 5

    return {
      'average_delivery_time': deliveryStats['average_delivery_time'] ?? 0.0,
      'on_time_delivery_rate': normalizedOnTimeRate.clamp(0.0, 1.0),
      'customer_satisfaction': customerSatisfaction.clamp(0.0, 5.0),
      'fastest_delivery': deliveryStats['fastest_delivery'] ?? 0.0,
      'slowest_delivery': deliveryStats['slowest_delivery'] ?? 0.0,
    };
  }
}
