import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/screens/admin/reseau/champs_reseau.dart';
import 'package:admin/screens/admin/reseau/zone_creation_dialog.dart';
import 'package:admin/services/delivery_zone_service.dart';
import 'package:admin/services/network_service.dart';
import 'package:admin/widgets/custom_button.dart';
import 'package:admin/widgets/custom_text_field.dart';

/// Ouverture ou correction d'un établissement.
///
/// ## Ce que la zone emporte
///
/// Le formulaire ne demande **ni pays, ni devise, ni fuseau** : la zone choisie
/// emporte la ville, donc le pays, donc la devise et le fuseau (ADR-006). Ce
/// n'est pas une commodité d'écran, c'est la raison pour laquelle un
/// établissement ne peut pas être incohérent avec son marché — il n'y a pas de
/// second champ pour le contredire.
///
/// ## Pourquoi la création ne publie pas
///
/// Le serveur crée toujours en **brouillon**. Un établissement neuf n'a ni
/// carte, ni horaires, ni livreur : le publier à l'instant où l'on valide un
/// formulaire le ferait apparaître dans l'application cliente comme une fiche
/// vide, et c'est exactement ce que faisait `is_active`, vrai par défaut. La
/// mise en service se fait depuis l'écran de provisionnement, une fois les
/// manques comblés.
class EtablissementFormDialog extends StatefulWidget {
  const EtablissementFormDialog({this.existant, super.key});

  /// Établissement à corriger, ou `null` pour une ouverture.
  final eccore.ManagedRestaurant? existant;

  static Future<bool> show(
    BuildContext context, {
    eccore.ManagedRestaurant? existant,
  }) async {
    final enregistre = await showDialog<bool>(
      context: context,
      builder: (_) => EtablissementFormDialog(existant: existant),
    );
    return enregistre ?? false;
  }

  @override
  State<EtablissementFormDialog> createState() => _EtablissementFormDialogState();
}

class _EtablissementFormDialogState extends State<EtablissementFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _slug = TextEditingController();
  final _description = TextEditingController();
  final _adresse = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _telephone = TextEditingController();
  final _email = TextEditingController();
  final _preparation = TextEditingController(text: '20');

  String? _zoneId;
  bool _slugTouche = false;
  bool _envoiEnCours = false;

  bool get _creation => widget.existant == null;

  @override
  void initState() {
    super.initState();
    final existant = widget.existant;
    if (existant != null) {
      _nom.text = existant.name;
      _slug.text = existant.slug;
      _slugTouche = true;
      _description.text = existant.description;
      _adresse.text = existant.address;
      _latitude.text = existant.latitude.toString();
      _longitude.text = existant.longitude.toString();
      _telephone.text = existant.phone ?? '';
      _email.text = existant.email ?? '';
      _preparation.text = existant.defaultPreparationMinutes.toString();
      _zoneId = existant.zoneId;
    }

    _nom.addListener(() {
      if (_slugTouche) return;
      final propose = slugifier(_nom.text);
      if (_slug.text != propose) _slug.text = propose;
    });
  }

  @override
  void dispose() {
    for (final champ in [
      _nom,
      _slug,
      _description,
      _adresse,
      _latitude,
      _longitude,
      _telephone,
      _email,
      _preparation,
    ]) {
      champ.dispose();
    }
    super.dispose();
  }

  Future<void> _ouvrirUneZone() async {
    final reseau = context.read<NetworkService>();
    final villes = reseau.cities.where((ville) => ville.isActive).toList();
    if (villes.isEmpty) return;

    final ville = await showDialog<eccore.ManagedCity>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Dans quelle ville ?'),
        children: [
          for (final v in villes)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(v),
              child: Text('${v.name} — ${v.countryIsoCode}'),
            ),
        ],
      ),
    );
    if (ville == null || !mounted) return;

    final creee = await ZoneCreationDialog.show(context, ville);
    if (creee != null && mounted) setState(() => _zoneId = creee.id);
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    final zone = _zoneId;
    if (zone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Choisissez une zone de livraison : c'est elle qui rattache "
            "l'établissement à une ville et à un marché.",
          ),
        ),
      );
      return;
    }

    setState(() => _envoiEnCours = true);
    final reseau = context.read<NetworkService>();

    final resultat = _creation
        ? await reseau.createRestaurant(
            name: _nom.text.trim(),
            slug: _slug.text.trim(),
            zoneId: zone,
            address: _adresse.text.trim(),
            latitude: double.parse(_latitude.text.trim()),
            longitude: double.parse(_longitude.text.trim()),
            phone: _telephone.text.trim(),
            description: _description.text.trim(),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            defaultPreparationMinutes: int.parse(_preparation.text.trim()),
          )
        : await reseau.updateRestaurant(
            slug: widget.existant!.slug,
            name: _nom.text.trim(),
            description: _description.text.trim(),
            address: _adresse.text.trim(),
            latitude: double.parse(_latitude.text.trim()),
            longitude: double.parse(_longitude.text.trim()),
            phone: _telephone.text.trim(),
            email: _email.text.trim(),
            defaultPreparationMinutes: int.parse(_preparation.text.trim()),
          );

    if (!mounted) return;
    setState(() => _envoiEnCours = false);

    if (resultat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reseau.error ?? "L'établissement n'a pas pu être enregistré."),
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
    final zones = context.watch<DeliveryZoneService>();
    final reseau = context.watch<NetworkService>();

    return AlertDialog(
      title: Text(_creation ? 'Ouvrir un établissement' : 'Modifier ${widget.existant!.name}'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Titre('Identité', scheme),
                CustomTextField(
                  label: "Nom de l'établissement",
                  hint: 'El Corazón Abidjan',
                  controller: _nom,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nom obligatoire' : null,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: "Identifiant d'URL",
                  hint: 'el-corazon-abidjan',
                  controller: _slug,
                  // Le slug voyage dans les URL des trois applications et
                  // désigne le panier d'un client : le changer casserait les
                  // paniers en cours et les liens partagés.
                  enabled: _creation,
                  onChanged: (_) => _slugTouche = true,
                  validator: (v) => RegExp(r'^[a-z0-9-]+$').hasMatch((v ?? '').trim())
                      ? null
                      : 'Minuscules, chiffres et tirets',
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Description (facultatif)',
                  controller: _description,
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                _Titre('Rattachement', scheme),
                _ChoixDeZone(
                  zoneId: _zoneId,
                  zones: zones,
                  reseau: reseau,
                  modifiable: _creation,
                  onChanged: (valeur) => setState(() => _zoneId = valeur),
                  onOuvrirUneZone: _ouvrirUneZone,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Adresse',
                  hint: 'Rue des Jardins, Cocody',
                  controller: _adresse,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Adresse obligatoire' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'Latitude',
                        hint: '5.3600',
                        controller: _latitude,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: (v) => _coordonnee(v, -90, 90),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        label: 'Longitude',
                        hint: '-4.0083',
                        controller: _longitude,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: (v) => _coordonnee(v, -180, 180),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "C'est le point de retrait des courses et l'origine du calcul de "
                  'distance. Les trois applications le lisent depuis ici : aucune '
                  "coordonnée d'établissement n'est écrite dans leur code.",
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                _Titre('Contact et service', scheme),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'Téléphone',
                        hint: '+22507000000',
                        controller: _telephone,
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            RegExp(r'^\+\d{6,15}$').hasMatch((v ?? '').trim())
                            ? null
                            : 'Format international, par exemple +22507000000',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        label: 'Email (facultatif)',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        label: 'Préparation (min)',
                        controller: _preparation,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final minutes = int.tryParse((v ?? '').trim());
                          if (minutes == null || minutes <= 0) return 'Minutes attendues';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                if (_creation) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.drafts_outlined, size: 18, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "L'établissement est créé en brouillon : il reste "
                            'invisible des clients tant que sa carte, ses horaires '
                            'et ses livreurs ne sont pas en place. '
                            "L'écran suivant liste ce qui manque.",
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
          text: _creation ? 'Créer en brouillon' : 'Enregistrer',
          isLoading: _envoiEnCours,
          onPressed: _envoiEnCours ? null : _enregistrer,
          width: 175,
        ),
      ],
    );
  }

  static String? _coordonnee(String? valeur, double min, double max) {
    final nombre = double.tryParse((valeur ?? '').trim());
    if (nombre == null) return 'Nombre décimal attendu';
    if (nombre < min || nombre > max) return 'Entre $min et $max';
    return null;
  }
}

/// Sélecteur de zone, avec la sortie de secours qui manquait.
///
/// Ouvrir un établissement dans une ville neuve suppose d'y avoir d'abord ouvert
/// une zone. Sans ce bouton, l'écran serait une impasse : une liste vide, sans
/// rien qui dise où aller.
class _ChoixDeZone extends StatelessWidget {
  const _ChoixDeZone({
    required this.zoneId,
    required this.zones,
    required this.reseau,
    required this.modifiable,
    required this.onChanged,
    required this.onOuvrirUneZone,
  });

  final String? zoneId;
  final DeliveryZoneService zones;
  final NetworkService reseau;
  final bool modifiable;
  final ValueChanged<String> onChanged;
  final VoidCallback onOuvrirUneZone;

  @override
  Widget build(BuildContext context) {
    final ouvertes = zones.zones.where((zone) => zone.isActive).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (!modifiable) {
      final courante = zones.zoneById(zoneId ?? '');
      return _LigneFigee(
        label: 'Zone de livraison',
        valeur: courante == null
            ? 'Zone rattachée'
            : '${courante.name} — ${zones.cityName(courante.cityId)}',
        aide:
            'Changer de zone changerait la ville, donc le marché et la devise. '
            "C'est une opération de reprise de données, pas un champ de fiche.",
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DeroulantReseau<String>(
          label: 'Zone de livraison',
          valeur: ouvertes.any((zone) => zone.id == zoneId) ? zoneId : null,
          entrees: [
            for (final zone in ouvertes)
              (zone.id, '${zone.name} — ${zones.cityName(zone.cityId)}'),
          ],
          aide: 'La zone emporte la ville, donc le pays, donc la devise et le fuseau.',
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: reseau.cities.isEmpty ? null : onOuvrirUneZone,
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: Text(
              ouvertes.isEmpty
                  ? 'Aucune zone : en ouvrir une'
                  : 'Ouvrir une nouvelle zone',
            ),
          ),
        ),
      ],
    );
  }
}

class _LigneFigee extends StatelessWidget {
  const _LigneFigee({required this.label, required this.valeur, required this.aide});

  final String label;
  final String valeur;
  final String aide;

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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Text(valeur),
        ),
        const SizedBox(height: 4),
        Text(
          aide,
          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte, this.scheme);

  final String texte;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        texte.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: scheme.primary,
        ),
      ),
    );
  }
}
