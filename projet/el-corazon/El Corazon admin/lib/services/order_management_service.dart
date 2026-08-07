import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

import 'package:admin/models/order.dart';
import 'package:admin/repositories/django_order_mapper.dart';
import 'package:admin/services/admin_auth_service.dart';

/// Supervision des commandes — `/api/v1/orders/manage/` (Phase 6).
///
/// Le périmètre visible n'est plus décidé ici : le serveur ne rend que les
/// commandes des établissements auxquels le compte est rattaché, et refuse les
/// gestes dont il n'a pas la permission. L'implémentation Supabase lisait la
/// table `orders` en entier et se contentait de masquer des boutons.
class OrderManagementService extends ChangeNotifier {
  eccore.ManagedOrderRepository get _orders =>
      eccore.ManagedOrderRepository(apiClient: AdminAuthService().apiClient);
  List<Order> _allOrders = [];
  bool _isLoading = false;

  List<Order> get allOrders => _allOrders;
  bool get isLoading => _isLoading;

  OrderManagementService() {
    // Defer initial load until after first frame to avoid notifying during build
    // Rafraîchissement manuel pour l'instant : le canal temps réel du
    // back-office est `ws/restaurants/{id}/dashboard/`, qui demande
    // l'identifiant de l'établissement supervisé — la sélection
    // d'établissement n'existe pas encore dans cet écran. L'ancien canal
    // Socket.IO visait le backend Node, retiré.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAllOrders());
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
      final remote = await _orders.list();
      _allOrders = remote.map(DjangoOrderMapper.toLocal).toList();
      eccore.Journal.trace('OrderManagementService: ${_allOrders.length} commande(s)');
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('OrderManagementService: chargement impossible — ${e.code}');
      _allOrders = [];
    } finally {
      _setLoading(false);
    }
  }

  /// Fait avancer le statut d'une commande.
  ///
  /// La machine à états est côté serveur : une transition impossible sort en
  /// 409 **avec les cibles autorisées**. Elle n'est pas rejouée ici — deux
  /// graphes finiraient par diverger, et c'est l'écran qui afficherait des
  /// boutons menant à un refus.
  ///
  /// L'annulation ne passe pas par ici : voir [cancelOrder], qui exige une
  /// permission distincte et un motif.
  Future<bool> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    if (newStatus == OrderStatus.cancelled) {
      return cancelOrder(orderId, 'Annulée depuis la supervision');
    }

    try {
      final updated = await _orders.updateStatus(
        orderId: orderId,
        status: DjangoOrderMapper.toRemoteStatus(newStatus),
      );
      _replaceLocally(DjangoOrderMapper.toLocal(updated));
      return true;
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('OrderManagementService: transition refusée — ${e.code}');
      return false;
    }
  }

  void _replaceLocally(Order order) {
    final index = _allOrders.indexWhere((existing) => existing.id == order.id);
    if (index != -1) {
      _allOrders[index] = order;
    } else {
      _allOrders.insert(0, order);
    }
    Future.microtask(notifyListeners);
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
  /// Refuse une commande : c'est une annulation, avec son motif.
  Future<bool> rejectOrder(String orderId, {String? reason}) async {
    final motif = reason?.trim();
    return cancelOrder(
      orderId,
      motif == null || motif.isEmpty ? 'Commande refusée' : motif,
    );
  }

  /// Rembourse une commande — `POST /payments/{id}/refund/`,
  /// permission `orders.refund`.
  ///
  /// Le remboursement est un **mouvement de paiement**, pas un statut de
  /// commande : l'ancienne version écrivait `status = refunded` sur la
  /// commande, plus `is_refunded` et `refund_amount`, sans qu'aucun encaissement
  /// ne soit contrôlé. Le serveur plafonne au montant réellement encaissé,
  /// déduction faite de ce qui a déjà été remboursé.
  ///
  /// Non branché tant que l'écran ne collecte pas la transaction à rembourser
  /// ni le motif, tous deux exigés par le contrat : envoyer un appel incomplet
  /// échouerait en 400 sous les yeux de l'opérateur.
  Future<bool> processRefund(String orderId, double amount) async {
    eccore.Journal.trace('OrderManagementService: remboursement non branché ($orderId)');
    return false;
  }

  /// Annule une commande — permission `orders.cancel`, motif obligatoire.
  ///
  /// Le motif n'est pas décoratif : l'opérateur annule la commande d'un tiers,
  /// qui sera remboursé et rappellera pour savoir pourquoi.
  Future<bool> cancelOrder(String orderId, String reason) async {
    try {
      final updated = await _orders.cancel(orderId: orderId, reason: reason);
      _replaceLocally(DjangoOrderMapper.toLocal(updated));
      return true;
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('OrderManagementService: annulation refusée — ${e.code}');
      return false;
    }
  }

  /// Propose la course d'une commande à un livreur — permission
  /// `orders.assign_courier`.
  ///
  /// « Proposer » et non « assigner » : le livreur accepte ou refuse. L'ancienne
  /// version écrivait `delivery_person_id` sur la commande, ce qui affectait
  /// quelqu'un sans lui demander — et sans vérifier qu'il était en ligne ni son
  /// dossier validé.
  ///
  /// [courierId] est l'identifiant du **dossier livreur**, celui que rend
  /// `/delivery/couriers/`.
  Future<bool> assignDriver(String orderId, String courierId) async {
    try {
      await eccore.ManagedCourierRepository(apiClient: AdminAuthService().apiClient)
          .offer(orderId: orderId, courierId: courierId);
      await refresh();
      return true;
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('OrderManagementService: affectation refusée — ${e.code}');
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

  /// Statuts d'une commande encore en cours — celle sur laquelle la
  /// supervision peut encore agir. Les terminales (livrée, annulée,
  /// remboursée, échouée) ne peuvent être ni urgentes ni en retard : leur
  /// sort est joué.
  static const Set<OrderStatus> _enCours = {
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.pickedUp,
    OrderStatus.onTheWay,
  };

  /// Au-delà de ce délai sans être confirmée ni préparée, une commande est
  /// signalée. C'est un seuil d'attention pour l'exploitation, pas une règle
  /// métier : rien ne se décide sur ce chiffre côté serveur.
  static const Duration _delaiUrgence = Duration(minutes: 20);

  /// Commandes qui traînent en début de parcours.
  ///
  /// L'écran affichait un bandeau d'alerte alimenté par une liste vide écrite
  /// en dur : la section ne s'affichait jamais, et une commande oubliée en
  /// cuisine ne se voyait qu'en parcourant les onglets.
  List<Order> get urgentOrders => urgentAmong(_allOrders);

  /// Commandes en cours dont l'heure de livraison annoncée est dépassée.
  List<Order> get overdueOrders => overdueAmong(_allOrders);

  /// Sélection pure, exposée à part des accesseurs d'instance.
  ///
  /// [now] est un paramètre plutôt qu'un `DateTime.now()` interne : ce sont des
  /// règles **temporelles**, et une règle temporelle qui lit l'horloge en son
  /// sein ne se vérifie qu'en attendant. L'écran omet l'argument ; les tests le
  /// fournissent.
  static List<Order> urgentAmong(List<Order> orders, {DateTime? now}) {
    final maintenant = now ?? DateTime.now();
    return orders
        .where(
          (order) =>
              (order.status == OrderStatus.pending ||
                  order.status == OrderStatus.confirmed) &&
              maintenant.difference(order.orderTime) > _delaiUrgence,
        )
        .toList()
      // La plus ancienne d'abord : c'est celle qui attend le plus.
      ..sort((a, b) => a.orderTime.compareTo(b.orderTime));
  }

  /// Commandes en cours dont l'heure de livraison annoncée est dépassée.
  ///
  /// Le délai annoncé vient de la zone (`estimated_delivery_minutes`), donc du
  /// serveur : le retard se mesure sur la promesse faite au client, et non sur
  /// une constante du back-office. Une commande sans heure annoncée n'est pas
  /// en retard — elle est seulement sans promesse, ce qui n'est pas la même
  /// chose et ne doit pas déclencher d'alerte.
  static List<Order> overdueAmong(List<Order> orders, {DateTime? now}) {
    final maintenant = now ?? DateTime.now();
    return orders
        .where(
          (order) =>
              _enCours.contains(order.status) &&
              order.estimatedDeliveryTime != null &&
              maintenant.isAfter(order.estimatedDeliveryTime!),
        )
        .toList()
      ..sort(
        (a, b) => a.estimatedDeliveryTime!.compareTo(b.estimatedDeliveryTime!),
      );
  }

  /// Commandes d'un statut donné, filtrées **par le serveur**.
  Future<List<Order>> loadOrdersByStatusFromDB(OrderStatus status) async {
    try {
      final remote = await _orders.list(status: DjangoOrderMapper.toRemoteStatus(status));
      return remote.map(DjangoOrderMapper.toLocal).toList();
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('OrderManagementService: filtre par statut impossible — ${e.code}');
      return [];
    }
  }

  /// Les [limit] commandes les plus récentes.
  Future<List<Order>> loadRecentOrdersFromDB({int limit = 5}) async {
    try {
      final remote = await _orders.list();
      return remote.take(limit).map(DjangoOrderMapper.toLocal).toList();
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('OrderManagementService: commandes récentes indisponibles — ${e.code}');
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
            order.orderTime.day == today.day,)
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
            order.orderTime.isBefore(endOfWeek),)
        .toList();
  }

  /// Obtenir les commandes de ce mois
  List<Order> getThisMonthOrders() {
    final now = DateTime.now();
    return _allOrders
        .where((order) =>
            order.orderTime.year == now.year &&
            order.orderTime.month == now.month,)
        .toList();
  }

  // `searchOrders` a été retiré : il rendait une liste filtrée que son seul
  // appelant jetait (`service.searchOrders(value);`), si bien que la barre de
  // recherche de la supervision ne filtrait rien. La recherche est désormais
  // un état d'écran, appliqué là où la liste est construite — un service
  // partagé n'a pas à porter le champ de saisie d'un écran.

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
                    : order.total),);

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
    eccore.Journal.trace('🔄 Rafraîchissement manuel des commandes...');
    await _loadAllOrders();
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

  /// Archiver les anciennes commandes
  Future<bool> archiveOldOrders({int daysOld = 90}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

      final oldOrders = _allOrders.where((order) {
        return order.orderTime.isBefore(cutoffDate) &&
            (order.status == OrderStatus.delivered ||
                order.status == OrderStatus.cancelled);
      }).toList();

      eccore.Journal.trace('Archiving ${oldOrders.length} old orders');

      // Dans un vrai système, on pourrait déplacer ces commandes vers une table d'archive
      // Pour l'instant, on les laisse dans la base mais on les filtre dans l'interface

      return true;
    } catch (e) {
      eccore.Journal.trace('Error archiving orders: $e');
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

    // `trends` porte des `Map<String, dynamic>` : on type les quatre valeurs
    // lues plutôt que de calculer sur du `dynamic`, où une clé absente
    // n'échouerait qu'à l'exécution.
    final commandesDebut = firstDay['total_orders']! as num;
    final commandesFin = lastDay['total_orders']! as num;
    final revenuDebut = firstDay['revenue']! as num;
    final revenuFin = lastDay['revenue']! as num;

    final orderGrowth = commandesFin - commandesDebut;
    final revenueGrowth = revenuFin - revenuDebut;

    final orderGrowthPercent =
        commandesDebut > 0 ? (orderGrowth / commandesDebut) * 100 : 0.0;

    final revenueGrowthPercent =
        revenuDebut > 0 ? (revenueGrowth / revenuDebut) * 100 : 0.0;

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
        (b['total_spent'] as double).compareTo(a['total_spent'] as double),);

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
              },)
          .toList(),
    };
  }

  /// Obtenir les statistiques de livraison
  Map<String, dynamic> getDeliveryStats() {
    final deliveredOrders = _allOrders
        .where((o) =>
            o.status == OrderStatus.delivered &&
            o.estimatedDeliveryTime != null,)
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
