/// Une commande vue du poste de cuisine — miroir de `KitchenOrderSerializer`
/// (`backend/apps/orders/serializers.py`).
///
/// ## Pourquoi ce modèle n'est pas [Order]
///
/// Le poste lisait la forme de **liste** des commandes, qui ne porte pas les
/// lignes : chaque carte affichait « 3 article(s) » et rien d'autre. Un écran
/// de cuisine qui ne dit pas ce qu'il faut cuisiner n'a pas d'usage.
///
/// La forme **détaillée** aurait été pire : elle porte les montants, l'adresse
/// et le téléphone du client, que le poste n'a aucune raison de connaître, et
/// elle les porte pour chaque commande du service, relue à chaque événement.
///
/// Ce modèle-ci est donc ce qu'on cuisine, et rien de plus : quoi, combien,
/// comment, depuis quand.
library;

/// Une ligne à préparer — sans prix, par construction.
class KitchenLine {
  const KitchenLine({
    required this.id,
    required this.itemName,
    required this.quantity,
    this.options = const [],
    this.notes = '',
  });

  factory KitchenLine.fromJson(Map<String, dynamic> json) => KitchenLine(
    id: json['id']?.toString() ?? '',
    itemName: json['item_name'] as String? ?? '',
    quantity: json['quantity'] as int? ?? 1,
    options: _optionsDepuis(json['options']),
    notes: json['notes'] as String? ?? '',
  );

  /// Les options voyagent en `[{group, option}]` — la forme figée sur la ligne
  /// de commande. Seul le choix intéresse la cuisine ; le nom du groupe
  /// (« Cuisson ») n'apprend rien à qui lit « À point ».
  static List<String> _optionsDepuis(Object? brut) {
    if (brut is! List) return const [];
    return [
      for (final option in brut)
        if (option is Map && (option['option']?.toString() ?? '').isNotEmpty)
          option['option'].toString()
        else if (option is String && option.isNotEmpty)
          option,
    ];
  }

  final String id;
  final String itemName;
  final int quantity;
  final List<String> options;

  /// La demande du client sur cette ligne — « sans oignons ».
  final String notes;

  /// « 2 × Burger Corazón (À point) ».
  String get libelle =>
      '$quantity × $itemName${options.isEmpty ? '' : ' (${options.join(', ')})'}';
}

/// Une commande de la file de production.
class KitchenOrder {
  const KitchenOrder({
    required this.id,
    required this.reference,
    required this.status,
    required this.allowedTransitions,
    required this.placedAt,
    this.estimatedDeliveryAt,
    this.itemsCount = 0,
    this.deliveryInstructions = '',
    this.lines = const [],
  });

  factory KitchenOrder.fromJson(Map<String, dynamic> json) {
    final estimee = json['estimated_delivery_at'] as String?;
    return KitchenOrder(
      id: json['id'] as String,
      reference: json['reference'] as String? ?? '',
      status: json['status'] as String,
      allowedTransitions: (json['allowed_transitions'] as List<dynamic>? ?? const [])
          .map((transition) => transition.toString())
          .toList(growable: false),
      placedAt: DateTime.parse(json['placed_at'] as String),
      estimatedDeliveryAt: estimee == null ? null : DateTime.parse(estimee),
      itemsCount: json['items_count'] as int? ?? 0,
      deliveryInstructions: json['delivery_instructions'] as String? ?? '',
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .map((ligne) => KitchenLine.fromJson(ligne as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final String id;
  final String reference;

  /// Voir `OrderStatus` côté serveur.
  final String status;

  /// Les étapes que le serveur autorise depuis l'état courant. **La** source
  /// des boutons : la machine à états ne se recopie pas côté client.
  final List<String> allowedTransitions;

  final DateTime placedAt;
  final DateTime? estimatedDeliveryAt;

  /// La somme des quantités — deux burgers et une pizza font trois articles.
  final int itemsCount;

  /// La consigne du client. Elle s'adresse au livreur, mais elle se lit au
  /// conditionnement : « pas de couverts » se décide en emballant.
  final String deliveryInstructions;

  final List<KitchenLine> lines;
}
