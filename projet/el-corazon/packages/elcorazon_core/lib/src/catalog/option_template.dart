import '../models/money.dart';

/// Option réutilisable de la bibliothèque d'un établissement — miroir de
/// `ManagedOptionTemplateSerializer`.
///
/// C'est un **modèle**, pas une option en service. L'appliquer à un article y
/// copie une option ; corriger le modèle ensuite ne repricera aucun article
/// déjà en vitrine, ni aucun panier en cours de composition (C1).
class OptionTemplate {
  const OptionTemplate({
    required this.id,
    required this.restaurantSlug,
    required this.name,
    required this.groupName,
    required this.priceDelta,
    required this.isDefault,
    required this.isActive,
    required this.sortOrder,
  });

  factory OptionTemplate.fromJson(Map<String, dynamic> json) {
    return OptionTemplate(
      id: json['id'] as String,
      restaurantSlug: json['restaurant'] as String,
      name: json['name'] as String,
      groupName: json['group_name'] as String? ?? '',
      priceDelta: Money.fromJson(json['price_delta'] as Map<String, dynamic>),
      isDefault: json['is_default'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  final String id;
  final String restaurantSlug;
  final String name;

  /// Groupe suggéré à l'application (« Cuisson », « Suppléments »). Il évite de
  /// redemander à chaque fois où ranger l'option, sans l'imposer.
  final String groupName;
  final Money priceDelta;

  /// Présélectionnée dans son groupe une fois appliquée — « à point ».
  final bool isDefault;
  final bool isActive;
  final int sortOrder;
}
