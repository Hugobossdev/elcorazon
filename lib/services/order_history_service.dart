import 'package:flutter/foundation.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/repositories/order_repository.dart';

/// Options de filtre pour l'historique des commandes
enum OrderFilter {
  all, // Toutes
  active, // En cours (pending, confirmed, preparing, ready)
  completed, // Terminées (delivered)
  cancelled, // Annulées
}

/// Options de tri pour l'historique des commandes
enum OrderSortOption {
  dateDesc, // Plus récentes en premier
  dateAsc, // Plus anciennes en premier
  totalDesc, // Plus chères en premier
  totalAsc, // Moins chères en premier
  status, // Par statut
}

/// Service pour gérer l'historique des commandes avec filtres et tri
class OrderHistoryService extends ChangeNotifier {
  final OrderRepository _repository;

  List<Order> _orders = [];
  OrderFilter _currentFilter = OrderFilter.all;
  OrderSortOption _sortOption = OrderSortOption.dateDesc;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  OrderHistoryService(this._repository);

  // Getters
  List<Order> get orders => _getFilteredAndSortedOrders();
  OrderFilter get currentFilter => _currentFilter;
  OrderSortOption get sortOption => _sortOption;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  bool get isLoading => _isLoading;

  /// Charger l'historique des commandes
  Future<void> loadOrders(String userId) async {
    _setLoading(true);

    try {
      _orders = await _repository.getUserOrders(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement des commandes: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Appliquer un filtre
  void applyFilter(OrderFilter filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  /// Appliquer un tri
  void applySort(OrderSortOption sort) {
    _sortOption = sort;
    notifyListeners();
  }

  /// Filtrer par date
  void filterByDateRange(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    notifyListeners();
  }

  /// Réinitialiser les filtres
  void resetFilters() {
    _currentFilter = OrderFilter.all;
    _sortOption = OrderSortOption.dateDesc;
    _startDate = null;
    _endDate = null;
    notifyListeners();
  }

  /// Obtenir les commandes filtrées et triées
  List<Order> _getFilteredAndSortedOrders() {
    var filtered = List<Order>.from(_orders);

      // Filtrer par statut
      switch (_currentFilter) {
        case OrderFilter.active:
          filtered = filtered.where((order) {
            return order.status == OrderStatus.pending ||
                order.status == OrderStatus.confirmed ||
                order.status == OrderStatus.preparing ||
                order.status == OrderStatus.ready ||
                order.status == OrderStatus.pickedUp ||
                order.status == OrderStatus.onTheWay;
          }).toList();
          break;
        case OrderFilter.completed:
          filtered = filtered.where((order) {
            return order.status == OrderStatus.delivered;
          }).toList();
          break;
        case OrderFilter.cancelled:
          filtered = filtered.where((order) {
            return order.status == OrderStatus.cancelled;
          }).toList();
          break;
        case OrderFilter.all:
          // Pas de filtre par statut
          break;
      }

    // Filtrer par date
    if (_startDate != null || _endDate != null) {
      filtered = filtered.where((order) {
        final orderDate = order.createdAt;
        
        if (_startDate != null && orderDate.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null && orderDate.isAfter(_endDate!.add(const Duration(days: 1)))) {
          return false;
        }
        
        return true;
      }).toList();
    }

    // Trier
    switch (_sortOption) {
      case OrderSortOption.dateDesc:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case OrderSortOption.dateAsc:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case OrderSortOption.totalDesc:
        filtered.sort((a, b) => b.total.compareTo(a.total));
        break;
      case OrderSortOption.totalAsc:
        filtered.sort((a, b) => a.total.compareTo(b.total));
        break;
      case OrderSortOption.status:
        filtered.sort((a, b) {
          // Trier par statut puis par date
          final statusComparison = a.status.toString().compareTo(b.status.toString());
          if (statusComparison != 0) return statusComparison;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
    }

    return filtered;
  }

  /// Obtenir les statistiques
  Map<String, dynamic> getStatistics() {
    final filtered = _getFilteredAndSortedOrders();
    
    double totalSpent = 0.0;
    final int totalOrders = filtered.length;
    final Map<OrderStatus, int> statusCount = {};

    for (final order in filtered) {
      totalSpent += order.total;
      statusCount[order.status] = (statusCount[order.status] ?? 0) + 1;
    }

    return {
      'totalOrders': totalOrders,
      'totalSpent': totalSpent,
      'averageOrderValue': totalOrders > 0 ? totalSpent / totalOrders : 0.0,
      'statusCount': statusCount,
    };
  }

  /// Obtenir les commandes groupées par date
  Map<String, List<Order>> getOrdersGroupedByDate() {
    final filtered = _getFilteredAndSortedOrders();
    final grouped = <String, List<Order>>{};

    for (final order in filtered) {
      final dateKey = _formatDateKey(order.createdAt);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(order);
    }

    return grouped;
  }

  /// Formater une date en clé de groupement
  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Aujourd\'hui';
    } else if (dateOnly == yesterday) {
      return 'Hier';
    } else if (dateOnly.isAfter(today.subtract(const Duration(days: 7)))) {
      return 'Cette semaine';
    } else if (dateOnly.isAfter(today.subtract(const Duration(days: 30)))) {
      return 'Ce mois';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}

