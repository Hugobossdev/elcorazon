import 'package:elcora_fast/services/customization_service.dart';

/// Les options qu'un gâteau tout fait suggère pour une composition sur mesure.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Quand un client part d'un « Fraisier rond » pour composer son propre
/// gâteau, l'écran pré-coche ce qu'il devine. Cette devinette vivait dans une
/// méthode de `cake_order_screen.dart` (2 886 lignes) qui, du même geste,
/// lisait le service, décidait des correspondances, écrivait les sélections et
/// affichait un bandeau. Rien ne pouvait l'interroger.
///
/// Ne reste ici que la question à laquelle on peut répondre sans rien
/// modifier : **de quel texte découlent quelles options ?** L'application des
/// sélections, elle, dépend des contraintes de catégorie et reste à l'écran.
///
/// Une seule correspondance subsiste : **le nom de l'option apparaît dans le
/// texte du gâteau**. Elle porte sur des libellés que l'exploitation a saisis,
/// des deux côtés, et ne fait que pré-cocher des options que le catalogue a
/// déjà fournies.
///
/// Un second chemin cherchait un mot français dans le texte et sa traduction
/// anglaise dans l'**identifiant** de l'option — « chocolat » et
/// `cake-flavor-chocolate`. Il ne pouvait fonctionner que sur les identifiants
/// des options de démonstration : ceux du catalogue sont des UUID, où
/// « chocolate » n'apparaît jamais. Il est parti avec elles.
List<CustomizationOption> optionsSuggereesPar(
  String texteDuGateau,
  List<CustomizationOption> options,
) {
  final texte = texteDuGateau.toLowerCase();

  return options.where((option) => _correspond(texte, option)).toList();
}

bool _correspond(String texte, CustomizationOption option) {
  final nom = option.name.toLowerCase();

  // Un nom vide serait contenu dans n'importe quoi et cocherait tout.
  return nom.isNotEmpty && texte.contains(nom);
}
