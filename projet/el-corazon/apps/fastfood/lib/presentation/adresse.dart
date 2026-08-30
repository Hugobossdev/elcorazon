import 'package:flutter/material.dart';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/theme.dart';

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
  maison(
    'home',
    'Maison',
    '🏠',
    Icons.home_rounded,
    AppColors.secondaryContainer,
    AppColors.secondaryDeep,
  ),
  travail(
    'work',
    'Travail',
    '💼',
    Icons.work_outline_rounded,
    AppColors.tertiaryLight,
    AppColors.tertiary,
  ),
  autre(
    'other',
    'Autre',
    '📍',
    Icons.place_outlined,
    AppColors.surfaceContainerHigh,
    AppColors.textSecondary,
  );

  const TypeAdresse(
    this.versServeur,
    this.libelle,
    this.pastille,
    this.icone,
    this.fond,
    this.encre,
  );

  /// La valeur que le serveur attend et rend (`AddressKind`).
  final String versServeur;

  final String libelle;
  final String pastille;

  /// L'icône du type, que la maquette `address_management` place en tête de
  /// chaque carte. Elle vivait auparavant dans un `switch` de
  /// `widgets/address_card.dart` — c'est-à-dire à côté du reste du vocabulaire
  /// du type, mais pas avec lui.
  final IconData icone;

  /// Fond et encre de la pastille du type.
  ///
  /// ## Pourquoi ce ne sont plus `Colors.green`, `blue` et `orange`
  ///
  /// Ces trois couleurs de Material n'appartiennent à aucun jeton du design
  /// system, et ce fichier est lu par les **quatre** écrans d'adresse : une
  /// couleur fausse ici se répandait partout. Elles suivent maintenant la
  /// palette — doré pour la maison, orange de la tertiaire pour le travail,
  /// neutre pour le reste.
  ///
  /// Ce sont des constantes d'`AppColors` plutôt que des rôles de thème :
  /// un constructeur d'énumération doit être `const`, et n'a donc pas de
  /// `BuildContext` sous la main. Les deux jeux se correspondent — les rôles
  /// du thème clair **sont** ces valeurs.
  final Color fond;
  final Color encre;

  /// Compatibilité : l'ancienne couleur unique, désormais celle de l'encre.
  Color get couleur => encre;

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
