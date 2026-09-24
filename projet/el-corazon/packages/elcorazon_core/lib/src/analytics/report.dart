/// Lignes et compteurs des rapports d'exploitation
/// (`backend/apps/analytics/reports.py`).
///
/// Les montants voyagent en **unité mineure** (`revenue_minor`) et restent des
/// entiers : une ligne de rapport est un nombre à tracer sur un graphique, pas
/// une somme à facturer.
///
/// **Chaque ligne monétaire porte sa devise.** L'en-tête de ce fichier disait
/// le contraire — « la devise est celle du marché » — et c'était faux dès que
/// le périmètre couvrait deux pays : le siège additionnait les XOF de Lomé et
/// les XAF de Douala dans un seul chiffre d'affaires. Le serveur découpe
/// désormais ses séries par devise ; l'écran choisit celle qu'il montre.
library;

/// Chiffre d'affaires livré d'une devise, dans un [AnalyticsOverview].
class CurrencyRevenue {
  const CurrencyRevenue({
    required this.currency,
    required this.ordersDelivered,
    required this.revenueMinor,
    required this.averageBasketMinor,
  });

  factory CurrencyRevenue.fromJson(Map<String, dynamic> json) {
    return CurrencyRevenue(
      currency: json['currency'] as String,
      ordersDelivered: json['orders_delivered'] as int,
      revenueMinor: json['revenue_minor'] as int,
      averageBasketMinor: json['average_basket_minor'] as int,
    );
  }

  final String currency;
  final int ordersDelivered;
  final int revenueMinor;
  final int averageBasketMinor;
}

/// Chiffre d'affaires d'une journée.
class RevenueRow {
  const RevenueRow({
    required this.day,
    required this.currency,
    required this.ordersCount,
    required this.revenueMinor,
  });

  factory RevenueRow.fromJson(Map<String, dynamic> json) {
    return RevenueRow(
      day: DateTime.parse(json['day'] as String),
      currency: json['currency'] as String,
      ordersCount: json['orders_count'] as int,
      revenueMinor: json['revenue_minor'] as int,
    );
  }

  final DateTime day;

  /// Une journée à deux devises rend **deux** lignes.
  final String currency;
  final int ordersCount;
  final int revenueMinor;
}

/// Un article, et ce qu'il a vendu sur la période.
class TopProductRow {
  const TopProductRow({
    required this.menuItemId,
    required this.itemName,
    required this.currency,
    required this.quantitySold,
    required this.revenueMinor,
  });

  factory TopProductRow.fromJson(Map<String, dynamic> json) {
    return TopProductRow(
      menuItemId: json['menu_item_id'] as String,
      itemName: json['item_name'] as String,
      currency: json['currency'] as String,
      quantitySold: json['quantity_sold'] as int,
      revenueMinor: json['revenue_minor'] as int,
    );
  }

  final String menuItemId;
  final String itemName;
  final String currency;
  final int quantitySold;
  final int revenueMinor;
}

/// Livraisons et gains d'un livreur sur la période.
class CourierPerformanceRow {
  const CourierPerformanceRow({
    required this.courierId,
    required this.courierName,
    required this.currency,
    required this.deliveries,
    required this.earningsMinor,
  });

  factory CourierPerformanceRow.fromJson(Map<String, dynamic> json) {
    return CourierPerformanceRow(
      courierId: json['courier_id'] as String,
      courierName: json['courier_name'] as String,
      currency: json['currency'] as String,
      deliveries: json['deliveries'] as int,
      earningsMinor: json['earnings_minor'] as int,
    );
  }

  final String courierId;
  final String courierName;
  final String currency;
  final int deliveries;
  final int earningsMinor;
}

/// Une ligne du rapport réseau — un pays, une ville, une zone ou une cuisine.
///
/// [revenueMinor] porte sur les commandes **livrées** ; [ordersCount] sur tout
/// ce qui a été commandé dans la fenêtre. Une ligne par devise : on
/// n'additionne pas des francs CFA et des nairas.
class NetworkRow {
  const NetworkRow({
    required this.key,
    required this.name,
    required this.currency,
    required this.ordersCount,
    required this.inProgressCount,
    required this.deliveredCount,
    required this.cancelledCount,
    required this.revenueMinor,
    this.cityName = '',
    this.countryIsoCode = '',
  });

  factory NetworkRow.fromJson(Map<String, dynamic> json) {
    return NetworkRow(
      key: json['key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      cityName: json['city'] as String? ?? '',
      countryIsoCode: json['country'] as String? ?? '',
      currency: json['currency'] as String? ?? '',
      ordersCount: json['orders_count'] as int? ?? 0,
      inProgressCount: json['in_progress_count'] as int? ?? 0,
      deliveredCount: json['delivered_count'] as int? ?? 0,
      cancelledCount: json['cancelled_count'] as int? ?? 0,
      revenueMinor: json['revenue_minor'] as int? ?? 0,
    );
  }

  /// Identifiant de l'entité regroupée — vide pour les commandes non situées.
  final String key;
  final String name;
  final String cityName;
  final String countryIsoCode;
  final String currency;
  final int ordersCount;
  final int inProgressCount;
  final int deliveredCount;
  final int cancelledCount;
  final int revenueMinor;

  /// Part des commandes annulées, de 0 à 1 — zéro sans commande.
  double get cancellationRate => ordersCount == 0 ? 0 : cancelledCount / ordersCount;
}

/// Commandes rangées par statut — un **compte**, sans montant : la somme
/// qu'il portait mêlait les devises d'un périmètre multi-pays, et rien ne la
/// lisait.
class StatusRow {
  const StatusRow({required this.status, required this.ordersCount});

  factory StatusRow.fromJson(Map<String, dynamic> json) {
    return StatusRow(
      status: json['status'] as String,
      ordersCount: json['orders_count'] as int,
    );
  }

  final String status;
  final int ordersCount;
}

/// Ventes agrégées par catégorie de la carte.
class CategoryRow {
  const CategoryRow({
    required this.categoryId,
    required this.categoryName,
    required this.currency,
    required this.quantitySold,
    required this.revenueMinor,
  });

  factory CategoryRow.fromJson(Map<String, dynamic> json) {
    return CategoryRow(
      categoryId: json['category_id'] as String,
      categoryName: json['category_name'] as String,
      currency: json['currency'] as String,
      quantitySold: json['quantity_sold'] as int,
      revenueMinor: json['revenue_minor'] as int,
    );
  }

  final String categoryId;
  final String categoryName;
  final String currency;
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
    required this.currency,
    required this.revenues,
    required this.customersCount,
    required this.couriersOnline,
    required this.menuItemsAvailable,
    required this.menuItemsTotal,
    required this.start,
    required this.end,
    required this.timezoneName,
    required this.timezoneCertain,
  });

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) {
    return AnalyticsOverview(
      ordersCount: json['orders_count'] as int,
      ordersDelivered: json['orders_delivered'] as int,
      ordersCancelled: json['orders_cancelled'] as int,
      revenueMinor: json['revenue_minor'] as int?,
      averageBasketMinor: json['average_basket_minor'] as int?,
      currency: json['currency'] as String?,
      revenues: (json['revenues'] as List<dynamic>? ?? const [])
          .map((ligne) => CurrencyRevenue.fromJson(ligne as Map<String, dynamic>))
          .toList(growable: false),
      customersCount: json['customers_count'] as int,
      couriersOnline: json['couriers_online'] as int,
      menuItemsAvailable: json['menu_items_available'] as int,
      menuItemsTotal: json['menu_items_total'] as int,
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      timezoneName: json['timezone_name'] as String? ?? 'UTC',
      timezoneCertain: json['timezone_certain'] as bool? ?? false,
    );
  }

  final int ordersCount;
  final int ordersDelivered;
  final int ordersCancelled;

  /// Chiffre d'affaires et panier moyen **d'une seule devise** ([currency]) —
  /// nuls quand le périmètre en encaisse plusieurs, parce que les rendre
  /// reviendrait à additionner des XOF et des XAF. [revenues] porte le
  /// détail dans tous les cas.
  final int? revenueMinor;
  final int? averageBasketMinor;
  final String? currency;

  /// Une ligne par devise, la dominante en tête.
  final List<CurrencyRevenue> revenues;
  final int customersCount;
  final int couriersOnline;
  final int menuItemsAvailable;
  final int menuItemsTotal;

  /// La fenêtre que le serveur a **réellement** agrégée, et le fuseau qui l'a
  /// découpée.
  ///
  /// Republiée parce que l'écran ne la connaît pas forcément : il peut ne rien
  /// demander, et obtenir la journée en cours de l'établissement. C'est la
  /// seule façon d'être sûr de la journée dont on parle — l'horloge du poste
  /// qui consulte ne la donne pas.
  ///
  /// Des dates, sans heure : la journée est celle du calendrier de la cuisine.
  final DateTime start;
  final DateTime end;
  final String timezoneName;

  /// Faux quand le périmètre traverse plusieurs fuseaux.
  ///
  /// « La journée » n'y a pas de sens unique, et l'écran doit le dire plutôt
  /// que d'afficher une date qui ne vaut pour personne.
  final bool timezoneCertain;

  /// La fenêtre porte sur une seule journée.
  bool get estUneJournee => start == end;

  /// Part des commandes menées jusqu'au bout, en pourcentage.
  double get completionRate =>
      ordersCount == 0 ? 0 : ordersDelivered * 100 / ordersCount;
}
