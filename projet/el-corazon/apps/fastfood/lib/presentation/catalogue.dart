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
  /// L'illustration de la catégorie, ou `null` si le pack n'en a pas.
  ///
  /// ## Pourquoi elle ne vient plus de `emoji`
  ///
  /// Le champ `emoji` du serveur reste, intact : c'est une donnée métier,
  /// saisie depuis l'admin Django, persistée et mise en cache. Mais il ne
  /// pilote plus le dessin. Un emoji Unicode rendu par la police système ne
  /// s'affiche pas pareil d'un téléphone à l'autre, et pas du tout sur les
  /// Android anciens. Le client choisit donc son illustration à partir du
  /// **slug**, qui est stable et ne dépend d'aucune saisie libre.
  ///
  /// La version précédente posait une assiette sur toute catégorie sans emoji.
  /// Le pack n'a rien pour « Salades » ni pour « Spécialités Togolaises », et
  /// une assiette vide devant un plat togolais dit moins que rien : ces
  /// catégories montrent leur seul intitulé.
  eccore.AppEmojiToken? get illustration => eccore.emojiDeCategorie(slug);
}
