import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

import 'package:admin/presentation/messages_erreur.dart';
import 'package:admin/services/admin_auth_service.dart';

/// « Tester une adresse » — ce que la commande ferait, à ce point.
///
/// **Tout vient du serveur** (`POST /delivery/coverage-test/`), qui passe par
/// la fonction même qu'appelle la création de commande : zone retenue et
/// pourquoi, zones écartées et pourquoi, cuisine, distance, frais, délai,
/// livreurs éligibles. L'écran ne recalcule rien ; il ne fait que lire.
class TesterUneAdresseScreen extends StatefulWidget {
  const TesterUneAdresseScreen({this.depot, super.key});

  /// Injecté par les tests ; le vrai dépôt sinon.
  final eccore.CoverageRepository? depot;

  @override
  State<TesterUneAdresseScreen> createState() => _TesterUneAdresseScreenState();
}

class _TesterUneAdresseScreenState extends State<TesterUneAdresseScreen> {
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _sousTotal = TextEditingController();
  final _devise = TextEditingController(text: 'XOF');
  final _cuisine = TextEditingController();

  late final eccore.CoverageRepository _depot =
      widget.depot ?? eccore.CoverageRepository(apiClient: AdminAuthService().apiClient);

  eccore.RapportDeCouverture? _rapport;
  String? _erreur;
  bool _enCours = false;

  Future<void> _tester() async {
    final lat = double.tryParse(_latitude.text.replaceAll(',', '.'));
    final lon = double.tryParse(_longitude.text.replaceAll(',', '.'));
    if (lat == null || lon == null) {
      setState(() => _erreur = 'Saisissez une latitude et une longitude.');
      return;
    }
    final montant = double.tryParse(_sousTotal.text.replaceAll(',', '.'));
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      final rapport = await _depot.tester(
        latitude: lat,
        longitude: lon,
        sousTotal: montant == null
            ? null
            : eccore.Money.fromMajorUnits(montant, _devise.text.trim().toUpperCase()),
        cuisineSlug: _cuisine.text.trim(),
      );
      if (mounted) setState(() => _rapport = rapport);
    } on Object catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tester une adresse')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _champ(_latitude, 'Latitude', const Key('latitude')),
              _champ(_longitude, 'Longitude', const Key('longitude')),
              _champ(_sousTotal, 'Panier (facultatif)', const Key('sous-total')),
              _champ(_devise, 'Devise', const Key('devise'), largeur: 90),
              _champ(_cuisine, 'Cuisine (slug, facultatif)', const Key('cuisine')),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _enCours ? null : _tester,
            icon: const Icon(Icons.travel_explore),
            label: const Text('Tester'),
          ),
          if (_enCours) const LinearProgressIndicator(),
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_erreur!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (_rapport != null) _Rapport(rapport: _rapport!),
        ],
      ),
    );
  }

  Widget _champ(TextEditingController c, String libelle, Key key, {double largeur = 200}) =>
      SizedBox(
        width: largeur,
        child: TextField(
          key: key,
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(labelText: libelle),
        ),
      );
}

class _Rapport extends StatelessWidget {
  const _Rapport({required this.rapport});

  final eccore.RapportDeCouverture rapport;

  static String _motif(String? code) => switch (code) {
        null => '',
        eccore.MotifIndisponibilite.aucuneCuisine => 'Aucune cuisine ne dessert ce point.',
        eccore.MotifIndisponibilite.adresseNonDesservie =>
          'Adresse hors zone, ou trop loin de la cuisine.',
        eccore.MotifIndisponibilite.zoneFermee => 'La zone est fermée à cette heure.',
        eccore.MotifIndisponibilite.zoneSuspendue => 'La zone est suspendue.',
        _ => code,
      };

  static String _exclusion(String? motif) => switch (motif) {
        null => 'concourait',
        'closed' => 'fermée à cette heure',
        'other_kitchen' => 'propre à une autre cuisine',
        'other_city' => 'zone d’une autre ville',
        _ => eccore.StatutZone.libelle(motif),
      };

  @override
  Widget build(BuildContext context) {
    final r = rapport;
    final scheme = Theme.of(context).colorScheme;
    final lignes = <(String, String)>[
      ('Pays', r.pays ?? '—'),
      ('Ville', r.ville ?? '—'),
      (
        'Zone',
        r.zone == null
            ? 'Aucune'
            : '${r.zone!.nom} (${eccore.StatutZone.libelle(r.zone!.statut)}, priorité ${r.zone!.priorite})'
      ),
      ('Pourquoi', r.raisonDuChoix ?? '—'),
      (
        'Cuisine',
        r.cuisine == null
            ? 'Aucune'
            : '${r.cuisine!.nom}${r.cuisine!.peutCommander ? '' : ' — ne prend pas de commande (${r.cuisine!.motif})'}'
      ),
      (
        'Charge de la cuisine',
        r.cuisine == null ? '—' : '${r.cuisine!.commandesEnCours} commande(s) en cuisine'
      ),
      ('Distance', r.distanceM == null ? '—' : '${(r.distanceM! / 1000).toStringAsFixed(2)} km'),
      (
        'Frais',
        r.frais == null
            ? 'Indiquez un panier pour chiffrer'
            : '${r.frais!.format()}${r.gratuite == true ? ' (offerte, valeur ${r.fraisBruts!.format()})' : ''}'
      ),
      ('Délai annoncé', r.delaiMinutes == null ? '—' : '${r.delaiMinutes} min'),
      ('Commande minimale', r.commandeMinimum?.format() ?? 'Aucune'),
      ('Livraison offerte dès', r.francoDes?.format() ?? 'Jamais'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            key: const Key('verdict'),
            color: r.disponible ? scheme.primaryContainer : scheme.errorContainer,
            child: ListTile(
              leading: Icon(r.disponible ? Icons.check_circle : Icons.cancel),
              title: Text(r.disponible ? 'Livrable' : 'Non livrable'),
              subtitle: r.disponible ? null : Text('${_motif(r.motif)}\n${r.raison ?? ''}'.trim()),
            ),
          ),
          for (final (libelle, valeur) in lignes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                      width: 180,
                      child: Text(libelle, style: TextStyle(color: scheme.onSurfaceVariant)),),
                  Expanded(child: Text(valeur)),
                ],
              ),
            ),
          if (r.zoneLaPlusProche != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.near_me_outlined),
                title: Text('Zone la plus proche : ${r.zoneLaPlusProche!.nom}'),
                subtitle: Text(
                    'à ${((r.zoneLaPlusProche!.distanceM ?? 0) / 1000).toStringAsFixed(1)} km',),
              ),
            ),
          if (r.candidates.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Zones qui couvrent ce point', style: Theme.of(context).textTheme.titleMedium),
            for (final c in r.candidates)
              ListTile(
                dense: true,
                leading: Text('#${(c.rang ?? 0) + 1}'),
                title: Text(
                    '${c.nom} — priorité ${c.priorite}, ${c.surfaceKm2?.toStringAsFixed(2) ?? '?'} km²',),
                subtitle: Text(c.id == r.zone?.id ? 'retenue' : _exclusion(c.exclueCar)),
              ),
          ],
          const SizedBox(height: 12),
          Text('Livreurs', style: Theme.of(context).textTheme.titleMedium),
          if (r.livreurs == null)
            const Text('Non visibles pour ce compte (couriers.read, ou cuisine hors périmètre).')
          else if (r.livreurs!.isEmpty)
            const Text('Aucun livreur rattaché.')
          else
            for (final l in r.livreurs!)
              Text(
                  '${l.eligible ? '✓' : '✗'} ${l.nom} — ${eccore.LivreurDeZone.libelleMotif(l.motif)}',),
        ],
      ),
    );
  }
}
