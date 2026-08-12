import 'package:flutter/material.dart';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Vocabulaire d'affichage du carnet d'adresses.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Le socle garde `kind` en chaîne brute, comme partout ailleurs : la valeur
/// voyage telle quelle dans le JSON, et un enum imposerait une correspondance
/// à tenir des deux côtés. Ce fichier pose par-dessus ce qu'un écran en
/// montre — un libellé, une pastille, une couleur.
///
/// Il vient de `models/address.dart`, retiré au lot 3.
enum TypeAdresse {
  maison('home', 'Maison', '🏠', Colors.green),
  travail('work', 'Travail', '💼', Colors.blue),
  autre('other', 'Autre', '📍', Colors.orange);

  const TypeAdresse(this.versServeur, this.libelle, this.pastille, this.couleur);

  /// La valeur que le serveur attend et rend (`AddressKind`).
  final String versServeur;

  final String libelle;
  final String pastille;
  final Color couleur;

  /// Depuis la valeur rendue par le serveur.
  ///
  /// Une valeur inconnue devient [autre] : un `kind` ajouté côté serveur ne
  /// doit pas faire échouer la lecture de tout le carnet.
  static TypeAdresse depuisServeur(String kind) {
    for (final type in values) {
      if (type.versServeur == kind) return type;
    }
    return autre;
  }
}

extension AdresseAffichee on eccore.Address {
  /// Le type, dans le vocabulaire de l'écran.
  TypeAdresse get type => TypeAdresse.depuisServeur(kind);

  /// La ville nommée par le serveur, ou [defaut] s'il ne la nomme pas.
  ///
  /// `city` est un identifiant de `City` ; `cityName` est le nom résolu, que
  /// le sérialiseur ne rend pas toujours.
  String villeOu(String defaut) =>
      (cityName == null || cityName!.isEmpty) ? defaut : cityName!;

  /// L'adresse en une ligne, pour une carte ou un récapitulatif.
  ///
  /// Le repère complète la ligne quand il existe : à Lomé, « face à la
  /// pharmacie » situe mieux qu'un numéro de rue.
  String get uneLigne {
    final base = [line1, if (line2.isNotEmpty) line2].join(', ');
    return landmark.isEmpty ? base : '$base ($landmark)';
  }

  /// La forme que le cache local range et relit.
  ///
  /// `toJson` du socle est la forme d'**écriture** : elle omet `id`, les
  /// horodatages et `city_name`, que le serveur seul établit. La relire avec
  /// `fromJson` échouerait sur l'`id` manquant. Le cache a donc besoin de la
  /// forme de **lecture**, celle que le serveur rend.
  Map<String, dynamic> versCache() => {
        ...toJson(),
        'id': id,
        'city_name': cityName,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
        'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      };
}
