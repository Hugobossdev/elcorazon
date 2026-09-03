/// Depuis combien de temps la dernière position connue date, et ce qu'on a le
/// droit d'en dire.
///
/// ## Pourquoi ce jugement est partagé
///
/// Trois écrans montrent une position qu'ils n'ont pas relevée eux-mêmes : la
/// carte du client, la carte de supervision du siège, la fiche d'un livreur.
/// Aucun ne distinguait « position d'il y a huit secondes » de « position d'il
/// y a onze minutes » : le repère était posé de la même façon dans les deux
/// cas, et le siège lisait donc comme un suivi en direct la dernière position
/// d'un livreur dont le téléphone s'était éteint. Une carte qui ment sur sa
/// fraîcheur est pire qu'une carte vide — on ne cherche pas un livreur dont on
/// croit savoir où il est.
///
/// Les seuils sont calés sur la cadence d'émission (`TrackingSettings`) : un
/// relevé toutes les dix secondes, un battement toutes les trente pour un
/// livreur immobile. Passé le double du battement, le silence n'est plus
/// explicable par l'immobilité.
enum FraicheurPosition {
  /// Le suivi fonctionne : le dernier relevé est dans la fenêtre attendue.
  fraiche,

  /// Le relevé a du retard — réseau intermittent, tunnel, téléphone en veille
  /// profonde. La position reste probablement voisine de la vraie.
  retardee,

  /// Plus rien depuis assez longtemps pour que la position affichée soit
  /// devenue une information historique. À montrer comme telle.
  perdue;

  /// Au-delà de ce délai, un relevé n'est plus « en direct ».
  static const seuilRetard = Duration(seconds: 60);

  /// Au-delà de ce délai, la position n'est plus qu'un souvenir.
  static const seuilPerte = Duration(minutes: 5);

  /// Juge un relevé daté de [releveA], vu à [maintenant].
  ///
  /// [maintenant] est un paramètre et non `DateTime.now()` pris à l'intérieur :
  /// c'est ce qui rend la règle testable sans attendre cinq minutes.
  ///
  /// Un horodatage **dans le futur** est traité comme frais : l'horloge du
  /// téléphone du livreur n'est pas la nôtre, et quelques secondes d'avance
  /// sont courantes. Les compter comme un retard afficherait « position perdue »
  /// sur un suivi qui marche.
  factory FraicheurPosition.depuis(DateTime releveA, {DateTime? maintenant}) {
    final age = (maintenant ?? DateTime.now()).difference(releveA);
    if (age >= seuilPerte) return FraicheurPosition.perdue;
    if (age >= seuilRetard) return FraicheurPosition.retardee;
    return FraicheurPosition.fraiche;
  }

  bool get estEnDirect => this == FraicheurPosition.fraiche;
}

/// « il y a 8 s », « il y a 5 min », « il y a 2 h ».
///
/// Le siège lit cette phrase pour décider s'il appelle le livreur ; elle doit
/// donc rester lisible d'un coup d'œil, sans seconde près. Un âge négatif —
/// horloge du téléphone en avance — se lit « à l'instant » plutôt que « il y a
/// -3 s ».
String ageLisible(DateTime releveA, {DateTime? maintenant}) {
  final age = (maintenant ?? DateTime.now()).difference(releveA);
  if (age.inSeconds < 5) return 'à l’instant';
  if (age.inSeconds < 60) return 'il y a ${age.inSeconds} s';
  if (age.inMinutes < 60) return 'il y a ${age.inMinutes} min';
  if (age.inHours < 24) return 'il y a ${age.inHours} h';
  return 'il y a ${age.inDays} j';
}
