import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/services/delivery_zone_service.dart';

/// Le contour d'une zone ouverte depuis le back-office.
///
/// Ouvrir une zone était **impossible** depuis l'interface : le dépôt savait
/// écrire (`ManagedGeographyRepository.createZone`), aucun écran ne l'appelait,
/// et `Restaurant.zone` étant une clé étrangère non nulle, aucun établissement
/// n'était donc créable ailleurs qu'à travers `django-admin`.
///
/// Le contour saisi est un disque approché — le tracé réel viendra de
/// l'exploitation, sur carte, dans le même champ. Deux propriétés le rendent
/// utilisable dès le premier jour, et ce sont elles qui sont gardées ici :
///
/// * **l'anneau est fermé.** PostGIS refuse un contour ouvert, et l'oubli est
///   l'erreur classique du GeoJSON écrit à la main ;
/// * **la longitude est corrigée de la latitude.** Un degré de longitude vaut
///   `cos(latitude)` fois un degré de latitude ; l'ignorer produirait une zone
///   deux fois trop large en longitude sous nos latitudes — c'est-à-dire une
///   zone qui accepte des courses qu'aucun livreur ne peut faire.
void main() {
  /// Distance approchée entre deux points, en kilomètres.
  ///
  /// Recalculée ici plutôt qu'empruntée au service : un test qui réutiliserait
  /// la formule qu'il vérifie ne vérifierait rien.
  double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const rayon = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLon = rad(lon2 - lon1);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * rayon * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  List<List<double>> anneau(Map<String, dynamic> geojson) {
    final coordonnees = geojson['coordinates'] as List<dynamic>;
    final polygone = coordonnees.first as List<dynamic>;
    return (polygone.first as List<dynamic>)
        .map((point) => (point as List<dynamic>).cast<double>())
        .toList();
  }

  group('Contour circulaire', () {
    test('le GeoJSON est un MultiPolygon — la forme que PostGIS attend', () {
      final contour = DeliveryZoneService.disqueGeoJson(
        latitude: 5.36,
        longitude: -4.0083,
        rayonKm: 10,
      );

      // `MultiPolygon` et non `Polygon` : une zone réelle est fréquemment
      // discontinue — un fleuve, une voie ferrée, une enclave non desservie la
      // coupent en plusieurs morceaux —, et le champ doit accepter le tracé
      // définitif sans changer de type.
      expect(contour['type'], 'MultiPolygon');
    });

    test('l’anneau est fermé', () {
      final contour = DeliveryZoneService.disqueGeoJson(
        latitude: 5.36,
        longitude: -4.0083,
        rayonKm: 10,
      );
      final points = anneau(contour);

      expect(points.first, points.last);
    });

    test('les coordonnées sortent en [lon, lat] — l’ordre du GeoJSON', () {
      // L'ordre inverse est l'erreur classique, et elle place les zones dans
      // l'océan : à Abidjan, une longitude de -4 lue comme une latitude
      // désignerait un point au large du Gabon.
      final contour = DeliveryZoneService.disqueGeoJson(
        latitude: 5.36,
        longitude: -4.0083,
        rayonKm: 5,
      );
      final points = anneau(contour);

      for (final point in points) {
        expect(point[0], inInclusiveRange(-4.2, -3.8), reason: 'longitude');
        expect(point[1], inInclusiveRange(5.2, 5.5), reason: 'latitude');
      }
    });

    test('chaque sommet est à peu près à la distance demandée', () {
      const latitude = 5.36;
      const longitude = -4.0083;
      const rayon = 10.0;

      final points = anneau(
        DeliveryZoneService.disqueGeoJson(
          latitude: latitude,
          longitude: longitude,
          rayonKm: rayon,
        ),
      );

      for (final point in points) {
        final distance = distanceKm(latitude, longitude, point[1], point[0]);
        // 3 % de tolérance : la conversion degrés/kilomètres est une
        // approximation sphérique locale, et c'est amplement suffisant pour un
        // contour provisoire dont le plafond kilométrique de la zone tranche
        // les cas limites.
        expect(distance, closeTo(rayon, rayon * 0.03));
      }
    });

    test('la correction de latitude n’est pas oubliée', () {
      // Sans le facteur `cos(latitude)`, l'écart en longitude serait le même
      // partout ; il doit grandir à mesure qu'on s'éloigne de l'équateur.
      double demiLargeur(double latitude) {
        final points = anneau(
          DeliveryZoneService.disqueGeoJson(
            latitude: latitude,
            longitude: 0,
            rayonKm: 10,
          ),
        );
        final longitudes = points.map((p) => p[0]);
        return longitudes.reduce(math.max) - longitudes.reduce(math.min);
      }

      final aLEquateur = demiLargeur(0);
      final sousLesTropiques = demiLargeur(45);

      expect(sousLesTropiques, greaterThan(aLEquateur * 1.3));
    });

    test('un rayon plus grand donne un contour plus large', () {
      double etendue(double rayonKm) {
        final points = anneau(
          DeliveryZoneService.disqueGeoJson(
            latitude: 5.36,
            longitude: -4.0083,
            rayonKm: rayonKm,
          ),
        );
        final latitudes = points.map((p) => p[1]);
        return latitudes.reduce(math.max) - latitudes.reduce(math.min);
      }

      expect(etendue(20), greaterThan(etendue(5)));
    });
  });
}
