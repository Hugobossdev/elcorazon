import 'package:elcora_fast/services/customization_service.dart';

/// Les mots d'un gâteau du catalogue et ce qu'ils désignent dans les options.
///
/// La clé est ce qu'on cherche dans le nom et la description du gâteau ; la
/// valeur est ce qu'on cherche dans l'identifiant de l'option
/// (`cake-flavor-chocolate`, `cake-shape-heart`…).
const motsDesGateaux = <String, String>{
  'chocolat': 'chocolate',
  'vanille': 'vanilla',
  'fraise': 'strawberry',
  'rond': 'round',
  'carré': 'square',
  'coeur': 'heart',
  'cœur': 'heart',
  'rectangle': 'rectangle',
  'petit': 'small',
  'moyen': 'medium',
  'grand': 'large',
};

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
/// Deux chemins mènent à une correspondance, et le premier gagne :
///
/// 1. le nom de l'option apparaît tel quel dans le texte du gâteau ;
/// 2. un mot de [motsDesGateaux] apparaît dans le texte **et** sa traduction
///    apparaît dans l'identifiant de l'option.
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
  if (nom.isNotEmpty && texte.contains(nom)) return true;

  final identifiant = option.id.toLowerCase();

  for (final entree in motsDesGateaux.entries) {
    if (texte.contains(entree.key) && identifiant.contains(entree.value)) {
      return true;
    }
  }

  return false;
}
