import 'package:elcorazon_core/src/directions/geo_point.dart';

/// La forme qu'on **envoie** pour une zone de livraison : un cercle, ou un
/// polygone tracé à la main.
///
/// Une seule entrée pour l'éditeur cartographique, quelle que soit la route —
/// zone de ville (`/geography/manage/zones/`) ou zone propre à une cuisine
/// (`/restaurants/manage/zones/`). Le serveur construit le contour, le ferme,
/// et refuse ce qui ne tient pas : sommets hors du globe, contour qui se
/// croise, surface démesurée. Rien de cela n'est rejoué ici — l'écran montre
/// le refus du serveur tel quel.
sealed class FormeDeZone {
  const FormeDeZone();

  /// Les champs du corps de requête que cette forme remplit.
  Map<String, dynamic> versJson();
}

/// Un disque : un centre et un rayon en mètres.
final class ZoneCirculaire extends FormeDeZone {
  const ZoneCirculaire({required this.centre, required this.rayonMetres});

  final GeoPoint centre;
  final int rayonMetres;

  @override
  Map<String, dynamic> versJson() => {
        'shape': 'circle',
        'center': {'lat': centre.latitude, 'lon': centre.longitude},
        'radius_meters': rayonMetres,
      };
}

/// Un contour tracé : les sommets dans l'ordre du tracé, **sans** répéter le
/// premier — le serveur ferme l'anneau.
final class ZonePolygonale extends FormeDeZone {
  const ZonePolygonale(this.sommets);

  final List<GeoPoint> sommets;

  /// Au moins trois sommets pour qu'il y ait une surface. Le serveur le
  /// vérifie aussi ; l'éditeur s'en sert pour griser « Enregistrer ».
  bool get estFerme => sommets.length >= 3;

  /// `[[longitude, latitude], …]` : l'ordre GeoJSON que le serveur attend,
  /// l'inverse de l'ordre parlé. C'est la conversion qui, faite à l'envers,
  /// place une zone de Lomé au large de la Somalie.
  @override
  Map<String, dynamic> versJson() => {
        'shape': 'polygon',
        'polygon_coordinates': [
          for (final point in sommets) [point.longitude, point.latitude],
        ],
      };
}
