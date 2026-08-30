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

/// Les paliers du programme de fidélité, et ce qui sépare du suivant.
///
/// ## Où vivent ces seuils, et où ils devraient vivre
///
/// **Ici, c'est-à-dire côté client.** Le serveur ne publie pas de paliers :
/// `GET /loyalty/account/` rend un solde, un cumul gagné et un cumul dépensé,
/// rien de plus. C'est une faiblesse connue et consignée — BR-006 de
/// `docs/STITCH_BACKEND_REQUIREMENTS.md` : deux versions de l'application en
/// circulation annonceront deux paliers différents pour le même solde, et
/// aucune ne fera foi au moment d'accorder l'avantage.
///
/// Les seuils sont donc rassemblés en **un seul endroit**, pour qu'il n'y ait
/// qu'une ligne à changer le jour où la route existe. Ils étaient auparavant
/// écrits dans `profil_utilisateur.dart`, qui les gardait pour lui.
///
/// Les noms sont ceux du produit — « Standard », « Fidèle », « VIP » — et non
/// ceux de la maquette Stitch (« Gold », « Platinum »), dont les seuils ne
/// correspondent à rien de ce qui est en place.
enum PalierFidelite {
  standard('Standard', 0),
  fidele('Fidèle', 200),
  vip('VIP', 500);

  const PalierFidelite(this.libelle, this.seuil);

  final String libelle;

  /// Solde à partir duquel le palier est atteint.
  final int seuil;

  /// Le palier correspondant à [points].
  static PalierFidelite pour(int points) {
    PalierFidelite atteint = standard;
    for (final palier in values) {
      if (points >= palier.seuil) atteint = palier;
    }
    return atteint;
  }

  /// Le palier au-dessus, ou `null` au sommet.
  PalierFidelite? get suivant {
    final rang = index + 1;
    return rang < values.length ? values[rang] : null;
  }
}

/// Où en est un solde entre son palier et le suivant.
///
/// [progression] vaut 1 au sommet : la barre est pleine, et il n'y a plus rien
/// à atteindre. Elle ne vaut jamais `NaN` — deux paliers ne partagent jamais
/// le même seuil, mais le garde-fou reste, un seuil se change par erreur.
({PalierFidelite palier, PalierFidelite? suivant, int pointsManquants, double progression})
    avancementDeFidelite(int points) {
  final palier = PalierFidelite.pour(points);
  final suivant = palier.suivant;

  if (suivant == null) {
    return (palier: palier, suivant: null, pointsManquants: 0, progression: 1);
  }

  final etendue = suivant.seuil - palier.seuil;
  final parcouru = points - palier.seuil;

  return (
    palier: palier,
    suivant: suivant,
    pointsManquants: (suivant.seuil - points).clamp(0, suivant.seuil),
    progression: etendue <= 0 ? 1.0 : (parcouru / etendue).clamp(0.0, 1.0),
  );
}
