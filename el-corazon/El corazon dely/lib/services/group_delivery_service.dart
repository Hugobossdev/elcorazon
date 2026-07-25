import 'package:flutter/foundation.dart';
import '../models/order.dart';

class GroupDeliveryRequest {
  final String id;
  final String initiatorUserId;
  final String deliveryAddress;
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
    required this.preferredTime,
    required this.maxDeliveryRadius,
    required this.joinedUserIds,
    required this.sharedDeliveryCost,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    required this.orderIds,
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
    // Simulate loading data
    await Future.delayed(const Duration(milliseconds: 300));

    // Mock data for testing
    _activeRequests = [
      GroupDeliveryRequest(
        id: '1',
        initiatorUserId: 'user123',
        deliveryAddress: 'Quartier Koulouba, Bamako',
        preferredTime: DateTime.now().add(const Duration(minutes: 45)),
        maxDeliveryRadius: 500,
        joinedUserIds: ['user123', 'user456'],
        sharedDeliveryCost: 1000,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        expiresAt: DateTime.now().add(const Duration(minutes: 20)),
        status: 'open',
        orderIds: ['order123'],
      ),
    ];

    _scheduledOrders = [
      ScheduledOrder(
        id: 'sched1',
        userId: 'user123',
        scheduledFor: DateTime.now().add(const Duration(hours: 2)),
        order: Order(
          id: 'order789',
          userId: 'user123',
          items: [],
          subtotal: 7000,
          paymentMethod: PaymentMethod.wallet,
          orderTime: DateTime.now(),
          createdAt: DateTime.now(),
          total: 7500,
          status: OrderStatus.pending,
          deliveryAddress: 'Mon adresse',
        ),
        status: 'scheduled',
      ),
    ];
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
      String requestId = DateTime.now().millisecondsSinceEpoch.toString();

      GroupDeliveryRequest request = GroupDeliveryRequest(
        id: requestId,
        initiatorUserId: initiatorUserId,
        deliveryAddress: deliveryAddress,
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

      return requestId;
    } catch (e) {
      debugPrint('Error creating group delivery request: $e');
      return null;
    }
  }

  /// Find nearby group delivery requests
  List<GroupDeliveryRequest> findNearbyRequests(String userAddress,
      {double maxDistance = 1000}) {
    return _activeRequests.where((request) {
      return request.status == 'open' &&
          request.expiresAt.isAfter(DateTime.now()) &&
          _calculateDistance(userAddress, request.deliveryAddress) <=
              maxDistance;
    }).toList();
  }

  /// Join an existing group delivery request
  Future<bool> joinGroupDelivery(
      String requestId, String userId, String orderId) async {
    try {
      int index = _activeRequests.indexWhere((r) => r.id == requestId);
      if (index == -1) return false;

      var request = _activeRequests[index];
      if (request.status != 'open' ||
          request.expiresAt.isBefore(DateTime.now())) {
        return false;
      }

      // Update request
      List<String> newJoinedUsers = List.from(request.joinedUserIds)
        ..add(userId);
      List<String> newOrderIds = List.from(request.orderIds)..add(orderId);
      double newSharedCost =
          _calculateSharedDeliveryCost(newJoinedUsers.length);

      GroupDeliveryRequest updatedRequest = GroupDeliveryRequest(
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
      int index = _activeRequests.indexWhere((r) => r.id == requestId);
      if (index == -1) return false;

      var request = _activeRequests[index];

      if (request.initiatorUserId == userId) {
        // If initiator leaves, cancel the request
        _activeRequests.removeAt(index);
      } else {
        List<String> newJoinedUsers = List.from(request.joinedUserIds)
          ..remove(userId);
        List<String> newOrderIds = List.from(request.orderIds);

        // Remove user's order (simplified - in real implementation, need to match user to order)
        if (newOrderIds.isNotEmpty) newOrderIds.removeLast();

        double newSharedCost =
            _calculateSharedDeliveryCost(newJoinedUsers.length);

        GroupDeliveryRequest updatedRequest = GroupDeliveryRequest(
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
      String scheduleId = DateTime.now().millisecondsSinceEpoch.toString();

      ScheduledOrder scheduledOrder = ScheduledOrder(
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
      int index =
          _scheduledOrders.indexWhere((order) => order.id == scheduleId);
      if (index == -1) return false;

      var order = _scheduledOrders[index];
      ScheduledOrder updatedOrder = ScheduledOrder(
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
    DateTime now = DateTime.now();
    DateTime tomorrow = now.add(const Duration(hours: 24));

    return _scheduledOrders
        .where((order) =>
            order.scheduledFor.isAfter(now) &&
            order.scheduledFor.isBefore(tomorrow) &&
            order.status == 'scheduled')
        .toList();
  }

  // Helper Functions

  double _calculateDistance(String address1, String address2) {
    // Simplified distance calculation - in real implementation, use GPS coordinates
    return address1 == address2 ? 0 : 500; // Mock distance
  }

  double _calculateBaseDeliveryCost() {
    return 2000.0; // Base delivery cost in CFA
  }

  double _calculateSharedDeliveryCost(int numberOfParticipants) {
    double baseCost = _calculateBaseDeliveryCost();
    return baseCost / numberOfParticipants;
  }

  /// Get delivery time slots for scheduling
  List<Map<String, dynamic>> getAvailableTimeSlots() {
    List<Map<String, dynamic>> slots = [];
    DateTime now = DateTime.now();

    // Generate slots for the next 7 days
    for (int day = 0; day < 7; day++) {
      DateTime date = now.add(Duration(days: day));

      // Skip past hours for today
      int startHour = day == 0 ? now.hour + 1 : 11;

      for (int hour = startHour; hour <= 22; hour++) {
        if (hour >= 11) {
          // Restaurant opens at 11 AM
          DateTime slotTime =
              DateTime(date.year, date.month, date.day, hour, 0);

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
    String dayName = _getDayName(time.weekday);
    String timeStr =
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
      'Dimanche'
    ];
    return days[weekday - 1];
  }

  bool _isTimeSlotAvailable(DateTime time) {
    // Check if the time slot is not overbooked (simplified check)
    int ordersInSlot = _scheduledOrders
        .where((order) =>
            order.scheduledFor.year == time.year &&
            order.scheduledFor.month == time.month &&
            order.scheduledFor.day == time.day &&
            order.scheduledFor.hour == time.hour)
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
    DateTime now = DateTime.now();

    List<ScheduledOrder> readyOrders = _scheduledOrders
        .where((order) =>
            order.status == 'scheduled' &&
            order.scheduledFor.isBefore(now.add(const Duration(minutes: 15))))
        .toList();

    for (var scheduledOrder in readyOrders) {
      // Update status to preparing
      int index = _scheduledOrders.indexWhere((o) => o.id == scheduledOrder.id);
      if (index != -1) {
        ScheduledOrder updatedOrder = ScheduledOrder(
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
          DateTime nextOccurrence = _calculateNextOccurrence(
              scheduledOrder.scheduledFor, scheduledOrder.recurrencePattern!);

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
            current.hour, current.minute);
      default:
        return current.add(const Duration(days: 1));
    }
  }

  /// Clean up expired requests and completed orders
  Future<void> cleanup() async {
    DateTime now = DateTime.now();

    // Remove expired group delivery requests
    _activeRequests.removeWhere((request) =>
        request.expiresAt.isBefore(now) && request.status == 'open');

    // Remove old completed scheduled orders (older than 30 days)
    _scheduledOrders.removeWhere((order) =>
        order.status == 'delivered' &&
        order.scheduledFor.isBefore(now.subtract(const Duration(days: 30))));

    notifyListeners();
  }
}
