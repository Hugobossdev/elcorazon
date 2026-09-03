import 'package:elcora_fast/services/location_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show LocationAvailability;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que le service de position de l'application **cliente** fait de plus que
/// son homologue livreur.
///
/// Les quatre causes d'empêchement et leurs remèdes sont vérifiés une fois,
/// côté livreur (`apps/dely/test/location_service_test.dart`) : c'est la même
/// logique, et la recopier ici ne dirait rien de neuf. Ce fichier couvre les
/// deux comportements qui n'existent que de ce côté, et qui ont chacun coûté
/// un défaut visible.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const canal = MethodChannel('flutter.baseflow.com/geolocator');
  final messagerie =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void simuleGeolocator({required bool serviceActif, required int permission}) {
    messagerie.setMockMethodCallHandler(canal, (appel) async {
      switch (appel.method) {
        case 'isLocationServiceEnabled':
          return serviceActif;
        case 'checkPermission':
        case 'requestPermission':
          return permission;
        case 'getCurrentPosition':
          return <String, dynamic>{
            'latitude': 6.1319,
            'longitude': 1.2255,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'accuracy': 8.0,
            'altitude': 12.0,
            'altitude_accuracy': 3.0,
            'heading': 0.0,
            'heading_accuracy': 0.0,
            'speed': 0.0,
            'speed_accuracy': 0.0,
            'is_mocked': false,
          };
        default:
          return null;
      }
    });
  }

  tearDown(() => messagerie.setMockMethodCallHandler(canal, null));

  test('c’est la même instance partout dans l’application', () async {
    // Chaque `LocationService()` construisait un objet neuf, dont
    // `currentPosition` restait nul tant que personne n'avait relevé la
    // position *sur cette instance-là*. Le tri des adresses par distance, qui
    // en construisait une à la volée, retombait donc systématiquement sur une
    // position absente : l'option existait dans le menu et ne triait rien.
    expect(identical(LocationService(), LocationService()), isTrue);

    simuleGeolocator(serviceActif: true, permission: 3);
    await LocationService().getCurrentLocation();

    // Une instance obtenue ailleurs voit le même relevé.
    expect(LocationService().currentPosition, isNotNull);
  });

  test('initialize ne lève pas quand la localisation est refusée', () async {
    // Elle est appelée au démarrage, avant tout écran. Une exception ici
    // faisait tomber l'initialisation des services, donc l'application
    // entière — pour une permission que le client a parfaitement le droit de
    // refuser.
    simuleGeolocator(serviceActif: false, permission: 1);

    await expectLater(LocationService().initialize(), completes);
    expect(
      LocationService().derniereDisponibilite,
      LocationAvailability.serviceDesactive,
    );
  });
}
