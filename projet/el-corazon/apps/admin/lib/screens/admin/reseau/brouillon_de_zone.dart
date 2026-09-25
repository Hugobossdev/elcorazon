import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Ce qu'on est en train de dessiner — sans carte.
///
/// La carte (`EditeurDeZone`) ne fait que **montrer** ce brouillon et lui
/// transmettre des gestes. La règle — combien de sommets, lequel retirer, ce
/// qu'on peut enregistrer — vit ici, où elle s'éprouve sans Google Maps.
///
/// Le brouillon ne valide que ce qu'il **sait** : un polygone demande trois
/// sommets, un cercle un centre. Le reste — contour qui se croise, surface
/// démesurée, sommet hors du globe — est jugé par le serveur, et son refus est
/// affiché tel quel : le rejouer ici ferait deux règles.
class BrouillonDeZone {
  BrouillonDeZone.cercle({eccore.GeoPoint? centre, this.rayonMetres = 3000})
      : estCercle = true,
        _centre = centre;

  BrouillonDeZone.polygone([List<eccore.GeoPoint> sommets = const []])
      : estCercle = false,
        rayonMetres = 3000,
        _sommets = List.of(sommets);

  /// Rouvre la forme d'une zone existante dans le bon outil : un cercle se
  /// rouvre en cercle, pas en polygone de soixante-quatre sommets.
  factory BrouillonDeZone.depuisZone(eccore.DeliveryZone zone) {
    if (zone.estCirculaire && zone.center != null) {
      return BrouillonDeZone.cercle(centre: zone.center, rayonMetres: zone.radiusMeters ?? 3000);
    }
    return BrouillonDeZone.polygone(zone.sommets);
  }

  /// Rayon autorisé par le curseur. Le serveur plafonne la **surface** à
  /// 5 000 km², soit un rayon d'environ 39,9 km : le curseur s'arrête avant,
  /// pour ne pas proposer un geste qui sera refusé.
  static const rayonMin = 200;
  static const rayonMax = 39000;

  bool estCercle;
  eccore.GeoPoint? _centre;
  int rayonMetres;
  List<eccore.GeoPoint> _sommets = [];

  eccore.GeoPoint? get centre => _centre;
  List<eccore.GeoPoint> get sommets => List.unmodifiable(_sommets);

  /// Change d'outil. Le tracé de l'autre outil est abandonné : garder un
  /// centre en passant au polygone ne voudrait rien dire.
  void basculer({required bool versCercle}) {
    if (versCercle == estCercle) return;
    estCercle = versCercle;
    _centre = null;
    _sommets = [];
  }

  /// Un toucher sur la carte : pose le centre, ou ajoute un sommet.
  void toucher(eccore.GeoPoint point) {
    if (estCercle) {
      _centre = point;
    } else {
      _sommets.add(point);
    }
  }

  void deplacerSommet(int index, eccore.GeoPoint point) {
    if (index < 0 || index >= _sommets.length) return;
    _sommets[index] = point;
  }

  void retirerSommet(int index) {
    if (index < 0 || index >= _sommets.length) return;
    _sommets.removeAt(index);
  }

  /// Retire le dernier sommet posé — le geste « annuler » d'un tracé.
  void annulerDernier() {
    if (_sommets.isNotEmpty) _sommets.removeLast();
  }

  void changerRayon(int metres) {
    rayonMetres = metres.clamp(rayonMin, rayonMax);
  }

  void effacer() {
    _centre = null;
    _sommets = [];
  }

  bool get estEnregistrable => estCercle ? _centre != null : _sommets.length >= 3;

  /// Ce qui manque, en une phrase — ou `null` si on peut enregistrer.
  String? get manque {
    if (estEnregistrable) return null;
    if (estCercle) return 'Touchez la carte pour placer le centre.';
    final reste = 3 - _sommets.length;
    return 'Encore $reste sommet${reste > 1 ? 's' : ''} pour fermer la zone.';
  }

  /// La forme à envoyer ; `null` tant que la zone n'est pas enregistrable.
  eccore.FormeDeZone? get forme {
    if (!estEnregistrable) return null;
    return estCercle
        ? eccore.ZoneCirculaire(centre: _centre!, rayonMetres: rayonMetres)
        : eccore.ZonePolygonale(List.of(_sommets));
  }
}
