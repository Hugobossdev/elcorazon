/// Les motifs pour lesquels le serveur refuse une commande — miroir de
/// `UnavailabilityCode` (`backend/common/availability.py`).
///
/// ## Pourquoi ces constantes existent
///
/// Le serveur rend, à côté de chaque « non » — établissement, article, ligne de
/// panier, devis, livrabilité —, un `unavailable_code` **stable** et une
/// `unavailable_reason` affichable. L'application affiche la phrase ; elle ne
/// compare que le code, jamais la phrase, qui peut changer sans préavis.
///
/// Ces constantes ne décident rien. Elles nomment des réponses : c'est le juge
/// de disponibilité du serveur (`apps.availability`) qui dit si l'on peut
/// commander, et l'application ne recompose plus cette règle à partir de
/// booléens.
///
/// ## Ce qu'aucune de ces constantes ne dit
///
/// Qu'une panne a eu lieu. Chacune est une **réponse** du serveur. Un serveur
/// injoignable, un 500, une réponse illisible se classent par `ApiFailure` —
/// et ne doivent jamais être traduits en [aucuneCuisine].
abstract final class MotifIndisponibilite {
  // --- la géographie -------------------------------------------------------
  /// Aucune cuisine en service ne dessert ce point.
  static const aucuneCuisine = 'no_kitchen_available';

  /// Une cuisine existe, mais l'adresse sort de sa desserte.
  static const adresseNonDesservie = 'address_not_served';

  // --- la cuisine ----------------------------------------------------------
  /// Jamais mise en service, ou marché fermé.
  static const cuisineNonPubliee = 'kitchen_unpublished';

  /// Retirée du service par l'exploitation.
  static const cuisineSuspendue = 'kitchen_suspended';

  /// Fermée par une fermeture exceptionnelle datée — elle a une fin annoncée.
  static const cuisineFermeeExceptionnellement = 'kitchen_temporarily_closed';

  /// Hors des plages d'ouverture.
  static const cuisineFermee = 'kitchen_closed';

  /// Ouverte, mais la prise de commande est suspendue — un coup de feu.
  ///
  /// S'appelait `cuisineSuspendue`, ce qui confondait la pause de quelques
  /// minutes avec la suspension décidée par l'exploitation : les deux codes
  /// existent désormais, et n'appellent pas le même message.
  static const cuisineEnPause = 'kitchen_paused';

  // --- l'article -----------------------------------------------------------
  static const articleRetire = 'item_withdrawn';
  static const articleIndisponible = 'item_unavailable';
  static const optionIndisponible = 'option_unavailable';
  static const personnalisationInvalide = 'invalid_customization';
  static const epuise = 'out_of_stock';

  // --- la matière ----------------------------------------------------------
  /// Un ingrédient manque pour le préparer.
  static const ruptureIngredient = 'ingredient_shortage';
}
