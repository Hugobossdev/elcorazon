import 'package:elcorazon_core/src/inventory/inventory.dart';
import 'package:elcorazon_core/src/inventory/quantity.dart';
import 'package:elcorazon_core/src/models/money.dart';
import 'package:elcorazon_core/src/network/api_client.dart';

/// Inventaire d'une cuisine — `/api/v1/inventory/manage/*`
/// (`backend/apps/inventory/backoffice.py`).
///
/// ## Ce que ce dépôt n'offre pas
///
/// **Aucune écriture de stock directe.** Le stock ne bouge qu'à travers une
/// réception, une perte ou une correction ; le serveur tient le journal et la
/// colonne ensemble, et applique le plafond au-delà duquel une seconde personne
/// doit valider. Une méthode `setOnHand` serait l'écriture sans trace que tout
/// le domaine existe pour interdire.
///
/// ## La clé d'idempotence, fournie par l'appelant
///
/// Réception, perte et correction exigent l'en-tête `Idempotency-Key`. La clé
/// est **fournie par l'écran**, et non tirée ici : c'est lui qui sait ce qu'est
/// « une tentative » — elle naît à l'ouverture du formulaire et ne change pas
/// quand l'utilisateur réappuie après une coupure. Tirée à chaque appel, elle
/// ne protégerait que contre un rejeu que personne ne fait.
class ManagedInventoryRepository {
  ManagedInventoryRepository({required this.apiClient});

  final ApiClient apiClient;

  static const _idempotence = 'Idempotency-Key';

  // ----------------------------------------------------------- référentiel

  Future<List<Ingredient>> ingredients({bool? isActive, String search = ''}) {
    return _collect(
      '/inventory/manage/ingredients/',
      Ingredient.fromJson,
      queryParameters: {
        if (isActive != null) 'is_active': isActive,
        if (search.isNotEmpty) 'search': search,
      },
    );
  }

  /// Réservé au siège par le serveur : un compte rattaché à une cuisine reçoit
  /// un 403, le référentiel n'appartenant à aucune.
  Future<Ingredient> createIngredient({
    required String name,
    required String slug,
    required String dimension,
    String description = '',
    List<String> allergens = const [],
  }) async {
    final response = await apiClient.post(
      '/inventory/manage/ingredients/',
      data: {
        'name': name,
        'slug': slug,
        'dimension': dimension,
        'description': description,
        'allergens': allergens,
      },
    );
    return Ingredient.fromJson(response.data as Map<String, dynamic>);
  }

  /// La dimension n'y figure pas : elle ne change plus après la création.
  Future<Ingredient> updateIngredient(
    String id, {
    String? name,
    String? description,
    List<String>? allergens,
    bool? isActive,
  }) async {
    final response = await apiClient.patch(
      '/inventory/manage/ingredients/$id/',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (allergens != null) 'allergens': allergens,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return Ingredient.fromJson(response.data as Map<String, dynamic>);
  }

  // ----------------------------------------------------------------- stock

  Future<List<StockLine>> stockLines({required String restaurantSlug, bool lowOnly = false}) {
    return _collect(
      '/inventory/manage/stock/',
      StockLine.fromJson,
      queryParameters: {'restaurant__slug': restaurantSlug, if (lowOnly) 'low': true},
    );
  }

  /// Ouvre la ligne — idempotent : une ligne déjà ouverte est rendue telle quelle.
  Future<StockLine> openStockLine({
    required String restaurantSlug,
    required String ingredientId,
    Quantity? lowStockThreshold,
  }) async {
    final response = await apiClient.post(
      '/inventory/manage/stock/',
      data: {
        'restaurant': restaurantSlug,
        'ingredient': ingredientId,
        if (lowStockThreshold != null) 'low_stock_threshold': lowStockThreshold.toJson(),
      },
    );
    return StockLine.fromJson(response.data as Map<String, dynamic>);
  }

  /// Fixe — ou retire, avec `null` — le seuil d'alerte.
  Future<StockLine> setLowStockThreshold(String stockLineId, Quantity? threshold) async {
    final response = await apiClient.patch(
      '/inventory/manage/stock/$stockLineId/',
      data: {'low_stock_threshold': threshold?.toJson()},
    );
    return StockLine.fromJson(response.data as Map<String, dynamic>);
  }

  // ------------------------------------------------------------- écritures

  /// Enregistre une livraison. [totalCost] est le prix **du lot**, tel qu'il
  /// figure sur la facture ; le serveur en déduit le coût par kilogramme.
  Future<StockMovement> receive({
    required String stockLineId,
    required Quantity quantity,
    required String idempotencyKey,
    Money? totalCost,
    String reference = '',
  }) async {
    final response = await apiClient.post(
      '/inventory/manage/stock/$stockLineId/receive/',
      data: {
        'quantity': quantity.toJson(),
        if (totalCost != null) 'total_cost': totalCost.toJson(),
        'reference': reference,
      },
      headers: {_idempotence: idempotencyKey},
    );
    return StockMovement.fromJson(response.data as Map<String, dynamic>);
  }

  /// Déclare une perte. Écrite tout de suite sous le plafond de la cuisine,
  /// soumise à validation au-delà — [Declaration.isPendingApproval] le dit.
  Future<Declaration> declareWaste({
    required String stockLineId,
    required Quantity quantity,
    required String reason,
    required String idempotencyKey,
  }) async {
    final response = await apiClient.post(
      '/inventory/manage/stock/$stockLineId/waste/',
      data: {'quantity': quantity.toJson(), 'reason': reason},
      headers: {_idempotence: idempotencyKey},
    );
    return Declaration.fromJson(response.data as Map<String, dynamic>);
  }

  /// Déclare un écart constaté par un comptage : [counted] est ce qu'on trouve
  /// sur l'étagère, et le serveur fait la soustraction contre le stock du
  /// moment.
  Future<Declaration> declareCount({
    required String stockLineId,
    required Quantity counted,
    required String reason,
    required String idempotencyKey,
  }) async {
    final response = await apiClient.post(
      '/inventory/manage/stock/$stockLineId/adjust/',
      data: {'counted': counted.toJson(), 'reason': reason},
      headers: {_idempotence: idempotencyKey},
    );
    return Declaration.fromJson(response.data as Map<String, dynamic>);
  }

  // --------------------------------------------------------------- journal

  /// Une page du journal d'une ligne. [next] est l'URL rendue par la page
  /// précédente : la reconstruire ferait perdre le curseur.
  Future<CursorPage<StockMovement>> movements({required String stockLineId, String? next}) async {
    final response = next != null
        ? await apiClient.get(next)
        : await apiClient.get(
            '/inventory/manage/movements/',
            queryParameters: {'stock_item': stockLineId},
          );
    final body = response.data as Map<String, dynamic>;
    return CursorPage(
      results: (body['results'] as List<dynamic>)
          .map((ligne) => StockMovement.fromJson(ligne as Map<String, dynamic>))
          .toList(),
      next: body['next'] as String?,
    );
  }

  // ------------------------------------------------------------ validation

  Future<List<AdjustmentRequest>> adjustmentRequests({
    required String restaurantSlug,
    String? status = 'pending',
  }) {
    return _collect(
      '/inventory/manage/adjustment-requests/',
      AdjustmentRequest.fromJson,
      queryParameters: {
        'stock_item__restaurant__slug': restaurantSlug,
        if (status != null) 'status': status,
      },
    );
  }

  Future<AdjustmentRequest> approve(String requestId, {String note = ''}) async {
    final response = await apiClient.post(
      '/inventory/manage/adjustment-requests/$requestId/approve/',
      data: {'note': note},
    );
    return AdjustmentRequest.fromJson(response.data as Map<String, dynamic>);
  }

  /// Le motif est obligatoire : la personne qui a déclaré doit savoir quoi
  /// recompter.
  Future<AdjustmentRequest> reject(String requestId, {required String note}) async {
    final response = await apiClient.post(
      '/inventory/manage/adjustment-requests/$requestId/reject/',
      data: {'note': note},
    );
    return AdjustmentRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<T>> _collect<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final items = <T>[];
    String? next = path;
    Map<String, dynamic>? parameters = queryParameters;

    while (next != null) {
      final response = await apiClient.get(next, queryParameters: parameters);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      items.addAll(results.map((json) => fromJson(json as Map<String, dynamic>)));
      next = body['next'] as String?;
      parameters = null;
    }

    return items;
  }
}
