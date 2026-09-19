import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Sur quoi travaille un compte du personnel : des marchés, des villes, des
/// établissements.
///
/// Les trois s'additionnent côté serveur. Un pays couvre toutes ses villes, une
/// ville tous ses établissements — **y compris ceux ouverts après la
/// nomination**, et c'est ce qui les distingue d'un rattachement établissement
/// par établissement, qui cesse silencieusement de suivre le réseau.
///
/// Ce type ne tranche rien : le serveur refuse (403) ce que le compte connecté
/// ne couvre pas lui-même. Il sert à montrer ce que chaque case accorde déjà,
/// pour qu'on ne coche pas trois fois la même cuisine.
class PerimetreDuCompte {
  const PerimetreDuCompte({
    this.pays = const {},
    this.villes = const {},
    this.etablissements = const {},
  });

  factory PerimetreDuCompte.du(eccore.StaffMember membre) => PerimetreDuCompte(
        pays: {for (final code in membre.countryCodes) code.toUpperCase()},
        villes: {...membre.citySlugs},
        etablissements: {...membre.restaurantSlugs},
      );

  /// Codes ISO, en capitales — le serveur les rend ainsi.
  final Set<String> pays;
  final Set<String> villes;
  final Set<String> etablissements;

  bool get estVide => pays.isEmpty && villes.isEmpty && etablissements.isEmpty;

  PerimetreDuCompte basculerPays(String iso) =>
      _copie(pays: _bascule(pays, iso.toUpperCase()));

  PerimetreDuCompte basculerVille(String slug) => _copie(villes: _bascule(villes, slug));

  PerimetreDuCompte basculerEtablissement(String slug) =>
      _copie(etablissements: _bascule(etablissements, slug));

  /// Le marché qui couvre déjà cette ville, ou `null`.
  String? couvertureDeVille(eccore.ManagedCity ville) {
    final iso = ville.countryIsoCode.toUpperCase();
    return pays.contains(iso) ? iso : null;
  }

  /// Ce qui couvre déjà cet établissement — sa ville ou son pays — ou `null`.
  ///
  /// La ville d'abord : c'est la réponse la plus précise, et celle qu'on
  /// décoche si l'on veut restreindre.
  String? couvertureDEtablissement(eccore.ManagedRestaurant etablissement) {
    if (villes.contains(etablissement.citySlug)) return etablissement.cityName;
    final iso = etablissement.countryIsoCode.toUpperCase();
    return pays.contains(iso) ? iso : null;
  }

  PerimetreDuCompte _copie({
    Set<String>? pays,
    Set<String>? villes,
    Set<String>? etablissements,
  }) =>
      PerimetreDuCompte(
        pays: pays ?? this.pays,
        villes: villes ?? this.villes,
        etablissements: etablissements ?? this.etablissements,
      );

  static Set<String> _bascule(Set<String> ensemble, String valeur) =>
      ensemble.contains(valeur) ? ({...ensemble}..remove(valeur)) : {...ensemble, valeur};
}

/// Ce que la liste du personnel affiche sous chaque compte.
///
/// Un compte rattaché à rien **ne voit rien** : le serveur ne confond jamais
/// l'absence de rattachement avec l'enseigne entière. La ligne le dit, parce
/// que c'est exactement l'oubli qui fait ouvrir un poste de cuisine vide.
///
/// Les noms sont résolus quand on les connaît, sinon on affiche la clé : un
/// compte peut être rattaché à un établissement que le lecteur ne voit pas.
String resumeDuPerimetre(
  eccore.StaffMember membre, {
  String Function(String iso)? nomDuPays,
  String Function(String slug)? nomDeVille,
  String Function(String slug)? nomDEtablissement,
}) {
  if (membre.isSuperuser) return 'Siège — voit tout le réseau';
  if (membre.sansPerimetre) return 'Rattaché à aucun établissement — ne voit rien';

  final morceaux = <String>[
    for (final iso in membre.countryCodes) 'Marché ${nomDuPays?.call(iso) ?? iso}',
    for (final slug in membre.citySlugs) nomDeVille?.call(slug) ?? slug,
  ];

  final etablissements = [
    for (final slug in membre.restaurantSlugs) nomDEtablissement?.call(slug) ?? slug,
  ];
  // Au-delà de deux, le nombre dit mieux que la liste : la ligne doit tenir
  // sous le nom du compte.
  if (etablissements.length > 2) {
    morceaux.add('${etablissements.length} établissements');
  } else {
    morceaux.addAll(etablissements);
  }

  return morceaux.join(' · ');
}
