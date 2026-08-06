import 'delivery_zone.dart';

/// Réponse de `GET /geography/zones/resolve/` — miroir de
/// `ZoneResolutionSerializer`.
///
/// « Je ne suis pas desservi » est une réponse, pas une erreur : le serveur
/// rend `200` avec [isCovered] à faux plutôt qu'un `404`, et l'application
/// affiche la carte sans traiter le cas nominal « je viens d'emménager hors
/// zone » dans une branche d'exception.
///
/// [zone] porte le barème réellement appliqué à ce point. C'est la seule
/// source d'un frais de livraison côté client : l'implémentation précédente
/// portait le sien en constantes (`500` de base, `200`/km, franco à `10 000`),
/// que personne ne pouvait changer sans republier les applications — et qui ne
/// correspondaient à rien de ce que le serveur facturait vraiment.
class ZoneResolution {
  const ZoneResolution({required this.isCovered, this.zone});

  factory ZoneResolution.fromJson(Map<String, dynamic> json) {
    final zone = json['zone'] as Map<String, dynamic>?;
    return ZoneResolution(
      // Redondant avec `zone != null`, et délibérément : c'est le booléen que
      // le serveur tranche, et il reste juste si la réponse gagne un jour un
      // cas « couvert mais momentanément suspendu ».
      isCovered: json['is_covered'] as bool? ?? false,
      zone: zone == null ? null : DeliveryZone.fromJson(zone),
    );
  }

  final bool isCovered;
  final DeliveryZone? zone;
}
