import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_service.dart';
import '../utils/price_formatter.dart';

/// Service pour gérer l'assignation des livreurs aux commandes
class DeliveryAssignmentService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final DatabaseService _databaseService = DatabaseService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    Future.microtask(() => notifyListeners());
  }

  /// Récupère tous les livreurs disponibles (utilisateurs avec rôle 'delivery')
  Future<List<Map<String, dynamic>>> getAvailableDeliveryPersons() async {
    try {
      _setLoading(true);
      debugPrint('🔍 Récupération des livreurs disponibles...');

      final response = await _supabase
          .from('users')
          .select('id, name, email, phone, is_online, last_seen')
          .eq('role', 'delivery')
          .eq('is_active', true)
          .order('is_online', ascending: false)
          .order('name');

      final List<Map<String, dynamic>> deliveryPersons =
          List<Map<String, dynamic>>.from(response);

      debugPrint('✅ ${deliveryPersons.length} livreur(s) trouvé(s)');
      return deliveryPersons;
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des livreurs: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Récupère les livreurs disponibles (en ligne et non occupés)
  Future<List<Map<String, dynamic>>> getOnlineDeliveryPersons() async {
    try {
      _setLoading(true);
      debugPrint('🔍 Récupération des livreurs en ligne...');

      // Récupérer les livreurs en ligne
      final onlineDeliverersResponse = await _supabase
          .from('users')
          .select('id, name, email, phone, is_online, last_seen')
          .eq('role', 'delivery')
          .eq('is_active', true)
          .eq('is_online', true)
          .order('name');

      final onlineDeliverers = List<Map<String, dynamic>>.from(onlineDeliverersResponse);

      // Pour chaque livreur, vérifier le nombre de livraisons actives
      final List<Map<String, dynamic>> availableDeliverers = [];

      for (var deliverer in onlineDeliverers) {
        final delivererId = deliverer['id'] as String?;
        if (delivererId == null) continue;

        // Compter les livraisons actives
        final activeDeliveriesResponse = await _supabase
            .from('orders')
            .select('id')
            .eq('delivery_person_id', delivererId)
            .inFilter('status', [
          'confirmed',
          'preparing',
          'ready',
          'picked_up',
          'on_the_way',
        ]);

        final activeDeliveries = List.from(activeDeliveriesResponse);
        final deliveryCount = activeDeliveries.length;

        availableDeliverers.add({
          ...deliverer,
          'active_deliveries_count': deliveryCount,
          'is_available': deliveryCount < 3, // Max 3 livraisons simultanées
        });
      }

      // Trier par disponibilité (disponible d'abord), puis par nombre de livraisons
      availableDeliverers.sort((a, b) {
        final aAvailable = a['is_available'] as bool;
        final bAvailable = b['is_available'] as bool;

        if (aAvailable != bAvailable) {
          return aAvailable ? -1 : 1;
        }

        final aCount = a['active_deliveries_count'] as int;
        final bCount = b['active_deliveries_count'] as int;
        return aCount.compareTo(bCount);
      });

      debugPrint('✅ ${availableDeliverers.length} livreur(s) en ligne trouvé(s)');
      return availableDeliverers;
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des livreurs en ligne: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Assigne un livreur à une commande
  Future<bool> assignDeliveryPerson({
    required String orderId,
    required String deliveryPersonId,
    bool sendNotification = true,
  }) async {
    try {
      _setLoading(true);
      debugPrint(
        '📦 Assignation du livreur $deliveryPersonId à la commande $orderId...',
      );

      // Vérifier que le livreur existe et est actif
      final deliverer = await _supabase
          .from('users')
          .select('id, name, role, is_active')
          .eq('id', deliveryPersonId)
          .eq('role', 'delivery')
          .single();

        if (deliverer['is_active'] != true) {
          throw Exception('Le livreur sélectionné n\'est pas disponible');
        }

        // Vérifier que la commande existe et peut être assignée
        final orderResponse = await _supabase
            .from('orders')
            .select('id, status, delivery_person_id')
            .eq('id', orderId)
            .maybeSingle();

        final order = orderResponse;
        if (order == null) {
          throw Exception('Commande introuvable');
        }

      final currentStatus = order['status'] as String?;
      if (currentStatus != 'pending' &&
          currentStatus != 'confirmed' &&
          currentStatus != 'ready') {
        throw Exception(
          'La commande ne peut pas être assignée dans son état actuel ($currentStatus)',
        );
      }

      // Assigner le livreur
      await _supabase.from('orders').update({
        'delivery_person_id': deliveryPersonId,
        'status': 'assigned',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      // Envoyer une notification au livreur si demandé
      if (sendNotification) {
        await _sendAssignmentNotification(orderId, deliveryPersonId);
      }

      debugPrint('✅ Livreur assigné avec succès');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'assignation: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Réassigner une commande à un autre livreur
  Future<bool> reassignDeliveryPerson({
    required String orderId,
    required String newDeliveryPersonId,
    String? reason,
  }) async {
    try {
      _setLoading(true);
      debugPrint(
        '🔄 Réassignation de la commande $orderId au livreur $newDeliveryPersonId...',
      );

      // Récupérer l'ancien livreur
      final order = await _supabase
          .from('orders')
          .select('delivery_person_id')
          .eq('id', orderId)
          .single();

      final oldDeliveryPersonId = order['delivery_person_id'] as String?;

      // Réassigner
      await assignDeliveryPerson(
        orderId: orderId,
        deliveryPersonId: newDeliveryPersonId,
        sendNotification: true,
      );

      // Notifier l'ancien livreur si présent
      if (oldDeliveryPersonId != null &&
          oldDeliveryPersonId != newDeliveryPersonId) {
        await _sendUnassignmentNotification(orderId, oldDeliveryPersonId, reason);
      }

      debugPrint('✅ Commande réassignée avec succès');
      return true;
    } catch (e) {
      debugPrint('❌ Erreur lors de la réassignation: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Désassigne un livreur d'une commande
  Future<bool> unassignDeliveryPerson(String orderId, {String? reason}) async {
    try {
      _setLoading(true);
      debugPrint('🔓 Désassignation de la commande $orderId...');

      // Récupérer le livreur actuel
      final order = await _supabase
          .from('orders')
          .select('delivery_person_id, status')
          .eq('id', orderId)
          .single();

      final deliveryPersonId = order['delivery_person_id'] as String?;

      // Retirer l'assignation
      await _supabase.from('orders').update({
        'delivery_person_id': null,
        'status': 'ready', // Retour au statut "prête"
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      // Notifier le livreur si présent
      if (deliveryPersonId != null) {
        await _sendUnassignmentNotification(orderId, deliveryPersonId, reason);
      }

      debugPrint('✅ Livreur désassigné avec succès');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Erreur lors de la désassignation: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Récupère les commandes assignées à un livreur
  Future<List<Map<String, dynamic>>> getAssignedOrders(String deliveryPersonId) async {
    try {
      _setLoading(true);

      final response = await _supabase
          .from('orders')
          .select('''
            *,
            order_items(*),
            users!orders_user_id_fkey(id, name, email, phone)
          ''')
          .eq('delivery_person_id', deliveryPersonId)
          .inFilter('status', [
        'assigned',
        'accepted',
        'picked_up',
        'on_the_way',
      ])
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des commandes assignées: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Récupère l'historique des livraisons d'un livreur
  Future<List<Map<String, dynamic>>> getDeliveryHistory(
    String deliveryPersonId, {
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      _setLoading(true);

      // Construire la requête de base
      var query = _supabase
          .from('orders')
          .select('''
            *,
            order_items(*),
            users!orders_user_id_fkey(id, name, email, phone)
          ''')
          .eq('delivery_person_id', deliveryPersonId)
          .inFilter('status', ['delivered', 'cancelled']);

      // Ajouter les filtres de date
      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      // Ajouter le tri et la limite
      dynamic finalQuery = query.order('created_at', ascending: false);
      if (limit != null && limit > 0) {
        finalQuery = (finalQuery as dynamic).limit(limit);
      }

      final response = await finalQuery;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération de l\'historique: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Récupère les statistiques d'un livreur
  Future<Map<String, dynamic>> getDeliveryPersonStats(String deliveryPersonId) async {
    try {
      _setLoading(true);

      // Récupérer toutes les commandes livrées par ce livreur
      final deliveredOrders = await _supabase
          .from('orders')
          .select('id, total, created_at, delivered_at, estimated_delivery_time')
          .eq('delivery_person_id', deliveryPersonId)
          .eq('status', 'delivered');

      final totalDeliveries = deliveredOrders.length;
      final totalRevenue = deliveredOrders.fold<double>(
        0.0,
        (sum, order) => sum + ((order['total'] as num?)?.toDouble() ?? 0.0),
      );

      // Calculer le temps de livraison moyen
      double totalDeliveryTime = 0.0;
      int onTimeCount = 0;

      for (var order in deliveredOrders) {
        final createdAt = DateTime.parse(order['created_at'] as String);
        final deliveredAt = order['delivered_at'] != null
            ? DateTime.parse(order['delivered_at'] as String)
            : createdAt;
        final estimatedTime = order['estimated_delivery_time'] != null
            ? DateTime.parse(order['estimated_delivery_time'] as String)
            : null;

        final deliveryTime = deliveredAt.difference(createdAt).inMinutes.toDouble();
        totalDeliveryTime += deliveryTime;

        if (estimatedTime != null &&
            deliveredAt.isBefore(estimatedTime.add(const Duration(minutes: 15)))) {
          onTimeCount++;
        }
      }

      final avgDeliveryTime =
          totalDeliveries > 0 ? totalDeliveryTime / totalDeliveries : 0.0;
      final onTimeRate =
          totalDeliveries > 0 ? (onTimeCount / totalDeliveries) * 100 : 0.0;

      // Commandes actives
      final activeOrders = await _supabase
          .from('orders')
          .select('id')
          .eq('delivery_person_id', deliveryPersonId)
          .inFilter('status', [
        'assigned',
        'accepted',
        'picked_up',
        'on_the_way',
      ]);

      // Calculer la note moyenne du livreur
      double averageRating = 0.0;
      try {
        // Récupérer le driver_id à partir du user_id
        final driverResponse = await _supabase
            .from('drivers')
            .select('id')
            .eq('user_id', deliveryPersonId)
            .maybeSingle();

        if (driverResponse != null) {
          final driverId = driverResponse['id'] as String;

          // Récupérer toutes les notes pour ce livreur
          final ratingsResponse = await _supabase
              .from('driver_ratings')
              .select('rating_average')
              .eq('driver_id', driverId);

          final ratings = List<Map<String, dynamic>>.from(ratingsResponse);

          if (ratings.isNotEmpty) {
            final totalRating = ratings.fold<double>(
              0.0,
              (sum, rating) =>
                  sum + ((rating['rating_average'] as num?)?.toDouble() ?? 0.0),
            );
            averageRating = totalRating / ratings.length;
          }
        }
      } catch (e) {
        debugPrint('⚠️ Erreur lors du calcul de la note moyenne: $e');
        // On continue avec averageRating = 0.0 si une erreur survient
      }

      return {
        'total_deliveries': totalDeliveries,
        'active_deliveries': activeOrders.length,
        'total_revenue': totalRevenue,
        'average_delivery_time': avgDeliveryTime,
        'on_time_rate': onTimeRate,
        'average_rating': averageRating,
      };
    } catch (e) {
      debugPrint('❌ Erreur lors du calcul des statistiques: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Envoie une notification d'assignation au livreur
  Future<void> _sendAssignmentNotification(
    String orderId,
    String deliveryPersonId,
  ) async {
    try {
      final order = await _databaseService.getOrderDetailsWithMenuItems(orderId);
      if (order == null) return;

      final orderNumber = orderId.substring(0, 8);
      final total = order['total'] ?? 0.0;
      final address = order['delivery_address'] ?? '';

      await _supabase.from('notifications').insert({
        'user_id': deliveryPersonId,
        'title': 'Nouvelle livraison assignée',
        'message':
            'Une nouvelle commande (#$orderNumber) de ${PriceFormatter.format(total)} vous a été assignée. Adresse: $address',
        'type': 'order_assignment',
        'data': {'order_id': orderId},
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Notification d\'assignation envoyée');
    } catch (e) {
      debugPrint('⚠️ Erreur lors de l\'envoi de la notification: $e');
    }
  }

  /// Envoie une notification de désassignation au livreur
  Future<void> _sendUnassignmentNotification(
    String orderId,
    String deliveryPersonId,
    String? reason,
  ) async {
    try {
      final orderNumber = orderId.substring(0, 8);
      final message = reason != null
          ? 'La commande #$orderNumber vous a été retirée. Raison: $reason'
          : 'La commande #$orderNumber vous a été retirée.';

      await _supabase.from('notifications').insert({
        'user_id': deliveryPersonId,
        'title': 'Commande retirée',
        'message': message,
        'type': 'order_unassignment',
        'data': {'order_id': orderId},
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Notification de désassignation envoyée');
    } catch (e) {
      debugPrint('⚠️ Erreur lors de l\'envoi de la notification: $e');
    }
  }

  /// Vérifie si un livreur peut accepter une nouvelle livraison
  Future<bool> canAcceptDelivery(String deliveryPersonId) async {
    try {
      final activeOrders = await _supabase
          .from('orders')
          .select('id')
          .eq('delivery_person_id', deliveryPersonId)
          .inFilter('status', [
        'assigned',
        'accepted',
        'picked_up',
        'on_the_way',
      ]);

      // Maximum 3 livraisons simultanées
      return activeOrders.length < 3;
    } catch (e) {
      debugPrint('❌ Erreur lors de la vérification: $e');
      return false;
    }
  }

  /// Auto-assigne une commande au meilleur livreur disponible
  Future<String?> autoAssignDelivery(String orderId) async {
    try {
      _setLoading(true);
      debugPrint('🤖 Auto-assignation de la commande $orderId...');

      // Récupérer les livreurs disponibles
      final availableDeliverers = await getOnlineDeliveryPersons();

      if (availableDeliverers.isEmpty) {
        debugPrint('⚠️ Aucun livreur disponible pour l\'auto-assignation');
        return null;
      }

      // Sélectionner le livreur avec le moins de livraisons actives
      final bestDeliverer = availableDeliverers
          .where((d) => d['is_available'] == true)
          .firstOrNull;

      if (bestDeliverer == null) {
        debugPrint('⚠️ Aucun livreur disponible pour l\'auto-assignation');
        return null;
      }

      final deliveryPersonId = bestDeliverer['id'] as String;

      // Assigner
      await assignDeliveryPerson(
        orderId: orderId,
        deliveryPersonId: deliveryPersonId,
        sendNotification: true,
      );

      debugPrint('✅ Auto-assignation réussie au livreur $deliveryPersonId');
      return deliveryPersonId;
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'auto-assignation: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }
}
