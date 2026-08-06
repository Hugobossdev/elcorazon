import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/delivery_zone_service.dart';
import 'zone_form_dialog.dart';

/// Sélection des zones desservies.
///
/// C'est l'écran qui répond à « où livre-t-on ? ». Le barème d'une zone — ce
/// qu'elle coûte — se règle à côté, dans [ZoneFormDialog] ; ici on ne décide
/// que de l'**ouverture**, parce que c'est le geste courant : on ferme un
/// quartier le temps d'une pénurie de livreurs, on rouvre le lendemain, et
/// personne ne veut traverser un formulaire de tarification pour cela.
///
/// Trois choix méritent d'être expliqués :
///
/// * **une bascule part immédiatement sur le serveur.** Le bouton « Sauvegarder »
///   de l'écran des paramètres n'écrit que des préférences locales du poste ; y
///   raccrocher la couverture de livraison ferait croire qu'un quartier est
///   fermé alors qu'il est encore servi, jusqu'à un geste supplémentaire que
///   rien ne réclame. L'écran le dit, plutôt que de le laisser deviner ;
/// * **les zones fermées restent affichées.** Les masquer supprimerait le seul
///   endroit d'où on peut les rouvrir ;
/// * **il n'y a pas de suppression.** Des commandes passées portent les frais
///   de leur zone : l'effacer rendrait leur addition inexplicable. Fermer
///   retire la zone de la couverture sans réécrire le passé.
class ZoneSelectionTab extends StatefulWidget {
  const ZoneSelectionTab({super.key});

  @override
  State<ZoneSelectionTab> createState() => _ZoneSelectionTabState();
}

class _ZoneSelectionTabState extends State<ZoneSelectionTab> {
  final _rechercheController = TextEditingController();
  String _recherche = '';

  @override
  void dispose() {
    _rechercheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Consumer<DeliveryZoneService>(
      builder: (context, service, child) {
        final groupes = DeliveryZoneService.filterGroups(
          service.zonesByCity,
          _recherche,
        );

        return RefreshIndicator(
          onRefresh: service.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _buildIntro(scheme),
              const SizedBox(height: 16),
              if (service.zones.isNotEmpty) ...[
                _buildResume(service, scheme),
                const SizedBox(height: 16),
                _buildRecherche(scheme),
                const SizedBox(height: 16),
              ],
              if (service.error != null) ...[
                _buildErreur(service, scheme),
                const SizedBox(height: 16),
              ],
              if (service.isLoading && service.zones.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (service.zones.isEmpty)
                _buildAucuneZone(scheme)
              else if (groupes.isEmpty)
                _buildAucunResultat(scheme)
              else
                ...groupes.entries.map(
                  (entree) => _buildVille(service, entree.key, entree.value, scheme),
                ),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------ entête

  Widget _buildIntro(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Zones desservies',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Choisissez les zones où la livraison est proposée. Une zone fermée '
          'disparaît de la couverture : les clients qui s’y trouvent ne peuvent '
          'plus commander en livraison, et les commandes déjà passées gardent '
          'leurs frais.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.cloud_done_outlined, size: 16, color: scheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Chaque changement est enregistré sur le serveur immédiatement — '
                'le bouton « Sauvegarder » ne concerne pas cet onglet.',
                style: TextStyle(
                  color: scheme.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResume(DeliveryZoneService service, ColorScheme scheme) {
    final desservies = service.activeZones.length;
    final total = service.zones.length;
    final villes = service.zonesByCity.length;

    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.map_outlined, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$desservies zone${desservies > 1 ? 's' : ''} desservie'
                    '${desservies > 1 ? 's' : ''} sur $total',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Réparties sur $villes ville${villes > 1 ? 's' : ''}',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (desservies == 0)
              Tooltip(
                message: 'Aucune zone ouverte : la livraison est indisponible '
                    'pour tous les clients.',
                child: Icon(Icons.warning_amber_rounded, color: scheme.error),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecherche(ColorScheme scheme) {
    return TextField(
      controller: _rechercheController,
      onChanged: (valeur) => setState(() => _recherche = valeur),
      decoration: InputDecoration(
        hintText: 'Rechercher une zone ou une ville…',
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: _recherche.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Effacer',
                onPressed: () {
                  _rechercheController.clear();
                  setState(() => _recherche = '');
                },
              ),
      ),
    );
  }

  // ------------------------------------------------------------------- états

  Widget _buildErreur(DeliveryZoneService service, ColorScheme scheme) {
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                service.error!,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            TextButton(onPressed: service.refresh, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  Widget _buildAucuneZone(ColorScheme scheme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(Icons.map_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Aucune zone de livraison n’est enregistrée. Le contour d’une '
                'zone se dessine côté serveur ; son ouverture et son barème se '
                'règlent ensuite ici.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAucunResultat(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          'Aucune zone ne correspond à « $_recherche ».',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- villes

  Widget _buildVille(
    DeliveryZoneService service,
    String ville,
    List<DeliveryZone> zones,
    ColorScheme scheme,
  ) {
    final ouvertes = zones.where((zone) => zone.isActive).length;
    final toutesOuvertes = ouvertes == zones.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Icon(Icons.location_city, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ville,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '$ouvertes ouverte${ouvertes > 1 ? 's' : ''} '
                        'sur ${zones.length}',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _basculerVille(service, ville, zones, !toutesOuvertes),
                  child: Text(toutesOuvertes ? 'Tout fermer' : 'Tout ouvrir'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...zones.map((zone) => _buildZone(service, zone, scheme)),
        ],
      ),
    );
  }

  Widget _buildZone(
    DeliveryZoneService service,
    DeliveryZone zone,
    ColorScheme scheme,
  ) {
    final enCours = service.isWriting(zone.id);

    return SwitchListTile(
      value: zone.isActive,
      // Neutralisé pendant l'écriture : voir `DeliveryZoneService.isWriting`.
      onChanged: enCours ? null : (ouverte) => _basculerZone(service, zone, ouverte),
      title: Text(
        zone.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(_resume(zone), style: TextStyle(color: scheme.onSurfaceVariant)),
      secondary: enCours
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Modifier le barème',
              onPressed: () => _modifierBareme(zone),
            ),
    );
  }

  /// Ce que coûte la zone, en une ligne : c'est l'information qui décide de
  /// l'ouvrir ou non.
  String _resume(DeliveryZone zone) {
    final devise = zone.currency == 'XOF' ? 'FCFA' : zone.currency;
    String montant(double valeur) => valeur == valeur.roundToDouble()
        ? valeur.toStringAsFixed(0)
        : valeur.toStringAsFixed(2);

    final parties = [
      '${montant(zone.deliveryFee)} $devise + ${montant(zone.feePerKm)} $devise/km',
      '~${zone.estimatedTimeMinutes} min',
      if (zone.freeDeliveryThreshold != null)
        'offerte dès ${montant(zone.freeDeliveryThreshold!)} $devise',
    ];
    return parties.join(' · ');
  }

  // ------------------------------------------------------------------ actions

  Future<void> _basculerZone(
    DeliveryZoneService service,
    DeliveryZone zone,
    bool ouverte,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;

    final ecrit = await service.setZoneActive(zone.id, ouverte);
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ecrit
              ? '${ouverte ? '✅' : '⛔'} « ${zone.name} » '
                  '${ouverte ? 'est desservie' : 'n’est plus desservie'}'
              : service.error ?? 'Changement refusé par le serveur.',
        ),
        backgroundColor: ecrit ? scheme.inverseSurface : scheme.error,
      ),
    );
  }

  Future<void> _basculerVille(
    DeliveryZoneService service,
    String ville,
    List<DeliveryZone> zones,
    bool ouvrir,
  ) async {
    // Fermer une ville entière retire d'un coup la livraison à tous ses
    // clients : cela se confirme. L'ouvrir n'expose à rien qu'on ne puisse
    // défaire, et n'a donc pas à être ralenti.
    if (!ouvrir) {
      final confirme = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Fermer toutes les zones de $ville ?'),
          content: Text(
            'Les clients de ${zones.length} zone${zones.length > 1 ? 's' : ''} '
            'ne pourront plus commander en livraison. Les commandes en cours ne '
            'sont pas touchées.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Tout fermer'),
            ),
          ],
        ),
      );
      if (confirme != true || !mounted) return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;

    final resultat = await service.setZonesActive(
      zones.map((zone) => zone.id),
      ouvrir,
    );
    if (!mounted) return;

    final modifiees = resultat.modifiees;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          resultat.echec
              // La série s'est arrêtée en chemin : dire ce qui est passé avant
              // d'annoncer le refus, sinon l'exploitant croit que rien n'a
              // changé alors qu'une partie des zones a bien basculé.
              ? '${modifiees > 0 ? '$modifiees zone(s) modifiée(s), puis arrêt : ' : ''}'
                  '${service.error ?? 'changement refusé par le serveur.'}'
              : modifiees == 0
                  ? 'Aucun changement : les zones de $ville étaient déjà '
                      '${ouvrir ? 'ouvertes' : 'fermées'}.'
                  : '$modifiees zone${modifiees > 1 ? 's' : ''} '
                      '${ouvrir ? 'ouverte' : 'fermée'}${modifiees > 1 ? 's' : ''} '
                      'à $ville',
        ),
        backgroundColor: resultat.echec ? scheme.error : scheme.inverseSurface,
      ),
    );
  }

  Future<void> _modifierBareme(DeliveryZone zone) async {
    final enregistre = await ZoneFormDialog.show(context, zone);
    if (!enregistre || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Barème de « ${zone.name} » enregistré'),
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
      ),
    );
  }
}
