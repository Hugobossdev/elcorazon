import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/presentation/adresse.dart';

/// Critère de tri du carnet d'adresses.
enum AddressSortType {
  name,
  distance,
  recent,
  type,
}

/// Ordonne le carnet pour l'affichage.
///
/// L'ordre s'obtenait par trois `sort` successifs — le critère choisi, puis
/// les favoris, puis l'adresse par défaut. `List.sort` n'étant **pas stable**
/// en Dart, chaque passe défaisait l'ordre de la précédente : trier par nom
/// avec un seul favori dans la liste suffisait à rendre le reste aléatoire.
///
/// Les priorités sont ici exprimées dans un comparateur unique, où elles
/// s'appliquent dans l'ordre annoncé : l'adresse par défaut, les favoris, puis
/// le critère demandé. Le départage final par identifiant garantit qu'un même
/// carnet s'affiche toujours dans le même ordre d'un rebuild à l'autre.
///
/// [distanceFrom] rend la distance à une adresse, ou `null` si la position de
/// l'appareil est inconnue — auquel cas le tri par distance ne réordonne rien
/// plutôt que de prétendre le faire.
///
/// [isFavorite] est passé plutôt que lu sur l'adresse : le favori est une
/// préférence d'appareil, que `AddressService` détient. L'entité du socle ne
/// le porte pas, et n'a pas à le porter.
List<eccore.Address> sortAddressesForDisplay(
  List<eccore.Address> addresses, {
  required AddressSortType sortType,
  double Function(eccore.Address address)? distanceFrom,
  bool Function(eccore.Address address)? isFavorite,
}) {
  bool favorite(eccore.Address a) => isFavorite?.call(a) ?? false;

  int byCriterion(eccore.Address a, eccore.Address b) {
    switch (sortType) {
      case AddressSortType.name:
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      case AddressSortType.distance:
        if (distanceFrom == null) return 0;
        return distanceFrom(a).compareTo(distanceFrom(b));
      case AddressSortType.recent:
        // Une adresse jamais synchronisée n'a pas d'horodatage ; elle passe
        // après celles qui en ont plutôt que de faire tomber le tri.
        final gauche = a.updatedAt;
        final droite = b.updatedAt;
        if (gauche == null && droite == null) return 0;
        if (gauche == null) return 1;
        if (droite == null) return -1;
        return droite.compareTo(gauche);
      case AddressSortType.type:
        return a.type.index.compareTo(b.type.index);
    }
  }

  final sorted = [...addresses];
  sorted.sort((a, b) {
    if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
    if (favorite(a) != favorite(b)) return favorite(a) ? -1 : 1;
    final criterion = byCriterion(a, b);
    return criterion != 0 ? criterion : (a.id ?? '').compareTo(b.id ?? '');
  });
  return sorted;
}
