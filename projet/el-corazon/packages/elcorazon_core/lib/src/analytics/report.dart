/// Lignes et compteurs des rapports d'exploitation
/// (`backend/apps/analytics/reports.py`).
///
/// Les montants voyagent en **unité mineure** (`revenue_minor`) et restent des
/// entiers : une ligne de rapport est un nombre à tracer sur un graphique, pas
/// une somme à facturer. La devise est celle du marché et n'appartient pas à la
/// ligne — l'y mettre laisserait croire qu'un rapport peut en mélanger deux.
library;

/// Chiffre d'affaires d'une journée.
class RevenueRow {
  const RevenueRow({
    required this.day,
    required this.ordersCount,
    required this.revenueMinor,
  });

  factory RevenueRow.fromJson(Map<String, dynamic> json) {
    return RevenueRow(
      day: DateTime.parse(json['day'] as String),
      ordersCount: json['orders_count'] as int,
      revenueMinor: json['revenue_minor'] as int,
    );
  }

  final DateTime day;
  final int ordersCount;
  final int revenueMinor;
}

/// Un article, et ce qu'il a vendu sur la période.
class TopProductRow {
  const TopProductRow({
    required this.menuItemId,
    required this.itemName,
    required this.quantitySold,
    required this.revenueMinor,
  });

  factory TopProductRow.fromJson(Map<String, dynamic> json) {
    return TopProductRow(
      menuItemId: json['menu_item_id'] as String,
      itemName: json['item_name'] as String,
      quantitySold: json['quantity_sold'] as int,
      revenueMinor: json['revenue_minor'] as int,
    );
  }

  final String menuItemId;
  final String itemName;
  final int quantitySold;
  final int revenueMinor;
}

/// Livraisons et gains d'un livreur sur la période.
class CourierPerformanceRow {
  const CourierPerformanceRow({
    required this.courierId,
    required this.courierName,
    required this.deliveries,
    required this.earningsMinor,
  });

  factory CourierPerformanceRow.fromJson(Map<String, dynamic> json) {
    return CourierPerformanceRow(
      courierId: json['courier_id'] as String,
      courierName: json['courier_name'] as String,
      deliveries: json['deliveries'] as int,
      earningsMinor: json['earnings_minor'] as int,
    );
  }

  final String courierId;
  final String courierName;
  final int deliveries;
  final int earningsMinor;
}

/// Commandes rangées par statut.
class StatusRow {
  const StatusRow({
    required this.status,
    required this.ordersCount,
    required this.revenueMinor,
  });

  factory StatusRow.fromJson(Map<String, dynamic> json) {
    return StatusRow(
      status: json['status'] as String,
      ordersCount: json['orders_count'] as int,
      revenueMinor: json['revenue_minor'] as int,
    );
  }

  final String status;
  final int ordersCount;
  final int revenueMinor;
}

/// Ventes agrégées par catégorie de la carte.
class CategoryRow {
  const CategoryRow({
    required this.categoryId,
    required this.categoryName,
    required this.quantitySold,
    required this.revenueMinor,
  });

  factory CategoryRow.fromJson(Map<String, dynamic> json) {
    return CategoryRow(
      categoryId: json['category_id'] as String,
      categoryName: json['category_name'] as String,
      quantitySold: json['quantity_sold'] as int,
      revenueMinor: json['revenue_minor'] as int,
    );
  }

  final String categoryId;
  final String categoryName;
  final int quantitySold;
  final int revenueMinor;
}

/// Chiffres de tête du tableau de bord.
///
/// Deux natures de chiffres y cohabitent, et c'est voulu : les commandes et le
/// chiffre d'affaires portent sur la fenêtre demandée, tandis que la carte et
/// la flotte sont des états **du moment** — un article disponible l'est
/// aujourd'hui, pas « entre le 1er et le 15 ».
class AnalyticsOverview {
  const AnalyticsOverview({
    required this.ordersCount,
    required this.ordersDelivered,
    required this.ordersCancelled,
    required this.revenueMinor,
    required this.averageBasketMinor,
    required this.customersCount,
    required this.couriersOnline,
    required this.menuItemsAvailable,
    required this.menuItemsTotal,
  });

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) {
    return AnalyticsOverview(
      ordersCount: json['orders_count'] as int,
      ordersDelivered: json['orders_delivered'] as int,
      ordersCancelled: json['orders_cancelled'] as int,
      revenueMinor: json['revenue_minor'] as int,
      averageBasketMinor: json['average_basket_minor'] as int,
      customersCount: json['customers_count'] as int,
      couriersOnline: json['couriers_online'] as int,
      menuItemsAvailable: json['menu_items_available'] as int,
      menuItemsTotal: json['menu_items_total'] as int,
    );
  }

  final int ordersCount;
  final int ordersDelivered;
  final int ordersCancelled;
  final int revenueMinor;
  final int averageBasketMinor;
  final int customersCount;
  final int couriersOnline;
  final int menuItemsAvailable;
  final int menuItemsTotal;

  /// Part des commandes menées jusqu'au bout, en pourcentage.
  double get completionRate =>
      ordersCount == 0 ? 0 : ordersDelivered * 100 / ordersCount;
}
