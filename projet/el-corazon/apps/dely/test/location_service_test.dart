import 'package:elcora_dely/services/location_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart'
    show LocationAvailability, LocationRemede;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le service de position, contre un `geolocator` simulé au niveau du canal
/// de plateforme.
///
/// ## Pourquoi ces tests-là
///
/// Le service rendait un `bool`, et les quatre situations qui empêchent un
/// relevé — GPS coupé, permission à redemander, refus définitif, capteur muet —
/// s'y écrasaient en un seul `false`. Chaque écran redécouvrait alors la cause
/// à sa façon, et se trompait : le sélecteur de point rappelait
/// `isLocationServiceEnabled` **après coup** pour deviner quoi afficher, la
/// feuille d'adresse ne devinait rien et invitait à « autoriser la
/// localisation » un client dont la permission était accordée mais le GPS
/// éteint.
///
/// On ne peut pas vérifier cela en lisant le code : il faut faire répondre le
/// greffon. Le canal de méthode le permet — c'est le seul point où les quatre
/// cas se distinguent réellement.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const canal = MethodChannel('flutter.baseflow.com/geolocator');
  final messagerie =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late LocationService service;
  late List<String> appels;

  /// Fait répondre le greffon.
  ///
  /// [permission] suit l'énumération native : 0 = refusée, 1 = refusée
  /// définitivement, 2 = pendant l'usage, 3 = toujours.
  void simuleGeolocator({
    required bool serviceActif,
    required int permission,
    Map<String, dynamic>? position,
    String? erreurPosition,
  }) {
    appels = [];
    messagerie.setMockMethodCallHandler(canal, (appel) async {
      appels.add(appel.method);
      switch (appel.method) {
        case 'isLocationServiceEnabled':
          return serviceActif;
        case 'checkPermission':
        case 'requestPermission':
          return permission;
        case 'getCurrentPosition':
          if (erreurPosition != null) {
            throw PlatformException(code: erreurPosition);
          }
          return position;
        default:
          return null;
      }
    });
  }

  setUp(() {
    service = LocationService();
  });

  tearDown(() {
    messagerie.setMockMethodCallHandler(canal, null);
  });

  Map<String, dynamic> positionLome() => <String, dynamic>{
        'latitude': 6.1319,
        'longitude': 1.2255,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'accuracy': 8.0,
        'altitude': 12.0,
        'altitude_accuracy': 3.0,
        'heading': 120.0,
        'heading_accuracy': 5.0,
        'speed': 4.2,
        'speed_accuracy': 1.0,
        'is_mocked': false,
      };

  group('GPS désactivé sur l’appareil', () {
    test('la cause est le service, pas la permission', () async {
      // Le piège : la permission peut être accordée depuis des mois sur un
      // téléphone dont la localisation est coupée. Tester la permission en
      // premier annoncerait « tout va bien », et le relevé échouerait ensuite
      // sans explication.
      simuleGeolocator(serviceActif: false, permission: 3);

      final etat = await service.disponibilite();

      expect(etat, LocationAvailability.serviceDesactive);
      expect(etat.estDisponible, isFalse);
      // Et surtout : on ne demande pas une permission qui ne débloquerait rien.
      expect(appels, isNot(contains('requestPermission')));
    });

    test('le remède renvoie aux réglages du système', () async {
      simuleGeolocator(serviceActif: false, permission: 3);

      final etat = await service.disponibilite();

      expect(etat.remede, LocationRemede.ouvrirReglagesDeLocalisation);
      expect(etat.consigne, isNotEmpty);
    });

    test('aucune position n’est rendue', () async {
      simuleGeolocator(serviceActif: false, permission: 3);

      expect(await service.getCurrentLocation(), isNull);
      expect(appels, isNot(contains('getCurrentPosition')));
    });
  });

  group('Permission', () {
    test('un refus simple se redemande une fois', () async {
      simuleGeolocator(serviceActif: true, permission: 0);

      final etat = await service.disponibilite();

      expect(etat, LocationAvailability.permissionRefusee);
      expect(etat.remede, LocationRemede.redemanderLaPermission);
      // La demande a bien été posée : c'est le seul moment où le système
      // accepte de l'afficher, et chaque appelant n'a pas à s'en souvenir.
      expect(appels, contains('requestPermission'));
    });

    test('un refus définitif ne se redemande pas', () async {
      // Le système ne réafficherait rien : insister laisse l'utilisateur
      // appuyer sur un bouton qui ne produit jamais de dialogue.
      simuleGeolocator(serviceActif: true, permission: 1);

      final etat = await service.disponibilite();

      expect(etat, LocationAvailability.permissionRefuseeDefinitivement);
      expect(etat.remede, LocationRemede.ouvrirLaFicheDeLApplication);
      expect(appels, isNot(contains('requestPermission')));
    });

    test('accordée pendant l’usage, le relevé est possible', () async {
      simuleGeolocator(serviceActif: true, permission: 2);

      expect(await service.disponibilite(), LocationAvailability.disponible);
    });

    test('accordée en permanence aussi', () async {
      simuleGeolocator(serviceActif: true, permission: 3);

      expect(await service.disponibilite(), LocationAvailability.disponible);
    });
  });

  group('Relevé de position', () {
    test('une position valide est rendue et retenue', () async {
      simuleGeolocator(
        serviceActif: true,
        permission: 3,
        position: positionLome(),
      );

      final position = await service.getCurrentLocation();

      expect(position, isNotNull);
      expect(position!.latitude, closeTo(6.1319, 1e-6));
      expect(position.longitude, closeTo(1.2255, 1e-6));
      expect(service.currentPosition, same(position));
      expect(service.derniereDisponibilite, LocationAvailability.disponible);
    });

    test('un capteur muet ne se confond pas avec un refus', () async {
      // C'est le seul des quatre cas où attendre est la bonne réponse : pas de
      // fixation satellite sous un toit, en sous-sol, en début de relevé.
      // L'annoncer comme une permission refusée enverrait l'utilisateur dans
      // des réglages où il n'a rien à changer.
      simuleGeolocator(
        serviceActif: true,
        permission: 3,
        erreurPosition: 'LOCATION_UPDATE_FAILURE',
      );

      expect(await service.getCurrentLocation(), isNull);
      expect(
        service.derniereDisponibilite,
        LocationAvailability.positionIndisponible,
      );
      expect(
        service.derniereDisponibilite.remede,
        LocationRemede.patienter,
      );
    });

    test('un relevé refusé n’écrase pas la dernière position connue', () async {
      simuleGeolocator(
        serviceActif: true,
        permission: 3,
        position: positionLome(),
      );
      final bonne = await service.getCurrentLocation();

      simuleGeolocator(
        serviceActif: false,
        permission: 3,
      );
      expect(await service.getCurrentLocation(), isNull);

      // La carte continue d'afficher le dernier point connu plutôt que de le
      // faire disparaître : c'est le bandeau de fraîcheur, pas l'effacement,
      // qui dit que la position a vieilli.
      expect(service.currentPosition, same(bonne));
    });
  });

  group('Notification des écrans', () {
    test('un changement d’état prévient les auditeurs', () async {
      simuleGeolocator(serviceActif: true, permission: 3);
      await service.disponibilite();

      var notifications = 0;
      void compter() => notifications++;
      service.addListener(compter);

      simuleGeolocator(serviceActif: false, permission: 3);
      await service.disponibilite();

      service.removeListener(compter);
      expect(notifications, 1);
    });

    test('un état inchangé ne provoque aucune reconstruction', () async {
      // Le service est écouté par des écrans avec carte : notifier sans
      // changement les ferait se reconstruire à chaque interrogation.
      simuleGeolocator(serviceActif: false, permission: 3);
      await service.disponibilite();

      var notifications = 0;
      void compter() => notifications++;
      service.addListener(compter);

      await service.disponibilite();
      await service.disponibilite();

      service.removeListener(compter);
      expect(notifications, 0);
    });
  });
}
