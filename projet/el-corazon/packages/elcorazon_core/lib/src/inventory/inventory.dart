import 'package:elcorazon_core/src/inventory/quantity.dart';
import 'package:elcorazon_core/src/models/money.dart';

/// Une référence d'achat de l'enseigne — miroir de `IngredientSerializer`
/// (`backend/apps/inventory/serializers.py`).
///
/// Elle n'appartient à aucune cuisine : une tomate est une tomate à Lomé comme
/// à Abidjan. Son **stock** et son **coût**, eux, sont par cuisine
/// ([StockLine]).
class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.slug,
    required this.dimension,
    required this.isActive,
    this.description = '',
    this.allergens = const [],
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String? ?? '',
      dimension: json['dimension'] as String,
      allergens: (json['allergens'] as List<dynamic>? ?? const [])
          .map((code) => code.toString())
          .toList(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final String slug;
  final String description;

  /// `mass`, `volume` ou `count`. Ne change plus après la création : elle donne
  /// leur sens à tous les mouvements passés.
  final String dimension;
  final List<String> allergens;

  /// Faux : la référence est retirée. On n'en reçoit plus, et une recette ne
  /// peut plus l'employer — mais son histoire reste lisible.
  final bool isActive;
}

/// Ce qu'une cuisine détient d'un ingrédient — miroir de `StockItemSerializer`.
///
/// Rien ici ne s'écrit directement : le stock ne bouge qu'à travers une
/// réception, une perte ou une correction, que le serveur journalise.
class StockLine {
  const StockLine({
    required this.id,
    required this.restaurantSlug,
    required this.ingredientId,
    required this.ingredientName,
    required this.dimension,
    required this.onHand,
    required this.reserved,
    required this.available,
    required this.isLow,
    required this.costUnit,
    this.lowStockThreshold,
    this.unitCost,
    this.stockValue,
  });

  factory StockLine.fromJson(Map<String, dynamic> json) {
    return StockLine(
      id: json['id'] as String,
      restaurantSlug: json['restaurant'] as String,
      ingredientId: json['ingredient'] as String,
      ingredientName: json['ingredient_name'] as String? ?? '',
      dimension: json['dimension'] as String? ?? '',
      onHand: Quantity.fromJson(json['on_hand'] as Map<String, dynamic>),
      reserved: Quantity.fromJson(json['reserved'] as Map<String, dynamic>),
      available: Quantity.fromJson(json['available'] as Map<String, dynamic>),
      lowStockThreshold: json['low_stock_threshold'] == null
          ? null
          : Quantity.fromJson(json['low_stock_threshold'] as Map<String, dynamic>),
      isLow: json['is_low'] as bool? ?? false,
      unitCost: json['unit_cost'] == null
          ? null
          : Money.fromJson(json['unit_cost'] as Map<String, dynamic>),
      costUnit: json['cost_unit'] as String? ?? '',
      stockValue: json['stock_value'] == null
          ? null
          : Money.fromJson(json['stock_value'] as Map<String, dynamic>),
    );
  }

  final String id;
  final String restaurantSlug;
  final String ingredientId;
  final String ingredientName;
  final String dimension;

  /// Physiquement présent.
  final Quantity onHand;

  /// Promis à des commandes, pas encore cuisiné.
  final Quantity reserved;

  /// Détenu moins promis — ce qu'une nouvelle commande peut encore emporter.
  final Quantity available;

  final Quantity? lowStockThreshold;

  /// Le disponible est au seuil d'alerte ou en dessous. Toujours faux sans seuil.
  final bool isLow;

  /// Coût moyen pondéré par [costUnit] — nul tant qu'aucune livraison facturée
  /// n'est entrée : inventer zéro afficherait une marge de 100 %.
  final Money? unitCost;

  /// `kg`, `l` ou `unit` : l'unité dans laquelle se lit [unitCost].
  final String costUnit;

  /// Valeur du stock détenu au coût moyen — nulle si le coût est inconnu.
  final Money? stockValue;
}

/// Une ligne du journal — miroir de `StockMovementSerializer`. Lecture seule :
/// un mouvement ne se modifie ni ne s'efface, il se contre-passe.
class StockMovement {
  const StockMovement({
    required this.id,
    required this.stockLineId,
    required this.ingredientName,
    required this.kind,
    required this.quantity,
    required this.createdAt,
    this.unitCost,
    this.value,
    this.actorName = '',
    this.reason = '',
    this.reference = '',
  });

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    final acteur = json['actor'] as Map<String, dynamic>?;
    return StockMovement(
      id: json['id'] as String,
      stockLineId: json['stock_item'] as String,
      ingredientName: json['ingredient_name'] as String? ?? '',
      kind: json['kind'] as String,
      quantity: Quantity.fromJson(json['quantity'] as Map<String, dynamic>),
      unitCost: json['unit_cost'] == null
          ? null
          : Money.fromJson(json['unit_cost'] as Map<String, dynamic>),
      value: json['value'] == null ? null : Money.fromJson(json['value'] as Map<String, dynamic>),
      actorName: acteur?['full_name'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String stockLineId;
  final String ingredientName;

  /// `receipt`, `purchase`, `consumption`, `waste`, `adjustment`, `transfer`,
  /// `reservation`, `release` (`MovementKind`).
  final String kind;

  /// Signée : négative pour une sortie.
  final Quantity quantity;
  final Money? unitCost;

  /// Valeur au coût figé sur la ligne, signée comme la quantité.
  final Money? value;
  final String actorName;
  final String reason;
  final String reference;
  final DateTime createdAt;
}

/// Une page du journal, par curseur — `HighVolumeCursorPagination`.
///
/// Pas de `count` : le journal ne cesse de grandir, et le compter à chaque
/// écran coûterait une lecture de la table entière.
class CursorPage<T> {
  const CursorPage({required this.results, this.next});

  final List<T> results;

  /// URL complète de la page suivante, ou `null` sur la dernière.
  final String? next;

  bool get hasNext => next != null;
}

/// Une perte ou une correction en attente de seconde validation — miroir de
/// `AdjustmentRequestSerializer`.
class AdjustmentRequest {
  const AdjustmentRequest({
    required this.id,
    required this.stockLineId,
    required this.restaurantSlug,
    required this.ingredientName,
    required this.kind,
    required this.quantity,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.estimatedValue,
    this.requestedById,
    this.requestedByName = '',
    this.decidedByName = '',
    this.decisionNote = '',
  });

  factory AdjustmentRequest.fromJson(Map<String, dynamic> json) {
    final demandeur = json['requested_by'] as Map<String, dynamic>?;
    final decideur = json['decided_by'] as Map<String, dynamic>?;
    return AdjustmentRequest(
      id: json['id'] as String,
      stockLineId: json['stock_item'] as String,
      restaurantSlug: json['restaurant'] as String? ?? '',
      ingredientName: json['ingredient_name'] as String? ?? '',
      kind: json['kind'] as String,
      quantity: Quantity.fromJson(json['quantity'] as Map<String, dynamic>),
      reason: json['reason'] as String? ?? '',
      estimatedValue: json['estimated_value'] == null
          ? null
          : Money.fromJson(json['estimated_value'] as Map<String, dynamic>),
      status: json['status'] as String,
      requestedById: demandeur?['id'] as String?,
      requestedByName: demandeur?['full_name'] as String? ?? '',
      decidedByName: decideur?['full_name'] as String? ?? '',
      decisionNote: json['decision_note'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String stockLineId;
  final String restaurantSlug;
  final String ingredientName;

  /// `waste` ou `adjustment`.
  final String kind;

  /// Signée, telle qu'elle sera écrite : une perte est négative.
  final Quantity quantity;
  final String reason;

  /// Au coût du moment de la déclaration — nulle si le coût était inconnu.
  final Money? estimatedValue;

  /// `pending`, `approved` ou `rejected`.
  final String status;

  /// Qui a déclaré. Le serveur refuse que cette personne tranche : l'écran
  /// s'en sert pour ne pas proposer un bouton qui ne peut qu'échouer.
  final String? requestedById;
  final String requestedByName;
  final String decidedByName;
  final String decisionNote;
  final DateTime createdAt;

  bool get isPending => status == 'pending';
}

/// Ce qu'une déclaration de perte ou de correction a produit.
///
/// Exactement l'un des deux : le mouvement, écrit parce que la valeur passait
/// sous le plafond de la cuisine ; ou la demande, qui attend une seconde
/// personne. L'application ne choisit pas — elle dit ce qui s'est passé.
class Declaration {
  const Declaration({this.movement, this.request});

  factory Declaration.fromJson(Map<String, dynamic> json) {
    return Declaration(
      movement: json['movement'] == null
          ? null
          : StockMovement.fromJson(json['movement'] as Map<String, dynamic>),
      request: json['request'] == null
          ? null
          : AdjustmentRequest.fromJson(json['request'] as Map<String, dynamic>),
    );
  }

  final StockMovement? movement;
  final AdjustmentRequest? request;

  bool get isPendingApproval => movement == null && request != null;
}

/// Une ligne de nomenclature — miroir de `RecipeLineSerializer`.
class RecipeLine {
  const RecipeLine({
    required this.ingredientId,
    required this.ingredientName,
    required this.quantity,
  });

  factory RecipeLine.fromJson(Map<String, dynamic> json) {
    return RecipeLine(
      ingredientId: json['ingredient'] as String,
      ingredientName: json['ingredient_name'] as String? ?? '',
      quantity: Quantity.fromJson(json['quantity'] as Map<String, dynamic>),
    );
  }

  final String ingredientId;
  final String ingredientName;

  /// Négative seulement sur la recette d'une option qui **retire** —
  /// « sans oignon ».
  final Quantity quantity;
}

/// La recette d'un plat ou d'une option — miroir de `RecipeSerializer`.
class Recipe {
  const Recipe({
    required this.id,
    required this.targetName,
    required this.restaurantSlug,
    required this.lines,
    this.menuItemId,
    this.optionId,
    this.notes = '',
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      menuItemId: json['menu_item'] as String?,
      optionId: json['option'] as String?,
      targetName: json['target_name'] as String? ?? '',
      restaurantSlug: json['restaurant'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .map((ligne) => RecipeLine.fromJson(ligne as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;

  /// Exactement l'un des deux est renseigné.
  final String? menuItemId;
  final String? optionId;
  final String targetName;
  final String restaurantSlug;
  final String notes;
  final List<RecipeLine> lines;
}

/// Ce qui reste à saisir avant de croire le coût matière d'une cuisine —
/// miroir de `CoverageSerializer`.
class RecipeCoverage {
  const RecipeCoverage({
    required this.restaurantSlug,
    required this.itemsTotal,
    required this.itemsWithRecipe,
    required this.missing,
  });

  factory RecipeCoverage.fromJson(Map<String, dynamic> json) {
    return RecipeCoverage(
      restaurantSlug: json['restaurant'] as String,
      itemsTotal: json['items_total'] as int,
      itemsWithRecipe: json['items_with_recipe'] as int,
      missing: (json['missing'] as List<dynamic>)
          .map(
            (plat) => (
              id: (plat as Map<String, dynamic>)['id'] as String,
              name: plat['name'] as String,
              category: plat['category'] as String? ?? '',
            ),
          )
          .toList(),
    );
  }

  final String restaurantSlug;
  final int itemsTotal;
  final int itemsWithRecipe;

  /// Les plats de la carte sans recette : ils ne consomment rien au stock, et
  /// leur coût matière est inconnu.
  final List<({String id, String name, String category})> missing;

  /// Part de la carte dont le coût matière est connu, entre 0 et 1.
  double get ratio => itemsTotal == 0 ? 1 : itemsWithRecipe / itemsTotal;

  bool get isComplete => missing.isEmpty;
}
