import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:elcora_fast/services/location_service.dart';
import 'package:elcora_fast/services/restaurant_context_service.dart';

/// **Choisir sa ville, puis sa cuisine.**
///
/// ## Ce que cet écran comble
///
/// `RestaurantContextService` savait depuis l'origine lister les
/// établissements, en désigner un et prévenir les caches du changement —
/// `hasChoice` et `select()` existaient. **Aucun écran ne les appelait.** Le
/// client se voyait donc attribuer le premier établissement rendu par le
/// serveur, sans jamais savoir qu'il y en avait d'autres, ni pouvoir en
/// changer : le multi-cuisine était complet côté serveur et invisible côté
/// client.
///
/// ## Ville d'abord, cuisine ensuite
///
/// La hiérarchie de l'écran suit celle des données (`Country → City →
/// Restaurant`). Une liste plate de dix restaurants répartis sur trois villes
/// oblige à lire chaque ligne pour trouver la sienne ; les villes en tête
/// réduisent le choix avant de le poser.
///
/// Le filtre par ville n'apparaît qu'à partir de deux villes, comme la feuille
/// elle-même n'est ouverte qu'à partir de deux établissements : un filtre à une
/// seule valeur est une décoration qui coûte un geste.
///
/// ## La position n'est pas demandée d'office
///
/// Le tri par proximité est proposé, pas imposé. Réclamer la géolocalisation au
/// lancement pour ordonner une liste est un coût disproportionné — et un refus,
/// une fois donné, est difficile à reprendre. Le bouton « Autour de moi » pose
/// la question au moment où la réponse sert visiblement à quelque chose.
///
/// Le tri **ne change pas** l'établissement courant : quelqu'un qui a choisi
/// une cuisine précise la garde en changeant de quartier. C'est une aide à la
/// découverte, pas une décision prise à sa place.
class SelecteurEtablissementSheet extends StatefulWidget {
  const SelecteurEtablissementSheet({super.key});

  /// Ouvre la feuille. Rend `true` si l'établissement courant a changé.
  ///
  /// Le booléen sert à l'appelant qui doit recharger son écran : changer de
  /// cuisine change le catalogue et les prix, et laisser les plats précédents
  /// affichés sous le nouveau nom serait pire qu'une liste vide, parce que rien
  /// ne le signalerait.
  static Future<bool> ouvrir(BuildContext context) async {
    final choisi = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const SelecteurEtablissementSheet(),
    );
    return choisi ?? false;
  }

  @override
  State<SelecteurEtablissementSheet> createState() => _SelecteurEtablissementSheetState();
}

class _SelecteurEtablissementSheetState extends State<SelecteurEtablissementSheet> {
  /// Ville retenue, ou `null` pour « toutes ».
  String? _ville;

  /// Une demande de position est-elle en cours ?
  bool _localisation = false;

  Future<void> _trierParProximite() async {
    setState(() => _localisation = true);
    try {
      final position = await context.read<LocationService>().getCurrentLocation();
      if (!mounted) return;

      if (position == null) {
        // Pas de message d'échec technique : `LocationService` a déjà retenu la
        // cause, et l'écran d'adresses sait la présenter avec le geste de
        // correction. Ici, la liste reste simplement dans son ordre précédent —
        // ce qui est un état parfaitement utilisable.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Position indisponible : la liste garde son ordre habituel.'),
          ),
        );
        return;
      }

      await context.read<RestaurantContextService>().trierParProximite(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } finally {
      if (mounted) setState(() => _localisation = false);
    }
  }

  Future<void> _choisir(eccore.Restaurant etablissement) async {
    final contexte = context.read<RestaurantContextService>();
    final avant = contexte.slug;
    await contexte.select(etablissement.slug);
    if (mounted) Navigator.of(context).pop(avant != contexte.slug);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Consumer<RestaurantContextService>(
      builder: (context, contexte, _) {
        final villes = contexte.villesDesservies;
        // La ville retenue peut avoir disparu entre deux chargements — son
        // dernier restaurant vient d'être suspendu. On retombe alors sur
        // « toutes » plutôt que d'afficher une liste vide inexplicable.
        final villeActive = (_ville != null && villes.contains(_ville)) ? _ville : null;
        final etablissements = villeActive == null
            ? contexte.restaurants
            : contexte.etablissementsDe(villeActive);

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Choisir une cuisine',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _localisation ? null : _trierParProximite,
                      icon: _localisation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 18),
                      label: const Text('Autour de moi'),
                    ),
                  ],
                ),
              ),
              if (villes.length > 1)
                _FiltreVilles(
                  villes: villes,
                  active: villeActive,
                  onChanged: (ville) => setState(() => _ville = ville),
                ),
              if (contexte.isLoading) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: etablissements.isEmpty
                    ? const _AucunEtablissement()
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: etablissements.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _CarteEtablissement(
                          etablissement: etablissements[index],
                          estCourant: etablissements[index].slug == contexte.slug,
                          onTap: () => _choisir(etablissements[index]),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FiltreVilles extends StatelessWidget {
  const _FiltreVilles({
    required this.villes,
    required this.active,
    required this.onChanged,
  });

  final List<String> villes;
  final String? active;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Toutes'),
              selected: active == null,
              onSelected: (_) => onChanged(null),
            ),
          ),
          for (final ville in villes)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(ville),
                selected: active == ville,
                onSelected: (_) => onChanged(ville),
              ),
            ),
        ],
      ),
    );
  }
}

/// Une cuisine, avec ce qui décide du choix : où elle est, si elle sert
/// maintenant, et à quelle distance quand on le sait.
class _CarteEtablissement extends StatelessWidget {
  const _CarteEtablissement({
    required this.etablissement,
    required this.estCourant,
    required this.onTap,
  });

  final eccore.Restaurant etablissement;
  final bool estCourant;
  final VoidCallback onTap;

  /// « 1,2 km » ou « 850 m ». Nul quand le serveur n'a pas mesuré — c'est le
  /// cas tant qu'on n'a pas trié par proximité, et afficher « 0 km » ferait
  /// croire à une proximité qu'on n'a pas établie.
  String? get _distance {
    final metres = etablissement.distanceMeters;
    if (metres == null) return null;
    if (metres < 1000) return '${metres.round()} m';
    return '${(metres / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final distance = _distance;

    return Card(
      elevation: 0,
      color: estCourant ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: estCourant ? scheme.primary : scheme.surfaceContainerHigh,
          child: Icon(
            Icons.storefront,
            color: estCourant ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          etablissement.name,
          style: TextStyle(
            fontWeight: estCourant ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                etablissement.cityName,
                if (distance != null) distance,
              ].where((partie) => partie.isNotEmpty).join(' · '),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            // Les trois états sont rendus séparément par le serveur
            // (`is_open`, `accepts_orders`, `can_order_now`) précisément pour
            // qu'on puisse dire *pourquoi* on ne peut pas commander : « fermé,
            // ouvre à 11 h » n'est pas « débordé, réessayez ».
            _Etat(etablissement: etablissement),
          ],
        ),
        trailing: estCourant
            ? Icon(Icons.check_circle, color: scheme.primary)
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _Etat extends StatelessWidget {
  const _Etat({required this.etablissement});

  final eccore.Restaurant etablissement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (texte, couleur) = switch (etablissement) {
      final r when r.canOrderNow => ('Ouvert', scheme.primary),
      final r when !r.isOpen => ('Fermé pour le moment', scheme.onSurfaceVariant),
      _ => ('Ne prend pas de commandes', scheme.error),
    };

    return Text(
      texte,
      style: TextStyle(fontSize: 12, color: couleur, fontWeight: FontWeight.w600),
    );
  }
}

class _AucunEtablissement extends StatelessWidget {
  const _AucunEtablissement();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Aucune cuisine dans cette ville',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Choisissez une autre ville, ou revenez plus tard.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
