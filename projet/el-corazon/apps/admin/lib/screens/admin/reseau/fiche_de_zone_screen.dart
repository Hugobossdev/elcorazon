import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:admin/presentation/messages_erreur.dart';
import 'package:admin/services/admin_auth_service.dart';

/// Fiche d'une zone : son statut et les gestes que le serveur permet, son
/// contour **entier**, ses horaires, ses cuisines et sa flotte.
///
/// ## Ce que l'écran ne décide pas
///
/// * **les gestes proposés** sont ceux de `zone.transitions`, lus dans la
///   machine à états du serveur — l'écran ne recopie pas le graphe ;
/// * **l'ouverture** de la zone se juge au serveur (`zone_closed`) ; l'écran
///   liste les plages, il ne dit pas « ouverte maintenant » ;
/// * **les cuisines et livreurs** viennent des mêmes fonctions que la
///   commande et le dispatch (`/delivery/zones/{id}/…`).
///
/// Une zone de ville et une zone propre à une cuisine s'y ouvrent de la même
/// façon ; seul change le préfixe des gestes ([cuisine]).
class FicheDeZoneScreen extends StatefulWidget {
  const FicheDeZoneScreen({
    required this.zone,
    this.cuisine = false,
    this.peutEcrire = true,
    this.gestes,
    this.couverture,
    this.afficherCarte = true,
    this.surChangement,
    super.key,
  });

  final eccore.DeliveryZone zone;

  /// Zone propre à une cuisine : gestes sous `/restaurants/manage/zones/`.
  final bool cuisine;

  /// Le compte peut-il écrire sur cette zone ? Présentation seulement : le
  /// serveur refuse de toute façon (403).
  final bool peutEcrire;

  /// Injectés par les tests ; les vrais dépôts sinon.
  final eccore.ZoneLifecycleRepository? gestes;
  final eccore.CoverageRepository? couverture;

  /// La carte Google n'a pas de rendu en test de widget.
  final bool afficherCarte;

  /// Prévenu de chaque zone que le serveur rend — la liste appelante se tient
  /// ainsi à jour sans recharger.
  final ValueChanged<eccore.DeliveryZone>? surChangement;

  @override
  State<FicheDeZoneScreen> createState() => _FicheDeZoneScreenState();
}

class _FicheDeZoneScreenState extends State<FicheDeZoneScreen> {
  late eccore.DeliveryZone _zone = widget.zone;
  bool _enCours = false;
  String? _erreur;

  List<eccore.CuisineDeZone>? _cuisines;
  Map<String, List<eccore.LivreurDeZone>>? _livreurs;
  String? _erreurReseau;

  late final eccore.ZoneLifecycleRepository _gestes = widget.gestes ??
      (widget.cuisine
          ? eccore.ZoneLifecycleRepository.cuisine(apiClient: AdminAuthService().apiClient)
          : eccore.ZoneLifecycleRepository.ville(apiClient: AdminAuthService().apiClient));
  late final eccore.CoverageRepository _couverture =
      widget.couverture ?? eccore.CoverageRepository(apiClient: AdminAuthService().apiClient);

  @override
  void initState() {
    super.initState();
    _chargerReseau();
  }

  Future<void> _chargerReseau() async {
    try {
      final cuisines = await _couverture.cuisinesDe(_zone.id);
      Map<String, List<eccore.LivreurDeZone>>? livreurs;
      try {
        livreurs = await _couverture.livreursDe(_zone.id);
      } on eccore.ApiException catch (e) {
        // Sans `couriers.read`, la flotte reste tue : ce n'est pas une panne.
        if (e.status != 403) rethrow;
      }
      if (!mounted) return;
      setState(() {
        _cuisines = cuisines;
        _livreurs = livreurs;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _erreurReseau = messageErreur(e));
    }
  }

  Future<void> _faire(Future<eccore.DeliveryZone> Function() geste) async {
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      final maj = await geste();
      if (!mounted) return;
      setState(() => _zone = maj);
      widget.surChangement?.call(maj);
    } on Object catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  // ------------------------------------------------------------------ gestes

  Future<void> _suspendre() async {
    final saisie = await showDialog<({String motif, DateTime? fin})>(
      context: context,
      builder: (_) => _DialogueSuspension(relais: _zone.overlaps),
    );
    if (saisie == null) return;
    await _faire(() => _gestes.suspendre(_zone.id, motif: saisie.motif, finPrevue: saisie.fin));
  }

  Future<void> _archiver() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archiver la zone ?'),
        content: const Text(
          'Une zone archivée ne livre plus et ne revient pas. Ses commandes '
          'passées restent lisibles ; pour la rouvrir, dupliquez-la.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true), child: const Text('Archiver'),),
        ],
      ),
    );
    if (ok == true) await _faire(() => _gestes.archiver(_zone.id));
  }

  Future<void> _dupliquer() async {
    final nom = await _demanderTexte(
        'Dupliquer la zone', 'Nom de la nouvelle zone', '${_zone.name} (copie)',);
    if (nom == null || nom.trim().isEmpty) return;
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      final copie = await _gestes.dupliquer(_zone.id, nom: nom.trim());
      widget.surChangement?.call(copie);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('« ${copie.name} » créée en brouillon')),
      );
    } on Object catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<String?> _demanderTexte(String titre, String libelle, String initial) {
    final champ = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titre),
        content: TextField(controller: champ, decoration: InputDecoration(labelText: libelle)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, champ.text), child: const Text('Valider'),),
        ],
      ),
    );
  }

  Future<void> _modifierHoraires() async {
    final semaine = await showDialog<List<eccore.HoraireDeZone>>(
      context: context,
      builder: (_) => _DialogueHoraires(initiales: _zone.horaires),
    );
    if (semaine == null) return;
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await _gestes.ecrireHoraires(_zone.id, semaine);
      // Relire la fiche entière : c'est elle qui porte horaires et traçabilité.
      final maj = await _gestes.relire(_zone.id);
      if (!mounted) return;
      setState(() => _zone = maj);
      widget.surChangement?.call(maj);
    } on Object catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _ajouterException() async {
    final saisie = await showDialog<_SaisieException>(
      context: context,
      builder: (_) => const _DialogueException(),
    );
    if (saisie == null) return;
    await _faire(() async {
      await _gestes.ajouterException(
        _zone.id,
        nature: saisie.nature,
        debut: saisie.debut,
        fin: saisie.fin,
        motif: saisie.motif,
      );
      return _gestes.relire(_zone.id);
    });
  }

  Future<void> _retirerException(eccore.ExceptionDeZone exception) => _faire(() async {
        await _gestes.retirerException(_zone.id, exception.id);
        return _gestes.relire(_zone.id);
      });

  // ------------------------------------------------------------------- rendu

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_zone.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _entete(scheme),
          if (_erreur != null)
            Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_erreur!, style: TextStyle(color: scheme.onErrorContainer)),
              ),
            ),
          if (_enCours) const LinearProgressIndicator(),
          if (widget.peutEcrire) _gestesPermis(),
          if (_zone.overlaps.isNotEmpty) _chevauchement(scheme),
          if (widget.afficherCarte && _zone.polygones.isNotEmpty) _carte(),
          _tracabilite(),
          _horaires(),
          _reseau(scheme),
        ],
      ),
    );
  }

  Widget _entete(ColorScheme scheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          key: const Key('statut-zone'),
          label: Text(eccore.StatutZone.libelle(_zone.status)),
          backgroundColor: _zone.status == eccore.StatutZone.publiee
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
        ),
        Chip(label: Text('Priorité ${_zone.priority}')),
        Chip(
          label: Text(
            '${_zone.polygones.length} morceau${_zone.polygones.length > 1 ? 'x' : ''}'
            '${_trous == 0 ? '' : ' · $_trous trou${_trous > 1 ? 's' : ''}'}',
          ),
        ),
        Chip(
            label:
                Text('Forfait ${_zone.baseFee.format()} · ${_zone.estimatedDeliveryMinutes} min'),),
      ],
    );
  }

  int get _trous => _zone.polygones.fold(0, (n, p) => n + (p.length - 1));

  Widget _gestesPermis() {
    final t = _zone.transitions;
    final boutons = <Widget>[
      if (t.contains(eccore.StatutZone.enRevue))
        FilledButton.tonal(
          onPressed: _enCours ? null : () => _faire(() => _gestes.soumettre(_zone.id)),
          child: const Text('Soumettre à la revue'),
        ),
      if (t.contains(eccore.StatutZone.publiee) && _zone.status == eccore.StatutZone.enRevue)
        FilledButton(
          onPressed: _enCours ? null : () => _faire(() => _gestes.publier(_zone.id)),
          child: const Text('Publier'),
        ),
      if (t.contains(eccore.StatutZone.brouillon))
        OutlinedButton(
          onPressed: _enCours ? null : () => _faire(() => _gestes.renvoyerEnBrouillon(_zone.id)),
          child: const Text('Renvoyer en brouillon'),
        ),
      if (t.contains(eccore.StatutZone.suspendue))
        OutlinedButton(
          onPressed: _enCours ? null : _suspendre,
          child: const Text('Suspendre'),
        ),
      if (t.contains(eccore.StatutZone.publiee) && _zone.status == eccore.StatutZone.suspendue)
        FilledButton(
          onPressed: _enCours ? null : () => _faire(() => _gestes.reactiver(_zone.id)),
          child: const Text('Réactiver'),
        ),
      if (t.contains(eccore.StatutZone.archivee))
        TextButton(onPressed: _enCours ? null : _archiver, child: const Text('Archiver')),
      TextButton.icon(
        onPressed: _enCours ? null : _dupliquer,
        icon: const Icon(Icons.copy_outlined),
        label: const Text('Dupliquer'),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Wrap(spacing: 8, runSpacing: 8, children: boutons),
    );
  }

  Widget _chevauchement(ColorScheme scheme) {
    return Card(
      color: scheme.tertiaryContainer,
      child: ListTile(
        leading: const Icon(Icons.warning_amber_outlined),
        title: const Text('Chevauchement détecté'),
        subtitle: Text(
          'Recouvre : ${_zone.overlaps.join(', ')}.\n'
          'Règle de résolution : la zone propre à la cuisine, puis la priorité '
          'la plus haute, puis la plus petite surface. Un chevauchement peut '
          'être voulu — une exception tarifaire dans une zone plus large.',
        ),
      ),
    );
  }

  Widget _carte() {
    LatLng ll(eccore.GeoPoint p) => LatLng(p.latitude, p.longitude);
    final polygones = <Polygon>{
      for (final (i, morceau) in _zone.polygones.indexed)
        Polygon(
          polygonId: PolygonId('morceau-$i'),
          points: morceau.first.map(ll).toList(),
          // Les anneaux suivants sont des trous : des enclaves non desservies.
          holes: [for (final trou in morceau.skip(1)) trou.map(ll).toList()],
          strokeWidth: 2,
          fillColor: Colors.teal.withValues(alpha: 0.2),
          strokeColor: Colors.teal,
        ),
    };
    final premier = _zone.polygones.first.first.first;
    return SizedBox(
      height: 280,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: ll(premier), zoom: 11),
          polygons: polygones,
          myLocationButtonEnabled: false,
        ),
      ),
    );
  }

  Widget _tracabilite() {
    String quand(DateTime? d) => d == null
        ? '—'
        : '${d.toLocal().day.toString().padLeft(2, '0')}/${d.toLocal().month.toString().padLeft(2, '0')}/${d.toLocal().year}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Traçabilité', style: Theme.of(context).textTheme.titleMedium),
            Text('Créée par ${_zone.createdBy ?? '—'} le ${quand(_zone.createdAt)}'),
            Text('Modifiée par ${_zone.updatedBy ?? '—'} le ${quand(_zone.updatedAt)}'),
            Text('Publiée par ${_zone.publishedBy ?? '—'} le ${quand(_zone.publishedAt)}'),
            if (_zone.status == eccore.StatutZone.suspendue)
              Text(
                'Suspendue : ${_zone.suspensionReason}'
                '${_zone.suspensionExpectedEndAt == null ? '' : ' — fin annoncée le ${quand(_zone.suspensionExpectedEndAt)}'}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _horaires() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Horaires', style: Theme.of(context).textTheme.titleMedium)),
                if (widget.peutEcrire)
                  TextButton(
                      onPressed: _enCours ? null : _modifierHoraires,
                      child: const Text('Modifier'),),
              ],
            ),
            if (_zone.horaires.isEmpty)
              const Text('Aucune plage : la zone suit les horaires de sa cuisine.')
            else
              for (final h in _zone.horaires)
                Text(
                  '${eccore.HoraireDeZone.jours[h.jour]} ${h.ouvre} – ${h.ferme}'
                  '${h.franchitMinuit ? ' (lendemain)' : ''}',
                ),
            const Divider(),
            Row(
              children: [
                const Expanded(child: Text('Exceptions à venir')),
                if (widget.peutEcrire)
                  TextButton(
                      onPressed: _enCours ? null : _ajouterException, child: const Text('Ajouter'),),
              ],
            ),
            if (_zone.exceptions.isEmpty) const Text('Aucune.'),
            for (final e in _zone.exceptions)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(e.estUneFermeture ? Icons.block : Icons.event_available),
                title: Text(
                  '${e.estUneFermeture ? 'Fermeture' : 'Ouverture'} · ${e.motif.isEmpty ? 'sans motif' : e.motif}',
                ),
                subtitle: Text('${e.debut.toLocal()} → ${e.fin.toLocal()}'),
                trailing: widget.peutEcrire
                    ? IconButton(
                        tooltip: 'Retirer',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _enCours ? null : () => _retirerException(e),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _reseau(ColorScheme scheme) {
    if (_erreurReseau != null) {
      return Card(
          child:
              ListTile(title: const Text('Cuisines et livreurs'), subtitle: Text(_erreurReseau!)),);
    }
    final cuisines = _cuisines;
    if (cuisines == null) {
      return const Padding(
          padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()),);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cuisines desservies', style: Theme.of(context).textTheme.titleMedium),
            if (cuisines.isEmpty) const Text('Aucune cuisine ne livre cette zone.'),
            for (final c in cuisines) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    Icon(c.peutCommander ? Icons.storefront : Icons.store_mall_directory_outlined),
                title: Text(c.nom),
                subtitle: Text(
                  '${c.ville} · ${c.distanceM == 0 ? 'dans la zone' : 'à ${((c.distanceM ?? 0) / 1000).toStringAsFixed(1)} km'}'
                  ' · ${c.peutCommander ? 'prend des commandes' : (c.motif ?? c.statut)}'
                  ' · ${c.commandesEnCours} en cuisine',
                ),
              ),
              if (_livreurs != null)
                for (final l in _livreurs![c.slug] ?? const <eccore.LivreurDeZone>[])
                  Padding(
                    padding: const EdgeInsets.only(left: 40),
                    child: Row(
                      children: [
                        Icon(
                          l.eligible ? Icons.check_circle : Icons.remove_circle_outline,
                          size: 16,
                          color: l.eligible ? scheme.primary : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                            child:
                                Text('${l.nom} — ${eccore.LivreurDeZone.libelleMotif(l.motif)}'),),
                      ],
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- dialogues

class _DialogueSuspension extends StatefulWidget {
  const _DialogueSuspension({required this.relais});

  /// Zones actives qui recoupent celle-ci : là où elles la couvrent, elles
  /// prennent le relais (`explain_resolution`) — suspendre ne coupe pas tout.
  final List<String> relais;

  @override
  State<_DialogueSuspension> createState() => _DialogueSuspensionState();
}

class _DialogueSuspensionState extends State<_DialogueSuspension> {
  final _motif = TextEditingController();
  int? _heures;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Suspendre la zone'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('motif-suspension'),
            controller: _motif,
            decoration: const InputDecoration(labelText: 'Motif (obligatoire)'),
            onChanged: (_) => setState(() {}),
          ),
          DropdownButtonFormField<int?>(
            initialValue: _heures,
            decoration: const InputDecoration(labelText: 'Fin annoncée'),
            items: const [
              DropdownMenuItem(child: Text('Sans date')),
              DropdownMenuItem(value: 2, child: Text('Dans 2 heures')),
              DropdownMenuItem(value: 12, child: Text('Dans 12 heures')),
              DropdownMenuItem(value: 24, child: Text('Dans 24 heures')),
            ],
            onChanged: (v) => setState(() => _heures = v),
          ),
          if (widget.relais.isNotEmpty)
            Padding(
              key: const Key('relais-suspension'),
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Là où elle recoupe ${widget.relais.join(', ')}, ces zones '
                'continueront de livrer. Pour couper la livraison d’un quartier, '
                'suspendez toutes les zones qui le couvrent.',
              ),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: _motif.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, (
                    motif: _motif.text.trim(),
                    fin: _heures == null ? null : DateTime.now().add(Duration(hours: _heures!)),
                  ),),
          child: const Text('Suspendre'),
        ),
      ],
    );
  }
}

class _DialogueHoraires extends StatefulWidget {
  const _DialogueHoraires({required this.initiales});

  final List<eccore.HoraireDeZone> initiales;

  @override
  State<_DialogueHoraires> createState() => _DialogueHorairesState();
}

class _DialogueHorairesState extends State<_DialogueHoraires> {
  late final List<eccore.HoraireDeZone> _plages = List.of(widget.initiales);
  int _jour = 0;
  final _ouvre = TextEditingController(text: '11:00');
  final _ferme = TextEditingController(text: '22:00');
  String? _erreur;

  static final _hhmm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  void _ajouter() {
    if (!_hhmm.hasMatch(_ouvre.text) || !_hhmm.hasMatch(_ferme.text)) {
      setState(() => _erreur = 'Heures au format HH:MM.');
      return;
    }
    setState(() {
      _erreur = null;
      _plages.add(eccore.HoraireDeZone(jour: _jour, ouvre: _ouvre.text, ferme: _ferme.text));
      _plages.sort((a, b) => a.jour != b.jour ? a.jour - b.jour : a.ouvre.compareTo(b.ouvre));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Horaires de la zone'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Vide : la zone suit les horaires de sa cuisine. Le serveur valide la semaine.',),
            for (final (i, p) in _plages.indexed)
              ListTile(
                dense: true,
                title: Text('${eccore.HoraireDeZone.jours[p.jour]} ${p.ouvre} – ${p.ferme}'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _plages.removeAt(i)),
                ),
              ),
            Row(
              children: [
                DropdownButton<int>(
                  value: _jour,
                  items: [
                    for (final (i, j) in eccore.HoraireDeZone.jours.indexed)
                      DropdownMenuItem(value: i, child: Text(j)),
                  ],
                  onChanged: (v) => setState(() => _jour = v ?? 0),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: _ouvre, decoration: const InputDecoration(labelText: 'Ouvre'),),),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: _ferme, decoration: const InputDecoration(labelText: 'Ferme'),),),
                IconButton(icon: const Icon(Icons.add), onPressed: _ajouter),
              ],
            ),
            if (_erreur != null)
              Text(_erreur!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _plages), child: const Text('Enregistrer'),),
      ],
    );
  }
}

class _SaisieException {
  const _SaisieException(this.nature, this.debut, this.fin, this.motif);

  final String nature;
  final DateTime debut;
  final DateTime fin;
  final String motif;
}

class _DialogueException extends StatefulWidget {
  const _DialogueException();

  @override
  State<_DialogueException> createState() => _DialogueExceptionState();
}

class _DialogueExceptionState extends State<_DialogueException> {
  String _nature = eccore.NatureExceptionZone.fermeture;
  DateTime? _jour;
  final _motif = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Exception d’horaires'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: eccore.NatureExceptionZone.fermeture, label: Text('Fermeture')),
              ButtonSegment(value: eccore.NatureExceptionZone.ouverture, label: Text('Ouverture')),
            ],
            selected: {_nature},
            onSelectionChanged: (s) => setState(() => _nature = s.first),
          ),
          ListTile(
            title: Text(
                _jour == null ? 'Choisir le jour' : '${_jour!.day}/${_jour!.month}/${_jour!.year}',),
            subtitle: const Text('La journée entière, à l’heure de l’appareil'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final maintenant = DateTime.now();
              final choisi = await showDatePicker(
                context: context,
                firstDate: DateTime(maintenant.year, maintenant.month, maintenant.day),
                lastDate: maintenant.add(const Duration(days: 366)),
              );
              if (choisi != null) setState(() => _jour = choisi);
            },
          ),
          TextField(
              controller: _motif,
              decoration: const InputDecoration(labelText: 'Motif (jour férié…)'),),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: _jour == null
              ? null
              : () => Navigator.pop(
                    context,
                    _SaisieException(
                        _nature, _jour!, _jour!.add(const Duration(days: 1)), _motif.text.trim(),),
                  ),
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
