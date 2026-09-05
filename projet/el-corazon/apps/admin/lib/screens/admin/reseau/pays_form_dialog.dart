import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/screens/admin/reseau/champs_reseau.dart';
import 'package:admin/services/network_service.dart';
import 'package:admin/widgets/custom_button.dart';
import 'package:admin/widgets/custom_text_field.dart';

/// Ouverture d'un marché.
///
/// C'est le seul écran du produit où se décide une **devise** et un **fuseau**,
/// et il faut savoir ce que cela engage : la devise est figée sur chaque
/// commande passée dans ce pays (ADR-007), si bien que la changer plus tard ne
/// convertit rien rétroactivement — le catalogue et l'historique se
/// retrouveraient dans deux unités. Le fuseau, lui, décide de l'heure à
/// laquelle les restaurants du pays ouvrent : une faute ici ferme un
/// établissement une heure trop tôt, tous les jours, sans que rien ne le
/// signale.
///
/// Les deux se saisissent donc à l'ouverture et nulle part ailleurs — le dépôt
/// n'expose d'ailleurs pas la devise en modification, pour la même raison.
class PaysFormDialog extends StatefulWidget {
  const PaysFormDialog({super.key});

  /// Ouvre le formulaire et rend `true` si le pays a été ouvert.
  static Future<bool> show(BuildContext context) async {
    final ouvert = await showDialog<bool>(
      context: context,
      builder: (_) => const PaysFormDialog(),
    );
    return ouvert ?? false;
  }

  @override
  State<PaysFormDialog> createState() => _PaysFormDialogState();
}

class _PaysFormDialogState extends State<PaysFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _iso = TextEditingController();
  final _indicatif = TextEditingController();

  /// Devises et fuseaux de la sous-région, plutôt qu'un champ libre.
  ///
  /// Listes courtes et fermées à dessein : `XOF` tapé `XAF` est une faute
  /// qu'aucun écran ne rattrape ensuite, et un fuseau mal orthographié
  /// (`Africa/Lomé`, avec l'accent) n'est refusé qu'à l'enregistrement. Un
  /// champ libre serait plus général et strictement plus fragile.
  static const Map<String, String> _devises = {
    'XOF': 'Franc CFA (UEMOA) — XOF',
    'XAF': 'Franc CFA (CEMAC) — XAF',
    'GHS': 'Cedi ghanéen — GHS',
    'NGN': 'Naira — NGN',
    'EUR': 'Euro — EUR',
    'USD': 'Dollar américain — USD',
  };

  static const List<String> _fuseaux = [
    'Africa/Abidjan',
    'Africa/Lome',
    'Africa/Accra',
    'Africa/Porto-Novo',
    'Africa/Ouagadougou',
    'Africa/Bamako',
    'Africa/Dakar',
    'Africa/Niamey',
    'Africa/Lagos',
    'Africa/Douala',
    'UTC',
  ];

  String _devise = 'XOF';
  String _fuseau = 'Africa/Abidjan';
  bool _envoiEnCours = false;

  @override
  void dispose() {
    _nom.dispose();
    _iso.dispose();
    _indicatif.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _envoiEnCours = true);

    final reseau = context.read<NetworkService>();
    final cree = await reseau.createCountry(
      isoCode: _iso.text.trim(),
      name: _nom.text.trim(),
      currency: _devise,
      phonePrefix: _indicatif.text.trim(),
      timezone: _fuseau,
    );

    if (!mounted) return;
    setState(() => _envoiEnCours = false);

    if (cree == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reseau.error ?? "Le pays n'a pas pu être ouvert."),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Ouvrir un marché'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomTextField(
                  label: 'Nom du pays',
                  hint: "Côte d'Ivoire",
                  controller: _nom,
                  validator: (valeur) =>
                      (valeur == null || valeur.trim().isEmpty) ? 'Nom obligatoire' : null,
                ),
                const SizedBox(height: 12),
                _ChampIso(controller: _iso),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Indicatif téléphonique',
                  hint: '+225',
                  controller: _indicatif,
                  keyboardType: TextInputType.phone,
                  validator: (valeur) => RegExp(r'^\+\d{1,4}$').hasMatch((valeur ?? '').trim())
                      ? null
                      : 'Format attendu : +225',
                ),
                const SizedBox(height: 16),
                DeroulantReseau<String>(
                  label: 'Devise',
                  valeur: _devise,
                  entrees: [
                    for (final entree in _devises.entries) (entree.key, entree.value),
                  ],
                  onChanged: (valeur) => setState(() => _devise = valeur),
                ),
                const SizedBox(height: 12),
                DeroulantReseau<String>(
                  label: 'Fuseau horaire',
                  valeur: _fuseau,
                  entrees: [for (final fuseau in _fuseaux) (fuseau, fuseau)],
                  onChanged: (valeur) => setState(() => _fuseau = valeur),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'La devise est figée sur chaque commande passée dans ce '
                          'pays : la changer plus tard ne convertit rien. Le fuseau '
                          "décide de l'heure d'ouverture de ses restaurants.",
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _envoiEnCours ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        CustomButton(
          text: 'Ouvrir le marché',
          isLoading: _envoiEnCours,
          onPressed: _envoiEnCours ? null : _enregistrer,
          width: 170,
        ),
      ],
    );
  }
}

/// Code ISO, mis en majuscules à la frappe.
///
/// [CustomTextField] n'expose pas `inputFormatters` ; plutôt que d'élargir un
/// widget partagé par tout le back-office pour un seul appelant, ce champ-ci
/// est posé directement — c'est le seul du produit qui en a besoin.
class _ChampIso extends StatelessWidget {
  const _ChampIso({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Code ISO (2 lettres)',
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLength: 2,
          inputFormatters: const [MajusculesFormatter()],
          decoration: const InputDecoration(
            hintText: 'CI',
            counterText: '',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          validator: (valeur) {
            final code = (valeur ?? '').trim();
            if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
              return 'Deux lettres, par exemple CI ou TG';
            }
            return null;
          },
        ),
      ],
    );
  }
}
