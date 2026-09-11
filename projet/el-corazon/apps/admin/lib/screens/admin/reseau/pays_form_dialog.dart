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

  /// Noms lisibles de quelques devises — **de l'habillage, pas une liste
  /// d'autorisation.**
  ///
  /// La liste des devises acceptées vient du serveur
  /// (`GET /geography/reference/`) ; cette table ne fait qu'écrire « Franc CFA
  /// (UEMOA) » à côté de `XOF`. Une devise absente d'ici s'affiche sous son
  /// code seul et reste parfaitement choisissable : c'est ce qui distingue un
  /// libellé d'un plafond.
  static const Map<String, String> _libelles = {
    'XOF': 'Franc CFA (UEMOA)',
    'XAF': 'Franc CFA (CEMAC)',
    'GHS': 'Cedi ghanéen',
    'NGN': 'Naira',
    'GNF': 'Franc guinéen',
    'EUR': 'Euro',
    'USD': 'Dollar américain',
  };

  /// Devise retenue, ou `null` tant que rien n'est choisi.
  ///
  /// **Sans valeur par défaut**, contrairement à l'ancien `XOF` : une devise
  /// pré-choisie se valide sans qu'on l'ait lue, et elle est ensuite figée sur
  /// chaque commande du pays. Le champ vaut la peine d'un geste explicite.
  String? _devise;
  String? _fuseau;
  bool _envoiEnCours = false;

  @override
  void initState() {
    super.initState();
    // Les valeurs disponibles viennent du serveur — celui-là même qui les fera
    // respecter. Chargées ici et non au démarrage : c'est le seul écran qui
    // s'en sert, et six cents fuseaux n'ont pas à voyager pour quelqu'un qui
    // vient regarder ses commandes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NetworkService>().chargerLaReference();
    });
  }

  @override
  void dispose() {
    _nom.dispose();
    _iso.dispose();
    _indicatif.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    final devise = _devise;
    final fuseau = _fuseau;
    if (devise == null || fuseau == null) return;

    setState(() => _envoiEnCours = true);

    final reseau = context.read<NetworkService>();
    final cree = await reseau.createCountry(
      isoCode: _iso.text.trim(),
      name: _nom.text.trim(),
      currency: devise,
      phonePrefix: _indicatif.text.trim(),
      timezone: fuseau,
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
                Consumer<NetworkService>(
                  builder: (context, reseau, _) {
                    final reference = reseau.reference;

                    if (reference.isEmpty) {
                      return const _ReferenceIndisponible();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DeroulantReseau<String>(
                          label: 'Devise',
                          valeur: _devise,
                          entrees: [
                            for (final devise in reference.currencies)
                              (
                                devise.code,
                                _libelles.containsKey(devise.code)
                                    ? '${_libelles[devise.code]} — ${devise.code}'
                                    : devise.code,
                              ),
                          ],
                          aide: 'Figée sur chaque commande passée dans ce pays.',
                          onChanged: (valeur) => setState(() => _devise = valeur),
                        ),
                        const SizedBox(height: 12),
                        _ChampFuseau(
                          fuseaux: reference.timezones,
                          chercher: reference.chercherFuseau,
                          valeur: _fuseau,
                          onChanged: (valeur) => setState(() => _fuseau = valeur),
                        ),
                      ],
                    );
                  },
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
          onPressed: (_envoiEnCours || _devise == null || _fuseau == null)
              ? null
              : _enregistrer,
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


/// Le serveur n'a pas rendu les valeurs disponibles.
///
/// Aucune liste de repli n'est proposée : ce serait réintroduire exactement le
/// hardcoding qu'on retire, et proposer une devise que le serveur pourrait
/// refuser fait échouer le formulaire après sa saisie complète. Mieux vaut dire
/// que rien n'est choisissable pour l'instant.
class _ReferenceIndisponible extends StatelessWidget {
  const _ReferenceIndisponible();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Devises et fuseaux disponibles non chargés. Vérifiez la connexion '
              'au serveur, puis rouvrez ce formulaire.',
              style: TextStyle(fontSize: 12, color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Choix d'un fuseau parmi les six cents identifiants IANA.
///
/// Un champ de recherche et non une liste déroulante : six cents entrées dans
/// un `DropdownButton` se parcourent au pixel près, et c'est précisément la
/// raison pour laquelle la version précédente n'en proposait que dix — un
/// plafond posé pour rendre l'écran utilisable, au prix d'une republication à
/// chaque nouveau marché.
///
/// La recherche ignore la casse et la ponctuation : « porto novo » trouve
/// `Africa/Porto-Novo`. Personne ne tape un identifiant IANA à la lettre près.
class _ChampFuseau extends StatelessWidget {
  const _ChampFuseau({
    required this.fuseaux,
    required this.chercher,
    required this.valeur,
    required this.onChanged,
  });

  final List<String> fuseaux;
  final List<String> Function(String) chercher;
  final String? valeur;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fuseau horaire',
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: valeur ?? ''),
          optionsBuilder: (saisie) {
            // Au-delà de quelques dizaines, la liste flottante devient un mur :
            // on borne l'affichage sans borner la recherche, qui porte bien sur
            // les six cents.
            final trouves = chercher(saisie.text);
            return trouves.length > 40 ? trouves.take(40) : trouves;
          },
          onSelected: onChanged,
          fieldViewBuilder: (context, controller, focusNode, onSubmit) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                hintText: 'Rechercher — par exemple « lome »',
                helperText: "Décide de l'heure d'ouverture des restaurants du pays.",
                helperMaxLines: 2,
              ),
              validator: (saisi) => fuseaux.contains((saisi ?? '').trim())
                  ? null
                  : 'Choisissez un fuseau dans la liste',
            );
          },
        ),
      ],
    );
  }
}
