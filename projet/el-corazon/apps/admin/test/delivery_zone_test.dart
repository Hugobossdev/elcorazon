import 'package:admin/services/delivery_zone_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Barème d'une zone vu du back-office.
///
/// C'est le seul endroit du produit où se décide ce que paiera un client pour
/// être livré. Le **seuil de franco** existait en base et dans l'API depuis
/// l'origine sans qu'aucune interface ne l'expose : une zone qui offrait la
/// livraison au-dessus d'un montant l'offrait jusqu'à ce qu'un développeur
/// passe en base.
///
/// Ces tests gardent la traduction entre ce que rend le serveur et ce
/// qu'affiche l'écran — et surtout la distinction entre « pas de seuil » et
/// « seuil à zéro », qui n'est pas la même offre commerciale.
void main() {
  eccore.Money xof(int montant) =>
      eccore.Money(amountMinor: montant, currency: 'XOF');

  eccore.DeliveryZone distante({
    eccore.Money? franco,
    eccore.Money? minimum,
    String devise = 'XOF',
    Map<String, dynamic>? contour,
    String cityId = 'city-lome',
  }) {
    return eccore.DeliveryZone(
      id: 'zone-centre',
      cityId: cityId,
      name: 'Centre-ville',
      boundary: contour,
      baseFee: eccore.Money(amountMinor: 600, currency: devise),
      feePerKm: eccore.Money(amountMinor: 150, currency: devise),
      freeDeliveryThreshold: franco,
      minOrderAmount: minimum,
      maxDistanceKm: 12,
      estimatedDeliveryMinutes: 35,
      isActive: true,
    );
  }

  group('Traduction du barème', () {
    test('le seuil de franco remonte jusqu’à l’écran', () {
      final zone = DeliveryZone.fromRemote(distante(franco: xof(12000)));

      expect(zone.freeDeliveryThreshold, 12000);
      expect(zone.hasFreeDelivery, isTrue);
    });

    test('« pas de seuil » n’est pas « seuil à zéro »', () {
      // Sans seuil, la livraison n'est jamais offerte. À zéro, elle l'est
      // toujours. Les confondre en un `double` par défaut ferait travailler
      // les livreurs gratuitement — ou l'inverse.
      final sansSeuil = DeliveryZone.fromRemote(distante());
      final seuilNul = DeliveryZone.fromRemote(distante(franco: xof(0)));

      expect(sansSeuil.freeDeliveryThreshold, isNull);
      expect(sansSeuil.hasFreeDelivery, isFalse);
      expect(seuilNul.freeDeliveryThreshold, 0);
      expect(seuilNul.hasFreeDelivery, isTrue);
    });

    test('le forfait, le tarif au kilomètre et le minimum sont exposés', () {
      final zone = DeliveryZone.fromRemote(distante(minimum: xof(2000)));

      expect(zone.deliveryFee, 600);
      expect(zone.feePerKm, 150);
      expect(zone.minOrderAmount, 2000);
      expect(zone.estimatedTimeMinutes, 35);
    });

    test('la devise est héritée du barème, pas écrite en dur', () {
      // Elle vient du pays (ADR-006). L'écran s'en sert pour convertir une
      // saisie : la supposer en francs CFA écrirait des centimes d'euro comme
      // s'il s'agissait d'euros entiers.
      expect(DeliveryZone.fromRemote(distante()).currency, 'XOF');
      expect(DeliveryZone.fromRemote(distante(devise: 'EUR')).currency, 'EUR');
    });
  });

  group('Contour affiché sur la carte', () {
    test('les coordonnées GeoJSON sont remises dans l’ordre des cartes', () {
      // Le GeoJSON est en [lon, lat] ; les cartes attendent l'inverse. Ne pas
      // convertir place les zones dans le golfe de Guinée.
      final zone = DeliveryZone.fromRemote(
        distante(
          contour: {
            'type': 'Polygon',
            'coordinates': [
              [
                [1.2255, 6.1319],
                [1.2300, 6.1400],
                [1.2255, 6.1319],
              ],
            ],
          },
        ),
      );

      expect(zone.polygon.first, {'latitude': 6.1319, 'longitude': 1.2255});
    });

    test('une zone sans contour ne fait pas planter l’écran', () {
      expect(DeliveryZone.fromRemote(distante()).polygon, isEmpty);
    });
  });

  group('Saisie du back-office vers le serveur', () {
    test('un seuil saisi en francs CFA part sans conversion', () {
      expect(eccore.Money.fromMajorUnits(12000, 'XOF').amountMinor, 12000);
    });

    test('un seuil saisi en euros part en centimes', () {
      expect(eccore.Money.fromMajorUnits(120.50, 'EUR').amountMinor, 12050);
    });
  });

  // ------------------------------------------------------------- sélection

  DeliveryZone locale(String id, String nom, String cityId, {bool active = true}) {
    return DeliveryZone(
      id: id,
      cityId: cityId,
      name: nom,
      polygon: const [],
      deliveryFee: 600,
      feePerKm: 150,
      estimatedTimeMinutes: 30,
      isActive: active,
      currency: 'XOF',
    );
  }

  const villes = {'city-lome': 'Lomé', 'city-kara': 'Kara'};

  final couverture = [
    locale('z-tokoin', 'Tokoin', 'city-lome'),
    locale('z-be', 'Bè', 'city-lome', active: false),
    locale('z-kara-centre', 'Centre', 'city-kara'),
  ];

  group('Regroupement par ville', () {
    test('chaque zone tombe sous le nom de sa ville', () {
      final groupes = DeliveryZoneService.groupByCity(couverture, villes);

      expect(groupes.keys, ['Kara', 'Lomé']);
      expect(groupes['Lomé']!.map((zone) => zone.name), ['Bè', 'Tokoin']);
      expect(groupes['Kara']!.single.name, 'Centre');
    });

    test('les villes sont ordonnées et les zones triées en leur sein', () {
      // L'ordre de la réponse serveur n'est pas celui qu'on veut afficher :
      // sans tri, la liste changerait de disposition d'un rechargement à
      // l'autre, sous les doigts de l'exploitant.
      final groupes = DeliveryZoneService.groupByCity(
        couverture.reversed.toList(),
        villes,
      );

      expect(groupes.keys, ['Kara', 'Lomé']);
      expect(groupes['Lomé']!.map((zone) => zone.name), ['Bè', 'Tokoin']);
    });

    test('les zones fermées restent dans la liste', () {
      // Les masquer supprimerait le seul endroit d'où on peut les rouvrir.
      final groupes = DeliveryZoneService.groupByCity(couverture, villes);

      expect(groupes['Lomé']!.where((zone) => !zone.isActive), hasLength(1));
    });

    test('une ville dont le nom manque ne fait pas disparaître ses zones', () {
      // La liste des villes peut avoir échoué — elle ne sert qu'à nommer. La
      // zone doit rester sélectionnable, sous un intitulé neutre plutôt que
      // sous un UUID.
      final groupes = DeliveryZoneService.groupByCity(
        [locale('z-orpheline', 'Zone', 'city-inconnue')],
        const {},
      );

      expect(groupes.keys.single, 'Ville non rattachée');
      expect(groupes.values.single, hasLength(1));
    });
  });

  group('Recherche dans la sélection', () {
    Map<String, List<DeliveryZone>> chercher(String requete) =>
        DeliveryZoneService.filterGroups(
          DeliveryZoneService.groupByCity(couverture, villes),
          requete,
        );

    test('une requête vide rend tout', () {
      expect(chercher('   ').keys, ['Kara', 'Lomé']);
    });

    test('le nom d’une zone la retient, seule', () {
      final trouve = chercher('tokoin');

      expect(trouve.keys.single, 'Lomé');
      expect(trouve['Lomé']!.single.name, 'Tokoin');
    });

    test('le nom d’une ville retient toutes ses zones', () {
      // Chercher « Kara » désigne la ville : ne rendre que les zones dont le
      // nom contient « Kara » rendrait une liste vide alors que la ville est
      // précisément ce qu'on a trouvé.
      final trouve = chercher('lomé');

      expect(trouve.keys.single, 'Lomé');
      expect(trouve['Lomé'], hasLength(2));
    });

    test('la recherche ignore la casse', () {
      expect(chercher('TOKOIN')['Lomé']!.single.name, 'Tokoin');
    });

    test('une requête sans correspondance ne rend rien', () {
      expect(chercher('sokodé'), isEmpty);
    });
  });
}
