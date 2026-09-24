import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/screens/admin/reseau/champs_reseau.dart';
import 'package:admin/screens/admin/reseau/selecteur_de_lieu.dart';
import 'package:admin/services/network_service.dart';
import 'package:admin/widgets/custom_button.dart';
import 'package:admin/widgets/custom_text_field.dart';

/// Ouverture d'une ville dans un pays.
///
/// Le pays est **choisi dans une liste** et non saisi, ce qui rend impossible
/// la combinaison que redoute l'exploitation — « pays Togo, ville Abidjan ».
/// Ce n'est pas une garde d'écran : une ville n'a qu'une seule clé de
/// rattachement côté serveur (`City.country`), si bien que la contradiction
/// n'est pas rejetée, elle est *inexprimable*. L'écran ne fait que refléter
/// cette propriété du schéma.
///
/// Le centroïde centre une carte et trie des résultats par proximité. Il ne
/// décide **jamais** d'une livrabilité : c'est le contour de la zone qui le
/// fait, et les confondre reviendrait à livrer par rayon autour d'un point
/// arbitraire.
class VilleFormDialog extends StatefulWidget {
  const VilleFormDialog({this.paysPreselectionne, super.key});

  /// Code ISO du pays déjà choisi — depuis l'onglet d'un pays, il n'y a pas de
  /// raison de le redemander.
  final String? paysPreselectionne;

  static Future<bool> show(BuildContext context, {String? paysPreselectionne}) async {
    final ouvert = await showDialog<bool>(
      context: context,
      builder: (_) => VilleFormDialog(paysPreselectionne: paysPreselectionne),
    );
    return ouvert ?? false;
  }

  @override
  State<VilleFormDialog> createState() => _VilleFormDialogState();
}

class _VilleFormDialogState extends State<VilleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _slug = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();

  String? _paysIso;
  bool _slugTouche = false;
  bool _envoiEnCours = false;

  @override
  void initState() {
    super.initState();
    _paysIso = widget.paysPreselectionne;
    // Le slug suit le nom tant que personne ne l'a corrigé à la main. Le
    // laisser vide obligerait à inventer un identifiant d'URL à chaque
    // ouverture de ville, et c'est ainsi qu'on obtient `abidjan-2`.
    _nom.addListener(() {
      if (_slugTouche) return;
      final propose = slugifier(_nom.text);
      if (_slug.text != propose) _slug.text = propose;
    });
  }

  @override
  void dispose() {
    _nom.dispose();
    _slug.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    final pays = _paysIso;
    if (pays == null) {
      setState(() {});
      return;
    }

    setState(() => _envoiEnCours = true);
    final reseau = context.read<NetworkService>();
    final creee = await reseau.createCity(
      countryIsoCode: pays,
      name: _nom.text.trim(),
      slug: _slug.text.trim(),
      latitude: double.parse(_latitude.text.trim()),
      longitude: double.parse(_longitude.text.trim()),
    );

    if (!mounted) return;
    setState(() => _envoiEnCours = false);

    if (creee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reseau.error ?? "La ville n'a pas pu être ouverte."),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  /// Ouvre la carte pour poser le centre de la ville.
  ///
  /// La recherche est bornée au pays déjà choisi dans le formulaire : chercher
  /// « Kara » sans borne rend une ville du Togo, une du Nigeria et une région
  /// de Turquie, et rien à l'écran ne dit laquelle est la bonne.
  ///
  /// Le nom proposé par Google **ne remplace pas** celui qu'on a tapé : c'est
  /// le nom qui décide du slug, donc de l'URL, et un renommage silencieux
  /// casserait les liens. Il n'est repris que si le champ est encore vide.
  Future<void> _chercherLeCentre() async {
    final courant = _positionCourante;
    final lieu = await SelecteurDeLieu.ouvrir(
      context,
      titre: 'Centre de la ville',
      positionInitiale: courant,
      countryCode: _paysIso,
    );
    if (lieu == null || !mounted) return;

    setState(() {
      _latitude.text = lieu.latitude.toStringAsFixed(6);
      _longitude.text = lieu.longitude.toStringAsFixed(6);
      final proposee = lieu.city ?? lieu.name;
      if (_nom.text.trim().isEmpty && proposee != null && proposee.isNotEmpty) {
        _nom.text = proposee;
      }
    });
  }

  eccore.GeoPoint? get _positionCourante {
    final lat = double.tryParse(_latitude.text.trim());
    final lon = double.tryParse(_longitude.text.trim());
    if (lat == null || lon == null) return null;
    return eccore.GeoPoint(lat, lon);
  }

  @override
  Widget build(BuildContext context) {
    final reseau = context.watch<NetworkService>();
    final paysOuverts = reseau.countries.where((pays) => pays.isActive).toList();

    return AlertDialog(
      title: const Text('Ouvrir une ville'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (paysOuverts.isEmpty)
                  const _AucunPays()
                else
                  DeroulantReseau<String>(
                    label: 'Pays',
                    valeur: _paysIso,
                    entrees: [
                      for (final pays in paysOuverts) (pays.isoCode, pays.label),
                    ],
                    aide: _aidePays(paysOuverts),
                    onChanged: (valeur) => setState(() => _paysIso = valeur),
                  ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Nom de la ville',
                  hint: 'Abidjan',
                  controller: _nom,
                  validator: (valeur) =>
                      (valeur == null || valeur.trim().isEmpty) ? 'Nom obligatoire' : null,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: "Identifiant d'URL",
                  hint: 'abidjan',
                  controller: _slug,
                  onChanged: (_) => _slugTouche = true,
                  validator: (valeur) =>
                      RegExp(r'^[a-z0-9-]+$').hasMatch((valeur ?? '').trim())
                      ? null
                      : 'Minuscules, chiffres et tirets',
                ),
                const SizedBox(height: 12),
                // **Le centre se cherche, plus ne se tape.**
                //
                // Chercher « Douala » rend son point en un geste ; le saisir au
                // clavier suppose d'aller le lire ailleurs, et d'intervertir
                // une fois sur deux la latitude et la longitude.
                //
                // Les champs restent visibles et modifiables : un relevé exact
                // se saisit plus vite qu'il ne se pointe, et une carte
                // indisponible ne doit pas empêcher d'ouvrir une ville.
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: _chercherLeCentre,
                    icon: const Icon(Icons.map_outlined),
                    label: Text(
                      _latitude.text.isEmpty
                          ? 'Chercher la ville sur la carte'
                          : 'Ajuster le centre sur la carte',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'Latitude du centre',
                        controller: _latitude,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: (valeur) => _coordonnee(valeur, -90, 90),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        label: 'Longitude du centre',
                        controller: _longitude,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: (valeur) => _coordonnee(valeur, -180, 180),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Ce point centre les cartes et trie par proximité. Il ne décide '
                  "d'aucune livraison : c'est le contour de la zone qui le fait.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          text: 'Ouvrir la ville',
          isLoading: _envoiEnCours,
          onPressed: (_envoiEnCours || paysOuverts.isEmpty) ? null : _enregistrer,
          width: 150,
        ),
      ],
    );
  }

  /// Rappelle la devise du pays choisi : c'est elle que porteront tous les
  /// barèmes des zones de cette ville, et le serveur refuse un montant libellé
  /// autrement.
  String? _aidePays(List<eccore.ManagedCountry> paysOuverts) {
    final iso = _paysIso;
    if (iso == null) return null;
    for (final pays in paysOuverts) {
      if (pays.isoCode == iso) {
        return 'Barèmes en ${pays.currency}, horaires en ${pays.timezone}.';
      }
    }
    return null;
  }

  static String? _coordonnee(String? valeur, double min, double max) {
    final nombre = double.tryParse((valeur ?? '').trim());
    if (nombre == null) return 'Nombre décimal attendu';
    if (nombre < min || nombre > max) return 'Entre $min et $max';
    return null;
  }
}

class _AucunPays extends StatelessWidget {
  const _AucunPays();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Aucun marché ouvert. Une ville se rattache à un pays : ouvrez '
              "d'abord le pays, dans l'onglet précédent.",
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
