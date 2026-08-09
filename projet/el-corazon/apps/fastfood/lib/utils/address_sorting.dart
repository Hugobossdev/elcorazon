import 'package:elcora_fast/models/address.dart';

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
List<Address> sortAddressesForDisplay(
  List<Address> addresses, {
  required AddressSortType sortType,
  double Function(Address address)? distanceFrom,
}) {
  int byCriterion(Address a, Address b) {
    switch (sortType) {
      case AddressSortType.name:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case AddressSortType.distance:
        if (distanceFrom == null) return 0;
        return distanceFrom(a).compareTo(distanceFrom(b));
      case AddressSortType.recent:
        return b.updatedAt.compareTo(a.updatedAt);
      case AddressSortType.type:
        return a.type.index.compareTo(b.type.index);
    }
  }

  final sorted = [...addresses];
  sorted.sort((a, b) {
    if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
    if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
    final criterion = byCriterion(a, b);
    return criterion != 0 ? criterion : a.id.compareTo(b.id);
  });
  return sorted;
}
