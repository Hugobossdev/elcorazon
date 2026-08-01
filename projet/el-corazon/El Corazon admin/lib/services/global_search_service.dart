import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'admin_auth_service.dart';

/// Un résultat de recherche, tel que l'affiche l'écran.
///
/// `title` et `subtitle` viennent du serveur : c'est lui qui sait ce qui
/// identifie une commande (sa référence) ou un livreur (son nom et son
/// véhicule). Les composer ici obligerait à recopier quatre mises en forme,
/// qui divergeraient à la première évolution du modèle.
class GlobalSearchResult {
  const GlobalSearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
  });

  final String id;
  final String title;
  final String subtitle;

  /// `order` | `customer` | `courier` | `menu_item`.
  final String type;
}

/// Résultats rangés par famille.
class GlobalSearchResults {
  const GlobalSearchResults({
    this.orders = const [],
    this.menuItems = const [],
    this.users = const [],
    this.drivers = const [],
  });

  final List<GlobalSearchResult> orders;
  final List<GlobalSearchResult> menuItems;
  final List<GlobalSearchResult> users;
  final List<GlobalSearchResult> drivers;

  bool get isEmpty =>
      orders.isEmpty && menuItems.isEmpty && users.isEmpty && drivers.isEmpty;

  List<GlobalSearchResult> get all => [
    ...orders,
    ...menuItems,
    ...users,
    ...drivers,
  ];
}

/// Recherche transverse — `/search/?q=…` (Phase 6).
///
/// **Un appel, pas quatre.** L'ancienne version lançait depuis le navigateur
/// quatre requêtes sur quatre tables, et c'est la seule chose qu'elle faisait :
/// ni permission, ni cloisonnement. Un opérateur de Kara y trouvait les
/// commandes de Lomé ; un compte privé de `customers.read` y lisait des numéros
/// de téléphone de clients.
///
/// Le serveur applique maintenant, famille par famille, la permission du
/// domaine et le périmètre d'établissement. Une famille dont le compte n'a pas
/// le droit est **absente** de la réponse plutôt que vide — « rien trouvé » et
/// « vous n'y avez pas accès » ne se corrigent pas de la même façon, et un
/// écran qui rend une liste vide dans les deux cas fait chercher au mauvais
/// endroit.
class GlobalSearchService extends ChangeNotifier {
  eccore.SearchRepository get _search =>
      eccore.SearchRepository(apiClient: AdminAuthService().apiClient);

  bool _isSearching = false;
  String? _error;

  bool get isSearching => _isSearching;
  String? get error => _error;

  Future<GlobalSearchResults> searchAll(String query) async {
    // Le serveur refuse en deçà de trois caractères ; le dire ici évite un
    // aller-retour à chaque frappe.
    if (query.trim().length < 3) return const GlobalSearchResults();

    _isSearching = true;
    _error = null;
    notifyListeners();

    try {
      final hits = await _search.search(query);
      return GlobalSearchResults(
        orders: _famille(hits, eccore.SearchKind.order),
        menuItems: _famille(hits, eccore.SearchKind.menuItem),
        users: _famille(hits, eccore.SearchKind.customer),
        drivers: _famille(hits, eccore.SearchKind.courier),
      );
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Recherche : indisponible — ${e.code}');
      return const GlobalSearchResults();
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Recherche rapide pour l'autocomplétion.
  Future<List<GlobalSearchResult>> quickSearch(String query) async {
    if (query.trim().length < 3) return const [];

    try {
      final hits = await _search.search(query, limit: 3);
      return hits.map(_toLocal).toList();
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      return const [];
    }
  }

  List<GlobalSearchResult> _famille(List<eccore.SearchHit> hits, String kind) =>
      hits.where((hit) => hit.kind == kind).map(_toLocal).toList();

  GlobalSearchResult _toLocal(eccore.SearchHit hit) => GlobalSearchResult(
    id: hit.id,
    title: hit.title,
    subtitle: hit.subtitle,
    type: hit.kind,
  );
}
