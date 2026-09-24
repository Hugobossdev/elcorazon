import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:admin/services/global_search_service.dart';
import 'package:admin/presentation/dialogues/details_commande.dart';
import 'package:admin/presentation/echec.dart';
import 'package:admin/presentation/retours.dart';
import 'package:admin/services/client_management_service.dart';
import 'package:admin/services/driver_management_service.dart';
import 'package:admin/services/order_management_service.dart';
import 'package:admin/screens/admin/client_management_screen.dart';
import 'package:admin/screens/admin/driver_detailed_stats_screen.dart';
import 'package:admin/screens/admin/menu_management_screen.dart';

/// Catégories disponibles pour filtrer les résultats de recherche
enum SearchCategory {
  orders,
  menuItems,
  users,
  drivers,
}

/// Recherche transverse du back-office.
///
/// ## Ce qu'un résultat ouvre
///
/// Chaque ligne ouvre **ce qu'on a trouvé** : la commande, la fiche du client,
/// les statistiques du livreur, la carte filtrée sur le produit. Seule la
/// commande le faisait ; les trois autres ouvraient la liste entière de leur
/// famille, où il fallait retrouver à la main la ligne qu'on venait de
/// chercher.
///
/// Le serveur ne rend une famille qu'au compte qui porte sa permission de
/// lecture (`apps/search/services.py`) — la même que celle de l'écran de la
/// famille dans la barre latérale. Un résultat affiché est donc un résultat
/// que ce compte a le droit d'ouvrir.
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  /// En deçà, le serveur refuse la requête — voir [GlobalSearchService].
  static const _longueurMinimale = 3;

  final TextEditingController _searchController = TextEditingController();
  final GlobalSearchService _searchService = GlobalSearchService();
  GlobalSearchResults? _results;
  String? _erreur;
  bool _isSearching = false;

  /// Un ensemble modifiable. C'était `SearchCategory.values` elle-même — une
  /// liste constante : décocher un filtre levait `Unsupported operation`.
  final Set<SearchCategory> _selectedCategories = {...SearchCategory.values};

  /// Numéro de la dernière recherche lancée. Une recherche part à chaque
  /// frappe : sans ce numéro, la réponse à « pou » arrivée après celle à
  /// « poulet » remplaçait les bons résultats par les anciens.
  int _derniere = 0;

  /// Un résultat est en cours d'ouverture : un second clic attend.
  bool _ouverture = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final numero = ++_derniere;
    if (query.trim().length < _longueurMinimale) {
      setState(() {
        _results = null;
        _erreur = null;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final results = await _searchService.searchAll(query);

    if (!mounted || numero != _derniere) return;
    setState(() {
      _results = results;
      // Le service rend une liste vide sur refus ou coupure : sans son motif,
      // l'écran annonçait « Aucun résultat trouvé » devant une panne.
      _erreur = _searchService.error;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Recherche Globale')),
      // Le champ et les filtres sont en tête du contenu, et non dans le
      // `bottom` de la barre : celui-ci était déclaré à 60 px pour un champ et
      // une rangée de filtres qui en occupent le double. Les filtres
      // débordaient sur la liste, et sur un téléphone, où ils passent sur
      // deux lignes, davantage encore.
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher commandes, produits, clients, livreurs...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              unawaited(_performSearch(''));
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  onChanged: (value) => unawaited(_performSearch(value)),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: SearchCategory.values.map((category) {
                      final isSelected = _selectedCategories.contains(category);
                      return FilterChip(
                        label: Text(_getCategoryLabel(category)),
                        selected: isSelected,
                        // Un filtre trie des résultats déjà reçus : il ne
                        // relance pas la recherche, qui rendait les quatre
                        // familles.
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _selectedCategories.add(category);
                          } else {
                            _selectedCategories.remove(category);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    final saisie = _searchController.text.trim();
    if (_results == null) {
      final manquants = _longueurMinimale - saisie.length;
      return _buildMessage(
        theme,
        Icons.search,
        saisie.isEmpty
            ? 'Recherchez dans toute l\'application'
            : 'Encore $manquants caractère${manquants > 1 ? 's' : ''}…',
        saisie.isEmpty
            ? 'Commandes, produits, clients, livreurs...'
            : 'La recherche commence à $_longueurMinimale caractères.',
      );
    }

    if (_erreur != null) {
      return _buildMessage(
        theme,
        Icons.cloud_off_outlined,
        'Recherche impossible',
        _erreur!,
        action: TextButton(
          onPressed: () => unawaited(_performSearch(_searchController.text)),
          child: const Text('Réessayer'),
        ),
      );
    }

    final visibles = [
      if (_selectedCategories.contains(SearchCategory.orders)) ..._results!.orders,
      if (_selectedCategories.contains(SearchCategory.menuItems)) ..._results!.menuItems,
      if (_selectedCategories.contains(SearchCategory.users)) ..._results!.users,
      if (_selectedCategories.contains(SearchCategory.drivers)) ..._results!.drivers,
    ];
    if (visibles.isEmpty) {
      return _buildMessage(
        theme,
        Icons.search_off,
        'Aucun résultat trouvé',
        _results!.isEmpty
            ? 'Essayez avec d\'autres mots-clés'
            : 'Des résultats existent dans les catégories décochées.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_results!.orders.isNotEmpty &&
            _selectedCategories.contains(SearchCategory.orders)) ...[
          _buildSectionHeader(
            'Commandes',
            _results!.orders.length,
            Icons.shopping_cart,
            Colors.blue,
          ),
          ..._results!.orders.map(_buildOrderCard),
        ],
        if (_results!.menuItems.isNotEmpty &&
            _selectedCategories.contains(SearchCategory.menuItems)) ...[
          _buildSectionHeader(
            'Produits',
            _results!.menuItems.length,
            Icons.restaurant,
            Colors.orange,
          ),
          ..._results!.menuItems.map(_buildMenuItemCard),
        ],
        if (_results!.users.isNotEmpty &&
            _selectedCategories.contains(SearchCategory.users)) ...[
          _buildSectionHeader(
            'Clients',
            _results!.users.length,
            Icons.person,
            Colors.green,
          ),
          ..._results!.users.map(_buildUserCard),
        ],
        if (_results!.drivers.isNotEmpty &&
            _selectedCategories.contains(SearchCategory.drivers)) ...[
          _buildSectionHeader(
            'Livreurs',
            _results!.drivers.length,
            Icons.delivery_dining,
            Colors.purple,
          ),
          ..._results!.drivers.map(_buildDriverCard),
        ],
      ],
    );
  }

  Widget _buildMessage(
    ThemeData theme,
    IconData icone,
    String titre,
    String detail, {
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icone,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(titre, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 8), action],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    int count,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _carte(
    GlobalSearchResult result, {
    required IconData icone,
    required Color couleur,
    required Future<void> Function() ouvrir,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: couleur.withValues(alpha: 0.1),
          child: Icon(icone, color: couleur),
        ),
        title: Text(result.title),
        subtitle: Text(result.subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => unawaited(_ouvrir(ouvrir)),
      ),
    );
  }

  /// Ouvre un résultat, un seul à la fois, et **dit** un refus : un dossier
  /// qui a changé de périmètre depuis la recherche, ou une coupure.
  Future<void> _ouvrir(Future<void> Function() ouvrir) async {
    if (_ouverture) return;
    _ouverture = true;
    try {
      await ouvrir();
    } on eccore.ApiException catch (e) {
      if (mounted) annoncerEchec(context, Echec.de(e));
    } finally {
      _ouverture = false;
    }
  }

  // La date de la commande n'est plus accolée ici : le sous-titre que rend le
  // serveur porte déjà ce qui identifie la ligne (destinataire et statut).
  Widget _buildOrderCard(GlobalSearchResult result) => _carte(
        result,
        icone: Icons.shopping_cart,
        couleur: Colors.blue,
        ouvrir: () => _ouvrirLaCommande(result.id),
      );

  /// Charge la fiche détaillée puis l'affiche.
  ///
  /// La recherche ne rend qu'un identifiant, un titre et un sous-titre — assez
  /// pour la liste, pas pour une fiche. Le détail se demande au serveur, ce qui
  /// rend au passage les lignes de la commande.
  Future<void> _ouvrirLaCommande(String orderId) async {
    final commande = await context.read<OrderManagementService>().loadDetail(orderId);

    if (!mounted) return;
    if (commande == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cette commande n’est plus lisible depuis ce compte.'),
        ),
      );
      return;
    }
    afficherDetailsCommande(context, commande);
  }

  /// La carte de l'établissement courant, filtrée sur le produit. La carte
  /// n'offre que les gestes que le compte peut faire — un formulaire
  /// d'édition ouvert directement ne le saurait pas.
  Widget _buildMenuItemCard(GlobalSearchResult result) => _carte(
        result,
        icone: Icons.restaurant,
        couleur: Colors.orange,
        ouvrir: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            // L'écran de la carte n'a pas de barre d'application : poussé tel
            // quel, il n'offrait aucun retour vers la recherche.
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Menu')),
              body: MenuManagementScreen(rechercheInitiale: result.title),
            ),
          ),
        ),
      );

  /// La fiche du client : ses chiffres et les notes de l'équipe.
  Widget _buildUserCard(GlobalSearchResult result) => _carte(
        result,
        icone: Icons.person,
        couleur: Colors.green,
        ouvrir: () async {
          final client = await context.read<ClientManagementService>().client(result.id);
          if (!mounted) return;
          await ouvrirFicheClient(context, client);
        },
      );

  /// Les statistiques du livreur, sur son dossier relu.
  Widget _buildDriverCard(GlobalSearchResult result) => _carte(
        result,
        icone: Icons.delivery_dining,
        couleur: Colors.purple,
        ouvrir: () async {
          final dossier =
              await context.read<DriverManagementService>().relireDossier(result.id);
          if (!mounted) return;
          await Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => DriverDetailedStatsScreen(driver: dossier)),
          );
        },
      );

  String _getCategoryLabel(SearchCategory category) {
    switch (category) {
      case SearchCategory.orders:
        return 'Commandes';
      case SearchCategory.menuItems:
        return 'Produits';
      case SearchCategory.users:
        return 'Clients';
      case SearchCategory.drivers:
        return 'Livreurs';
    }
  }
}
