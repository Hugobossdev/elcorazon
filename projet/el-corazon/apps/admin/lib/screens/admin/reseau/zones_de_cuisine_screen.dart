import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

import 'package:admin/presentation/messages_erreur.dart';
import 'package:admin/screens/admin/reseau/brouillon_de_zone.dart';
import 'package:admin/screens/admin/reseau/editeur_de_zone.dart';
import 'package:admin/services/admin_auth_service.dart';

/// « Cuisine → Zones de livraison » : les zones **propres** à une cuisine.
///
/// La route existait côté serveur, cloisonnée et journalisée, sans un écran
/// pour s'en servir. Le gérant ne pouvait pas dire jusqu'où sa cuisine livre.
///
/// Tout ce qui se décide se décide au serveur, et l'écran le montre :
///
/// * une autre cuisine ne voit pas ces zones — la liste est déjà filtrée ;
/// * un contour qui se croise, sort du globe ou couvre plus de 5 000 km² est
///   refusé, et le refus s'affiche sous la fiche ;
/// * une zone qui porte encore la cuisine ne se supprime pas — le 409 nomme la
///   cuisine à rattacher ailleurs, et c'est lui qu'on lit.
class ZonesDeCuisineScreen extends StatefulWidget {
  const ZonesDeCuisineScreen({
    required this.etablissement,
    this.depot,
    this.resoudreVille,
    super.key,
  });

  final eccore.ManagedRestaurant etablissement;

  /// Injectés par les tests ; le vrai dépôt et l'annuaire des villes sinon.
  final eccore.RestaurantZoneRepository? depot;
  final Future<String> Function(String citySlug)? resoudreVille;

  @override
  State<ZonesDeCuisineScreen> createState() => _ZonesDeCuisineScreenState();
}

class _ZonesDeCuisineScreenState extends State<ZonesDeCuisineScreen> {
  late final eccore.RestaurantZoneRepository _depot =
      widget.depot ?? eccore.RestaurantZoneRepository(apiClient: AdminAuthService().apiClient);

  List<eccore.DeliveryZone>? _zones;
  Object? _echec;

  eccore.ManagedRestaurant get _cuisine => widget.etablissement;
  eccore.GeoPoint get _cadrage => eccore.GeoPoint(_cuisine.latitude, _cuisine.longitude);

  @override
  void initState() {
    super.initState();
    unawaited(_charger());
  }

  Future<void> _charger() async {
    setState(() => _echec = null);
    try {
      final zones = await _depot.zonesDe(_cuisine.slug);
      if (mounted) setState(() => _zones = zones);
    } catch (erreur) {
      if (mounted) setState(() => _echec = erreur);
    }
  }

  Future<String> _villeDeLaCuisine() async {
    final resoudre = widget.resoudreVille;
    if (resoudre != null) return resoudre(_cuisine.citySlug);
    final villes =
        await eccore.ManagedGeographyRepository(apiClient: AdminAuthService().apiClient).cities();
    return villes.firstWhere((ville) => ville.slug == _cuisine.citySlug).id;
  }

  void _dire(String message, {bool echec = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: echec ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _basculer(eccore.DeliveryZone zone, bool active) async {
    try {
      await _depot.modifier(zone.id, active: active);
      await _charger();
    } catch (erreur) {
      if (mounted) _dire(messageErreur(erreur), echec: true);
    }
  }

  Future<void> _supprimer(eccore.DeliveryZone zone) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la zone ?'),
        content: Text(
          'La zone « ${zone.name} » ne sera plus desservie. Les commandes passées '
          'la gardent dans leur historique. Pour arrêter de livrer sans rien '
          'effacer, désactivez-la plutôt.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Garder')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    try {
      await _depot.supprimer(zone.id);
      if (mounted) _dire('Zone « ${zone.name} » supprimée.');
      await _charger();
    } catch (erreur) {
      // Le 409 d'une zone qui porte la cuisine dit laquelle rattacher
      // ailleurs : c'est la phrase du serveur qu'on montre.
      if (mounted) _dire(messageErreur(erreur), echec: true);
    }
  }

  Future<void> _ouvrirFiche([eccore.DeliveryZone? existante]) async {
    final enregistree = await showDialog<bool>(
      context: context,
      builder: (_) => _FicheDeZone(
        cuisine: _cuisine,
        depot: _depot,
        existante: existante,
        voisines: [
          for (final zone in _zones ?? const <eccore.DeliveryZone>[])
            if (zone.id != existante?.id) zone,
        ],
        cadrage: _cadrage,
        villeDeLaCuisine: _villeDeLaCuisine,
      ),
    );
    if (enregistree == true) await _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Zones — ${_cuisine.name}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _zones == null ? null : () => _ouvrirFiche(),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Nouvelle zone'),
      ),
      body: _corps(context),
    );
  }

  Widget _corps(BuildContext context) {
    final echec = _echec;
    if (echec != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(messageErreur(echec), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _charger, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }
    final zones = _zones;
    if (zones == null) return const Center(child: CircularProgressIndicator());
    if (zones.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aucune zone propre : la cuisine livre selon les zones de sa ville.\n'
            'Créez-en une pour fixer vous-même jusqu’où elle livre, et à quel prix.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: zones.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final zone = zones[index];
          return Card(
            child: ListTile(
              leading: Icon(zone.estCirculaire ? Icons.circle_outlined : Icons.polyline_outlined),
              title: Text(zone.name),
              subtitle: Text(
                '${_forme(zone)} · forfait ${zone.baseFee.format()}'
                '${zone.isActive ? '' : ' · désactivée'}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: zone.isActive,
                    onChanged: (active) => _basculer(zone, active),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Actions',
                    onSelected: (action) =>
                        action == 'modifier' ? _ouvrirFiche(zone) : _supprimer(zone),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'modifier', child: Text('Modifier')),
                      PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
                    ],
                  ),
                ],
              ),
              onTap: () => _ouvrirFiche(zone),
            ),
          );
        },
      ),
    );
  }

  static String _forme(eccore.DeliveryZone zone) {
    if (zone.estCirculaire) {
      final rayon = zone.radiusMeters ?? 0;
      return 'cercle de ${(rayon / 1000).toStringAsFixed(1)} km';
    }
    return 'polygone de ${zone.sommets.length} sommets';
  }
}

/// Nom, barème et forme d'une zone — création ou modification.
class _FicheDeZone extends StatefulWidget {
  const _FicheDeZone({
    required this.cuisine,
    required this.depot,
    required this.voisines,
    required this.cadrage,
    required this.villeDeLaCuisine,
    this.existante,
  });

  final eccore.ManagedRestaurant cuisine;
  final eccore.RestaurantZoneRepository depot;
  final eccore.DeliveryZone? existante;
  final List<eccore.DeliveryZone> voisines;
  final eccore.GeoPoint cadrage;
  final Future<String> Function() villeDeLaCuisine;

  @override
  State<_FicheDeZone> createState() => _FicheDeZoneState();
}

class _FicheDeZoneState extends State<_FicheDeZone> {
  final _cle = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.existante?.name ?? '');
  late final _forfait = TextEditingController(
    text: widget.existante?.baseFee.toMajorUnits().toStringAsFixed(0) ?? '',
  );
  late final _parKm = TextEditingController(
    text: widget.existante?.feePerKm.toMajorUnits().toStringAsFixed(0) ?? '0',
  );
  late final _distanceMax = TextEditingController(
    text: widget.existante?.maxDistanceKm.toStringAsFixed(0) ?? '10',
  );
  late final _delai = TextEditingController(
    text: '${widget.existante?.estimatedDeliveryMinutes ?? 30}',
  );

  /// La forme dessinée **dans cette fiche** ; nulle tant qu'on ne l'a pas
  /// redessinée — une modification garde alors le contour existant.
  eccore.FormeDeZone? _forme;
  bool _envoi = false;
  String? _refus;

  bool get _creation => widget.existante == null;

  @override
  void dispose() {
    for (final champ in [_nom, _forfait, _parKm, _distanceMax, _delai]) {
      champ.dispose();
    }
    super.dispose();
  }

  Future<void> _dessiner() async {
    final existante = widget.existante;
    final forme = await EditeurDeZone.ouvrir(
      context,
      cadrage: widget.cadrage,
      brouillon: existante == null ? null : BrouillonDeZone.depuisZone(existante),
      voisines: widget.voisines,
    );
    if (forme != null && mounted) setState(() => _forme = forme);
  }

  eccore.Money _montant(TextEditingController champ) =>
      eccore.Money.fromMajorUnits(double.parse(champ.text.trim()), widget.cuisine.currency);

  Future<void> _enregistrer() async {
    if (!_cle.currentState!.validate()) return;
    final forme = _forme;
    if (_creation && forme == null) {
      setState(() => _refus = 'Dessinez la zone avant de l’enregistrer.');
      return;
    }
    setState(() {
      _envoi = true;
      _refus = null;
    });
    try {
      if (_creation) {
        await widget.depot.creer(
          restaurantSlug: widget.cuisine.slug,
          cityId: await widget.villeDeLaCuisine(),
          nom: _nom.text.trim(),
          forme: forme!,
          forfait: _montant(_forfait),
          parKm: _montant(_parKm),
          distanceMaxKm: double.parse(_distanceMax.text.trim()),
          dureeEstimeeMinutes: int.parse(_delai.text.trim()),
        );
      } else {
        await widget.depot.modifier(
          widget.existante!.id,
          nom: _nom.text.trim(),
          forme: forme,
          forfait: _montant(_forfait),
          parKm: _montant(_parKm),
          distanceMaxKm: double.parse(_distanceMax.text.trim()),
          dureeEstimeeMinutes: int.parse(_delai.text.trim()),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (erreur) {
      // Le refus du serveur — contour qui se croise, surface démesurée,
      // devise — reste affiché sous la fiche, qui reste ouverte.
      if (mounted) {
        setState(() {
          _envoi = false;
          _refus = messageErreur(erreur);
        });
      }
    }
  }

  String? _nombre(String? valeur, {bool entier = false}) {
    final texte = (valeur ?? '').trim();
    if (texte.isEmpty) return 'Obligatoire';
    final nombre = entier ? int.tryParse(texte) : double.tryParse(texte);
    if (nombre == null || nombre < 0) return 'Nombre positif attendu';
    return null;
  }

  String get _formeDecrite {
    final forme = _forme;
    if (forme == null) return _creation ? 'Aucune forme dessinée' : 'Forme actuelle conservée';
    return switch (forme) {
      eccore.ZoneCirculaire(:final rayonMetres) =>
        'Cercle de ${(rayonMetres / 1000).toStringAsFixed(1)} km',
      eccore.ZonePolygonale(:final sommets) => 'Polygone de ${sommets.length} sommets',
    };
  }

  @override
  Widget build(BuildContext context) {
    final devise = widget.cuisine.currency;

    return AlertDialog(
      title: Text(_creation ? 'Nouvelle zone' : 'Modifier « ${widget.existante!.name} »'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _cle,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nom,
                  decoration: const InputDecoration(labelText: 'Nom de la zone'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Obligatoire' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text(_formeDecrite)),
                    OutlinedButton.icon(
                      onPressed: _envoi ? null : _dessiner,
                      icon: const Icon(Icons.map_outlined),
                      label: Text(_creation && _forme == null ? 'Dessiner' : 'Redessiner'),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _forfait,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Forfait de livraison ($devise)'),
                  validator: _nombre,
                ),
                TextFormField(
                  controller: _parKm,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Supplément par km ($devise)'),
                  validator: _nombre,
                ),
                TextFormField(
                  controller: _distanceMax,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Distance maximale (km)'),
                  validator: _nombre,
                ),
                TextFormField(
                  controller: _delai,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Délai estimé (minutes)'),
                  validator: (v) => _nombre(v, entier: true),
                ),
                if (_refus != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _refus!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _envoi ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _envoi ? null : _enregistrer,
          child: _envoi
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
