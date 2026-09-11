import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

/// Le référentiel géographique partagé — livrabilité, géocodage, modes de zone.
///
/// Ces trois contrats existent pour supprimer trois duplications :
///
/// * la livrabilité était recomposée par chaque application à partir d'une
///   réponse partielle, et la zone qui *affichait* un tarif n'était pas choisie
///   par la même règle que celle qui le *facturait* ;
/// * le géocodage inverse ne rendait qu'une chaîne, et chaque écran devinait la
///   ville en y cherchant son nom ;
/// * le cercle d'une zone était discrétisé côté client, avec une approximation
///   locale qui s'écarte hors de nos latitudes.
class _FakeServer implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  /// Réponse à servir pour la livrabilité — modifiable par le test.
  Map<String, dynamic> livrabilite = {
    'is_available': true,
    'reason': null,
    'restaurant': {
      'id': 'r-1',
      'name': 'El Corazón Lomé',
      'slug': 'el-corazon-lome',
      'description': '',
      'address': 'Boulevard du 13 Janvier',
      'location': {'lat': 6.1319, 'lon': 1.2255},
      'city': 'Lomé',
      'city_slug': 'lome',
      'country': 'TG',
      'phone_prefix': '+228',
      'phone': '+22890000000',
      'cover_image': null,
      'currency': 'XOF',
      'delivery_fee_from': {'amount': '500', 'currency': 'XOF'},
      'estimated_delivery_minutes': 30,
      'default_preparation_minutes': 20,
      'is_open': true,
      'accepts_orders': true,
      'can_order_now': true,
      'distance_m': null,
      'created_at': '2026-09-01T10:00:00Z',
      'updated_at': '2026-09-01T10:00:00Z',
    },
    'zone': {
      'id': 'z-1',
      'name': 'Centre-ville',
      'city': {
        'id': 'c-1',
        'name': 'Lomé',
        'slug': 'lome',
        'country': {
          'id': 'p-1',
          'iso_code': 'TG',
          'iso3_code': 'TGO',
          'name': 'Togo',
          'currency': 'XOF',
          'currency_symbol': 'FCFA',
          'phone_prefix': '+228',
          'timezone': 'Africa/Lome',
          'default_language': 'fr',
          'centroid': null,
        },
        'centroid': {'lat': 6.1319, 'lon': 1.2255},
      },
      'base_fee': {'amount': '500', 'currency': 'XOF'},
      'fee_per_km': {'amount': '100', 'currency': 'XOF'},
      'free_delivery_threshold': null,
      'min_order_amount': null,
      'max_distance_km': '15.00',
      'estimated_delivery_minutes': 30,
    },
    'distance_m': 1850.0,
    'estimated_minutes': 50,
    'delivery_fee': {'amount': '685', 'currency': 'XOF'},
    'gross_delivery_fee': {'amount': '685', 'currency': 'XOF'},
    'is_free_delivery': false,
  };

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    if (options.path.contains('/restaurants/delivery-check/')) {
      return ResponseBody.fromString(
        jsonEncode(livrabilite),
        200,
        headers: _jsonHeaders,
      );
    }

    if (options.path.contains('/geography/geocode/reverse/')) {
      return ResponseBody.fromString(
        jsonEncode({
          'latitude': 6.37,
          'longitude': 2.42,
          'formatted_address': 'Rue de Lomé, Cotonou, Bénin',
          'place_id': 'ChIJexemple',
          'country': 'Bénin',
          'country_code': 'BJ',
          'region': 'Littoral',
          'city': 'Cotonou',
          'district': 'Ganhi',
          'postal_code': null,
          'street': 'Rue de Lomé',
          'street_number': '12',
        }),
        200,
        headers: _jsonHeaders,
      );
    }

    if (options.path.contains('/geography/manage/zones/')) {
      return ResponseBody.fromString(
        jsonEncode({
          'id': 'z-neuve',
          'name': 'Zone neuve',
          'city': 'c-1',
          'restaurant': null,
          'shape': 'circle',
          'boundary': {
            'type': 'MultiPolygon',
            'coordinates': [
              [
                [
                  [1.2, 6.1],
                  [1.3, 6.1],
                  [1.3, 6.2],
                  [1.2, 6.1],
                ],
              ],
            ],
          },
          'center': {'lat': 6.1319, 'lon': 1.2255},
          'radius_meters': 5000,
          'priority': 0,
          'base_fee': {'amount': '500', 'currency': 'XOF'},
          'fee_per_km': {'amount': '100', 'currency': 'XOF'},
          'free_delivery_threshold': null,
          'min_order_amount': null,
          'max_distance_km': '15.00',
          'estimated_delivery_minutes': 30,
          'is_active': true,
          'overlaps': <String>[],
          'created_at': '2026-09-08T10:00:00Z',
          'updated_at': '2026-09-08T10:00:00Z',
        }),
        201,
        headers: _jsonHeaders,
      );
    }

    throw UnimplementedError('Route non simulée : ${options.path}');
  }
}

ApiClient _client(_FakeServer server) => ApiClient(
  baseUrl: 'http://test.local/api/v1',
  tokenStorage: TokenStorage(),
  testAdapter: server,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  group('Livrabilité', () {
    test('la réponse porte tout ce dont un écran a besoin', () async {
      // Établissement, zone, distance, délai et frais — d'un seul appel. Aucune
      // des trois applications n'obtenait cela avant : chacune recomposait le
      // reste à sa façon.
      final server = _FakeServer();

      final reponse = await DeliveryCheckRepository(apiClient: _client(server))
          .check(latitude: 6.135, longitude: 1.23);

      expect(reponse.isAvailable, isTrue);
      expect(reponse.restaurant?.slug, 'el-corazon-lome');
      expect(reponse.zone?.name, 'Centre-ville');
      expect(reponse.distanceMeters, 1850.0);
      expect(reponse.estimatedMinutes, 50);
      expect(reponse.deliveryFee?.amountMinor, 685);
    });

    test('le délai annoncé couvre la préparation et la course', () async {
      // 20 minutes de cuisine plus 30 de trajet : c'est ce que le client
      // attend réellement. La zone seule promettait un repas en trente minutes.
      final reponse = await DeliveryCheckRepository(apiClient: _client(_FakeServer()))
          .check(latitude: 6.135, longitude: 1.23);

      expect(reponse.estimatedMinutes, 50);
    });

    test('un refus dit pourquoi, et ce n’est pas une erreur', () async {
      // « Hors zone », « trop loin », « panier trop léger » appellent trois
      // gestes différents. Un booléen seul obligerait chaque application à
      // inventer son message.
      final server = _FakeServer()
        ..livrabilite = {
          'is_available': false,
          'reason':
              'Aucun établissement ne dessert cette adresse pour le moment.',
          'restaurant': null,
          'zone': null,
          'distance_m': null,
          'estimated_minutes': null,
          'delivery_fee': null,
          'gross_delivery_fee': null,
          'is_free_delivery': null,
        };

      final reponse = await DeliveryCheckRepository(apiClient: _client(server))
          .check(latitude: 48.85, longitude: 2.35);

      expect(reponse.isAvailable, isFalse);
      expect(reponse.reason, contains('dessert'));
      expect(reponse.restaurant, isNull);
    });

    test('le sous-total déclenche la tarification, et rien sans lui', () async {
      final server = _FakeServer();
      final depot = DeliveryCheckRepository(apiClient: _client(server));

      await depot.check(latitude: 6.135, longitude: 1.23);
      await depot.check(
        latitude: 6.135,
        longitude: 1.23,
        subtotal: const Money(amountMinor: 5000, currency: 'XOF'),
        restaurantSlug: 'el-corazon-lome',
      );

      final sansPanier = server.requests.first.data as Map<String, dynamic>;
      final avecPanier = server.requests.last.data as Map<String, dynamic>;
      expect(sansPanier.containsKey('subtotal'), isFalse);
      expect(avecPanier['subtotal'], {'amount': '5000', 'currency': 'XOF'});
      expect(avecPanier['restaurant'], 'el-corazon-lome');
    });

    test('la distance se lit en mètres puis en kilomètres', () async {
      final reponse = await DeliveryCheckRepository(apiClient: _client(_FakeServer()))
          .check(latitude: 6.135, longitude: 1.23);

      expect(reponse.distanceLabel, '1,9 km');
    });

    test('sans mesure, aucune distance n’est affichée', () {
      // Afficher « 0 km » ferait croire à une proximité qu'on n'a pas établie.
      const reponse = DeliveryAvailability(isAvailable: true);

      expect(reponse.distanceLabel, isNull);
    });
  });

  group('Géocodage inverse', () {
    test('la ville vient des composants, pas du texte de l’adresse', () async {
      // « Rue de Lomé, Cotonou » est à Cotonou. L'extraction par sous-chaîne y
      // trouvait Lomé — le défaut exact de l'implémentation précédente.
      final resultat = await ReverseGeocodeRepository(apiClient: _client(_FakeServer()))
          .lookup(latitude: 6.37, longitude: 2.42);

      expect(resultat.city, 'Cotonou');
      expect(resultat.country, 'Bénin');
      expect(resultat.countryCode, 'BJ');
      expect(resultat.district, 'Ganhi');
    });

    test('la ligne de rue se recompose sans répéter la ville', () async {
      // Un champ « adresse » de formulaire ne doit pas répéter la ville et le
      // pays, qui ont leurs propres champs juste en dessous.
      final resultat = await ReverseGeocodeRepository(apiClient: _client(_FakeServer()))
          .lookup(latitude: 6.37, longitude: 2.42);

      expect(resultat.streetLine, '12 Rue de Lomé');
      expect(resultat.isNamed, isTrue);
    });

    test('une position que personne ne nomme reste une position valide', () {
      // Au large, Google ne rend rien. L'administrateur peut vouloir y poser un
      // point de retrait ; en faire une erreur le lui interdirait.
      const resultat = ReverseGeocodeResult(latitude: 0, longitude: 0);

      expect(resultat.isNamed, isFalse);
      expect(resultat.streetLine, isNull);
    });
  });

  group('Modes de saisie d’une zone', () {
    ManagedGeographyRepository depot(_FakeServer server) =>
        ManagedGeographyRepository(apiClient: _client(server));

    test('un cercle envoie son centre et son rayon, pas un contour', () async {
      // La discrétisation vit **une fois**, côté serveur, et elle est
      // géodésique. Deux écrans qui dessineraient chacun leur cercle
      // produiraient deux zones différentes pour la même saisie.
      final server = _FakeServer();

      await depot(server).createZone(
        cityId: 'c-1',
        name: 'Disque',
        shape: 'circle',
        center: (latitude: 6.1319, longitude: 1.2255),
        radiusMeters: 5000,
        baseFee: const Money(amountMinor: 500, currency: 'XOF'),
        feePerKm: const Money(amountMinor: 100, currency: 'XOF'),
      );

      final corps = server.requests.single.data as Map<String, dynamic>;
      expect(corps['shape'], 'circle');
      expect(corps['center'], {'lat': 6.1319, 'lon': 1.2255});
      expect(corps['radius_meters'], 5000);
      expect(corps.containsKey('boundary'), isFalse);
    });

    test('un polygone envoie ses sommets', () async {
      final server = _FakeServer();

      await depot(server).createZone(
        cityId: 'c-1',
        name: 'Contour tracé',
        polygonCoordinates: const [
          [1.20, 6.10],
          [1.26, 6.10],
          [1.26, 6.16],
        ],
        baseFee: const Money(amountMinor: 500, currency: 'XOF'),
        feePerKm: const Money(amountMinor: 100, currency: 'XOF'),
      );

      final corps = server.requests.single.data as Map<String, dynamic>;
      expect(corps['shape'], 'polygon');
      expect((corps['polygon_coordinates'] as List).length, 3);
    });

    test('un cercle sans rayon est refusé avant l’appel réseau', () {
      // Le serveur refuserait aussi ; le faire ici évite un aller-retour et un
      // message d'erreur qui arrive après la saisie de tout le formulaire.
      expect(
        () => depot(_FakeServer()).createZone(
          cityId: 'c-1',
          name: 'Disque sans rayon',
          shape: 'circle',
          center: (latitude: 6.13, longitude: 1.22),
          baseFee: const Money(amountMinor: 500, currency: 'XOF'),
          feePerKm: const Money(amountMinor: 100, currency: 'XOF'),
        ),
        throwsArgumentError,
      );
    });

    test('un rayon et des sommets ensemble sont refusés', () async {
      // Cette combinaison trahit un écran qui n'a pas nettoyé son état. Laisser
      // passer produirait une zone silencieusement différente de ce que
      // l'administrateur croit avoir dessiné.
      expect(
        () => depot(_FakeServer()).createZone(
          cityId: 'c-1',
          name: 'Ambigu',
          shape: 'circle',
          center: (latitude: 6.13, longitude: 1.22),
          radiusMeters: 4000,
          polygonCoordinates: const [
            [1.2, 6.1],
            [1.3, 6.1],
            [1.3, 6.2],
          ],
          baseFee: const Money(amountMinor: 500, currency: 'XOF'),
          feePerKm: const Money(amountMinor: 100, currency: 'XOF'),
        ),
        throwsArgumentError,
      );
    });

    test('une zone sans aucun contour est refusée', () {
      expect(
        () => depot(_FakeServer()).createZone(
          cityId: 'c-1',
          name: 'Vide',
          baseFee: const Money(amountMinor: 500, currency: 'XOF'),
          feePerKm: const Money(amountMinor: 100, currency: 'XOF'),
        ),
        throwsArgumentError,
      );
    });
  });
}
