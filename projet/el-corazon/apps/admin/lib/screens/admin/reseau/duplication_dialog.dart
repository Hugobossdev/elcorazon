import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/screens/admin/reseau/champs_reseau.dart';
import 'package:admin/services/delivery_zone_service.dart';
import 'package:admin/services/network_service.dart';
import 'package:admin/widgets/custom_button.dart';
import 'package:admin/widgets/custom_text_field.dart';

/// **Ouvrir un établissement en repartant d'un autre.**
///
/// Recopier à la main une carte de quarante articles, leurs groupes d'options
/// et sept plages horaires, c'est une demi-journée et des oublis. C'est le
/// geste que ce dialogue remplace.
///
/// ## Ce que l'écran ne propose pas, et pourquoi il n'y a pas de case
///
/// Commandes, clients, livreurs, paiements, historiques et statistiques
/// n'apparaissent nulle part — pas décochés par défaut, **absents**. Le serveur
/// n'a pas de section pour eux : il n'existe aucun chemin de code pour les
/// copier. Une case, même décochée par défaut, finirait un jour cochée par
/// erreur, et un établissement neuf naîtrait avec le chiffre d'affaires d'un
/// autre.
///
/// Les zones de livraison non plus : elles appartiennent à la ville et leur
/// contour est un polygone réel. Recopier celui de Lomé vers Abidjan poserait
/// un périmètre de livraison dans le golfe de Guinée. La zone d'arrivée est
/// donc **choisie**, comme à toute ouverture.
///
/// ## Pourquoi l'adresse est obligatoire
///
/// Hériter l'adresse, la position et le téléphone de la source produirait une
/// fiche complète en apparence qui pointe sur une autre ville. C'est le pire
/// état possible : il passe la validation, et se découvre à la première course.
class DuplicationDialog extends StatefulWidget {
  const DuplicationDialog({required this.source, super.key});

  final eccore.ManagedRestaurant source;

  /// Ouvre le dialogue. Rend `true` si un établissement a été créé.
  static Future<bool> show(
    BuildContext context, {
    required eccore.ManagedRestaurant source,
  }) async {
    final cree = await showDialog<bool>(
      context: context,
      builder: (_) => DuplicationDialog(source: source),
    );
    return cree ?? false;
  }

  @override
  State<DuplicationDialog> createState() => _DuplicationDialogState();
}

class _DuplicationDialogState extends State<DuplicationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _slug = TextEditingController();
  final _adresse = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _telephone = TextEditingController();
  final _email = TextEditingController();

  String? _zoneId;
  bool _slugTouche = false;
  bool _envoiEnCours = false;

  /// Sections cochées. Les trois le sont par défaut : dupliquer sans rien
  /// recopier revient à créer un établissement, ce que l'autre formulaire fait
  /// déjà — le cas existe, mais ce n'est pas celui qu'on vient chercher ici.
  final Set<String> _sections = {'general', 'opening_hours', 'catalog'};

  @override
  void initState() {
    super.initState();
    _nom.addListener(() {
      if (_slugTouche) return;
      final propose = slugifier(_nom.text);
      if (_slug.text != propose) _slug.text = propose;
    });
  }

  @override
  void dispose() {
    for (final champ in [_nom, _slug, _adresse, _latitude, _longitude, _telephone, _email]) {
      champ.dispose();
    }
    super.dispose();
  }

  /// Devise de la zone visée, ou `null` tant qu'aucune n'est choisie.
  ///
  /// Sert à prévenir **avant** l'envoi qu'une carte ne traversera pas la
  /// frontière monétaire. Le serveur refuse de toute façon en 409, mais un
  /// avertissement affiché sous la case évite de remplir tout le formulaire
  /// pour se le voir dire ensuite.
  String? _deviseCible(DeliveryZoneService zones) => zones.zoneById(_zoneId ?? '')?.currency;

  bool _memeDevise(DeliveryZoneService zones) {
    final cible = _deviseCible(zones);
    return cible == null || cible == widget.source.currency;
  }

  Future<void> _dupliquer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_zoneId == null) return;

    setState(() => _envoiEnCours = true);
    final reseau = context.read<NetworkService>();

    final copie = await reseau.duplicateRestaurant(
      sourceSlug: widget.source.slug,
      name: _nom.text.trim(),
      slug: _slug.text.trim(),
      zoneId: _zoneId!,
      address: _adresse.text.trim(),
      latitude: double.parse(_latitude.text.trim()),
      longitude: double.parse(_longitude.text.trim()),
      phone: _telephone.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      sections: _sections.toList()..sort(),
    );

    if (!mounted) return;
    setState(() => _envoiEnCours = false);
    if (copie != null) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Consumer2<NetworkService, DeliveryZoneService>(
      builder: (context, reseau, zones, _) {
        final ouvertes = zones.zones.where((zone) => zone.isActive).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        final memeDevise = _memeDevise(zones);

        return AlertDialog(
          title: Text('Dupliquer ${widget.source.name}'),
          content: SizedBox(
            width: 560,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Encart(
                      scheme: scheme,
                      texte:
                          'Le nouvel établissement naît en brouillon, comme toute '
                          'ouverture. Ni commandes, ni clients, ni livreurs, ni '
                          'historiques ne sont copiés.',
                    ),
                    const SizedBox(height: 16),
                    _Titre('Identité', scheme),
                    CustomTextField(
                      label: 'Nom du nouvel établissement',
                      controller: _nom,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Nom obligatoire' : null,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      label: "Identifiant d'URL",
                      controller: _slug,
                      onChanged: (_) => _slugTouche = true,
                      validator: (v) => RegExp(r'^[a-z0-9-]+$').hasMatch((v ?? '').trim())
                          ? null
                          : 'Minuscules, chiffres et tirets',
                    ),
                    const SizedBox(height: 20),
                    _Titre('Où', scheme),
                    DeroulantReseau<String>(
                      label: 'Zone de livraison',
                      valeur: ouvertes.any((zone) => zone.id == _zoneId) ? _zoneId : null,
                      entrees: [
                        for (final zone in ouvertes)
                          (zone.id, '${zone.name} — ${zones.cityName(zone.cityId)}'),
                      ],
                      aide:
                          'La zone emporte la ville, le pays, la devise et le fuseau. '
                          "Elle n'est jamais copiée : un contour est un lieu réel.",
                      onChanged: (valeur) => setState(() => _zoneId = valeur),
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      label: 'Adresse',
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
                    const SizedBox(height: 12),
                    CustomTextField(
                      label: 'Téléphone',
                      controller: _telephone,
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Téléphone obligatoire'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      label: 'Email (facultatif)',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    _Titre('Ce qui est recopié', scheme),
                    _Section(
                      cle: 'general',
                      titre: 'Informations générales',
                      sous: 'Description et délai de préparation.',
                      sections: _sections,
                      onChanged: (actif) => setState(
                        () => actif ? _sections.add('general') : _sections.remove('general'),
                      ),
                    ),
                    _Section(
                      cle: 'opening_hours',
                      titre: 'Horaires',
                      sous: 'Les heures ne sont pas converties : 11 h ici reste 11 h là-bas.',
                      sections: _sections,
                      onChanged: (actif) => setState(
                        () => actif
                            ? _sections.add('opening_hours')
                            : _sections.remove('opening_hours'),
                      ),
                    ),
                    _Section(
                      cle: 'catalog',
                      titre: 'Catalogue',
                      sous: 'Catégories, articles, options et suppléments.',
                      sections: _sections,
                      // Verrouillée entre deux devises : le serveur refuserait,
                      // et laisser cocher une case qui fera échouer l'envoi
                      // n'aide personne.
                      active: memeDevise,
                      onChanged: (actif) => setState(
                        () => actif ? _sections.add('catalog') : _sections.remove('catalog'),
                      ),
                    ),
                    if (!memeDevise)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${widget.source.name} facture en ${widget.source.currency} et '
                          'la zone visée en ${_deviseCible(zones)}. Une carte '
                          "recopiée garderait ses montants sans changer d'unité. "
                          'Dupliquez sans le catalogue, puis saisissez les prix du '
                          'nouveau marché.',
                          style: TextStyle(fontSize: 12, color: scheme.error),
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
              text: 'Dupliquer',
              isLoading: _envoiEnCours,
              onPressed: (_envoiEnCours || _zoneId == null) ? null : _dupliquer,
            ),
          ],
        );
      },
    );
  }
}

/// Valide une coordonnée : présente, numérique, dans les bornes.
///
/// Les bornes ne sont pas décoratives : une longitude saisie à la place d'une
/// latitude passe silencieusement au-delà de 90, et l'établissement se retrouve
/// au pôle — hors de sa zone, donc invalide, mais seulement au moment de la
/// mise en service.
String? _coordonnee(String? valeur, double min, double max) {
  final nombre = double.tryParse((valeur ?? '').trim());
  if (nombre == null) return 'Nombre décimal attendu';
  if (nombre < min || nombre > max) return 'Entre $min et $max';
  return null;
}

class _Section extends StatelessWidget {
  const _Section({
    required this.cle,
    required this.titre,
    required this.sous,
    required this.sections,
    required this.onChanged,
    this.active = true,
  });

  final String cle;
  final String titre;
  final String sous;
  final Set<String> sections;
  final ValueChanged<bool> onChanged;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: active && sections.contains(cle),
      onChanged: active ? (coche) => onChanged(coche ?? false) : null,
      title: Text(titre, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(sous, style: const TextStyle(fontSize: 12)),
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
      padding: const EdgeInsets.only(bottom: 8),
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

class _Encart extends StatelessWidget {
  const _Encart({required this.scheme, required this.texte});

  final ColorScheme scheme;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(texte, style: const TextStyle(fontSize: 12)),
    );
  }
}
