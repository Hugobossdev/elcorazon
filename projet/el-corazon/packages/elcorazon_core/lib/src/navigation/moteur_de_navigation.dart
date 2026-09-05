import 'package:elcorazon_core/src/directions/geo_point.dart';
import 'package:elcorazon_core/src/directions/route_info.dart';
import 'package:elcorazon_core/src/directions/route_step.dart';
import 'package:elcorazon_core/src/navigation/etat_navigation.dart';
import 'package:elcorazon_core/src/navigation/geo_calcul.dart';
import 'package:elcorazon_core/src/navigation/phrases_navigation.dart';
import 'package:elcorazon_core/src/navigation/suivi_de_trace.dart';

/// Un relevé de position tel que la navigation le consomme.
///
/// Volontairement distinct du `Position` de `geolocator` : ce moteur doit
/// tourner dans un test sans greffon de plateforme, et c'est la seule
/// condition pour que la logique de guidage — paliers, répétitions, sortie
/// d'itinéraire, arrivée — soit vérifiable autrement qu'en roulant.
class PositionNavigation {
  const PositionNavigation({
    required this.point,
    required this.horodatage,
    this.capDegres,
    this.vitesseMetresParSeconde,
    this.precisionMetres,
  });

  final GeoPoint point;
  final DateTime horodatage;

  /// Cap rendu par le capteur, ou `null` s'il n'en rend pas.
  ///
  /// `geolocator` rend `0` aussi bien pour « plein nord » que pour « je ne
  /// sais pas », et un appareil immobile ne sait pas : la frontière est faite
  /// à l'entrée, dans l'application, pas ici.
  final double? capDegres;

  final double? vitesseMetresParSeconde;

  /// Rayon d'incertitude annoncé par le capteur, en mètres.
  ///
  /// Ce n'est pas un ornement : un relevé à 150 mètres près place le livreur
  /// n'importe où dans le pâté de maisons, et c'est exactement ce qui
  /// déclencherait une sortie d'itinéraire sur un livreur qui roule droit.
  final double? precisionMetres;
}

/// Les seuils de la navigation, tous nommés et tous ajustables.
///
/// Aucun n'est écrit au milieu du code : ce sont les valeurs qu'on corrige
/// après avoir roulé, et les chercher dans une condition au fond d'une méthode
/// est le meilleur moyen d'en corriger une et d'oublier les autres.
class ReglagesNavigation {
  const ReglagesNavigation({
    this.seuilSortieMetres = 60,
    this.relevesHorsTraceAvantRecalcul = 3,
    this.delaiEntreRecalculs = const Duration(seconds: 20),
    this.rayonArriveeMetres = 60,
    this.paliersAnnonceMetres = const [500, 200],
    this.palierImmediatMetres = 50,
    this.precisionMaximaleMetres = 75,
    this.vitesseDeReferenceKmH = 30,
    this.ecartEtaSignificatif = const Duration(seconds: 60),
    this.dureeMaximaleDAncrageEta = const Duration(seconds: 60),
  });

  /// Écart au tracé à partir duquel on considère que le livreur l'a quitté.
  ///
  /// Soixante mètres, et non vingt : en ville dense, un relevé GPS dérive
  /// facilement de trente mètres entre deux immeubles, et une contre-allée
  /// parallèle à la voie principale n'est pas une sortie d'itinéraire.
  final double seuilSortieMetres;

  /// Nombre de relevés consécutifs au-delà du seuil avant de conclure.
  ///
  /// Un seul relevé aberrant suffit sinon à déclencher un recalcul — et un
  /// recalcul coûte une requête, une nouvelle polyline, une annonce vocale, et
  /// la confiance du livreur.
  final int relevesHorsTraceAvantRecalcul;

  /// Temps mort entre deux recalculs. Empêche la boucle : un livreur arrêté à
  /// cinquante mètres du tracé, dans un embouteillage sur la voie d'à côté,
  /// redemanderait sinon un itinéraire toutes les deux secondes.
  final Duration delaiEntreRecalculs;

  /// Rayon autour de la destination au-delà duquel on n'est pas arrivé.
  final double rayonArriveeMetres;

  /// Distances auxquelles la manœuvre est annoncée **avec** sa distance.
  final List<int> paliersAnnonceMetres;

  /// Distance à laquelle la manœuvre est annoncée **sans** sa distance —
  /// « tournez à droite », parce que c'est maintenant.
  final int palierImmediatMetres;

  /// Au-delà de cette incertitude, le relevé sert encore à afficher un repère,
  /// mais plus à décider d'une sortie d'itinéraire ni d'une arrivée.
  final double precisionMaximaleMetres;

  /// Vitesse retenue pour estimer une durée quand l'itinéraire n'en donne pas.
  final double vitesseDeReferenceKmH;

  /// Écart à partir duquel l'heure d'arrivée affichée est réancrée.
  final Duration ecartEtaSignificatif;

  /// Durée au bout de laquelle elle est réancrée de toute façon.
  final Duration dureeMaximaleDAncrageEta;
}

/// Ce que le moteur demande à l'application après un relevé.
///
/// Il ne parle pas et n'appelle pas Google lui-même : il dit ce qu'il faut
/// faire, et l'application le fait. C'est ce qui permet de vérifier « une
/// instruction est prononcée une seule fois » sans monter de moteur de
/// synthèse.
class DecisionNavigation {
  const DecisionNavigation({
    this.aPrononcer = const [],
    this.recalculDemande = false,
  });

  /// Les phrases à prononcer, dans l'ordre. Presque toujours vide ou d'un seul
  /// élément.
  final List<String> aPrononcer;

  /// Un nouvel itinéraire doit être demandé depuis la position courante.
  final bool recalculDemande;

  bool get sansEffet => aPrononcer.isEmpty && !recalculDemande;
}

/// La logique de navigation, sans carte, sans réseau, sans plateforme.
///
/// ## Ce qu'il fait
///
/// Il reçoit des positions et un itinéraire, et il en déduit quatre choses :
/// où en est le livreur sur son tracé, quelle manœuvre vient ensuite, ce qu'il
/// faut lui dire et quand, et s'il faut redemander un itinéraire.
///
/// ## Ce qu'il ne fait pas
///
/// Il n'ouvre pas le GPS — la position lui est donnée, et elle vient de
/// `RealtimeTrackingService`, seul détenteur du flux. Il n'appelle pas Google —
/// il demande un recalcul, l'application le fait. Il ne prononce rien — il rend
/// des phrases. Il ne fait **jamais** avancer la course : arriver quelque part
/// n'est pas récupérer un repas ni le remettre.
///
/// Ces quatre abstentions ne sont pas de la pureté pour la pureté : ce sont
/// elles qui rendent la navigation vérifiable depuis un poste de développement
/// à six cents kilomètres du restaurant.
class MoteurDeNavigation {
  MoteurDeNavigation({
    ReglagesNavigation reglages = const ReglagesNavigation(),
    LangueNavigation langue = LangueNavigation.francais,
  })  : _reglages = reglages,
        _langue = langue,
        _phrases = PhrasesNavigation.pour(langue);

  final ReglagesNavigation _reglages;
  LangueNavigation _langue;
  PhrasesNavigation _phrases;

  ReglagesNavigation get reglages => _reglages;
  LangueNavigation get langue => _langue;
  PhrasesNavigation get phrases => _phrases;

  /// Change la langue du guidage. Le contexte vocal est remis à zéro : sans
  /// cela, une instruction déjà dite en français ne serait jamais redite en
  /// anglais, et le changement de langue resterait inaudible jusqu'au
  /// carrefour suivant.
  void changerDeLangue(LangueNavigation langue) {
    if (_langue == langue) return;
    _langue = langue;
    _phrases = PhrasesNavigation.pour(langue);
    _oublierCeQuiAEteDit();
  }

  // ------------------------------------------------------------------ état

  EtatNavigation _etat = EtatNavigation.inactif;
  EtapeNavigation _etape = EtapeNavigation.restaurant;
  ModeNavigation _mode = ModeNavigation.apercu;
  String? _erreur;

  EtatNavigation get etat => _etat;
  EtapeNavigation get etape => _etape;
  ModeNavigation get mode => _mode;

  /// Message d'erreur destiné au livreur, ou `null`.
  String? get erreur => _erreur;

  // ------------------------------------------------------------ itinéraire

  RouteInfo? _itineraire;
  TraceSuivie? _trace;

  /// Distance cumulée, sur [_trace], de la fin de chaque étape.
  List<double> _finDEtape = const [];

  RouteInfo? get itineraire => _itineraire;

  /// Le tracé à dessiner sur la carte.
  ///
  /// Assemblé à partir des tracés d'étape quand il y en a, et non du tracé
  /// d'ensemble : `overview_polyline` est une version **simplifiée** que
  /// Google destine à un aperçu, dont les sommets ne coïncident pas avec les
  /// carrefours. Y projeter la position ferait flotter la distance avant
  /// manœuvre de plusieurs dizaines de mètres, précisément là où elle doit
  /// être juste.
  List<GeoPoint> get trace => _trace?.points ?? const [];

  // -------------------------------------------------------------- position

  PositionNavigation? _dernierePosition;
  PositionSurItineraire? _situation;
  double? _capLisse;

  PositionNavigation? get position => _dernierePosition;

  /// Position ramenée sur le tracé, ou la position brute hors itinéraire.
  GeoPoint? get pointAffiche =>
      _situation?.pointProjete ?? _dernierePosition?.point;

  /// Cap à donner au repère et à la caméra, ou `null` s'il n'est pas fiable.
  double? get capDegres => _capLisse;

  /// Écart au tracé du dernier relevé, en mètres. `null` hors guidage.
  double? get ecartAuTraceMetres => _situation?.ecartMetres;

  // ------------------------------------------------------------- manœuvres

  int _indexEtape = 0;

  /// L'étape en cours — la manœuvre vers laquelle le livreur roule.
  RouteStep? get etapeCourante {
    final etapes = _itineraire?.steps ?? const <RouteStep>[];
    return _indexEtape < etapes.length ? etapes[_indexEtape] : null;
  }

  /// Celle d'après, pour l'afficher en second sur le bandeau.
  RouteStep? get etapeSuivante {
    final etapes = _itineraire?.steps ?? const <RouteStep>[];
    return _indexEtape + 1 < etapes.length ? etapes[_indexEtape + 1] : null;
  }

  /// Distance jusqu'à la manœuvre courante, en mètres. `null` sans guidage.
  double? get distanceAvantManoeuvreMetres {
    final situation = _situation;
    if (situation == null || _indexEtape >= _finDEtape.length) return null;
    return (_finDEtape[_indexEtape] - situation.distanceParcourueMetres)
        .clamp(0, double.infinity);
  }

  /// L'instruction courante, telle qu'elle s'affiche et se prononce.
  String? get instructionCourante {
    final etape = etapeCourante;
    if (etape == null) return null;
    final distance = distanceAvantManoeuvreMetres;
    if (distance == null || distance <= _reglages.palierImmediatMetres) {
      return _phrases.instructionImmediate(etape);
    }
    return _phrases.instructionADistance(etape, distance.round());
  }

  // ------------------------------------------------------------- distances

  /// Ce qu'il reste à parcourir **le long du tracé**, en mètres.
  double? get distanceRestanteMetres => _situation?.distanceRestanteMetres;

  DateTime? _heureArriveeAncree;
  DateTime? _ancreePosee;

  /// Heure d'arrivée estimée, stable.
  ///
  /// ## Pourquoi une heure, et pas une durée
  ///
  /// Une durée recalculée à chaque relevé bouge de quelques secondes toutes
  /// les deux secondes : « 12 min », « 11 min », « 12 min ». Le livreur la
  /// relit sans arrêt parce qu'elle change, et n'en tire rien.
  ///
  /// Une heure d'arrivée, elle, tient : elle est **ancrée** au calcul, et la
  /// durée restante s'en déduit en décomptant. Elle n'est réancrée que lorsque
  /// l'estimation s'écarte d'une minute, ou au bout d'une minute — un
  /// embouteillage se voit, une variation de dix secondes non.
  DateTime? get heureArriveeEstimee => _heureArriveeAncree;

  /// Durée restante affichée, déduite de l'heure d'arrivée ancrée.
  Duration? dureeRestante({DateTime? maintenant}) {
    final arrivee = _heureArriveeAncree;
    if (arrivee == null) return null;
    final reste = arrivee.difference(maintenant ?? DateTime.now());
    return reste.isNegative ? Duration.zero : reste;
  }

  // ------------------------------------------------------- contexte vocal

  final Set<int> _paliersDits = <int>{};
  bool _immediatDit = false;
  bool _arriveeAnnoncee = false;
  String? _derniereInstructionPrononcee;

  /// La dernière phrase prononcée — c'est elle que le bouton « répéter »
  /// redemande.
  String? get derniereInstructionPrononcee => _derniereInstructionPrononcee;

  // --------------------------------------------------- sortie d'itinéraire

  int _relevesHorsTrace = 0;
  DateTime? _dernierRecalcul;

  // ------------------------------------------------------------- commandes

  /// Démarre — ou reprend — le guidage vers [etape] sur [itineraire].
  ///
  /// Rend les phrases d'ouverture : en mode aperçu il n'y en a aucune, la voix
  /// n'ayant rien à faire tant que le livreur regarde sa carte à l'arrêt.
  DecisionNavigation demarrer({
    required EtapeNavigation etape,
    required RouteInfo itineraire,
    ModeNavigation mode = ModeNavigation.navigation,
  }) {
    _etape = etape;
    _mode = mode;
    _erreur = null;
    _arriveeAnnoncee = false;
    _poserLItineraire(itineraire);
    _etat = etape.etatEnRoute;

    if (mode != ModeNavigation.navigation) return const DecisionNavigation();
    return _dire([_phrases.departVers(etape)]);
  }

  /// Remplace l'itinéraire — après un recalcul, ou après un changement
  /// d'étape.
  ///
  /// [annoncer] distingue les deux : un recalcul se signale (« nouvel
  /// itinéraire »), un premier calcul non.
  DecisionNavigation remplacerLItineraire(
    RouteInfo itineraire, {
    bool annoncer = true,
  }) {
    _poserLItineraire(itineraire);
    if (_etat == EtatNavigation.horsItineraire ||
        _etat == EtatNavigation.erreur ||
        _etat == EtatNavigation.preparation) {
      _etat = _etape.etatEnRoute;
    }
    _erreur = null;

    if (!annoncer || _mode != ModeNavigation.navigation) {
      return const DecisionNavigation();
    }
    return _dire([_phrases.itineraireRecalcule]);
  }

  /// Passe à l'étape suivante — typiquement restaurant vers client, une fois
  /// la commande **déclarée récupérée par le livreur**.
  ///
  /// Le contexte vocal est intégralement remis à zéro : les paliers déjà dits
  /// appartenaient à un autre trajet, et les garder ferait sauter la première
  /// annonce du nouveau.
  DecisionNavigation changerDEtape(EtapeNavigation etape) {
    if (_etape == etape) return const DecisionNavigation();

    _etape = etape;
    _etat = EtatNavigation.preparation;
    _arriveeAnnoncee = false;
    _itineraire = null;
    _trace = null;
    _finDEtape = const [];
    _situation = null;
    _indexEtape = 0;
    _heureArriveeAncree = null;
    _ancreePosee = null;
    _oublierCeQuiAEteDit();

    if (_mode != ModeNavigation.navigation) return const DecisionNavigation();
    return _dire([_phrases.departVers(etape)]);
  }

  /// Bascule aperçu / navigation.
  DecisionNavigation changerDeMode(ModeNavigation mode) {
    if (_mode == mode) return const DecisionNavigation();
    _mode = mode;

    if (mode == ModeNavigation.apercu) {
      // Repasser en aperçu ne doit pas laisser une annonce en cours dans
      // l'oreille du livreur ; c'est l'application qui coupe le moteur de
      // synthèse, le contexte est simplement oublié.
      _oublierCeQuiAEteDit();
      return const DecisionNavigation();
    }
    if (_itineraire == null) return const DecisionNavigation();
    return _dire([_phrases.departVers(_etape)]);
  }

  /// La position n'est plus disponible — GPS coupé, permission retirée, flux
  /// interrompu. [raison] est la phrase déjà rédigée pour le livreur.
  DecisionNavigation signalerPositionIndisponible(String? raison) {
    if (_etat == EtatNavigation.positionIndisponible) {
      return const DecisionNavigation();
    }
    final guidait = _etat.guide;
    _etat = EtatNavigation.positionIndisponible;
    _erreur = raison;

    // On ne l'annonce que si le guidage tournait : le dire à l'ouverture d'un
    // écran, avant la première fixation, ferait parler le téléphone pour un
    // état parfaitement normal des dix premières secondes.
    if (!guidait || _mode != ModeNavigation.navigation) {
      return const DecisionNavigation();
    }
    return _dire([_phrases.positionPerdue]);
  }

  /// La position est revenue.
  void signalerPositionRetrouvee() {
    if (_etat != EtatNavigation.positionIndisponible) return;
    _erreur = null;
    _etat = _itineraire == null ? EtatNavigation.preparation : _etape.etatEnRoute;
  }

  /// L'itinéraire n'a pas pu être calculé.
  DecisionNavigation signalerErreur(String message) {
    _etat = EtatNavigation.erreur;
    _erreur = message;
    if (_mode != ModeNavigation.navigation) return const DecisionNavigation();
    return _dire([_phrases.itineraireImpossible]);
  }

  /// La course est close.
  void terminer() {
    _etat = EtatNavigation.terminee;
    _oublierCeQuiAEteDit();
  }

  /// Remet tout à zéro.
  void arreter() {
    _etat = EtatNavigation.inactif;
    _mode = ModeNavigation.apercu;
    _itineraire = null;
    _trace = null;
    _finDEtape = const [];
    _situation = null;
    _dernierePosition = null;
    _capLisse = null;
    _indexEtape = 0;
    _erreur = null;
    _heureArriveeAncree = null;
    _ancreePosee = null;
    _relevesHorsTrace = 0;
    _dernierRecalcul = null;
    _arriveeAnnoncee = false;
    _oublierCeQuiAEteDit();
  }

  /// La phrase à répéter sur demande du livreur, ou `null`.
  ///
  /// L'instruction **courante**, et non la dernière prononcée : entre les
  /// deux, le livreur a pu franchir la manœuvre, et lui rejouer une consigne
  /// périmée l'enverrait dans la mauvaise rue.
  String? phraseARepeter() => instructionCourante ?? _derniereInstructionPrononcee;

  // -------------------------------------------------------------- le cœur

  /// Consomme un relevé de position et rend ce qu'il faut en faire.
  DecisionNavigation mettreAJour(
    PositionNavigation position, {
    DateTime? maintenant,
  }) {
    final horloge = maintenant ?? position.horodatage;
    _dernierePosition = position;
    _majCap(position);

    if (_etat == EtatNavigation.positionIndisponible) signalerPositionRetrouvee();
    if (_etat == EtatNavigation.inactif || _etat == EtatNavigation.terminee) {
      return const DecisionNavigation();
    }

    final trace = _trace;
    if (trace == null || trace.estVide) return const DecisionNavigation();

    final situation = trace.situer(
      position.point,
      depuisLeSegment: _situation?.indexSegment ?? 0,
    );
    if (situation == null) return const DecisionNavigation();
    _situation = situation;

    _majEtapeCourante();
    _majHeureDArrivee(horloge);

    // Un relevé trop imprécis affiche encore un repère, mais ne décide de
    // rien : conclure à une sortie d'itinéraire — ou à une arrivée — sur un
    // point donné à 150 mètres près, c'est conclure sur du bruit.
    final fiable = (position.precisionMetres ?? 0) <= _reglages.precisionMaximaleMetres;

    final aDire = <String>[];
    var recalcul = false;

    final arrivee = _verifierLArrivee(fiable);
    if (arrivee != null) {
      aDire.add(arrivee);
      return _dire(aDire);
    }

    // L'aperçu est passif : le livreur regarde son itinéraire, il ne le suit
    // pas. Y déclencher un recalcul consommerait du quota Google et
    // remplacerait, sous ses yeux, le tracé qu'il est en train de lire.
    if (_etat.guide && fiable && _mode == ModeNavigation.navigation) {
      recalcul = _verifierLaSortieDItineraire(situation, horloge, aDire);
    }

    final enGuidage = _etat == EtatNavigation.versLeRestaurant ||
        _etat == EtatNavigation.versLeClient;
    if (!recalcul && enGuidage) {
      final annonce = _annonceAFaire();
      if (annonce != null) aDire.add(annonce);
    }

    return _dire(aDire, recalculDemande: recalcul);
  }

  // ----------------------------------------------------------- mécanismes

  void _poserLItineraire(RouteInfo itineraire) {
    _itineraire = itineraire;

    // Le tracé et les bornes d'étape sortent du **même** assemblage, en une
    // passe. Les mesurer séparément — le tracé d'un côté, la somme des
    // `distance` de Google de l'autre — les laisse diverger de quelques mètres
    // par manœuvre, et l'écart cumulé sur trente carrefours décale la dernière
    // annonce d'une rue entière.
    final assemblage = _assembler(itineraire);
    _trace = assemblage.trace;
    _finDEtape = assemblage.finDEtape;
    _situation = null;
    _indexEtape = 0;
    _relevesHorsTrace = 0;
    _heureArriveeAncree = null;
    _ancreePosee = null;
    _oublierCeQuiAEteDit();
  }

  /// Assemble le tracé complet et les bornes de chaque étape, en une passe.
  ///
  /// Le tracé est fait des tracés d'étape bout à bout, et non de
  /// `overview_polyline` : ce dernier est une version **simplifiée** que Google
  /// destine à un aperçu, dont les sommets ne coïncident pas avec les
  /// carrefours. Il ne sert que de repli, pour un itinéraire rendu sans
  /// manœuvres.
  ///
  /// Les doublons de jonction sont retirés : le dernier point d'une étape et le
  /// premier de la suivante sont le même carrefour, et le garder deux fois
  /// insère un segment de longueur nulle par manœuvre.
  static _Assemblage _assembler(RouteInfo itineraire) {
    if (itineraire.steps.isEmpty) {
      return _Assemblage(TraceSuivie(itineraire.polylinePoints), const []);
    }

    final points = <GeoPoint>[];
    final dernierIndex = <int>[];

    for (final etape in itineraire.steps) {
      final morceau = etape.polylinePoints.isEmpty
          ? [etape.start, etape.end]
          : etape.polylinePoints;
      for (final point in morceau) {
        if (points.isEmpty || points.last != point) points.add(point);
      }
      dernierIndex.add(points.length - 1);
    }

    if (points.length < 2) {
      return _Assemblage(TraceSuivie(itineraire.polylinePoints), const []);
    }

    final trace = TraceSuivie(points);
    return _Assemblage(
      trace,
      [for (final index in dernierIndex) trace.cumulJusquA(index)],
    );
  }

  void _majEtapeCourante() {
    final situation = _situation;
    if (situation == null || _finDEtape.isEmpty) return;

    final parcouru = situation.distanceParcourueMetres;
    var index = _indexEtape;
    // On n'avance jamais que vers l'avant : un relevé qui recule de deux
    // mètres ne doit pas faire redire l'instruction précédente.
    while (index < _finDEtape.length - 1 && parcouru >= _finDEtape[index]) {
      index++;
    }

    if (index != _indexEtape) {
      _indexEtape = index;
      // Nouvelle manœuvre : les paliers du virage précédent ne la concernent
      // pas. C'est ce qui fait qu'un livreur entend « tournez à droite dans
      // 200 mètres » à chaque carrefour, et non une seule fois pour tout le
      // trajet.
      _paliersDits.clear();
      _immediatDit = false;
    }
  }

  void _majCap(PositionNavigation position) {
    final duCapteur = position.capDegres;
    final vitesse = position.vitesseMetresParSeconde ?? 0;

    // Un appareil immobile rend un cap qui tourne au hasard : le repère du
    // livreur pivoterait sur lui-même à l'arrêt devant le restaurant. En
    // dessous d'un mètre par seconde — le pas d'un piéton — on garde le
    // dernier cap connu, quitte à n'en avoir aucun au tout début.
    if (duCapteur == null || vitesse < 1.0) return;

    final actuel = _capLisse;
    if (actuel == null) {
      _capLisse = duCapteur;
      return;
    }

    // Lissage : on ne suit pas un cap qui saute de plus de quatre-vingt-dix
    // degrés d'un relevé à l'autre sans que la vitesse le justifie — c'est du
    // bruit, pas un virage.
    _capLisse = GeoCalcul.ecartDeCap(actuel, duCapteur) > 90 && vitesse < 3
        ? actuel
        : duCapteur;
  }

  void _majHeureDArrivee(DateTime maintenant) {
    final situation = _situation;
    if (situation == null) return;

    final secondes = _dureeRestanteEstimee(situation);
    final estimation = maintenant.add(Duration(seconds: secondes));

    final ancree = _heureArriveeAncree;
    final posee = _ancreePosee;
    final ecarte = ancree == null ||
        estimation.difference(ancree).abs() >= _reglages.ecartEtaSignificatif;
    final perimee = posee == null ||
        maintenant.difference(posee) >= _reglages.dureeMaximaleDAncrageEta;

    if (ecarte || perimee) {
      _heureArriveeAncree = estimation;
      _ancreePosee = maintenant;
    }
  }

  /// Durée restante, en secondes, au prorata de ce qui reste de l'étape en
  /// cours plus les étapes suivantes.
  int _dureeRestanteEstimee(PositionSurItineraire situation) {
    final etapes = _itineraire?.steps ?? const <RouteStep>[];
    if (etapes.isEmpty || _finDEtape.isEmpty) {
      final metresParSeconde = _reglages.vitesseDeReferenceKmH * 1000 / 3600;
      return (situation.distanceRestanteMetres / metresParSeconde).round();
    }

    var secondes = 0.0;
    for (var i = _indexEtape; i < etapes.length; i++) {
      if (i == _indexEtape) {
        final longueur = etapes[i].distanceMeters;
        final reste = (_finDEtape[i] - situation.distanceParcourueMetres)
            .clamp(0, double.infinity);
        final fraction = longueur == 0 ? 0.0 : (reste / longueur).clamp(0.0, 1.0);
        secondes += etapes[i].durationSeconds * fraction;
      } else {
        secondes += etapes[i].durationSeconds;
      }
    }
    return secondes.round();
  }

  /// Rend la phrase d'arrivée si le livreur vient d'arriver, `null` sinon.
  String? _verifierLArrivee(bool fiable) {
    if (!fiable || _arriveeAnnoncee) return null;

    final situation = _situation;
    final position = _dernierePosition;
    final trace = _trace;
    if (situation == null || position == null || trace == null) return null;

    // Deux mesures, et la plus petite l'emporte : le long du tracé, parce que
    // c'est le trajet réel ; à vol d'oiseau, parce qu'un livreur qui coupe par
    // le parking arrive sans avoir fini le tracé.
    final aLaFinDuTrace = situation.distanceRestanteMetres;
    final aLaDestination =
        GeoCalcul.distanceMetres(position.point, trace.points.last);
    final distance = aLaFinDuTrace < aLaDestination ? aLaFinDuTrace : aLaDestination;

    if (distance > _reglages.rayonArriveeMetres) return null;

    _arriveeAnnoncee = true;
    _etat = _etape.etatArrive;
    return _mode == ModeNavigation.navigation ? _phrases.arriveeA(_etape) : null;
  }

  /// Conclut — ou non — à une sortie d'itinéraire. Rend `true` si un recalcul
  /// doit être demandé, et empile la phrase à prononcer dans [aDire].
  bool _verifierLaSortieDItineraire(
    PositionSurItineraire situation,
    DateTime maintenant,
    List<String> aDire,
  ) {
    if (situation.ecartMetres <= _reglages.seuilSortieMetres) {
      _relevesHorsTrace = 0;
      // Revenu sur le tracé de lui-même, sans qu'un recalcul ait abouti : on
      // reprend le guidage plutôt que de rester bloqué en « hors itinéraire ».
      if (_etat == EtatNavigation.horsItineraire) _etat = _etape.etatEnRoute;
      return false;
    }

    _relevesHorsTrace++;
    if (_relevesHorsTrace < _reglages.relevesHorsTraceAvantRecalcul) return false;

    final dernier = _dernierRecalcul;
    if (dernier != null &&
        maintenant.difference(dernier) < _reglages.delaiEntreRecalculs) {
      // Le temps mort. L'état reste « hors itinéraire » — le livreur doit
      // continuer de voir qu'il l'est — mais on ne redemande rien et on ne
      // répète pas l'annonce.
      _etat = EtatNavigation.horsItineraire;
      return false;
    }

    final premiereFois = _etat != EtatNavigation.horsItineraire;
    _etat = EtatNavigation.horsItineraire;
    _dernierRecalcul = maintenant;
    _relevesHorsTrace = 0;

    if (premiereFois && _mode == ModeNavigation.navigation) {
      aDire.add(_phrases.sortieDItineraire);
    }
    return true;
  }

  /// L'annonce due à ce relevé, ou `null` s'il n'y a rien à dire.
  ///
  /// C'est ici que se joue la règle « une instruction, une fois ». Elle tient à
  /// un détail : quand une annonce part, on retient **tous les paliers que la
  /// distance courante satisfait déjà**, et pas seulement celui qui a
  /// déclenché.
  ///
  /// Sans cela, un livreur qui passe de 600 à 150 mètres entre deux relevés —
  /// ce que fait n'importe qui à cinquante à l'heure — entendrait « dans
  /// 150 mètres, tournez à droite » au titre du palier de 500, puis, deux
  /// secondes plus tard, « dans 140 mètres, tournez à droite » au titre du
  /// palier de 200. Deux fois la même consigne, à dix mètres d'écart.
  String? _annonceAFaire() {
    if (_mode != ModeNavigation.navigation) return null;

    final etape = etapeCourante;
    final distance = distanceAvantManoeuvreMetres;
    if (etape == null || distance == null) return null;

    if (distance <= _reglages.palierImmediatMetres) {
      if (_immediatDit) return null;
      _immediatDit = true;
      _paliersDits.addAll(_reglages.paliersAnnonceMetres);
      return _phrases.instructionImmediate(etape);
    }

    for (final palier in _reglages.paliersAnnonceMetres) {
      if (_paliersDits.contains(palier)) continue;
      if (distance > palier) continue;

      // Un palier n'a de sens que s'il tombe **à l'intérieur** de l'étape.
      // Sur une étape de 80 mètres, « dans 500 mètres, tournez à droite »
      // serait suivi de « tournez à droite » quelques secondes plus tard :
      // deux annonces pour un seul virage, dont la première est fausse.
      // Seule l'annonce immédiate a alors du sens.
      final tropCourt = palier >= etape.distanceMeters;

      // Retenu dans les deux cas, avec tous les paliers que la distance
      // courante satisfait déjà : voir l'en-tête de la méthode.
      for (final autre in _reglages.paliersAnnonceMetres) {
        if (distance <= autre) _paliersDits.add(autre);
      }
      if (tropCourt) continue;

      return _phrases.instructionADistance(etape, distance.round());
    }
    return null;
  }

  DecisionNavigation _dire(List<String> phrases, {bool recalculDemande = false}) {
    if (phrases.isNotEmpty) _derniereInstructionPrononcee = phrases.last;
    return DecisionNavigation(
      aPrononcer: List.unmodifiable(phrases),
      recalculDemande: recalculDemande,
    );
  }

  void _oublierCeQuiAEteDit() {
    _paliersDits.clear();
    _immediatDit = false;
    _derniereInstructionPrononcee = null;
  }
}

/// Le tracé prêt à suivre et les bornes de ses étapes — le résultat d'un seul
/// assemblage, pour qu'ils ne puissent pas se contredire.
class _Assemblage {
  const _Assemblage(this.trace, this.finDEtape);

  final TraceSuivie trace;

  /// `finDEtape[i]` = distance, depuis le début du tracé, du point où la
  /// manœuvre de l'étape `i` s'exécute.
  final List<double> finDEtape;
}
