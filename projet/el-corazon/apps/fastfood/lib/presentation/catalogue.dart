import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Ce que les écrans lisent d'un article ou d'une catégorie du catalogue.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// `models/menu_item.dart` et `models/menu_category.dart` doublaient
/// `eccore.MenuItem` et `eccore.Category`, et `DjangoMenuRepository` traduisait
/// de l'un vers l'autre. Ce qui reste ici n'est pas une copie : ce sont les
/// quelques accès d'affichage que le modèle local offrait en plus, posés sur
/// l'entité du socle.
extension ArticleAffiche on eccore.MenuItem {
  /// Le prix en unité majeure, pour l'affichage seul.
  ///
  /// Jamais pour recalculer un total : le serveur est seul à l'établir
  /// (ADR-007).
  double get prixAffiche => price.toMajorUnits();

  /// Les deux régimes que les écrans distinguent.
  ///
  /// Le contrat ne porte pas de booléens séparés : ils se lisent sur
  /// `dietary_tags`, qui en connaît d'autres.
  bool get estVegetarien => dietaryTags.contains('vegetarian');
  bool get estVegan => dietaryTags.contains('vegan');

  /// L'article est-il commandable en l'état ?
  bool get estCommandable => isAvailable;
}

extension CategorieAffichee on eccore.Category {
  /// La pastille de la catégorie, ou une assiette à défaut.
  ///
  /// `emoji` est vide dès que l'établissement n'en a pas configuré. Ce repli
  /// existe parce que `OfflineSyncService` écartait purement et simplement
  /// toute catégorie sans pastille : elle disparaissait du mode hors-ligne.
  String get pastille => emoji.isEmpty ? '🍽️' : emoji;
}
