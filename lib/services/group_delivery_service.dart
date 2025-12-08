import 'package:flutter/foundation.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/supabase/supabase_config.dart';
import 'package:elcora_fast/services/geocoding_service.dart';

class GroupDeliveryRequest {
  final String id;
  final String initiatorUserId;
  final String deliveryAddress;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final DateTime preferredTime;
  final double maxDeliveryRadius; // in meters
  final List<String> joinedUserIds;
  final double sharedDeliveryCost;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String status; // 'open', 'closed', 'delivering', 'completed'
  final List<String> orderIds;

  GroupDeliveryRequest({
    required this.id,
    required this.initiatorUserId,
    required this.deliveryAddress,
    required this.preferredTime, required this.maxDeliveryRadius, required this.joinedUserIds, required this.sharedDeliveryCost, required this.createdAt, required this.expiresAt, required this.status, required this.orderIds, this.deliveryLatitude,
    this.deliveryLongitude,
  });
}

class ScheduledOrder {
  final String id;
  final String userId;
  final DateTime scheduledFor;
  final Order order;
  final String status; // 'scheduled', 'preparing', 'ready', 'delivered'
  final bool isRecurring;
  final String? recurrencePattern; // 'daily', 'weekly', 'monthly'
  final DateTime? recurrenceEndDate;

  ScheduledOrder({
    required this.id,
    required this.userId,
    required this.scheduledFor,
    required this.order,
    required this.status,
    this.isRecurring = false,
    this.recurrencePattern,
    this.recurrenceEndDate,
  });
}

class GroupDeliveryService extends ChangeNotifier {
  static final GroupDeliveryService _instance =
      GroupDeliveryService._internal();
  factory GroupDeliveryService() => _instance;
  GroupDeliveryService._internal();

  final GeocodingService _geocodingService = GeocodingService();
  List<GroupDeliveryRequest> _activeRequests = [];
  List<ScheduledOrder> _scheduledOrders = [];
  bool _isInitialized = false;

  List<GroupDeliveryRequest> get activeRequests =>
      List.unmodifiable(_activeRequests);
  List<ScheduledOrder> get scheduledOrders =>
      List.unmodifiable(_scheduledOrders);
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadGroupDeliveryData();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing Group Delivery Service: $e');
    }
  }

  Future<void> _loadGroupDeliveryData() async {
    try {
      // Load group orders from Supabase with GPS coordinates
      final groupOrdersResponse = await SupabaseConfig.client
          .from('orders')
          .select('''
            id,
            user_id,
            group_id,
            delivery_address,
            delivery_latitude,
            delivery_longitude,
            estimated_delivery_time,
            delivery_fee,
            created_at,
            status
          ''')
          .eq('is_group_order', true)
          .inFilter('status', ['pending', 'confirmed', 'preparing'])
          .order('created_at', ascending: false);

      if (groupOrdersResponse.isNotEmpty) {
        // Group orders by group_id
        final Map<String, List<Map<String, dynamic>>> groupedOrders = {};
        
        for (final orderData in groupOrdersResponse) {
          try {
            final orderMap = Map<String, dynamic>.from(orderData);
            final groupId = orderMap['group_id'] as String?;
            
            if (groupId != null) {
              if (!groupedOrders.containsKey(groupId)) {
                groupedOrders[groupId] = [];
              }
              groupedOrders[groupId]!.add(orderMap);
            }
          } catch (e) {
            debugPrint('❌ Error parsing group order: $e');
          }
        }

        // Convert grouped orders to GroupDeliveryRequest objects
        for (final entry in groupedOrders.entries) {
          final groupId = entry.key;
          final orders = entry.value;
          
          if (orders.isEmpty) continue;

          // Use the first order as the base (initiator)
          final firstOrder = orders.first;
          final allUserIds = orders.map((o) => o['user_id'] as String).toSet().toList();
          final allOrderIds = orders.map((o) => o['id'] as String).toList();

          // Get coordinates from the first order (they should be the same for group orders)
          final latitude = firstOrder['delivery_latitude'] != null
              ? (firstOrder['delivery_latitude'] as num).toDouble()
              : null;
          final longitude = firstOrder['delivery_longitude'] != null
              ? (firstOrder['delivery_longitude'] as num).toDouble()
              : null;

          // If coordinates are missing, try to geocode the address
          double? finalLatitude = latitude;
          double? finalLongitude = longitude;
          
          if (finalLatitude == null || finalLongitude == null) {
            final address = firstOrder['delivery_address'] as String? ?? '';
            if (address.isNotEmpty) {
              final coords = await _geocodingService.geocodeAddress(address);
              if (coords != null) {
                finalLatitude = coords.latitude;
                finalLongitude = coords.longitude;
                
                // Update the order in Supabase with the geocoded coordinates
                try {
                  await SupabaseConfig.client
                      .from('orders')
                      .update({
                        'delivery_latitude': finalLatitude,
                        'delivery_longitude': finalLongitude,
                      })
                      .eq('id', firstOrder['id'] as String);
                } catch (e) {
                  debugPrint('⚠️ Error updating order coordinates: $e');
                }
              }
            }
          }

          final request = GroupDeliveryRequest(
            id: groupId,
            initiatorUserId: firstOrder['user_id'] as String,
            deliveryAddress: firstOrder['delivery_address'] as String? ?? '',
            deliveryLatitude: finalLatitude,
            deliveryLongitude: finalLongitude,
            preferredTime: firstOrder['estimated_delivery_time'] != null
                ? DateTime.parse(firstOrder['estimated_delivery_time'] as String)
                : DateTime.now().add(const Duration(minutes: 30)),
            maxDeliveryRadius: 2000.0, // Default 2km
            joinedUserIds: allUserIds,
            sharedDeliveryCost: _calculateSharedDeliveryCost(allUserIds.length),
            createdAt: firstOrder['created_at'] != null
                ? DateTime.parse(firstOrder['created_at'] as String)
                : DateTime.now(),
            expiresAt: DateTime.now().add(const Duration(minutes: 30)),
            status: 'open',
            orderIds: allOrderIds,
          );

          _activeRequests.add(request);
        }
      }

      // Load scheduled orders (can be stored in a separate table or in orders with scheduled status)
      // For now, we'll keep scheduled orders in memory
      _scheduledOrders = [];

      debugPrint('✅ Loaded ${_activeRequests.length} group delivery requests from Supabase');
    } catch (e) {
      debugPrint('❌ Error loading group delivery data from Supabase: $e');
      // Fallback to empty data
      _activeRequests = [];
      _scheduledOrders = [];
    }
  }

  // Group Delivery Functions

  /// Create a new group delivery request
  Future<String?> createGroupDeliveryRequest({
    required String initiatorUserId,
    required String deliveryAddress,
    required DateTime preferredTime,
    required double maxDeliveryRadius,
    required String orderId,
  }) async {
    try {
      // Generate UUID for group ID
      final String groupId = DateTime.now().millisecondsSinceEpoch.toString();

      // Geocode the delivery address to get coordinates
      final deliveryCoords = await _geocodingService.geocodeAddress(deliveryAddress);
      double? latitude;
      double? longitude;
      
      if (deliveryCoords != null) {
        latitude = deliveryCoords.latitude;
        longitude = deliveryCoords.longitude;
      }

      // Update the order in Supabase to mark it as a group order
      try {
        await SupabaseConfig.client
            .from('orders')
            .update({
              'is_group_order': true,
              'group_id': groupId,
              'delivery_latitude': latitude,
              'delivery_longitude': longitude,
            })
            .eq('id', orderId);
      } catch (e) {
        debugPrint('⚠️ Error updating order in Supabase: $e');
      }

      final GroupDeliveryRequest request = GroupDeliveryRequest(
        id: groupId,
        initiatorUserId: initiatorUserId,
        deliveryAddress: deliveryAddress,
        deliveryLatitude: latitude,
        deliveryLongitude: longitude,
        preferredTime: preferredTime,
        maxDeliveryRadius: maxDeliveryRadius,
        joinedUserIds: [initiatorUserId],
        sharedDeliveryCost: _calculateBaseDeliveryCost(),
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
        status: 'open',
        orderIds: [orderId],
      );

      _activeRequests.add(request);
      notifyListeners();

      debugPrint('✅ Created group delivery request: $groupId');
      return groupId;
    } catch (e) {
      debugPrint('❌ Error creating group delivery request: $e');
      return null;
    }
  }

  /// Find nearby group delivery requests using GPS coordinates
  Future<List<GroupDeliveryRequest>> findNearbyRequests(
    String userAddress, {
    double maxDistance = 1000,
    double? userLatitude,
    double? userLongitude,
  }) async {
    final nearbyRequests = <GroupDeliveryRequest>[];

    // Get user coordinates if not provided
    LatLng? userCoords;
    if (userLatitude != null && userLongitude != null) {
      userCoords = LatLng(userLatitude, userLongitude);
    } else {
      // Geocode user address if coordinates not provided
      userCoords = await _geocodingService.geocodeAddress(userAddress);
      if (userCoords == null) {
        debugPrint('⚠️ Could not geocode user address: $userAddress');
        return nearbyRequests;
      }
    }

    for (final request in _activeRequests) {
      if (request.status == 'open' &&
          request.expiresAt.isAfter(DateTime.now())) {
        double distance;
        
        // Use GPS coordinates if available (faster and more accurate)
        if (request.deliveryLatitude != null && 
            request.deliveryLongitude != null) {
          final requestCoords = LatLng(
            request.deliveryLatitude!,
            request.deliveryLongitude!,
          );
          distance = _calculateDistanceFromCoords(userCoords, requestCoords);
        } else {
          // Fallback to address-based calculation
          distance = await _calculateDistance(userAddress, request.deliveryAddress);
        }
        
        if (distance <= maxDistance) {
          nearbyRequests.add(request);
        }
      }
    }

    return nearbyRequests;
  }

  /// Join an existing group delivery request
  Future<bool> joinGroupDelivery(
      String requestId, String userId, String orderId,) async {
    try {
      final int index = _activeRequests.indexWhere((r) => r.id == requestId);
      if (index == -1) return false;

      final request = _activeRequests[index];
      if (request.status != 'open' ||
          request.expiresAt.isBefore(DateTime.now())) {
        return false;
      }

      // Update request
      final List<String> newJoinedUsers = List.from(request.joinedUserIds)
        ..add(userId);
      final List<String> newOrderIds = List.from(request.orderIds)..add(orderId);
      final double newSharedCost =
          _calculateSharedDeliveryCost(newJoinedUsers.length);

      final GroupDeliveryRequest updatedRequest = GroupDeliveryRequest(
        id: request.id,
        initiatorUserId: request.initiatorUserId,
        deliveryAddress: request.deliveryAddress,
        preferredTime: request.preferredTime,
        maxDeliveryRadius: request.maxDeliveryRadius,
        joinedUserIds: newJoinedUsers,
        sharedDeliveryCost: newSharedCost,
        createdAt: request.createdAt,
        expiresAt: request.expiresAt,
        status: request.status,
        orderIds: newOrderIds,
      );

      _activeRequests[index] = updatedRequest;
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error joining group delivery: $e');
      return false;
    }
  }

  /// Leave a group delivery request
  Future<bool> leaveGroupDelivery(String requestId, String userId) async {
    try {
      final int index = _activeRequests.indexWhere((r) => r.id == requestId);
      if (index == -1) return false;

      final request = _activeRequests[index];

      if (request.initiatorUserId == userId) {
        // If initiator leaves, cancel the request
        _activeRequests.removeAt(index);
      } else {
        final List<String> newJoinedUsers = List.from(request.joinedUserIds)
          ..remove(userId);
        final List<String> newOrderIds = List.from(request.orderIds);

        // Remove user's order (simplified - in real implementation, need to match user to order)
        if (newOrderIds.isNotEmpty) newOrderIds.removeLast();

        final double newSharedCost =
            _calculateSharedDeliveryCost(newJoinedUsers.length);

        final GroupDeliveryRequest updatedRequest = GroupDeliveryRequest(
          id: request.id,
          initiatorUserId: request.initiatorUserId,
          deliveryAddress: request.deliveryAddress,
          deliveryLatitude: request.deliveryLatitude,
          deliveryLongitude: request.deliveryLongitude,
          preferredTime: request.preferredTime,
          maxDeliveryRadius: request.maxDeliveryRadius,
          joinedUserIds: newJoinedUsers,
          sharedDeliveryCost: newSharedCost,
          createdAt: request.createdAt,
          expiresAt: request.expiresAt,
          status: request.status,
          orderIds: newOrderIds,
        );

        _activeRequests[index] = updatedRequest;
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error leaving group delivery: $e');
      return false;
    }
  }

  // Scheduled Order Functions

  /// Schedule an order for later
  Future<String?> scheduleOrder({
    required String userId,
    required DateTime scheduledTime,
    required Order order,
    bool isRecurring = false,
    String? recurrencePattern,
    DateTime? recurrenceEndDate,
  }) async {
    try {
      final String scheduleId = DateTime.now().millisecondsSinceEpoch.toString();

      final ScheduledOrder scheduledOrder = ScheduledOrder(
        id: scheduleId,
        userId: userId,
        scheduledFor: scheduledTime,
        order: order,
        status: 'scheduled',
        isRecurring: isRecurring,
        recurrencePattern: recurrencePattern,
        recurrenceEndDate: recurrenceEndDate,
      );

      _scheduledOrders.add(scheduledOrder);
      notifyListeners();

      return scheduleId;
    } catch (e) {
      debugPrint('Error scheduling order: $e');
      return null;
    }
  }

  /// Cancel a scheduled order
  Future<bool> cancelScheduledOrder(String scheduleId) async {
    try {
      _scheduledOrders.removeWhere((order) => order.id == scheduleId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error canceling scheduled order: $e');
      return false;
    }
  }

  /// Update a scheduled order
  Future<bool> updateScheduledOrder(String scheduleId, DateTime newTime) async {
    try {
      final int index =
          _scheduledOrders.indexWhere((order) => order.id == scheduleId);
      if (index == -1) return false;

      final order = _scheduledOrders[index];
      final ScheduledOrder updatedOrder = ScheduledOrder(
        id: order.id,
        userId: order.userId,
        scheduledFor: newTime,
        order: order.order,
        status: order.status,
        isRecurring: order.isRecurring,
        recurrencePattern: order.recurrencePattern,
        recurrenceEndDate: order.recurrenceEndDate,
      );

      _scheduledOrders[index] = updatedOrder;
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error updating scheduled order: $e');
      return false;
    }
  }

  /// Get scheduled orders for a user
  List<ScheduledOrder> getUserScheduledOrders(String userId) {
    return _scheduledOrders.where((order) => order.userId == userId).toList();
  }

  /// Get upcoming scheduled orders (next 24 hours)
  List<ScheduledOrder> getUpcomingScheduledOrders() {
    final DateTime now = DateTime.now();
    final DateTime tomorrow = now.add(const Duration(hours: 24));

    return _scheduledOrders
        .where((order) =>
            order.scheduledFor.isAfter(now) &&
            order.scheduledFor.isBefore(tomorrow) &&
            order.status == 'scheduled',)
        .toList();
  }

  // Helper Functions

  /// Calculate distance between two addresses using GPS coordinates
  /// This method geocodes addresses if coordinates are not available
  Future<double> _calculateDistance(String address1, String address2) async {
    try {
      if (address1 == address2) return 0.0;

      // Geocode both addresses to get coordinates
      final coords1 = await _geocodingService.geocodeAddress(address1);
      final coords2 = await _geocodingService.geocodeAddress(address2);

      if (coords1 == null || coords2 == null) {
        debugPrint('⚠️ Could not geocode addresses for distance calculation');
        debugPrint('   Address 1: $address1');
        debugPrint('   Address 2: $address2');
        // Fallback: return a default distance if geocoding fails
        return 1000.0; // 1km default
      }

      // Calculate distance using Haversine formula (returns distance in kilometers)
      final distanceKm = _geocodingService.calculateDistance(coords1, coords2);
      
      // Convert to meters
      return distanceKm * 1000;
    } catch (e) {
      debugPrint('❌ Error calculating distance: $e');
      // Fallback distance
      return 1000.0;
    }
  }

  /// Calculate distance between two coordinates using Haversine formula (synchronous version)
  /// This is the preferred method as it uses real GPS coordinates directly
  double _calculateDistanceFromCoords(LatLng coords1, LatLng coords2) {
    try {
      // Use the GeocodingService's Haversine formula implementation
      final distanceKm = _geocodingService.calculateDistance(coords1, coords2);
      return distanceKm * 1000; // Convert to meters
    } catch (e) {
      debugPrint('❌ Error calculating distance from coordinates: $e');
      return 1000.0;
    }
  }

  double _calculateBaseDeliveryCost() {
    return 2000.0; // Base delivery cost in CFA
  }

  double _calculateSharedDeliveryCost(int numberOfParticipants) {
    final double baseCost = _calculateBaseDeliveryCost();
    return baseCost / numberOfParticipants;
  }

  /// Get delivery time slots for scheduling
  List<Map<String, dynamic>> getAvailableTimeSlots() {
    final List<Map<String, dynamic>> slots = [];
    final DateTime now = DateTime.now();

    // Generate slots for the next 7 days
    for (int day = 0; day < 7; day++) {
      final DateTime date = now.add(Duration(days: day));

      // Skip past hours for today
      final int startHour = day == 0 ? now.hour + 1 : 11;

      for (int hour = startHour; hour <= 22; hour++) {
        if (hour >= 11) {
          // Restaurant opens at 11 AM
          final DateTime slotTime =
              DateTime(date.year, date.month, date.day, hour);

          slots.add({
            'time': slotTime,
            'label': _formatTimeSlot(slotTime),
            'available': _isTimeSlotAvailable(slotTime),
          });
        }
      }
    }

    return slots;
  }

  String _formatTimeSlot(DateTime time) {
    final String dayName = _getDayName(time.weekday);
    final String timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    if (DateTime.now().day == time.day) {
      return 'Aujourd\'hui à $timeStr';
    } else if (DateTime.now().add(const Duration(days: 1)).day == time.day) {
      return 'Demain à $timeStr';
    } else {
      return '$dayName ${time.day}/${time.month} à $timeStr';
    }
  }

  String _getDayName(int weekday) {
    const days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    return days[weekday - 1];
  }

  bool _isTimeSlotAvailable(DateTime time) {
    // Check if the time slot is not overbooked (simplified check)
    final int ordersInSlot = _scheduledOrders
        .where((order) =>
            order.scheduledFor.year == time.year &&
            order.scheduledFor.month == time.month &&
            order.scheduledFor.day == time.day &&
            order.scheduledFor.hour == time.hour,)
        .length;

    return ordersInSlot < 10; // Max 10 orders per hour slot
  }

  /// Get recurring pattern options
  List<Map<String, dynamic>> getRecurrencePatterns() {
    return [
      {
        'value': 'daily',
        'label': 'Tous les jours',
        'description': 'Commande répétée chaque jour',
      },
      {
        'value': 'weekly',
        'label': 'Toutes les semaines',
        'description': 'Commande répétée chaque semaine le même jour',
      },
      {
        'value': 'monthly',
        'label': 'Tous les mois',
        'description': 'Commande répétée chaque mois à la même date',
      },
    ];
  }

  /// Process scheduled orders that are ready
  Future<void> processScheduledOrders() async {
    final DateTime now = DateTime.now();

    final List<ScheduledOrder> readyOrders = _scheduledOrders
        .where((order) =>
            order.status == 'scheduled' &&
            order.scheduledFor.isBefore(now.add(const Duration(minutes: 15))),)
        .toList();

    for (final scheduledOrder in readyOrders) {
      // Update status to preparing
      final int index = _scheduledOrders.indexWhere((o) => o.id == scheduledOrder.id);
      if (index != -1) {
        final ScheduledOrder updatedOrder = ScheduledOrder(
          id: scheduledOrder.id,
          userId: scheduledOrder.userId,
          scheduledFor: scheduledOrder.scheduledFor,
          order: scheduledOrder.order,
          status: 'preparing',
          isRecurring: scheduledOrder.isRecurring,
          recurrencePattern: scheduledOrder.recurrencePattern,
          recurrenceEndDate: scheduledOrder.recurrenceEndDate,
        );

        _scheduledOrders[index] = updatedOrder;

        // If recurring, create next occurrence
        if (scheduledOrder.isRecurring) {
          final DateTime nextOccurrence = _calculateNextOccurrence(
              scheduledOrder.scheduledFor, scheduledOrder.recurrencePattern!,);

          if (scheduledOrder.recurrenceEndDate == null ||
              nextOccurrence.isBefore(scheduledOrder.recurrenceEndDate!)) {
            await scheduleOrder(
              userId: scheduledOrder.userId,
              scheduledTime: nextOccurrence,
              order: scheduledOrder.order,
              isRecurring: true,
              recurrencePattern: scheduledOrder.recurrencePattern,
              recurrenceEndDate: scheduledOrder.recurrenceEndDate,
            );
          }
        }
      }
    }

    if (readyOrders.isNotEmpty) {
      notifyListeners();
    }
  }

  DateTime _calculateNextOccurrence(DateTime current, String pattern) {
    switch (pattern) {
      case 'daily':
        return current.add(const Duration(days: 1));
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(current.year, current.month + 1, current.day,
            current.hour, current.minute,);
      default:
        return current.add(const Duration(days: 1));
    }
  }

  /// Clean up expired requests and completed orders
  Future<void> cleanup() async {
    final DateTime now = DateTime.now();

    // Remove expired group delivery requests
    _activeRequests.removeWhere((request) =>
        request.expiresAt.isBefore(now) && request.status == 'open',);

    // Remove old completed scheduled orders (older than 30 days)
    _scheduledOrders.removeWhere((order) =>
        order.status == 'delivered' &&
        order.scheduledFor.isBefore(now.subtract(const Duration(days: 30))),);

    notifyListeners();
  }
}
