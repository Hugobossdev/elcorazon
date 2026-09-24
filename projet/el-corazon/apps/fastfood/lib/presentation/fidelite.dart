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

/// Rang d'un palier dans l'échelle — ce qui décide de sa couleur, plutôt que
/// son nom, que l'exploitation peut changer.
enum RangDePalier { entree, intermediaire, sommet }

/// Où en est le compte dans l'échelle des paliers, **telle que le serveur la
/// calcule** (`GET /loyalty/account/` : `tier`, `next_tier`,
/// `points_to_next_tier`).
///
/// Les seuils vivaient ici, écrits en dur (Standard, Fidèle 200, VIP 500), à
/// côté d'une seconde échelle de « niveaux » sans rapport dans le service de
/// gamification — BR-006. Ils sont désormais une donnée du serveur, éditée à
/// l'administration ; ce fichier ne fait plus que les présenter.
///
/// Le palier se mesure en points **cumulés gagnés**, pas au solde : échanger
/// ses points ne fait pas redescendre. [progression] se lit donc sur
/// `lifetimeEarned`.
({String? palier, String? suivant, int pointsManquants, double progression, RangDePalier rang})
    avancementDeFidelite(eccore.PointsAccount? compte) {
  final palier = compte?.tier;
  final suivant = compte?.nextTier;
  final gagnes = compte?.lifetimeEarned ?? 0;

  final rang = (palier == null || palier.threshold == 0)
      ? RangDePalier.entree
      : (suivant == null ? RangDePalier.sommet : RangDePalier.intermediaire);

  if (suivant == null) {
    return (
      palier: palier?.name,
      suivant: null,
      pointsManquants: 0,
      progression: palier == null ? 0.0 : 1.0,
      rang: rang,
    );
  }

  final base = palier?.threshold ?? 0;
  final etendue = suivant.threshold - base;
  return (
    palier: palier?.name,
    suivant: suivant.name,
    pointsManquants: compte?.pointsToNextTier ?? (suivant.threshold - gagnes).clamp(0, suivant.threshold),
    progression: etendue <= 0 ? 1.0 : ((gagnes - base) / etendue).clamp(0.0, 1.0),
    rang: rang,
  );
}
