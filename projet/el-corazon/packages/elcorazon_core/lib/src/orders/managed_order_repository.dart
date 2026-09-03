import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/network/page.dart';
import 'package:elcorazon_core/src/orders/order.dart';

/// Supervision des commandes — `/api/v1/orders/manage/`
/// (`backend/apps/orders/backoffice.py`).
///
/// Ni création ni suppression, et ce n'est pas une omission : une commande naît
/// d'un panier client, jamais d'un écran d'exploitation ; et c'est une pièce
/// comptable, donc ce qui n'a pas eu lieu s'annule au lieu de disparaître.
///
/// Le périmètre est **le filtre de requête du serveur** : un membre du
/// personnel ne voit que les commandes des établissements auxquels il est
/// rattaché. Il n'y a pas de filtre à écrire ici, donc pas de filtre à oublier.
class ManagedOrderRepository {
  ManagedOrderRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Commandes de supervision, les plus récentes d'abord.
  ///
  /// [placedFrom]/[placedTo] bornent le service en cours : sans elles, un
  /// écran de supervision charge l'historique entier pour n'en afficher que la
  /// fin.
  Future<List<Order>> list({
    String? status,
    String? restaurantSlug,
    String? customerId,
    DateTime? placedFrom,
    DateTime? placedTo,
  }) async {
    final orders = <Order>[];
    String? path = '/orders/manage/';
    Map<String, dynamic>? queryParameters = {
      if (status != null) 'status': status,
      if (restaurantSlug != null) 'restaurant__slug': restaurantSlug,
      if (customerId != null) 'customer': customerId,
      if (placedFrom != null) 'placed_at__gte': placedFrom.toUtc().toIso8601String(),
      if (placedTo != null) 'placed_at__lte': placedTo.toUtc().toIso8601String(),
    };

    while (path != null) {
      final response = await apiClient.get(path, queryParameters: queryParameters);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      orders.addAll(results.map((json) => Order.fromJson(json as Map<String, dynamic>)));
      path = body['next'] as String?;
      queryParameters = null;
    }

    return orders;
  }

  /// **Une page** de commandes de supervision, filtrée par le serveur.
  ///
  /// À préférer à [list] partout où l'écran affiche une liste que l'opérateur
  /// parcourt : [list] suit `next` jusqu'au bout, ce qui convient à un total à
  /// calculer et pas du tout à un tableau à afficher. Sur un an de service,
  /// c'est la différence entre une requête et plusieurs centaines.
  ///
  /// [pageSize] est plafonné à 100 par le serveur (`max_page_size`) ; demander
  /// davantage rend simplement 100.
  Future<Page<Order>> listPage({
    String? status,
    String? restaurantSlug,
    String? customerId,
    DateTime? placedFrom,
    DateTime? placedTo,
    String? search,
    int pageSize = 20,
  }) async {
    final response = await apiClient.get(
      '/orders/manage/',
      queryParameters: {
        'page_size': pageSize,
        if (status != null) 'status': status,
        if (restaurantSlug != null) 'restaurant__slug': restaurantSlug,
        if (customerId != null) 'customer': customerId,
        if (placedFrom != null) 'placed_at__gte': placedFrom.toUtc().toIso8601String(),
        if (placedTo != null) 'placed_at__lte': placedTo.toUtc().toIso8601String(),
        // Coupé puis testé : `'   '` n'est pas vide au sens de Dart, et
        // l'envoyer ferait filtrer le serveur sur des espaces — donc zéro
        // résultat, pour une recherche que l'opérateur croit vide.
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return Page<Order>.fromJson(
      response.data as Map<String, dynamic>,
      Order.fromJson,
    );
  }

  /// La page désignée par une URL `next`/`previous` rendue par le serveur.
  ///
  /// L'URL porte déjà les filtres de la requête d'origine : la rejouer telle
  /// quelle garantit que la page suivante suit bien la précédente, ce qu'une
  /// reconstruction à partir d'un numéro de page ne garantit pas.
  Future<Page<Order>> pageAt(String url) async {
    final response = await apiClient.get(url);
    return Page<Order>.fromJson(
      response.data as Map<String, dynamic>,
      Order.fromJson,
    );
  }

  /// Le nombre de commandes **par statut** — `GET /orders/manage/counts/`.
  ///
  /// Une requête pour les huit compteurs, sur le périmètre du compte et les
  /// filtres passés. Les obtenir autrement demanderait un appel paginé par
  /// onglet — cinq requêtes pour cinq nombres, à chaque ouverture de l'écran —
  /// ou de charger toutes les commandes pour les compter ici, ce que la
  /// pagination cherche précisément à éviter.
  ///
  /// Les filtres sont **les mêmes que ceux de la liste**, et c'est nécessaire :
  /// un onglet qui annoncerait douze commandes et en afficherait trois ferait
  /// chercher les neuf autres.
  ///
  /// Tous les statuts sont présents dans la réponse, à zéro le cas échéant :
  /// l'appelant n'a pas à distinguer « aucune commande » d'une clé absente.
  Future<Map<String, int>> countsByStatus({
    String? restaurantSlug,
    String? search,
    DateTime? placedFrom,
    DateTime? placedTo,
  }) async {
    final response = await apiClient.get(
      '/orders/manage/counts/',
      queryParameters: {
        if (restaurantSlug != null) 'restaurant__slug': restaurantSlug,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (placedFrom != null) 'placed_at__gte': placedFrom.toUtc().toIso8601String(),
        if (placedTo != null) 'placed_at__lte': placedTo.toUtc().toIso8601String(),
      },
    );
    final body = response.data as Map<String, dynamic>;
    return {
      for (final entree in body.entries) entree.key: (entree.value as num).toInt(),
    };
  }

  Future<Order> getById(String orderId) async {
    final response = await apiClient.get('/orders/manage/$orderId/');
    return Order.fromJson(response.data as Map<String, dynamic>);
  }

  /// Fait avancer le statut — permission `orders.update_status`.
  ///
  /// La machine à états décide côté serveur : une transition refusée sort en
  /// 409 **avec les cibles autorisées**, ce qui permet d'afficher les bons
  /// boutons plutôt que de rejouer le graphe ici.
  ///
  /// `cancelled` n'est pas une cible acceptée : annuler passe par [cancel], qui
  /// exige une permission distincte et un motif. Faire avancer le service est
  /// le geste de tous les jours ; annuler la commande d'un tiers ne l'est pas.
  Future<Order> updateStatus({
    required String orderId,
    required String status,
    String reason = '',
  }) async {
    final response = await apiClient.post(
      '/orders/manage/$orderId/status/',
      data: {'status': status, if (reason.isNotEmpty) 'reason': reason},
    );
    return Order.fromJson(response.data as Map<String, dynamic>);
  }

  /// Annule une commande — permission `orders.cancel`, motif obligatoire.
  Future<Order> cancel({required String orderId, required String reason}) async {
    final response = await apiClient.post(
      '/orders/manage/$orderId/cancel/',
      data: {'reason': reason},
    );
    return Order.fromJson(response.data as Map<String, dynamic>);
  }
}
