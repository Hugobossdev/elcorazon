import 'package:elcorazon_core/src/models/money.dart';

/// Une taille telle que le back-office la gère — `ManagedVariantSerializer`.
///
/// Distincte de `Variante` (ce que voit le client) : elle porte ce qui ne se
/// montre pas au client — le SKU, et `isActive`, qui retire la taille de la
/// carte sans effacer sa saisie.
class TailleGeree {
  const TailleGeree({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.price,
    this.sku = '',
    this.isAvailable = true,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory TailleGeree.fromJson(Map<String, dynamic> json) => TailleGeree(
        id: json['id'] as String,
        menuItemId: json['menu_item'] as String,
        name: json['name'] as String,
        price: Money.fromJson(json['price'] as Map<String, dynamic>),
        sku: json['sku'] as String? ?? '',
        isAvailable: json['is_available'] as bool? ?? true,
        isActive: json['is_active'] as bool? ?? true,
        sortOrder: json['sort_order'] as int? ?? 0,
      );

  final String id;
  final String menuItemId;
  final String name;

  /// Prix **absolu** : il remplace celui de l'article (décision du 2026-09-25).
  final Money price;
  final String sku;
  final bool isAvailable;
  final bool isActive;
  final int sortOrder;
}
