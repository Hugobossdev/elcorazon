import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:admin/presentation/echec.dart';
import 'package:admin/services/admin_auth_service.dart';

/// Rapports d'exploitation — `/analytics/reports/*` (Phase 6).
///
/// Ce service ne calcule rien que le serveur n'ait agrégé. L'ancienne version
/// téléchargeait *toutes* les commandes, tous les comptes, tous les articles et
/// tous les livreurs pour les additionner dans le navigateur.
///
/// ## Une devise à la fois
///
/// Les montants arrivent en **unité mineure**, et chaque ligne porte désormais
/// sa devise. Jusqu'au 22 septembre 2026, un périmètre couvrant le Togo (XOF)
/// et le Cameroun (XAF) voyait les deux additionnées dans un seul chiffre
/// d'affaires, formaté « FCFA ». Chaque série est donc rendue **pour une
/// devise** : celle demandée, ou la dominante du périmètre. Les autres restent
/// accessibles — `currencies` les liste — et jamais mêlées.
///
/// Les conversions passent par [eccore.Money], qui connaît l'exposant de
/// chaque devise : « l'unité mineure est le franc » n'est vrai que pour le
/// franc CFA.
class AnalyticsService extends ChangeNotifier {
  eccore.ReportingRepository get _reports =>
      eccore.ReportingRepository(apiClient: AdminAuthService().apiClient);

  // --------------------------------------------------- la journée en cours

  JourneeDExploitation? _journee;
  bool _journeeEnCours = false;
  Echec? _echecJournee;

  /// Les chiffres de la journée **de l'établissement**, ou nul avant la
  /// première lecture.
  JourneeDExploitation? get journee => _journee;
  bool get journeeEnCours => _journeeEnCours;
  Echec? get echecJournee => _echecJournee;
  String? get erreurJournee => _echecJournee?.message;

  /// Charge la journée en cours, telle que le serveur la découpe.
  ///
  /// Aucune date n'est envoyée — c'est délibéré, et c'est la seule façon
  /// d'obtenir « aujourd'hui » : le serveur seul sait quel jour il est là où
  /// l'activité a lieu. La semaine part du lundi de **cette** journée.
  Future<void> chargerLaJournee() async {
    if (_journeeEnCours) return;
    _journeeEnCours = true;
    _echecJournee = null;
    notifyListeners();

    try {
      final apercu = await _reports.overview();
      final jour = apercu.start;
      final lundi = DateTime(jour.year, jour.month, jour.day)
          .subtract(Duration(days: jour.weekday - 1));
      final semaine = await _reports.revenue(start: lundi, end: jour);

      final parDevise = <String, int>{};
      for (final ligne in semaine) {
        parDevise.update(
          ligne.currency,
          (cumul) => cumul + ligne.revenueMinor,
          ifAbsent: () => ligne.revenueMinor,
        );
      }
      _journee = JourneeDExploitation(apercu: apercu, revenusDeLaSemaine: parDevise);
    } on eccore.ApiException catch (e) {
      _echecJournee = Echec.de(e);
      eccore.Journal.trace('Analytics : journée indisponible — ${e.code}');
    } finally {
      _journeeEnCours = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------- rapports d'écran
  //
  // Ces méthodes **laissent remonter** l'`ApiException`. Elles rendaient une
  // série vide sur échec et posaient `_error`, que rien ne remettait à zéro :
  // un 403 s'affichait comme une période sans vente, et un échec ancien
  // restait collé à l'écran après un rechargement réussi. C'est l'écran qui
  // décide quoi montrer, sur la nature de l'échec ([Echec]).

  /// Aperçu de la fenêtre : compteurs, et chiffre d'affaires **par devise**.
  Future<Map<String, dynamic>> getGeneralStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final fin = endDate ?? DateTime.now();
    final debut = startDate ?? fin.subtract(const Duration(days: 30));

    final apercu = await _reports.overview(start: debut, end: fin);
    return {
      'orders': {
        'total': apercu.ordersCount,
        'completed': apercu.ordersDelivered,
        'cancelled': apercu.ordersCancelled,
        'completionRate': apercu.completionRate,
      },
      'revenue': {
        // Une ligne par devise, la dominante en tête — jamais un total mêlé.
        'byCurrency': [
          for (final ligne in apercu.revenues)
            {
              'currency': ligne.currency,
              'total': montant(ligne.revenueMinor, ligne.currency),
              'averageOrderValue': montant(ligne.averageBasketMinor, ligne.currency),
              'orders': ligne.ordersDelivered,
            },
        ],
      },
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
  }

  /// Chiffre d'affaires quotidien d'**une** devise ([devise], sinon la
  /// dominante). La réponse dit laquelle (`currency`) et lesquelles existent
  /// (`currencies`).
  Future<Map<String, dynamic>> getRevenueAnalytics({
    required DateTime startDate,
    required DateTime endDate,
    String? devise,
  }) async {
    return _serieRevenus(
      await _reports.revenue(start: startDate, end: endDate),
      devise,
    );
  }

  Future<Map<String, dynamic>> getOrderAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final revenus = await _reports.revenue(start: startDate, end: endDate);
    final statuts = await _reports.ordersByStatus(start: startDate, end: endDate);
    return _serieCommandes(revenus, statuts);
  }

  Future<Map<String, dynamic>> getCategoryAnalytics({
    required DateTime startDate,
    required DateTime endDate,
    String? devise,
  }) async {
    return _serieCategories(
      await _reports.categories(start: startDate, end: endDate),
      devise,
    );
  }

  /// Les articles les plus vendus, chacun **avec sa devise** : un article
  /// appartient à une cuisine, donc à un marché.
  Future<List<Map<String, dynamic>>> getTopSellingItems({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 5,
  }) async {
    final fin = endDate ?? DateTime.now();
    final debut = startDate ?? fin.subtract(const Duration(days: 30));

    final lignes = await _reports.topProducts(start: debut, end: fin, limit: limit);
    return [
      for (final ligne in lignes)
        {
          'menu_item_id': ligne.menuItemId,
          'menu_item_name': ligne.itemName,
          'total_quantity': ligne.quantitySold,
          'total_revenue': montant(ligne.revenueMinor, ligne.currency),
          'currency': ligne.currency,
        },
    ];
  }

  /// Livraisons et gains par livreur. Les gains sont rendus avec leur devise
  /// (`driverEarningsCurrency`) : un livreur de Douala est payé en XAF.
  Future<Map<String, dynamic>> getDriverAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final lignes = await _reports.couriers(start: startDate, end: endDate);
    return {
      'driverDeliveries': <String, int>{
        for (final ligne in lignes) ligne.courierName: ligne.deliveries,
      },
      'driverEarnings': <String, double>{
        for (final ligne in lignes)
          ligne.courierName: montant(ligne.earningsMinor, ligne.currency),
      },
      'driverEarningsCurrency': <String, String>{
        for (final ligne in lignes) ligne.courierName: ligne.currency,
      },
    };
  }

  // --------------------------------------------------------- mise en forme

  /// Unité mineure → unité majeure, **selon la devise** (exposant compris).
  static double montant(int mineur, String devise) =>
      eccore.Money(amountMinor: mineur, currency: devise).toMajorUnits();

  /// Les devises présentes, la plus lourde en tête.
  static List<String> devisesParPoids(Iterable<({String devise, int mineur})> lignes) {
    final poids = <String, int>{};
    for (final ligne in lignes) {
      poids.update(
        ligne.devise,
        (cumul) => cumul + ligne.mineur,
        ifAbsent: () => ligne.mineur,
      );
    }
    final devises = poids.keys.toList()
      ..sort((a, b) => poids[b]!.compareTo(poids[a]!));
    return devises;
  }

  static String? _retenue(List<String> devises, String? demandee) =>
      demandee != null && devises.contains(demandee)
          ? demandee
          : (devises.isEmpty ? null : devises.first);

  Map<String, dynamic> _serieRevenus(List<eccore.RevenueRow> lignes, String? demandee) {
    final devises = devisesParPoids(
      lignes.map((l) => (devise: l.currency, mineur: l.revenueMinor)),
    );
    final devise = _retenue(devises, demandee);
    final retenues = lignes.where((l) => l.currency == devise);
    return {
      'currency': devise,
      'currencies': devises,
      'totalRevenue': retenues.fold<double>(
        0,
        (somme, ligne) => somme + montant(ligne.revenueMinor, ligne.currency),
      ),
      'dailyRevenue': <String, double>{
        for (final ligne in retenues) _jour(ligne.day): montant(ligne.revenueMinor, ligne.currency),
      },
    };
  }

  /// `dailyOrders` compte les commandes **livrées** par jour, toutes devises
  /// confondues — un compte, pas un montant : deux commandes font deux
  /// commandes, qu'elles soient payées en XOF ou en XAF.
  Map<String, dynamic> _serieCommandes(
    List<eccore.RevenueRow> revenus,
    List<eccore.StatusRow> statuts,
  ) {
    final parJour = <String, int>{};
    for (final ligne in revenus) {
      parJour.update(
        _jour(ligne.day),
        (cumul) => cumul + ligne.ordersCount,
        ifAbsent: () => ligne.ordersCount,
      );
    }
    return {
      'totalOrders': statuts.fold<int>(0, (somme, ligne) => somme + ligne.ordersCount),
      'statusCounts': <String, int>{
        for (final ligne in statuts) ligne.status: ligne.ordersCount,
      },
      'dailyOrders': parJour,
    };
  }

  Map<String, dynamic> _serieCategories(List<eccore.CategoryRow> lignes, String? demandee) {
    final devises = devisesParPoids(
      lignes.map((l) => (devise: l.currency, mineur: l.revenueMinor)),
    );
    final devise = _retenue(devises, demandee);
    final retenues = lignes.where((l) => l.currency == devise).toList();
    return {
      'currency': devise,
      'currencies': devises,
      'categoryCounts': <String, int>{
        for (final ligne in retenues) ligne.categoryName: ligne.quantitySold,
      },
      'categoryRevenue': <String, double>{
        for (final ligne in retenues) ligne.categoryName: montant(ligne.revenueMinor, ligne.currency),
      },
    };
  }

  String _jour(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// Les chiffres d'une journée d'exploitation, et de quelle journée il s'agit.
///
/// Un chiffre daté peut être vérifié ; un chiffre sans date ne peut qu'être
/// cru. Et un chiffre d'affaires sans devise ne peut qu'être mal lu : il y en
/// a désormais un **par devise** du périmètre.
class JourneeDExploitation {
  const JourneeDExploitation({required this.apercu, required this.revenusDeLaSemaine});

  final eccore.AnalyticsOverview apercu;

  /// Cumul de la semaine en cours, lundi compris, **par devise**.
  final Map<String, int> revenusDeLaSemaine;

  int get commandesDuJour => apercu.ordersCount;
  int get livraisonsDuJour => apercu.ordersDelivered;
  int get annulationsDuJour => apercu.ordersCancelled;

  /// Chiffre d'affaires livré du jour, une entrée par devise, la dominante en
  /// tête. Vide s'il n'y a eu aucune livraison.
  List<eccore.CurrencyRevenue> get revenusDuJour => apercu.revenues;

  /// La journée couverte, telle que le serveur l'a découpée.
  DateTime get jour => apercu.start;

  /// Comment nommer cette journée à l'écran.
  ///
  /// Le fuseau y figure dès qu'il est **incertain** — un périmètre qui
  /// traverse plusieurs pays n'a pas de journée commune.
  String get libelle {
    final date = '${jour.day.toString().padLeft(2, '0')}/'
        '${jour.month.toString().padLeft(2, '0')}';
    if (apercu.timezoneCertain) return 'Journée du $date';
    return 'Journée du $date — plusieurs fuseaux, découpage en UTC';
  }
}
