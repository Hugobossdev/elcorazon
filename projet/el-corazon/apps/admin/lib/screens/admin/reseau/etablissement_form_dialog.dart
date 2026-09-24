import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/presentation/inventaire.dart';
import 'package:admin/screens/admin/reseau/champs_reseau.dart';
import 'package:admin/screens/admin/reseau/selecteur_de_lieu.dart';
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
  final _plafond = TextEditingController();

  String? _zoneId;
  bool _affectationAutomatique = true;
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
      final plafond = existant.stockAdjustmentCeiling;
      _plafond.text = plafond == null ? '' : '${plafond.toMajorUnits()}'.replaceFirst(RegExp(r'\.0$'), '');
      _zoneId = existant.zoneId;
      _affectationAutomatique = existant.autoDispatchCouriers;
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
      _plafond,
    ]) {
      champ.dispose();
    }
    super.dispose();
  }

  /// Code pays du marché visé, pour borner la recherche de lieux.
  ///
  /// Il vient de la zone choisie — laquelle emporte la ville, donc le pays
  /// (ADR-006). Nul tant qu'aucune zone n'est retenue : la recherche est alors
  /// mondiale, ce qui est le bon défaut quand on ne sait pas encore où l'on
  /// ouvre.
  String? _paysDeLaZoneChoisie(DeliveryZoneService zones, NetworkService reseau) {
    final zone = zones.zoneById(_zoneId ?? '');
    if (zone == null) return null;
    final ville = reseau.cities.where((v) => v.id == zone.cityId).firstOrNull;
    return ville?.countryIsoCode;
  }

  /// Indicatif du pays de la zone choisie (`phone_prefix`), vide sinon.
  ///
  /// L'exemple du champ téléphone était un numéro ivoirien écrit en dur,
  /// proposé aussi pour un établissement de Lomé ou de Douala.
  String _indicatif(DeliveryZoneService zones, NetworkService reseau) {
    final iso = _paysDeLaZoneChoisie(zones, reseau);
    return iso == null ? '' : (reseau.countryByIso(iso)?.phonePrefix ?? '');
  }

  /// Applique ce que le sélecteur a rapporté.
  ///
  /// **L'adresse n'est écrasée que si elle est vide.** Quelqu'un qui a saisi
  /// « Entrée de service, portail bleu » ne doit pas la perdre parce qu'il
  /// ajuste le marqueur de trois mètres — c'est la règle « rien n'écrase une
  /// donnée validée à la main ». Les coordonnées, elles, sont précisément ce
  /// qu'on vient chercher : elles sont remplacées.
  void _appliquerLeLieu(LieuChoisi lieu) {
    setState(() {
      _latitude.text = lieu.latitude.toStringAsFixed(6);
      _longitude.text = lieu.longitude.toStringAsFixed(6);

      final proposee = lieu.address;
      if (_adresse.text.trim().isEmpty && proposee != null && proposee.isNotEmpty) {
        _adresse.text = proposee;
      }
      if (_nom.text.trim().isEmpty && (lieu.name ?? '').isNotEmpty) {
        _nom.text = lieu.name!;
      }
    });
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
            autoDispatchCouriers: _affectationAutomatique,
            stockAdjustmentCeiling:
                prixDuLot(_plafond.text, devise: widget.existant!.currency),
            clearStockAdjustmentCeiling: _plafond.text.trim().isEmpty,
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
                // **La position se pose sur une carte, plus au clavier.**
                //
                // Deux champs « Latitude » et « Longitude » restaient la seule
                // façon de placer un établissement. Personne ne connaît par
                // cœur les coordonnées d'une adresse : on les copiait depuis un
                // autre onglet, avec une chance sur deux de les intervertir —
                // et une longitude saisie en latitude place un restaurant de
                // Lomé au pôle, ce qui ne se voit qu'à la mise en service.
                //
                // Les champs restent lisibles, et modifiables : quelqu'un qui a
                // un relevé GPS exact doit pouvoir le saisir sans passer par
                // une carte.
                _ChoixDeLaPosition(
                  latitude: _latitude,
                  longitude: _longitude,
                  adresse: _adresse,
                  countryCode: _paysDeLaZoneChoisie(zones, reseau),
                  onLieuChoisi: _appliquerLeLieu,
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
                        hint: _indicatif(zones, reseau).isEmpty
                            ? 'Format international : +indicatif puis numéro'
                            : '${_indicatif(zones, reseau)}…',
                        controller: _telephone,
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            RegExp(r'^\+\d{6,15}$').hasMatch((v ?? '').trim())
                            ? null
                            : _indicatif(zones, reseau).isEmpty
                                ? 'Format international : + suivi de 6 à 15 chiffres'
                                : 'Format international, commençant par ${_indicatif(zones, reseau)}',
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
                if (!_creation) ...[
                  const SizedBox(height: 20),
                  _Titre('Livraison', scheme),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _affectationAutomatique,
                    onChanged: (valeur) => setState(() => _affectationAutomatique = valeur),
                    title: const Text('Affecter les livreurs automatiquement'),
                    subtitle: Text(
                      _affectationAutomatique
                          ? 'Dès qu’une commande est prête, la course est proposée au livreur '
                              'compatible le plus proche — même zone, en ligne, sans course en cours.'
                          : 'Les courses s’affectent à la main depuis la supervision.',
                    ),
                  ),
                ],
                // Le plafond ne se fixe qu'une fois l'établissement ouvert : sa
                // devise vient de la zone, et un montant saisi avant de la
                // connaître se lirait dans la mauvaise unité.
                if (!_creation) ...[
                  const SizedBox(height: 20),
                  _Titre('Inventaire', scheme),
                  CustomTextField(
                    label: 'Plafond des pertes sans validation (${widget.existant!.currency})',
                    hint: 'Vide : toute perte attend une validation',
                    controller: _plafond,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      try {
                        prixDuLot(v ?? '', devise: widget.existant!.currency);
                        return null;
                      } on FormatException {
                        return 'Montant attendu, sans décimale superflue';
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Au-delà de ce montant, une perte ou une correction de stock attend '
                    'la validation d’une autre personne. Laissé vide, tout se valide.',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
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

}

/// Valide une coordonnée : présente, numérique, dans les bornes.
///
/// Les bornes ne sont pas décoratives. Une longitude saisie à la place d'une
/// latitude passe silencieusement au-delà de 90, et l'établissement se retrouve
/// au pôle — hors de sa zone, donc invalide, mais seulement au moment de la
/// mise en service.
///
/// Fonction de fichier et non méthode statique : deux widgets l'utilisent
/// depuis que la position se pose aussi sur une carte.
String? _coordonnee(String? valeur, double min, double max) {
  final nombre = double.tryParse((valeur ?? '').trim());
  if (nombre == null) return 'Nombre décimal attendu';
  if (nombre < min || nombre > max) return 'Entre $min et $max';
  return null;
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


/// Position de l'établissement : une carte, et les coordonnées qu'elle produit.
///
/// Les deux champs restent affichés et modifiables. Ce n'est pas une
/// concession : un relevé GPS exact se saisit plus vite qu'il ne se pointe, et
/// une carte indisponible — clé absente, réseau coupé — ne doit pas empêcher
/// d'ouvrir un établissement.
class _ChoixDeLaPosition extends StatelessWidget {
  const _ChoixDeLaPosition({
    required this.latitude,
    required this.longitude,
    required this.adresse,
    required this.countryCode,
    required this.onLieuChoisi,
  });

  final TextEditingController latitude;
  final TextEditingController longitude;
  final TextEditingController adresse;
  final String? countryCode;
  final ValueChanged<LieuChoisi> onLieuChoisi;

  eccore.GeoPoint? get _positionCourante {
    final lat = double.tryParse(latitude.text.trim());
    final lon = double.tryParse(longitude.text.trim());
    if (lat == null || lon == null) return null;
    return eccore.GeoPoint(lat, lon);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: () async {
              final lieu = await SelecteurDeLieu.ouvrir(
                context,
                titre: 'Position de l’établissement',
                positionInitiale: _positionCourante,
                countryCode: countryCode,
              );
              if (lieu != null) onLieuChoisi(lieu);
            },
            icon: const Icon(Icons.map_outlined),
            label: Text(
              _positionCourante == null
                  ? 'Placer sur la carte'
                  : 'Ajuster sur la carte',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                label: 'Latitude',
                controller: latitude,
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
                controller: longitude,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: (v) => _coordonnee(v, -180, 180),
              ),
            ),
          ],
        ),
        if (countryCode == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Choisissez d’abord une zone : la recherche de lieux se bornera '
              'alors au marché visé.',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}
