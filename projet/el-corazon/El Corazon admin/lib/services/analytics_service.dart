import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'admin_auth_service.dart';

/// Rapports d'exploitation — `/analytics/reports/*` (Phase 6).
///
/// Ce service ne calcule plus rien. L'ancienne version téléchargeait *toutes*
/// les commandes, tous les comptes, tous les articles et tous les livreurs pour
/// les additionner dans le navigateur, avec des pauses de 300 ms entre les
/// requêtes et trois tentatives en cas d'échec — un aveu que l'appel était trop
/// lourd. Le tableau de bord ralentissait à mesure que la plateforme
/// grandissait, et ses totaux ne portaient que sur ce que la pagination avait
/// bien voulu rendre.
///
/// Les montants arrivent en **unité mineure** et ne servent qu'à l'affichage :
/// un rapport se trace, il ne se refacture pas.
///
/// Les méthodes rendent des `Map` parce que c'est la forme qu'attendent les
/// écrans de graphiques ; ce qui change, c'est que les clés sont désormais
/// remplies par le serveur, une requête par rapport.
class AnalyticsService extends ChangeNotifier {
  eccore.ReportingRepository get _reports =>
      eccore.ReportingRepository(apiClient: AdminAuthService().apiClient);

  Map<String, dynamic> _analyticsData = {};
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic> get analyticsData => _analyticsData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Charge en une passe les trois séries du tableau de bord.
  Future<void> loadAnalyticsData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final revenus = await _reports.revenue(start: startDate, end: endDate);
      final statuts = await _reports.ordersByStatus(
        start: startDate,
        end: endDate,
      );
      final categories = await _reports.categories(
        start: startDate,
        end: endDate,
      );

      _analyticsData = {
        'revenue': _serieRevenus(revenus),
        'orders': _serieCommandes(revenus, statuts),
        'categories': _serieCategories(categories),
      };
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Analytics : rapports indisponibles — ${e.code}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Chiffres de tête.
  ///
  /// La fenêtre est facultative parce que l'écran qui les affiche n'en choisit
  /// pas : à défaut, les trente derniers jours. Sans fenêtre du tout, le
  /// serveur agrégerait toute la vie de la plateforme à chaque affichage.
  Future<Map<String, dynamic>> getGeneralStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final fin = endDate ?? DateTime.now();
    final debut = startDate ?? fin.subtract(const Duration(days: 30));

    try {
      final apercu = await _reports.overview(start: debut, end: fin);
      return {
        'orders': {
          'total': apercu.ordersCount,
          'completed': apercu.ordersDelivered,
          'cancelled': apercu.ordersCancelled,
          'completionRate': apercu.completionRate,
        },
        'revenue': {
          'total': _majeur(apercu.revenueMinor),
          'averageOrderValue': _majeur(apercu.averageBasketMinor),
        },
        // Les comptes du personnel ne sont plus comptés ici : c'est une donnée
        // d'administration, pas un chiffre de vente, et elle a son écran.
        'users': {'total': apercu.customersCount},
        'products': {
          'total': apercu.menuItemsTotal,
          'available': apercu.menuItemsAvailable,
          'availabilityRate': apercu.menuItemsTotal == 0
              ? 0.0
              : apercu.menuItemsAvailable * 100 / apercu.menuItemsTotal,
        },
        'drivers': {'active': apercu.couriersOnline},
      };
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Analytics : aperçu indisponible — ${e.code}');
      notifyListeners();
      return _apercuVide();
    }
  }

  Future<Map<String, dynamic>> getRevenueAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      return _serieRevenus(
        await _reports.revenue(start: startDate, end: endDate),
      );
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Analytics : chiffre d\'affaires indisponible — ${e.code}');
      return _serieRevenus(const []);
    }
  }

  Future<Map<String, dynamic>> getOrderAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final revenus = await _reports.revenue(start: startDate, end: endDate);
      final statuts = await _reports.ordersByStatus(
        start: startDate,
        end: endDate,
      );
      return _serieCommandes(revenus, statuts);
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Analytics : commandes indisponibles — ${e.code}');
      return _serieCommandes(const [], const []);
    }
  }

  Future<Map<String, dynamic>> getCategoryAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      return _serieCategories(
        await _reports.categories(start: startDate, end: endDate),
      );
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Analytics : catégories indisponibles — ${e.code}');
      return _serieCategories(const []);
    }
  }

  /// Articles les plus vendus sur la période.
  ///
  /// L'agrégation est côté serveur : l'ancienne version passait par une
  /// fonction de base de données appelée depuis le navigateur, avec les mêmes
  /// clés que ci-dessous — elles sont conservées pour l'écran, mais remplies
  /// par `/analytics/reports/top-products/`.
  Future<List<Map<String, dynamic>>> getTopSellingItems({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 5,
  }) async {
    final fin = endDate ?? DateTime.now();
    final debut = startDate ?? fin.subtract(const Duration(days: 30));

    try {
      final lignes = await _reports.topProducts(
        start: debut,
        end: fin,
        limit: limit,
      );
      return [
        for (final ligne in lignes)
          {
            'menu_item_id': ligne.menuItemId,
            'menu_item_name': ligne.itemName,
            'total_quantity': ligne.quantitySold,
            'total_revenue': _majeur(ligne.revenueMinor),
          },
      ];
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Analytics : top ventes indisponible — ${e.code}');
      return const [];
    }
  }

  /// Livraisons et gains par livreur.
  ///
  /// La note moyenne n'y figure plus : l'ancienne version la lisait sur la
  /// **commande**, où elle n'a jamais existé, et rendait donc toujours zéro.
  /// Elle vit sur le dossier du livreur, que l'écran de la flotte affiche.
  Future<Map<String, dynamic>> getDriverAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final lignes = await _reports.couriers(start: startDate, end: endDate);
      return {
        'driverDeliveries': <String, int>{
          for (final ligne in lignes) ligne.courierName: ligne.deliveries,
        },
        'driverEarnings': <String, double>{
          for (final ligne in lignes)
            ligne.courierName: _majeur(ligne.earningsMinor),
        },
      };
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Analytics : livreurs indisponibles — ${e.code}');
      return {
        'driverDeliveries': <String, int>{},
        'driverEarnings': <String, double>{},
      };
    }
  }

  // --------------------------------------------------------- mise en forme

  Map<String, dynamic> _serieRevenus(List<eccore.RevenueRow> lignes) {
    return {
      'totalRevenue': lignes.fold<double>(
        0,
        (somme, ligne) => somme + _majeur(ligne.revenueMinor),
      ),
      'dailyRevenue': <String, double>{
        for (final ligne in lignes)
          _jour(ligne.day): _majeur(ligne.revenueMinor),
      },
    };
  }

  /// `dailyOrders` compte les commandes **livrées** par jour, comme le chiffre
  /// d'affaires qu'il accompagne : les deux courbes se lisent l'une sous
  /// l'autre, et elles porteraient sur des ensembles différents si l'une
  /// comptait aussi ce qui a été annulé. La répartition complète, annulations
  /// comprises, est dans `statusCounts`.
  Map<String, dynamic> _serieCommandes(
    List<eccore.RevenueRow> revenus,
    List<eccore.StatusRow> statuts,
  ) {
    return {
      'totalOrders': statuts.fold<int>(
        0,
        (somme, ligne) => somme + ligne.ordersCount,
      ),
      'statusCounts': <String, int>{
        for (final ligne in statuts) ligne.status: ligne.ordersCount,
      },
      'dailyOrders': <String, int>{
        for (final ligne in revenus) _jour(ligne.day): ligne.ordersCount,
      },
    };
  }

  Map<String, dynamic> _serieCategories(List<eccore.CategoryRow> lignes) {
    return {
      'categoryCounts': <String, int>{
        for (final ligne in lignes) ligne.categoryName: ligne.quantitySold,
      },
      'categoryRevenue': <String, double>{
        for (final ligne in lignes)
          ligne.categoryName: _majeur(ligne.revenueMinor),
      },
    };
  }

  Map<String, dynamic> _apercuVide() => {
    'orders': {
      'total': 0,
      'completed': 0,
      'cancelled': 0,
      'completionRate': 0.0,
    },
    'revenue': {'total': 0.0, 'averageOrderValue': 0.0},
    'users': {'total': 0},
    'products': {'total': 0, 'available': 0, 'availabilityRate': 0.0},
    'drivers': {'active': 0},
  };

  /// Les francs CFA n'ont pas de décimale : l'unité mineure est le franc.
  double _majeur(int mineur) => mineur.toDouble();

  String _jour(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
