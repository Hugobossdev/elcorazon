import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Régimes alimentaires d'un article, tels que l'écran les manipule.
///
/// Le contrat ne porte pas de booléens : il porte `dietary_tags`, **une liste
/// ouverte que l'exploitation enrichit sans migration** (c'est le mot du
/// serveur). Le back-office n'en montre que deux — végétarien, végan — parce
/// que ce sont les deux qui se décident depuis cet écran.
///
/// D'où la précaution de [regimesAvec] : recomposer la liste à partir des seuls
/// booléens de l'écran **effacerait** tous les autres. Un article marqué
/// `halal` perdait son étiquette au premier enregistrement, sans que rien ne
/// le signale — c'est ce que faisait `MenuService._regimes` jusqu'au lot 3.
abstract final class Regimes {
  static const vegetarien = 'vegetarian';
  static const vegan = 'vegan';

  /// Les deux régimes que le back-office donne à cocher.
  static const modifiablesIci = {vegetarien, vegan};

  /// La liste à renvoyer au serveur.
  ///
  /// Elle part de [existants] — ce que le serveur nous a rendu — et n'y touche
  /// que pour les deux régimes de l'écran. Tout le reste passe intact.
  static List<String> regimesAvec(
    List<String> existants, {
    required bool vegetarien,
    required bool vegan,
  }) {
    final regimes = existants.where((t) => !modifiablesIci.contains(t)).toList();
    if (vegetarien) regimes.add(Regimes.vegetarien);
    if (vegan) regimes.add(Regimes.vegan);
    return regimes;
  }
}

extension LectureRegimes on eccore.ManagedMenuItem {
  bool get estVegetarien => dietaryTags.contains(Regimes.vegetarien);
  bool get estVegan => dietaryTags.contains(Regimes.vegan);
}
