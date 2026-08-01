import '../network/api_client.dart';
import 'report.dart';

/// Rapports d'exploitation — `/api/v1/analytics/reports/*`
/// (`backend/apps/analytics/views.py`), sous permission `analytics.read`.
///
/// Séparé d'[AnalyticsRepository], qui est le point de vue d'une app cliente :
/// celle-ci **écrit** des événements, elle ne lit aucun chiffre. Les mélanger
/// mettrait dans les trois applications un dépôt dont les deux tiers sont
/// interdits à leurs utilisateurs.
///
/// Tout est agrégé côté serveur. Le back-office précédent téléchargeait les
/// commandes, les comptes et les articles pour les compter dans le navigateur :
/// le tableau de bord ralentissait à mesure que la plateforme grandissait, et
/// ses totaux ne portaient que sur ce que la pagination avait rendu.
class ReportingRepository {
  ReportingRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Chiffre d'affaires jour par jour, sur les commandes **livrées**.
  Future<List<RevenueRow>> revenue({
    required DateTime start,
    required DateTime end,
  }) {
    return _rows('/analytics/reports/revenue/', RevenueRow.fromJson, start, end);
  }

  /// Articles les plus vendus.
  Future<List<TopProductRow>> topProducts({
    required DateTime start,
    required DateTime end,
    int limit = 10,
  }) {
    return _rows(
      '/analytics/reports/top-products/',
      TopProductRow.fromJson,
      start,
      end,
      extra: {'limit': limit.toString()},
    );
  }

  /// Livraisons et gains par livreur.
  Future<List<CourierPerformanceRow>> couriers({
    required DateTime start,
    required DateTime end,
  }) {
    return _rows(
      '/analytics/reports/couriers/',
      CourierPerformanceRow.fromJson,
      start,
      end,
    );
  }

  /// Répartition des commandes par statut — annulations comprises.
  Future<List<StatusRow>> ordersByStatus({
    required DateTime start,
    required DateTime end,
  }) {
    return _rows('/analytics/reports/orders/', StatusRow.fromJson, start, end);
  }

  /// Ventes par catégorie de la carte.
  Future<List<CategoryRow>> categories({
    required DateTime start,
    required DateTime end,
  }) {
    return _rows(
      '/analytics/reports/categories/',
      CategoryRow.fromJson,
      start,
      end,
    );
  }

  /// Chiffres de tête du tableau de bord, en un appel.
  Future<AnalyticsOverview> overview({
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await apiClient.get(
      '/analytics/reports/overview/',
      queryParameters: _fenetre(start, end),
    );
    return AnalyticsOverview.fromJson(response.data as Map<String, dynamic>);
  }

  // -------------------------------------------------------------- interne

  Future<List<T>> _rows<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
    DateTime start,
    DateTime end, {
    Map<String, dynamic> extra = const {},
  }) async {
    final response = await apiClient.get(
      path,
      queryParameters: {..._fenetre(start, end), ...extra},
    );
    // Les rapports ne sont pas paginés : ce sont des agrégats, déjà bornés par
    // leur fenêtre de dates.
    return (response.data as List<dynamic>)
        .map((json) => fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Le serveur attend des **dates**, pas des instants : un rapport porte sur
  /// des journées entières, et lui envoyer une heure laisserait croire à une
  /// précision qu'il n'applique pas.
  Map<String, dynamic> _fenetre(DateTime start, DateTime end) => {
    'start': _jour(start),
    'end': _jour(end),
  };

  String _jour(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
