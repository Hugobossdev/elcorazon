import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/services/delivery_zone_service.dart';
import 'package:admin/services/network_service.dart';
import 'package:admin/widgets/custom_button.dart';
import 'package:admin/widgets/custom_text_field.dart';

/// Ouverture d'une zone de livraison — **le chaînon qui manquait**.
///
/// `Restaurant.zone` est une clé étrangère non nulle : sans zone, aucun
/// établissement n'est créable. Le dépôt savait écrire une zone depuis
/// l'origine (`ManagedGeographyRepository.createZone`), et aucun écran ne
/// l'appelait — c'est pourquoi ouvrir une ville passait obligatoirement par
/// `django-admin`.
///
/// ## Un centre et un rayon, pas un contour tracé
///
/// Le serveur attend un `MultiPolygon`, la forme que produisent les outils de
/// cartographie et celle que l'exploitation tracera pour de bon. Un éditeur de
/// contour sur carte est un travail à part entière, et son absence ne doit pas
/// empêcher d'ouvrir un marché : le disque saisi ici couvre un quartier de
/// façon utilisable dès le premier jour, et se remplace ensuite par le contour
/// réel **sans migration** — c'est le même champ.
///
/// ## Ce que porte une zone
///
/// Le barème, et lui seul décide de ce que paiera un client. La devise n'est
/// pas saisie : elle est héritée du pays (ADR-006), et le serveur refuse un
/// montant libellé autrement. L'écran l'affiche pour qu'on sache dans quelle
/// unité on tape.
class ZoneCreationDialog extends StatefulWidget {
  const ZoneCreationDialog({required this.ville, super.key});

  final eccore.ManagedCity ville;

  /// Ouvre le formulaire et rend la zone créée, ou `null`.
  ///
  /// C'est la zone telle que la tient [DeliveryZoneService] — le modèle
  /// d'affichage du back-office, construit depuis la réponse du serveur. La
  /// reconvertir en `eccore.DeliveryZone` obligerait à inventer les champs que
  /// le modèle d'affichage n'a pas repris, et l'appelant n'en a besoin que pour
  /// son identifiant et son nom.
  static Future<DeliveryZone?> show(BuildContext context, eccore.ManagedCity ville) {
    return showDialog<DeliveryZone>(
      context: context,
      builder: (_) => ZoneCreationDialog(ville: ville),
    );
  }

  @override
  State<ZoneCreationDialog> createState() => _ZoneCreationDialogState();
}

class _ZoneCreationDialogState extends State<ZoneCreationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _rayon = TextEditingController();
  final _forfait = TextEditingController();
  final _parKm = TextEditingController();
  final _franco = TextEditingController();
  final _minimum = TextEditingController();
  /// Pré-rempli avec la valeur par défaut du serveur
  /// (`DeliveryZone.estimated_delivery_minutes`, 30), et non un chiffre choisi
  /// ici : le formulaire propose ce que la base aurait retenu.
  final _delai = TextEditingController(text: '30');

  bool _envoiEnCours = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _nom.text = '${widget.ville.name} — centre';
    // Le centre de la ville tel que le serveur le connaît : un point de départ
    // plausible, là où le formulaire montrait des coordonnées d'Abidjan en
    // exemple, pour toutes les villes.
    final lat = widget.ville.centroidLatitude;
    final lon = widget.ville.centroidLongitude;
    if (lat != null && lon != null) {
      _latitude.text = lat.toStringAsFixed(4);
      _longitude.text = lon.toStringAsFixed(4);
    }
  }

  @override
  void dispose() {
    for (final champ in [
      _nom,
      _latitude,
      _longitude,
      _rayon,
      _forfait,
      _parKm,
      _franco,
      _minimum,
      _delai,
    ]) {
      champ.dispose();
    }
    super.dispose();
  }

  /// Devise héritée du pays de la ville — `null` tant que le pays n'est pas
  /// chargé. Aucune devise de repli : un barème libellé dans une devise
  /// devinée serait refusé par le serveur (« Ce pays facture en … »).
  String? _devise(NetworkService reseau) =>
      reseau.countryByIso(widget.ville.countryIsoCode)?.currency;

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    final devise = _devise(context.read<NetworkService>());
    if (devise == null) {
      setState(() => _erreur = 'Le pays de cette ville n’est pas chargé : sa devise est inconnue.');
      return;
    }
    setState(() {
      _envoiEnCours = true;
      _erreur = null;
    });

    final zones = context.read<DeliveryZoneService>();
    final creee = await zones.createZone(
      cityId: widget.ville.id,
      name: _nom.text.trim(),
      centerLatitude: double.parse(_latitude.text.trim()),
      centerLongitude: double.parse(_longitude.text.trim()),
      radiusKm: double.parse(_rayon.text.trim()),
      currency: devise,
      baseFee: double.parse(_forfait.text.trim()),
      feePerKm: double.parse(_parKm.text.trim()),
      freeDeliveryThreshold: _optionnel(_franco),
      minOrderAmount: _optionnel(_minimum),
      estimatedDeliveryMinutes: int.parse(_delai.text.trim()),
    );

    if (!mounted) return;
    setState(() => _envoiEnCours = false);

    if (creee == null) {
      setState(() => _erreur = zones.error ?? "La zone n'a pas pu être ouverte.");
      return;
    }
    Navigator.of(context).pop(creee);
  }

  static double? _optionnel(TextEditingController champ) {
    final texte = champ.text.trim();
    return texte.isEmpty ? null : double.tryParse(texte);
  }

  @override
  Widget build(BuildContext context) {
    final reseau = context.watch<NetworkService>();
    final devise = _devise(reseau);
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text('Ouvrir une zone — ${widget.ville.name}'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomTextField(
                  label: 'Nom de la zone',
                  hint: '${widget.ville.name} — quartiers desservis',
                  controller: _nom,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nom obligatoire' : null,
                ),
                const SizedBox(height: 16),
                _Section(titre: 'Couverture', scheme: scheme),
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
                        validator: (v) => _coordonnee(v, -90, 90),
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
                        validator: (v) => _coordonnee(v, -180, 180),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        label: 'Rayon (km)',
                        controller: _rayon,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          final rayon = double.tryParse((v ?? '').trim());
                          if (rayon == null) return 'Nombre attendu';
                          if (rayon <= 0) return 'Le rayon doit être positif';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Contour circulaire approché, à remplacer plus tard par le tracé '
                  "réel de l'exploitation — c'est le même champ, sans reprise de "
                  'données.',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                _Section(titre: 'Barème — en ${devise ?? '…'}', scheme: scheme),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'Forfait de base',
                        hint: '500',
                        controller: _forfait,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: _montantObligatoire,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        label: 'Tarif au kilomètre',
                        hint: '100',
                        controller: _parKm,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: _montantObligatoire,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'Livraison offerte au-delà de (facultatif)',
                        hint: '15000',
                        controller: _franco,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: _montantFacultatif,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        label: 'Commande minimum (facultatif)',
                        hint: '1000',
                        controller: _minimum,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: _montantFacultatif,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        label: 'Délai estimé (min)',
                        hint: '35',
                        controller: _delai,
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
                if (_erreur != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _erreur!,
                      style: TextStyle(color: scheme.onErrorContainer),
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
          onPressed: _envoiEnCours ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        CustomButton(
          text: 'Ouvrir la zone',
          isLoading: _envoiEnCours,
          onPressed: _envoiEnCours ? null : _enregistrer,
          width: 150,
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

  static String? _montantObligatoire(String? valeur) {
    final montant = double.tryParse((valeur ?? '').trim());
    if (montant == null) return 'Montant attendu';
    if (montant < 0) return 'Montant positif';
    return null;
  }

  static String? _montantFacultatif(String? valeur) {
    final texte = (valeur ?? '').trim();
    if (texte.isEmpty) return null;
    return _montantObligatoire(texte);
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.titre, required this.scheme});

  final String titre;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        titre.toUpperCase(),
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
