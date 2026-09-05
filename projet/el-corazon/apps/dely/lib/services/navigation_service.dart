import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:elcora_dely/repositories/django_delivery_repository.dart';
import 'package:elcora_dely/services/directions_service.dart';
import 'package:elcora_dely/services/navigation_voice_service.dart';
import 'package:elcora_dely/services/source_de_position.dart';

/// La navigation du livreur, branchée sur ce qui existe déjà.
///
/// ## Ce qu'il assemble, et ce qu'il n'ouvre pas
///
/// Ce service ne relève **aucune** position. Il écoute
/// `RealtimeTrackingService`, seul détenteur du flux GPS, comme le fait déjà
/// l'écran de suivi. Ouvrir un second `getPositionStream` pour bouger un repère
/// est exactement ce qu'un audit précédent a supprimé : deux flux haute
/// précision sur le même appareil, c'est deux fois le poste le plus lourd d'un
/// téléphone, et une carte qui peut afficher une position pendant que le vrai
/// suivi est en panne.
///
/// Il n'ouvre pas non plus de canal temps réel, ne calcule pas de distance à la
/// main, et ne fait pas avancer la course. Il tient quatre choses ensemble :
///
/// * le flux de position du suivi ;
/// * `DirectionsService`, donc `DirectionsRepository` du socle ;
/// * `MoteurDeNavigation`, qui décide ce qu'il faut dire ;
/// * `NavigationVoiceService`, qui le dit.
///
/// ## Ce qu'il ne décide jamais
///
/// L'avancement de la course. Arriver au restaurant n'est pas récupérer la
/// commande ; arriver chez le client n'est pas l'avoir livré. Le GPS assiste,
/// le serveur tranche (`allowed_transitions`). [majCourse] **suit** l'étape
/// déclarée par le livreur et validée par le serveur ; il ne la provoque pas.
class NavigationService extends ChangeNotifier {
  NavigationService({
    SourceDePosition? positions,
    DirectionsService? directions,
    NavigationVoiceService? voix,
    eccore.MoteurDeNavigation? moteur,
  })  : _positions = positions ?? SuiviCommeSource(),
        _directions = directions ?? DirectionsService(),
        voix = voix ?? NavigationVoiceService(),
        _moteur = moteur ?? eccore.MoteurDeNavigation();

  /// Le flux de position, en lecture. Voir [SourceDePosition] : ce service
  /// n'ouvre aucun capteur, il écoute celui de la course.
  final SourceDePosition _positions;
  final DirectionsService _directions;
  final eccore.MoteurDeNavigation _moteur;

  /// La voix, exposée pour que l'écran offre ses réglages — couper le son,
  /// changer de langue, répéter — sans passer par une méthode de plus ici.
  final NavigationVoiceService voix;

  Course? _course;
  bool _ouvert = false;
  bool _calculEnCours = false;

  /// Le tracé affiché est-il un **repli** — une ligne droite — plutôt qu'un
  /// itinéraire routier ?
  ///
  /// L'écran de suivi dessinait ce repli sans le dire : un trait entre deux
  /// points, présenté comme une route. Un livreur qui le suit traverse des
  /// murs. Il reste affiché — il vaut mieux que rien pour situer la
  /// destination — mais il s'annonce.
  bool _traceApproximatif = false;

  // --------------------------------------------------------------- lecture

  Course? get course => _course;

  eccore.EtatNavigation get etat => _moteur.etat;
  eccore.EtapeNavigation get etapeNavigation => _moteur.etape;
  eccore.ModeNavigation get mode => _moteur.mode;
  eccore.LangueNavigation get langue => _moteur.langue;

  bool get enNavigation => _moteur.mode == eccore.ModeNavigation.navigation;
  bool get traceApproximatif => _traceApproximatif;

  /// Un calcul d'itinéraire est en cours.
  bool get calculEnCours => _calculEnCours;

  /// Le tracé à poser sur la carte.
  List<LatLng> get trace => _moteur.trace.enLatLng;

  /// Position du livreur telle qu'elle s'affiche — ramenée sur le tracé quand
  /// il y en a un, brute sinon.
  LatLng? get positionLivreur {
    final point = _moteur.pointAffiche;
    return point == null ? null : LatLng(point.latitude, point.longitude);
  }

  /// Cap du livreur, ou `null` s'il n'est pas fiable — à l'arrêt, notamment.
  double? get capLivreur => _moteur.capDegres;

  /// Le point de retrait, tel que l'affectation le porte.
  LatLng? get pointRestaurant {
    final course = _course;
    return course == null
        ? null
        : LatLng(course.latitudeRetrait, course.longitudeRetrait);
  }

  /// Le point de livraison, tel que la commande le porte.
  LatLng? get pointClient {
    final course = _course;
    return course == null
        ? null
        : LatLng(course.latitudeLivraison, course.longitudeLivraison);
  }

  /// Où le livreur doit se rendre **maintenant**.
  ///
  /// Jamais choisi à la main : il découle de l'étape de la course. Demander à
  /// un livreur de sélectionner sa destination alors que la commande la porte,
  /// c'est lui faire saisir ce qu'on sait déjà.
  LatLng? get destination =>
      _moteur.etape == eccore.EtapeNavigation.restaurant
          ? pointRestaurant
          : pointClient;

  /// Nom de la destination, tel que le livreur le lit.
  String get destinationLibelle {
    final course = _course;
    if (course == null) return '';
    return _moteur.etape == eccore.EtapeNavigation.restaurant
        ? course.assignment.restaurantName
        : (course.destinataire.isEmpty ? 'Client' : course.destinataire);
  }

  /// L'instruction à afficher en grand, ou `null` quand il n'y en a pas.
  String? get instruction => _moteur.instructionCourante;

  /// La manœuvre en cours — c'est elle qui choisit la flèche.
  eccore.Manoeuvre? get manoeuvre => _moteur.etapeCourante?.manoeuvre;

  /// La manœuvre d'après, à afficher en second.
  String? get instructionSuivante {
    final suivante = _moteur.etapeSuivante;
    return suivante == null ? null : _moteur.phrases.instructionImmediate(suivante);
  }

  double? get distanceAvantManoeuvreMetres => _moteur.distanceAvantManoeuvreMetres;
  double? get distanceRestanteMetres => _moteur.distanceRestanteMetres;
  DateTime? get heureArriveeEstimee => _moteur.heureArriveeEstimee;
  Duration? get dureeRestante => _moteur.dureeRestante();

  /// Ce qui empêche la navigation d'avancer, en une phrase pour le livreur.
  ///
  /// Vient du moteur quand c'est l'itinéraire qui manque, du suivi quand c'est
  /// la position : c'est lui qui a essayé d'ouvrir le flux et qui sait pourquoi
  /// il n'y est pas arrivé.
  String? get obstacle => _moteur.erreur ?? _positions.obstacle;

  /// Le suivi de position tourne-t-il ?
  bool get positionSuivie => _positions.suitLaPosition;

  // -------------------------------------------------------------- commandes

  /// Ouvre la navigation sur une course, en **aperçu**.
  ///
  /// L'aperçu, et non la navigation : ouvrir une carte ne doit pas faire parler
  /// le téléphone. Le livreur démarre le guidage quand il est en selle.
  Future<void> ouvrir(Course course) async {
    _course = course;
    _ouvert = true;

    _positions.addListener(_surNouvellePosition);
    unawaited(voix.initialize());

    final destination = _destinationDe(course);
    if (destination == null) return;

    _moteur.demarrer(
      etape: _etapeDe(course),
      // Un itinéraire vide en attendant le vrai : le moteur a besoin d'une
      // étape et d'un état, l'écran d'une carte. Le calcul suit.
      itineraire: _itineraireDroit(_origine ?? destination, destination),
      mode: eccore.ModeNavigation.apercu,
    );
    _traceApproximatif = true;
    notifyListeners();

    await _calculer(annoncer: false);
    _surNouvellePosition();
  }

  /// Passe en navigation : la carte suit, la voix parle, l'itinéraire se
  /// recalcule.
  Future<void> demarrerLaNavigation() async {
    if (!_ouvert || enNavigation) return;

    await voix.initialize();
    final decision = _moteur.changerDeMode(eccore.ModeNavigation.navigation);
    notifyListeners();
    await _appliquer(decision);

    // L'itinéraire de l'aperçu date peut-être de plusieurs minutes, et le
    // livreur a bougé entre-temps. On repart de là où il est.
    await _calculer(annoncer: false);
  }

  /// Revient en aperçu et fait taire la voix.
  ///
  /// N'arrête **pas** le suivi de position : celui-ci appartient à la course,
  /// pas à cet écran, et le client continue de suivre sa livraison. Le bouton
  /// qui prétendait le contraire a déjà été corrigé une fois.
  Future<void> arreterLaNavigation() async {
    if (!enNavigation) return;
    _moteur.changerDeMode(eccore.ModeNavigation.apercu);
    await voix.stop();
    notifyListeners();
  }

  /// Suit l'évolution de la course.
  ///
  /// Appelée quand le livreur a franchi une étape — commande récupérée,
  /// livraison confirmée — et que le **serveur** l'a enregistrée. C'est ce qui
  /// fait basculer la navigation du restaurant vers le client sans que personne
  /// n'ait à choisir une destination.
  Future<void> majCourse(Course course) async {
    _course = course;

    if (course.prochaineEtape == null) {
      _moteur.terminer();
      await voix.stop();
      notifyListeners();
      return;
    }

    final voulue = _etapeDe(course);
    if (voulue == _moteur.etape) {
      notifyListeners();
      return;
    }

    final decision = _moteur.changerDEtape(voulue);
    _traceApproximatif = true;
    notifyListeners();
    await _appliquer(decision);
    await _calculer(annoncer: false);
  }

  /// Redit l'instruction courante.
  Future<void> repeterLInstruction() async {
    final phrase = _moteur.phraseARepeter();
    if (phrase == null) return;
    // Prioritaire : le livreur vient de la demander, elle ne fait pas la queue
    // derrière une annonce en cours.
    await voix.speak(phrase, prioritaire: true);
  }

  /// Recalcule l'itinéraire depuis la position courante, sur demande.
  Future<void> recalculer() => _calculer(annoncer: false);

  /// Change la langue du guidage — phrases **et** voix, ensemble.
  ///
  /// Les deux, parce qu'une seule ne suffit pas : des phrases anglaises
  /// prononcées par une voix française sont incompréhensibles, et l'inverse
  /// aussi. L'itinéraire est aussi redemandé, ses instructions venant de
  /// Google dans la langue de la requête.
  Future<void> definirLangue(eccore.LangueNavigation langue) async {
    if (_moteur.langue == langue) return;
    _moteur.changerDeLangue(langue);
    await voix.definirLangue(langue);
    notifyListeners();
    await _calculer(annoncer: false);
  }

  /// Referme la navigation et rend tout ce qu'elle tenait.
  ///
  /// Le suivi de position, lui, n'est pas coupé ici : `AppService` le referme
  /// dès qu'aucune course n'est active (`suivreLaCourse`). Le faire aussi ici
  /// laisserait croire que c'est cet écran qui en décide.
  Future<void> fermer() async {
    if (!_ouvert) return;
    _ouvert = false;
    _positions.removeListener(_surNouvellePosition);
    _moteur.arreter();
    await voix.stop();
    _course = null;
    notifyListeners();
  }

  // ------------------------------------------------------------- mécanismes

  eccore.GeoPoint? get _origine {
    final position = _positions.positionCourante;
    return position == null
        ? null
        : eccore.GeoPoint(position.latitude, position.longitude);
  }

  static eccore.EtapeNavigation _etapeDe(Course course) => course.repasRecupere
      ? eccore.EtapeNavigation.client
      : eccore.EtapeNavigation.restaurant;

  eccore.GeoPoint? _destinationDe(Course course) {
    final etape = _etapeDe(course);
    return etape == eccore.EtapeNavigation.restaurant
        ? eccore.GeoPoint(course.latitudeRetrait, course.longitudeRetrait)
        : eccore.GeoPoint(course.latitudeLivraison, course.longitudeLivraison);
  }

  /// Une position vient d'arriver — ou le suivi vient de s'interrompre.
  void _surNouvellePosition() {
    if (!_ouvert) return;

    final position = _positions.positionCourante;
    if (position == null) {
      final decision = _moteur.signalerPositionIndisponible(
        _positions.obstacle,
      );
      notifyListeners();
      unawaited(_appliquer(decision));
      return;
    }

    final decision = _moteur.mettreAJour(_versPositionNavigation(position));
    notifyListeners();
    unawaited(_appliquer(decision));
  }

  static eccore.PositionNavigation _versPositionNavigation(Position position) {
    return eccore.PositionNavigation(
      point: eccore.GeoPoint(position.latitude, position.longitude),
      horodatage: position.timestamp,
      // `geolocator` rend `0` pour « plein nord » comme pour « je ne sais
      // pas ». La vitesse tranche : un appareil qui ne bouge pas n'a pas de
      // cap, et le moteur refuse de tourner le repère en dessous d'un mètre
      // par seconde. La frontière est faite ici, une fois.
      capDegres: position.speed > 0.5 ? position.heading : null,
      vitesseMetresParSeconde: position.speed,
      precisionMetres: position.accuracy,
    );
  }

  /// Exécute ce que le moteur a décidé : prononcer, et recalculer.
  Future<void> _appliquer(eccore.DecisionNavigation decision) async {
    if (decision.sansEffet) return;

    for (final phrase in decision.aPrononcer) {
      // Les annonces d'arrivée et de sortie d'itinéraire passent devant : ce
      // sont les deux seules qui perdent tout leur sens si elles arrivent
      // après la fin d'une instruction de virage.
      await voix.speak(phrase, prioritaire: _estUrgente(phrase));
    }

    if (decision.recalculDemande) await _calculer(annoncer: true);
  }

  bool _estUrgente(String phrase) =>
      phrase == _moteur.phrases.sortieDItineraire ||
      phrase == _moteur.phrases.arriveeA(eccore.EtapeNavigation.restaurant) ||
      phrase == _moteur.phrases.arriveeA(eccore.EtapeNavigation.client);

  /// Demande un itinéraire depuis la position courante.
  ///
  /// ## Quand il est appelé, et quand il ne l'est pas
  ///
  /// À l'ouverture, au démarrage de la navigation, au changement d'étape, à la
  /// sortie d'itinéraire, et sur demande. **Pas** à chaque relevé de position :
  /// l'écran de suivi le faisait, avec un étranglement à cent mètres et trente
  /// secondes, soit une requête Google par minute et par livreur, pour une
  /// donnée qui ne change pas — le tracé entre deux points est le même à trente
  /// mètres près. La distance restante et la durée se recalculent en local, le
  /// long du tracé déjà connu.
  ///
  /// La contrepartie est assumée : un embouteillage apparu après le calcul
  /// n'apparaît pas dans l'heure d'arrivée avant le recalcul suivant. Un bouton
  /// le redemande.
  Future<void> _calculer({required bool annoncer}) async {
    final course = _course;
    final destination = course == null ? null : _destinationDe(course);
    if (destination == null || _calculEnCours) return;

    final origine = _origine;
    if (origine == null) return;

    _calculEnCours = true;
    notifyListeners();

    try {
      final itineraire = await _directions.getRoute(
        origin: LatLng(origine.latitude, origine.longitude),
        destination: LatLng(destination.latitude, destination.longitude),
        avecEtapes: true,
        langue: _moteur.langue.code,
      );

      if (!_ouvert) return;

      if (itineraire == null) {
        // Clé Google absente : ce n'est pas une panne, c'est une
        // configuration. Le repli s'affiche, et il s'annonce.
        _poserLeRepli(origine, destination);
        return;
      }

      _traceApproximatif = false;
      final decision = _moteur.remplacerLItineraire(itineraire, annoncer: annoncer);
      notifyListeners();
      await _appliquer(decision);
    } catch (e) {
      eccore.Journal.trace('❌ Itinéraire indisponible : $e');
      if (!_ouvert) return;
      _poserLeRepli(origine, destination);
      final decision = _moteur.signalerErreur(
        e is eccore.DirectionsException
            ? e.message
            : 'Impossible de calculer l’itinéraire. Vérifiez votre connexion.',
      );
      notifyListeners();
      await _appliquer(decision);
    } finally {
      _calculEnCours = false;
      if (_ouvert) notifyListeners();
    }
  }

  void _poserLeRepli(eccore.GeoPoint origine, eccore.GeoPoint destination) {
    _traceApproximatif = true;
    _moteur.remplacerLItineraire(
      _itineraireDroit(origine, destination),
      annoncer: false,
    );
    notifyListeners();
  }

  /// Un « itinéraire » réduit à la ligne droite entre deux points.
  ///
  /// Sans manœuvre — et c'est délibéré : le moteur, ne trouvant pas d'étape,
  /// se tait au lieu d'inventer des virages sur un trait qui traverse les
  /// pâtés de maisons. La distance et la destination restent justes, et c'est
  /// tout ce qu'on peut honnêtement en tirer.
  eccore.RouteInfo _itineraireDroit(
    eccore.GeoPoint origine,
    eccore.GeoPoint destination,
  ) {
    final metres = eccore.GeoCalcul.distanceMetres(origine, destination);
    final minutes =
        (metres / 1000 / _moteur.reglages.vitesseDeReferenceKmH * 60).round();
    return eccore.RouteInfo(
      distanceKm: metres / 1000,
      distanceMeters: metres.round(),
      durationMinutes: minutes.clamp(1, 240),
      polylinePoints: [origine, destination],
      encodedPolyline: '',
      timestamp: DateTime.now(),
    );
  }

  @override
  void dispose() {
    if (_ouvert) _positions.removeListener(_surNouvellePosition);
    _ouvert = false;
    voix.dispose();
    super.dispose();
  }
}
