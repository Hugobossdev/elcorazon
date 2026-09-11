import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/screens/admin/reseau/duplication_dialog.dart';
import 'package:admin/screens/admin/reseau/etablissement_form_dialog.dart';
import 'package:admin/screens/admin/reseau/pays_form_dialog.dart';
import 'package:admin/screens/admin/reseau/provisionnement_screen.dart';
import 'package:admin/screens/admin/reseau/ville_form_dialog.dart';
import 'package:admin/screens/admin/reseau/zone_creation_dialog.dart';
import 'package:admin/services/delivery_zone_service.dart';
import 'package:admin/services/network_service.dart';

/// Le réseau : marchés, villes, établissements.
///
/// Trois onglets dans l'ordre où l'on provisionne, parce que c'est un ordre
/// **imposé par le schéma** et non une préférence d'ergonomie : une ville se
/// rattache à un pays, une zone à une ville, un établissement à une zone. Un
/// écran qui laisserait commencer par la fin ne ferait qu'échouer plus tard,
/// avec un message de clé étrangère.
///
/// Chaque onglet montre les entités **fermées comprises** : c'est d'ici qu'on
/// rouvre un marché, et masquer les fermés rendrait le geste impossible depuis
/// l'écran même qui sert à le faire.
class ReseauScreen extends StatefulWidget {
  const ReseauScreen({super.key});

  @override
  State<ReseauScreen> createState() => _ReseauScreenState();
}

class _ReseauScreenState extends State<ReseauScreen> with SingleTickerProviderStateMixin {
  late final TabController _onglets;

  @override
  void initState() {
    super.initState();
    _onglets = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NetworkService>().resolve();
    });
  }

  @override
  void dispose() {
    _onglets.dispose();
    super.dispose();
  }

  Future<void> _ajouter() async {
    final reseau = context.read<NetworkService>();
    switch (_onglets.index) {
      case 0:
        if (await PaysFormDialog.show(context)) await reseau.refresh();
      case 1:
        if (mounted && await VilleFormDialog.show(context)) await reseau.refresh();
      case 2:
        if (mounted && await EtablissementFormDialog.show(context)) await reseau.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkService>(
      builder: (context, reseau, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Réseau'),
            bottom: TabBar(
              controller: _onglets,
              tabs: const [
                Tab(icon: Icon(Icons.public), text: 'Marchés'),
                Tab(icon: Icon(Icons.location_city), text: 'Villes'),
                Tab(icon: Icon(Icons.storefront), text: 'Établissements'),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Recharger',
                onPressed: reseau.isLoading ? null : reseau.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: Column(
            children: [
              if (reseau.error != null) _Bandeau(message: reseau.error!),
              if (reseau.isLoading) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: TabBarView(
                  controller: _onglets,
                  children: const [
                    _OngletPays(),
                    _OngletVilles(),
                    _OngletEtablissements(),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: reseau.isLoading ? null : _ajouter,
            icon: const Icon(Icons.add),
            label: Text(
              switch (_onglets.index) {
                0 => 'Ouvrir un marché',
                1 => 'Ouvrir une ville',
                _ => 'Ouvrir un établissement',
              },
            ),
          ),
        );
      },
    );
  }
}

class _Bandeau extends StatelessWidget {
  const _Bandeau({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

class _OngletPays extends StatelessWidget {
  const _OngletPays();

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkService>(
      builder: (context, reseau, _) {
        if (reseau.countries.isEmpty) {
          return const _Vide(
            icone: Icons.public_off,
            titre: 'Aucun marché',
            texte: "Un marché porte la devise et le fuseau de tout ce qu'on ouvrira "
                'dedans. Commencez par là.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: reseau.countries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final pays = reseau.countries[index];
            final villes = reseau.citiesOf(pays.isoCode).length;

            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(pays.isoCode)),
                title: Text(pays.name),
                subtitle: Text(
                  '${pays.currency} · ${pays.timezone} · ${pays.phonePrefix} · '
                  '$villes ville(s)',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Switch(
                  value: pays.isActive,
                  onChanged: reseau.isLoading
                      ? null
                      : (actif) => reseau.setCountryActive(pays.isoCode, actif),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _OngletVilles extends StatelessWidget {
  const _OngletVilles();

  @override
  Widget build(BuildContext context) {
    return Consumer2<NetworkService, DeliveryZoneService>(
      builder: (context, reseau, zones, _) {
        if (reseau.cities.isEmpty) {
          return const _Vide(
            icone: Icons.location_off,
            titre: 'Aucune ville',
            texte: 'Une ville se rattache à un marché ouvert. Elle porte les '
                'zones de livraison, qui portent les barèmes.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: reseau.cities.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final ville = reseau.cities[index];
            final zonesDeLaVille =
                zones.zones.where((zone) => zone.cityId == ville.id).toList();
            final etablissements = reseau.restaurantsOf(ville.slug).length;

            return Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.location_city),
                    title: Text('${ville.name} — ${ville.countryIsoCode}'),
                    subtitle: Text(
                      '${zonesDeLaVille.length} zone(s) · $etablissements établissement(s)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Switch(
                      value: ville.isActive,
                      onChanged: reseau.isLoading
                          ? null
                          : (actif) => reseau.setCityActive(ville.id, actif),
                    ),
                  ),
                  if (zonesDeLaVille.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Aucune zone : aucun établissement n'y est créable.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final creee = await ZoneCreationDialog.show(context, ville);
                              if (creee != null && context.mounted) {
                                await context.read<NetworkService>().refresh();
                              }
                            },
                            child: const Text('Ouvrir une zone'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Établissements du réseau — recherche, filtres, et une ligne par cuisine.
///
/// ## Pourquoi le filtre est appliqué ici et non demandé au serveur
///
/// `NetworkService` charge le réseau **entier** une fois : c'est ce dont les
/// trois onglets ont besoin ensemble — l'onglet Villes compte les
/// établissements de chaque ville, l'onglet Marchés compte les villes. Refaire
/// une requête filtrée à chaque frappe viderait cette liste partagée et ferait
/// clignoter les deux autres onglets.
///
/// Le filtre serveur existe et sert ailleurs
/// (`ManagedRestaurantRepository.list`) : il est fait pour les écrans qui ne
/// chargent qu'une population. À l'échelle d'un réseau — quelques dizaines
/// d'établissements — filtrer une liste déjà en mémoire est instantané et ne
/// coûte aucun aller-retour.
class _OngletEtablissements extends StatefulWidget {
  const _OngletEtablissements();

  @override
  State<_OngletEtablissements> createState() => _OngletEtablissementsState();
}

class _OngletEtablissementsState extends State<_OngletEtablissements> {
  final _recherche = TextEditingController();

  /// Code ISO retenu, ou `null` pour « tous les marchés ».
  String? _pays;

  /// Slug de ville retenu, ou `null`.
  String? _ville;

  /// État du cycle de vie retenu, ou `null`.
  eccore.RestaurantLifecycle? _statut;

  bool get _filtre =>
      _pays != null || _ville != null || _statut != null || _recherche.text.trim().isNotEmpty;

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  void _reinitialiser() {
    setState(() {
      _pays = null;
      _ville = null;
      _statut = null;
      _recherche.clear();
    });
  }

  List<eccore.ManagedRestaurant> _retenus(NetworkService reseau) {
    final terme = _recherche.text.trim().toLowerCase();

    return reseau.restaurants.where((etablissement) {
      if (_pays != null && etablissement.countryIsoCode != _pays) return false;
      if (_ville != null && etablissement.citySlug != _ville) return false;
      if (_statut != null && etablissement.status != _statut) return false;
      if (terme.isEmpty) return true;
      // Nom et adresse, comme `search_fields` côté serveur : chercher sur les
      // mêmes colonnes des deux côtés évite qu'un même mot trouve ici et pas
      // là-bas.
      return etablissement.name.toLowerCase().contains(terme) ||
          etablissement.address.toLowerCase().contains(terme);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkService>(
      builder: (context, reseau, _) {
        if (reseau.restaurants.isEmpty) {
          return const _Vide(
            icone: Icons.storefront_outlined,
            titre: 'Aucun établissement',
            texte: 'Un établissement se rattache à une zone de livraison, qui '
                'emporte sa ville, son marché, sa devise et son fuseau.',
          );
        }

        final retenus = _retenus(reseau);
        // Les villes proposées suivent le marché retenu : offrir « Abidjan »
        // sous « Togo » produirait un filtre qui ne rend jamais rien.
        final villes = (_pays == null ? reseau.cities : reseau.citiesOf(_pays!)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        return Column(
          children: [
            _BarreDeFiltres(
              recherche: _recherche,
              pays: _pays,
              ville: _ville,
              statut: _statut,
              paysDisponibles: reseau.countries,
              villesDisponibles: villes,
              onRecherche: (_) => setState(() {}),
              onPays: (iso) => setState(() {
                _pays = iso;
                // La ville retenue peut ne plus appartenir au marché : la
                // garder afficherait une liste vide sans raison visible.
                if (iso != null &&
                    _ville != null &&
                    !reseau.citiesOf(iso).any((v) => v.slug == _ville)) {
                  _ville = null;
                }
              }),
              onVille: (slug) => setState(() => _ville = slug),
              onStatut: (statut) => setState(() => _statut = statut),
              onReinitialiser: _filtre ? _reinitialiser : null,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${retenus.length} établissement(s)'
                  '${_filtre ? ' sur ${reseau.restaurants.length}' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Expanded(
              child: retenus.isEmpty
                  ? const _Vide(
                      icone: Icons.search_off,
                      titre: 'Aucun résultat',
                      texte: 'Aucun établissement ne correspond à ces filtres. '
                          'Élargissez la recherche ou réinitialisez.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      itemCount: retenus.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _CarteEtablissement(etablissement: retenus[index]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _BarreDeFiltres extends StatelessWidget {
  const _BarreDeFiltres({
    required this.recherche,
    required this.pays,
    required this.ville,
    required this.statut,
    required this.paysDisponibles,
    required this.villesDisponibles,
    required this.onRecherche,
    required this.onPays,
    required this.onVille,
    required this.onStatut,
    required this.onReinitialiser,
  });

  final TextEditingController recherche;
  final String? pays;
  final String? ville;
  final eccore.RestaurantLifecycle? statut;
  final List<eccore.ManagedCountry> paysDisponibles;
  final List<eccore.ManagedCity> villesDisponibles;
  final ValueChanged<String> onRecherche;
  final ValueChanged<String?> onPays;
  final ValueChanged<String?> onVille;
  final ValueChanged<eccore.RestaurantLifecycle?> onStatut;
  final VoidCallback? onReinitialiser;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: recherche,
            onChanged: onRecherche,
            decoration: InputDecoration(
              hintText: 'Rechercher par nom ou adresse',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: recherche.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        recherche.clear();
                        onRecherche('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Menu<String?>(
                  intitule: pays == null ? 'Tous les marchés' : 'Marché : $pays',
                  actif: pays != null,
                  entrees: [
                    (null, 'Tous les marchés'),
                    for (final marche in paysDisponibles)
                      (marche.isoCode, '${marche.name} (${marche.isoCode})'),
                  ],
                  onChoisi: onPays,
                ),
                const SizedBox(width: 8),
                _Menu<String?>(
                  intitule: ville == null ? 'Toutes les villes' : 'Ville : $ville',
                  actif: ville != null,
                  entrees: [
                    (null, 'Toutes les villes'),
                    for (final v in villesDisponibles) (v.slug, v.name),
                  ],
                  onChoisi: onVille,
                ),
                const SizedBox(width: 8),
                _Menu<eccore.RestaurantLifecycle?>(
                  intitule: statut == null ? 'Tous les statuts' : statut!.label,
                  actif: statut != null,
                  entrees: [
                    (null, 'Tous les statuts'),
                    for (final etat in eccore.RestaurantLifecycle.values) (etat, etat.label),
                  ],
                  onChoisi: onStatut,
                ),
                if (onReinitialiser != null) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onReinitialiser,
                    icon: const Icon(Icons.filter_alt_off, size: 18),
                    label: const Text('Réinitialiser'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton-filtre à menu déroulant.
///
/// Un `PopupMenuButton` et non un `DropdownButton` : la barre est horizontale
/// et défilante, et un `DropdownButton` y impose une largeur fixe qui rogne les
/// noms de ville longs.
class _Menu<T> extends StatelessWidget {
  const _Menu({
    required this.intitule,
    required this.actif,
    required this.entrees,
    required this.onChoisi,
  });

  final String intitule;
  final bool actif;
  final List<(T, String)> entrees;
  final ValueChanged<T> onChoisi;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuButton<T>(
      onSelected: onChoisi,
      itemBuilder: (_) => [
        for (final (valeur, libelle) in entrees)
          PopupMenuItem<T>(value: valeur, child: Text(libelle)),
      ],
      child: Chip(
        label: Text(intitule),
        avatar: const Icon(Icons.filter_list, size: 16),
        backgroundColor: actif ? scheme.primaryContainer : null,
      ),
    );
  }
}

class _CarteEtablissement extends StatelessWidget {
  const _CarteEtablissement({required this.etablissement});

  final eccore.ManagedRestaurant etablissement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final manques = etablissement.configurationGaps.length;

    return Card(
      child: ListTile(
        leading: Icon(
          etablissement.status.isPublished ? Icons.storefront : Icons.construction,
          color: etablissement.status.isPublished ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Text(etablissement.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${etablissement.cityName} (${etablissement.countryIsoCode}) · '
              '${etablissement.currency}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                _Pastille(
                  texte: etablissement.status.label,
                  couleurFond: etablissement.status.isPublished
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  couleurTexte: etablissement.status.isPublished
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
                if (manques > 0)
                  _Pastille(
                    texte: '$manques à régler',
                    couleurFond: scheme.errorContainer,
                    couleurTexte: scheme.onErrorContainer,
                  ),
                if (etablissement.status.isPublished && !etablissement.acceptsOrders)
                  _Pastille(
                    texte: 'Commandes suspendues',
                    couleurFond: scheme.tertiaryContainer,
                    couleurTexte: scheme.onTertiaryContainer,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _Compteurs(etablissement: etablissement),
          ],
        ),
        isThreeLine: true,
        trailing: _Actions(etablissement: etablissement),
        onTap: () => _ouvrirLaConfiguration(context),
      ),
    );
  }

  void _ouvrirLaConfiguration(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProvisionnementScreen(slug: etablissement.slug),
      ),
    );
  }
}

/// Compteurs d'exploitation d'un établissement.
///
/// Comptés par le serveur en une requête annotée (`orders_count`,
/// `couriers_count`, `menu_items_count`) et non dérivés d'une liste chargée
/// ici : le tableau de bord précédent téléchargeait les commandes pour les
/// compter à l'écran, et le total ne portait alors que sur la page affichée.
///
/// Les trois ensemble, parce qu'ils répondent à trois questions différentes
/// devant la même décision — cet établissement est-il prêt, tourne-t-il, et
/// avec qui : « 0 produit » explique pourquoi il ne peut pas ouvrir, « 0
/// livreur » pourquoi il ne peut pas livrer.
class _Compteurs extends StatelessWidget {
  const _Compteurs({required this.etablissement});

  final eccore.ManagedRestaurant etablissement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 12,
      children: [
        _Compteur(
          icone: Icons.receipt_long,
          valeur: etablissement.ordersCount,
          intitule: 'commandes',
          scheme: scheme,
        ),
        _Compteur(
          icone: Icons.delivery_dining,
          valeur: etablissement.couriersCount,
          intitule: 'livreurs',
          scheme: scheme,
          // Zéro livreur empêche la mise en service : c'est une des phrases de
          // `configuration_gaps`, et le compteur la rend visible avant même
          // d'ouvrir la fiche.
          alerte: etablissement.couriersCount == 0,
        ),
        _Compteur(
          icone: Icons.restaurant_menu,
          valeur: etablissement.menuItemsCount,
          intitule: 'produits',
          scheme: scheme,
          alerte: etablissement.menuItemsCount == 0,
        ),
      ],
    );
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur({
    required this.icone,
    required this.valeur,
    required this.intitule,
    required this.scheme,
    this.alerte = false,
  });

  final IconData icone;
  final int valeur;
  final String intitule;
  final ColorScheme scheme;
  final bool alerte;

  @override
  Widget build(BuildContext context) {
    final couleur = alerte ? scheme.error : scheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 14, color: couleur),
        const SizedBox(width: 4),
        Text(
          '$valeur $intitule',
          style: TextStyle(fontSize: 11, color: couleur),
        ),
      ],
    );
  }
}

/// Menu d'actions d'une ligne d'établissement.
///
/// Configurer, modifier, dupliquer. La mise en service, la suspension et la
/// réouverture n'y sont pas : elles vivent sur l'écran de provisionnement, à
/// côté de la liste de ce qui manque encore. Les proposer ici les couperait de
/// cette liste, et « pourquoi ne puis-je pas publier ? » n'aurait plus de
/// réponse à l'écran.
///
/// Aucune suppression : des commandes, un catalogue et des dossiers livreurs
/// renvoient à un établissement. Le retirer de l'application se fait en le
/// suspendant, ce qui laisse l'historique lisible.
class _Actions extends StatelessWidget {
  const _Actions({required this.etablissement});

  final eccore.ManagedRestaurant etablissement;

  Future<void> _dupliquer(BuildContext context) async {
    final cree = await DuplicationDialog.show(context, source: etablissement);
    if (cree && context.mounted) {
      await context.read<NetworkService>().refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Établissement dupliqué, en brouillon. Vérifiez sa fiche avant de le publier.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _modifier(BuildContext context) async {
    final enregistre = await EtablissementFormDialog.show(context, existant: etablissement);
    if (enregistre && context.mounted) {
      await context.read<NetworkService>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      onSelected: (action) async {
        switch (action) {
          case 'configurer':
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProvisionnementScreen(slug: etablissement.slug),
              ),
            );
          case 'modifier':
            await _modifier(context);
          case 'dupliquer':
            await _dupliquer(context);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'configurer',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.tune),
            title: Text('Configurer'),
          ),
        ),
        PopupMenuItem(
          value: 'modifier',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('Modifier la fiche'),
          ),
        ),
        PopupMenuItem(
          value: 'dupliquer',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.copy_all_outlined),
            title: Text('Dupliquer'),
            subtitle: Text('Carte et horaires, jamais les commandes'),
          ),
        ),
      ],
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({
    required this.texte,
    required this.couleurFond,
    required this.couleurTexte,
  });

  final String texte;
  final Color couleurFond;
  final Color couleurTexte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: couleurFond,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texte,
        style: TextStyle(fontSize: 11, color: couleurTexte, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide({required this.icone, required this.titre, required this.texte});

  final IconData icone;
  final String titre;
  final String texte;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(titre, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              texte,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
