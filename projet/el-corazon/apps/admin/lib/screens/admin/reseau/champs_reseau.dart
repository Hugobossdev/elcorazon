import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Champs partagés des formulaires du réseau.
///
/// Les trois formulaires — pays, ville, établissement — posent ensemble neuf
/// listes déroulantes et trois codes à mettre en majuscules. Sans ce fichier,
/// le même `DropdownButtonFormField` habillé à la main serait recopié neuf
/// fois, et divergerait au premier ajustement de style : c'est exactement la
/// dérive que le back-office a déjà connue sur ses cartes de statistiques.

/// Liste déroulante étiquetée, dans le style des champs de saisie du
/// back-office ([CustomTextField]).
class DeroulantReseau<T> extends StatelessWidget {
  const DeroulantReseau({
    required this.label,
    required this.valeur,
    required this.entrees,
    required this.onChanged,
    this.aide,
    super.key,
  });

  final String label;

  /// Valeur courante. `null` affiche l'invite plutôt qu'un choix par défaut :
  /// une ville pré-choisie au hasard se valide sans qu'on l'ait lue.
  final T? valeur;

  /// Couples `(valeur, intitulé)`, dans l'ordre d'affichage.
  final List<(T, String)> entrees;

  final ValueChanged<T> onChanged;

  /// Phrase sous le champ — ce que ce choix engage, quand ce n'est pas
  /// évident.
  final String? aide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: valeur,
          isExpanded: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            hintText: entrees.isEmpty ? 'Aucun choix disponible' : 'Choisir…',
            helperText: aide,
            helperMaxLines: 3,
          ),
          items: [
            for (final (cle, intitule) in entrees)
              DropdownMenuItem<T>(value: cle, child: Text(intitule)),
          ],
          onChanged: entrees.isEmpty
              ? null
              : (choisi) {
                  if (choisi != null) onChanged(choisi);
                },
        ),
      ],
    );
  }
}

/// Met en majuscules à la frappe — pour les codes ISO.
///
/// Le serveur accepte `ci` et le range en `CI` ; l'écran afficherait alors une
/// valeur différente de celle qu'on vient de saisir. Normaliser à la frappe
/// évite ce décalage sans rien interdire.
class MajusculesFormatter extends TextInputFormatter {
  const MajusculesFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue ancien, TextEditingValue nouveau) {
    return TextEditingValue(
      text: nouveau.text.toUpperCase(),
      selection: nouveau.selection,
    );
  }
}

/// Fabrique un identifiant d'URL à partir d'un intitulé.
///
/// Le serveur exige un `SlugField` et ne le dérive pas du nom : le laisser à la
/// saisie libre produit des identifiants incohérents d'un établissement à
/// l'autre (`ElCorazon_Abidjan`, `abidjan-2`), qui voyagent ensuite dans les
/// URL de trois applications. La proposition est modifiable — un slug pris se
/// corrige à la main — mais elle est juste par défaut.
///
/// Les diacritiques sont retirés par correspondance explicite plutôt que par
/// une normalisation Unicode : Dart n'expose pas de forme NFD dans sa
/// bibliothèque standard, et les quelques lettres concernées ici sont connues.
String slugifier(String intitule) {
  const accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
    'ç': 'c',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ñ': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ý': 'y', 'ÿ': 'y',
  };

  final sansAccent = intitule.toLowerCase().split('').map((c) => accents[c] ?? c).join();

  return sansAccent
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
