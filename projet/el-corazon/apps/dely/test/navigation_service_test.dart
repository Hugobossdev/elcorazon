import 'dart:math' as math;

import 'package:elcora_dely/presentation/libelles_course.dart';
import 'package:elcora_dely/repositories/django_delivery_repository.dart';
import 'package:elcora_dely/services/directions_service.dart';
import 'package:elcora_dely/services/navigation_service.dart';
import 'package:elcora_dely/services/navigation_voice_service.dart';
import 'package:elcora_dely/services/source_de_position.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Le flux de position, piloté par le test.
///
/// Il remplace `SuiviCommeSource`, c'est-à-dire la **vue en lecture** sur
/// `RealtimeTrackingService`. Rien d'autre du chemin qu'une position parcourt
/// n'est remplacé : le moteur, les phrases, la file de la voix sont les vrais.
class _SourcePilotee extends ChangeNotifier implements SourceDePosition {
  Position? _position;
  String? _obstacle;

  @override
  Position? get positionCourante => _position;

  @override
  String? get obstacle => _obstacle;

  @override
  bool get suitLaPosition => _position != null;

  /// Combien d'abonnés — c'est ce qui prouve qu'une fermeture rend le flux.
  int ecouteurs = 0;

  @override
  void addListener(VoidCallback ecouteur) {
    ecouteurs++;
    super.addListener(ecouteur);
  }

  @override
  void removeListener(VoidCallback ecouteur) {
    ecouteurs--;
    super.removeListener(ecouteur);
  }

  void poser(Position position) {
    _position = position;
    _obstacle = null;
    notifyListeners();
  }

  /// Le suivi s'interrompt : la position redevient nulle, et le service dit
  /// pourquoi.
  void perdre(String raison) {
    _position = null;
    _obstacle = raison;
    notifyListeners();
  }
}

/// Google, remplacé à sa frontière.
class _DirectionsSimulees implements DirectionsService {
  _DirectionsSimulees(this.fabrique);

  /// Construit l'itinéraire rendu, à partir des deux points demandés.
  final eccore.RouteInfo Function(eccore.GeoPoint de, eccore.GeoPoint a) fabrique;

  final List<({LatLng origine, LatLng destination, String langue, bool avecEtapes})>
      appels = [];

  /// Quand elle est posée, chaque appel lève — quota, réseau, clé refusée.
  Exception? panne;

  @override
  Future<eccore.RouteInfo?> getRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
    String mode = 'driving',
    String langue = 'fr',
    bool avecEtapes = false,
  }) async {
    appels.add((
      origine: origin,
      destination: destination,
      langue: langue,
      avecEtapes: avecEtapes,
    ));
    final defaillance = panne;
    if (defaillance != null) throw defaillance;

    return fabrique(
      eccore.GeoPoint(origin.latitude, origin.longitude),
      eccore.GeoPoint(destination.latitude, destination.longitude),
    );
  }

  @override
  Future<eccore.DistanceTimeInfo?> getDistanceAndTime({
    required LatLng origin,
    required LatLng destination,
    String mode = 'driving',
  }) async =>
      null;

  @override
  double calculateStraightLineDistance(LatLng point1, LatLng point2) =>
      eccore.GeoCalcul.distanceMetres(
        eccore.GeoPoint(point1.latitude, point1.longitude),
        eccore.GeoPoint(point2.latitude, point2.longitude),
      ) /
      1000;

  @override
  void clearCache() {}
}

/// Le haut-parleur, remplacé à sa frontière.
class _MoteurVocalMuet implements MoteurVocal {
  final List<String> dites = [];
  int arrets = 0;

  @override
  Future<bool> preparer({
    required String langue,
    required double volume,
    required double vitesse,
  }) async =>
      true;

  @override
  Future<void> dire(String texte) async => dites.add(texte);

  @override
  Future<void> taire() async => arrets++;

  @override
  Future<void> suspendre() async {}

  @override
  Future<void> liberer() async {}
}

/// Le parcours complet du livreur, guidé, sans carte, sans GPS et sans voix.
///
/// ## Ce que ce fichier exerce
///
/// La chaîne entière, telle qu'elle tourne sur le téléphone : une position
/// entre par la source, traverse `MoteurDeNavigation`, ressort en phrase, et
/// part au moteur de synthèse. Les trois seules pièces remplacées sont celles
/// qui ne peuvent pas exister dans un test — le capteur, Google, le
/// haut-parleur — et chacune l'est **à sa frontière**, pas au milieu de la
/// logique.
///
/// Le scénario est celui d'une livraison :
///
///     course acceptée → navigation vers le restaurant → arrivée →
///     commande récupérée → navigation vers le client → sortie d'itinéraire →
///     recalcul → fin de course → tout est rendu
///
/// ## Ce qu'il protège en particulier
///
/// Que **le GPS ne fasse jamais avancer la course**. La navigation suit l'étape
/// déclarée par le livreur et enregistrée par le serveur ; arriver quelque part
/// met un bouton en avant, cela ne l'appuie pas.
void main() {
  const restaurant = eccore.GeoPoint(6.1319, 1.2228);
  const client = eccore.GeoPoint(6.1500, 1.2400);
  const metreEnLatitude = 1 / 111320.0;
  final metreEnLongitude =
      1 / (111320.0 * math.cos(restaurant.latitude * math.pi / 180));

  /// Le livreur part d'un kilomètre au sud du restaurant.
  final depart = eccore.GeoPoint(
    restaurant.latitude - 1000 * metreEnLatitude,
    restaurant.longitude,
  );

  /// Un itinéraire droit entre deux points, découpé en manœuvres.
  ///
  /// Suffisant, et volontairement : la géométrie est vérifiée ailleurs
  /// (`geo_calcul_test`, `moteur_de_navigation_test`). Ce qui se joue ici est
  /// l'assemblage.
  eccore.RouteInfo itineraireEntre(eccore.GeoPoint de, eccore.GeoPoint a) {
    const manoeuvres = 2;
    eccore.GeoPoint jalon(int i) => eccore.GeoPoint(
          de.latitude + (a.latitude - de.latitude) * i / manoeuvres,
          de.longitude + (a.longitude - de.longitude) * i / manoeuvres,
        );

    final etapes = <eccore.RouteStep>[];
    for (var i = 0; i < manoeuvres; i++) {
      final debut = jalon(i);
      final fin = jalon(i + 1);
      final metres = eccore.GeoCalcul.distanceMetres(debut, fin).round();
      etapes.add(
        eccore.RouteStep(
          distanceMeters: metres,
          durationSeconds: (metres / 8.33).round(),
          start: debut,
          end: fin,
          instruction: 'Continuer',
          manoeuvre: i == manoeuvres - 1
              ? eccore.Manoeuvre.aucune
              : eccore.Manoeuvre.aDroite,
          polylinePoints: [debut, fin],
        ),
      );
    }

    final total = etapes.fold<int>(0, (t, e) => t + e.distanceMeters);
    return eccore.RouteInfo(
      distanceKm: total / 1000,
      distanceMeters: total,
      durationMinutes: (total / 500).round().clamp(1, 240),
      polylinePoints: [de, a],
      encodedPolyline: '',
      timestamp: DateTime(2026, 9, 5, 12),
      steps: etapes,
    );
  }

  // ---------------------------------------------------------------- fixtures

  Course course({
    required String statut,
    required List<String> transitions,
  }) {
    return Course(
      assignment: eccore.Assignment.fromJson({
        'id': 'course-1',
        'order': 'a1b2c3d4-0000-0000-0000-000000000001',
        'order_reference': 'CMD-0001',
        'restaurant_name': 'El Corazón Lomé',
        'pickup_location': {
          'lat': restaurant.latitude,
          'lon': restaurant.longitude,
        },
        'delivery_address_line': 'Rue du Commerce, Lomé',
        'delivery_landmark': '',
        'delivery_location': {'lat': client.latitude, 'lon': client.longitude},
        'recipient_name': 'Awa',
        'recipient_phone': '+22890000000',
        'courier': {
          'id': 'livreur-7',
          'full_name': 'Kodjo',
          'vehicle_type': 'moto',
          'rating_average': '4.8',
          'rating_count': 12,
        },
        'status': statut,
        'allowed_transitions': transitions,
        'courier_fee': {'amount': '1000', 'currency': 'XOF'},
        'offered_at': '2026-08-02T12:00:00Z',
        'created_at': '2026-08-02T11:59:00Z',
        'updated_at': '2026-08-02T12:00:00Z',
      }),
    );
  }

  Course acceptee() => course(
        statut: eccore.DeliveryStatus.accepted,
        transitions: const [eccore.DeliveryStatus.pickedUp],
      );

  Course recuperee() => course(
        statut: eccore.DeliveryStatus.pickedUp,
        transitions: const [eccore.DeliveryStatus.onTheWay],
      );

  Course livree() => course(
        statut: eccore.DeliveryStatus.delivered,
        transitions: const [],
      );

  // ------------------------------------------------------------------- outils

  late _SourcePilotee positions;
  late _DirectionsSimulees directions;
  late _MoteurVocalMuet moteur;
  late NavigationService navigation;

  Position positionA(eccore.GeoPoint point, {double vitesse = 0}) => Position(
        latitude: point.latitude,
        longitude: point.longitude,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 20,
        headingAccuracy: 0,
        speed: vitesse,
        speedAccuracy: 0,
      );

  setUp(() {
    positions = _SourcePilotee();
    directions = _DirectionsSimulees(itineraireEntre);
    moteur = _MoteurVocalMuet();
    navigation = NavigationService(
      positions: positions,
      directions: directions,
      voix: NavigationVoiceService(moteur: moteur),
    );
  });

  tearDown(() async {
    await navigation.fermer();
  });

  /// Pousse une position dans la chaîne, comme le ferait le flux du suivi.
  Future<void> rouler(eccore.GeoPoint point) async {
    positions.poser(positionA(point, vitesse: 8.3));
    await pumpEventQueue();
  }

  eccore.GeoPoint surLaRoute(
    eccore.GeoPoint de,
    eccore.GeoPoint a,
    double fraction,
  ) =>
      eccore.GeoPoint(
        de.latitude + (a.latitude - de.latitude) * fraction,
        de.longitude + (a.longitude - de.longitude) * fraction,
      );

  Future<void> ouvrirDepuisLeDepart() async {
    positions.poser(positionA(depart));
    await navigation.ouvrir(acceptee());
  }

  Future<void> demarrer() async {
    await ouvrirDepuisLeDepart();
    await navigation.demarrerLaNavigation();
    await pumpEventQueue();
  }

  group('Ouverture d’une course', () {
    test('la destination vient de la course, jamais d’un choix', () async {
      await ouvrirDepuisLeDepart();

      expect(navigation.etapeNavigation, eccore.EtapeNavigation.restaurant);
      expect(
        navigation.destination,
        LatLng(restaurant.latitude, restaurant.longitude),
      );
      expect(navigation.destinationLibelle, 'El Corazón Lomé');
    });

    test('elle ouvre en aperçu — le téléphone ne parle pas tout seul', () async {
      await ouvrirDepuisLeDepart();
      await pumpEventQueue();

      expect(navigation.enNavigation, isFalse);
      expect(moteur.dites, isEmpty);
    });

    test('l’itinéraire est demandé avec ses manœuvres et sa langue', () async {
      // Sans manœuvres, aucune instruction n'est possible : c'est la raison
      // pour laquelle l'écran n'en avait aucune avant cette tranche.
      await ouvrirDepuisLeDepart();

      expect(directions.appels, hasLength(1));
      expect(directions.appels.single.avecEtapes, isTrue);
      expect(directions.appels.single.langue, 'fr');
      expect(navigation.traceApproximatif, isFalse);
      expect(navigation.trace.length, greaterThan(1));
    });

    test('sans position connue, le repli s’affiche et s’annonce', () async {
      // Le tracé en ligne droite était auparavant dessiné comme un itinéraire.
      // Un livreur qui le suit traverse des murs.
      await navigation.ouvrir(acceptee());

      expect(navigation.traceApproximatif, isTrue);
      expect(directions.appels, isEmpty);
      expect(navigation.trace, hasLength(2));
    });
  });

  group('Guidage vers le restaurant', () {
    test('le départ est annoncé', () async {
      await demarrer();

      expect(moteur.dites, contains('Navigation vers le restaurant.'));
      expect(navigation.enNavigation, isTrue);
      expect(navigation.etat, eccore.EtatNavigation.versLeRestaurant);
    });

    test('les instructions sont prononcées en roulant', () async {
      await demarrer();
      moteur.dites.clear();

      for (final fraction in [0.2, 0.35, 0.45, 0.49]) {
        await rouler(surLaRoute(depart, restaurant, fraction));
      }

      expect(
        moteur.dites.where((p) => p.contains('tournez à droite')),
        isNotEmpty,
        reason: 'la manœuvre du milieu du trajet doit être annoncée',
      );
    });

    test('la même instruction n’est pas répétée', () async {
      await demarrer();
      moteur.dites.clear();

      // Vingt relevés serrés : sans anti-répétition, ce serait vingt annonces.
      for (var i = 0; i < 20; i++) {
        await rouler(surLaRoute(depart, restaurant, 0.30 + i * 0.001));
      }

      final annonces =
          moteur.dites.where((p) => p.contains('tournez à droite')).toList();
      expect(annonces, hasLength(lessThanOrEqualTo(2)));
      expect(annonces.toSet(), hasLength(annonces.length));
    });

    test('l’arrivée est détectée et annoncée', () async {
      await demarrer();
      await rouler(restaurant);

      expect(navigation.etat, eccore.EtatNavigation.arriveAuRestaurant);
      expect(moteur.dites, contains('Vous êtes arrivé au restaurant.'));
    });

    test('arriver ne fait pas avancer la course', () async {
      // La règle la plus importante du fichier. Un relevé GPS ne prouve ni
      // qu'un sac a changé de mains, ni qu'un client a payé, et il se falsifie.
      await demarrer();
      await rouler(restaurant);

      expect(navigation.course!.etape, EtapeCourse.acceptee);
      expect(navigation.course!.prochaineEtape, EtapeCourse.recuperee);
    });
  });

  group('Passage au client', () {
    Future<void> jusquAuRestaurant() async {
      await demarrer();
      await rouler(restaurant);
      moteur.dites.clear();
      directions.appels.clear();
    }

    test('la commande récupérée fait basculer la destination', () async {
      await jusquAuRestaurant();
      await navigation.majCourse(recuperee());
      await pumpEventQueue();

      expect(navigation.etapeNavigation, eccore.EtapeNavigation.client);
      expect(navigation.destination, LatLng(client.latitude, client.longitude));
      expect(moteur.dites, contains('Navigation vers le client.'));
    });

    test('un nouvel itinéraire est demandé vers le client', () async {
      await jusquAuRestaurant();
      await navigation.majCourse(recuperee());

      expect(directions.appels, hasLength(1));
      expect(
        directions.appels.single.destination,
        LatLng(client.latitude, client.longitude),
      );
    });

    test('le contexte vocal repart à zéro', () async {
      // Les paliers déjà dits appartenaient au trajet précédent ; les garder
      // ferait rouler le livreur en silence jusqu'au premier carrefour.
      await jusquAuRestaurant();
      await navigation.majCourse(recuperee());
      moteur.dites.clear();

      for (final fraction in [0.2, 0.35, 0.45]) {
        await rouler(surLaRoute(restaurant, client, fraction));
      }
      expect(moteur.dites, isNotEmpty);
    });

    test('l’arrivée chez le client est annoncée', () async {
      await jusquAuRestaurant();
      await navigation.majCourse(recuperee());
      await rouler(client);

      expect(navigation.etat, eccore.EtatNavigation.arriveChezLeClient);
      expect(moteur.dites, contains('Vous êtes arrivé à destination.'));
    });
  });

  group('Sortie d’itinéraire', () {
    test('elle est annoncée et provoque un seul recalcul', () async {
      await demarrer();
      moteur.dites.clear();
      directions.appels.clear();

      final aCote = surLaRoute(depart, restaurant, 0.4);
      final devie = eccore.GeoPoint(
        aCote.latitude,
        aCote.longitude + 300 * metreEnLongitude,
      );
      for (var i = 0; i < 6; i++) {
        await rouler(devie);
      }

      expect(
        moteur.dites.where((p) => p.contains('quitté l’itinéraire')),
        hasLength(1),
      );
      expect(directions.appels, hasLength(1), reason: 'le temps mort tient');
      expect(moteur.dites, contains('Nouvel itinéraire.'));
    });
  });

  group('Fin de course', () {
    test('la course livrée arrête le guidage', () async {
      await demarrer();
      await navigation.majCourse(livree());

      expect(navigation.etat, eccore.EtatNavigation.terminee);
    });

    test('fermer rend le flux, la voix et l’itinéraire', () async {
      await demarrer();
      expect(positions.ecouteurs, 1);

      await navigation.fermer();

      expect(positions.ecouteurs, 0, reason: 'plus d’abonné au flux');
      expect(navigation.etat, eccore.EtatNavigation.inactif);
      expect(navigation.trace, isEmpty);
      expect(navigation.course, isNull);
      expect(moteur.arrets, greaterThan(0));
    });

    test('une position reçue après la fermeture ne réveille rien', () async {
      await demarrer();
      await navigation.fermer();
      moteur.dites.clear();

      await rouler(restaurant);
      expect(moteur.dites, isEmpty);
      expect(navigation.etat, eccore.EtatNavigation.inactif);
    });
  });

  group('Position indisponible', () {
    test('l’obstacle du suivi est repris tel quel', () async {
      await demarrer();
      await rouler(surLaRoute(depart, restaurant, 0.2));
      moteur.dites.clear();

      positions.perdre('La localisation est désactivée sur cet appareil.');
      await pumpEventQueue();

      expect(navigation.etat, eccore.EtatNavigation.positionIndisponible);
      expect(
        navigation.obstacle,
        'La localisation est désactivée sur cet appareil.',
      );
      expect(moteur.dites, contains('Position perdue. Recherche du signal.'));
    });

    test('la position revenue reprend le guidage', () async {
      await demarrer();
      await rouler(surLaRoute(depart, restaurant, 0.2));
      positions.perdre('GPS coupé');
      await pumpEventQueue();

      await rouler(surLaRoute(depart, restaurant, 0.3));
      expect(navigation.etat, eccore.EtatNavigation.versLeRestaurant);
    });
  });

  group('Itinéraire indisponible', () {
    test('le repli s’affiche et l’obstacle est dit au livreur', () async {
      directions.panne = const eccore.DirectionsException(
        'Quota API dépassé',
        status: 'OVER_QUERY_LIMIT',
      );

      await ouvrirDepuisLeDepart();
      await pumpEventQueue();

      expect(navigation.traceApproximatif, isTrue);
      expect(navigation.trace, hasLength(2));
      expect(navigation.obstacle, 'Quota API dépassé');
    });
  });

  group('Langue', () {
    test('changer de langue bascule les phrases et redemande la route', () async {
      await demarrer();
      directions.appels.clear();

      await navigation.definirLangue(eccore.LangueNavigation.anglais);

      expect(navigation.langue, eccore.LangueNavigation.anglais);
      expect(directions.appels.single.langue, 'en');
    });
  });
}
