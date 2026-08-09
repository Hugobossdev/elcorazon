import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Vocabulaire d'affichage du programme de fidélité.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Il remplace `models/loyalty_reward.dart` et `models/loyalty_transaction.dart`,
/// recopiés depuis les entités du socle par `django_loyalty_repository.dart`.
/// Les deux déclaraient des valeurs que le serveur ne produit pas — le
/// commentaire de l'adaptateur le disait déjà, sans en tirer la conséquence.
enum GenreRecompense {
  remise('discount', 'Remise'),
  livraisonOfferte('free_delivery', 'Livraison offerte');

  const GenreRecompense(this.versServeur, this.libelle);

  final String versServeur;
  final String libelle;

  /// Depuis `RewardKind`.
  ///
  /// L'énumération locale en déclarait cinq : `freeItem`, `cashback` et
  /// `exclusiveOffer` n'ont aucun équivalent côté serveur et ne pouvaient donc
  /// jamais apparaître.
  static GenreRecompense depuisServeur(String kind) =>
      kind == 'free_delivery' ? livraisonOfferte : remise;
}

enum GenreMouvementPoints {
  gagnes('earned', 'Points gagnés'),
  depenses('spent', 'Points dépensés'),
  expires('expired', 'Points expirés'),
  ajustes('adjusted', 'Ajustement');

  const GenreMouvementPoints(this.versServeur, this.libelle);

  final String versServeur;
  final String libelle;

  /// Depuis `PointsEntryKind`.
  ///
  /// `bonus` figurait dans l'énumération locale sans exister côté serveur.
  static GenreMouvementPoints depuisServeur(String kind) {
    for (final genre in values) {
      if (genre.versServeur == kind) return genre;
    }
    return ajustes;
  }

  /// Le mouvement ajoute-t-il des points au compte ?
  bool get crediteLeCompte => this == gagnes;
}

extension RecompenseAffichee on eccore.Reward {
  GenreRecompense get genre => GenreRecompense.depuisServeur(kind);

  /// La valeur de la remise en unité majeure, pour l'affichage seulement.
  double get remiseAffichee => discount.toMajorUnits();

  /// Le compte a-t-il de quoi l'échanger ?
  bool estAccessibleAvec(int solde) => solde >= pointsCost;
}

extension MouvementAffiche on eccore.PointsEntry {
  GenreMouvementPoints get genre => GenreMouvementPoints.depuisServeur(kind);

  /// Le mouvement signé, tel qu'on l'écrit dans un relevé : `+120`, `-500`.
  ///
  /// Le serveur rend déjà `delta` signé ; le préfixe explicite n'est là que
  /// pour les crédits, qu'un `+` distingue d'un solde.
  String get deltaAffiche => delta > 0 ? '+$delta' : '$delta';
}
