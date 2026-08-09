import 'dart:math';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/services/location_service.dart';
import 'package:elcora_fast/models/address.dart';
import 'package:elcora_fast/utils/address_sorting.dart';
import 'package:elcora_fast/widgets/address_card.dart';
import 'package:elcora_fast/screens/client/address_detail_bottom_sheet.dart';

// `AddressSortType` et l'ordre d'affichage vivent désormais dans
// `utils/address_sorting.dart` — une fonction pure, donc testable, ce que le
// tri ne pouvait pas être tant qu'il était enfermé dans l'état de cet écran.
export 'package:elcora_fast/utils/address_sorting.dart' show AddressSortType;

class AddressManagementScreen extends StatefulWidget {
  const AddressManagementScreen({super.key});

  @override
  State<AddressManagementScreen> createState() =>
      _AddressManagementScreenState();
}

class _AddressManagementScreenState extends State<AddressManagementScreen> {
  final AddressService _addressService = AddressService();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  AddressSortType _sortType = AddressSortType.recent;
  bool _favoritesOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Efface la recherche — champ **et** filtre.
  ///
  /// Le `TextField` n'avait pas de contrôleur : la croix et la puce de filtre
  /// remettaient `_searchQuery` à vide, mais le texte restait affiché. Le
  /// client voyait sa recherche à l'écran et la liste complète en dessous.
  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Consumer<AddressService>(
        builder: (context, addressService, child) {
          // Le carnet vit côté serveur : sans session il n'y en a pas, et le
          // formulaire d'ajout mènerait à un refus. Le dire ici évite de faire
          // saisir une adresse pour rien.
          if (!addressService.canEdit) return _buildSignedOutState();

          if (!addressService.hasAddresses) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: _buildContent(addressService),
          );
        },
      ),
      floatingActionButton: Consumer<AddressService>(
        builder: (context, addressService, child) {
          if (!addressService.canEdit) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: _showAddAddressSheet,
            icon: const Icon(Icons.add_location),
            label: const Text('Ajouter'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          );
        },
      ),
    );
  }

  Widget _buildSignedOutState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'Connectez-vous',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Vos adresses de livraison sont rattachées à votre compte : '
              'elles vous suivent d\'un appareil à l\'autre.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Mes Adresses'),
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      actions: [
        // Filtre favoris
        IconButton(
          onPressed: () {
            setState(() {
              _favoritesOnly = !_favoritesOnly;
            });
          },
          icon: Icon(
            _favoritesOnly ? Icons.star : Icons.star_border,
            color: _favoritesOnly ? Colors.amber : null,
          ),
          tooltip: 'Favoris uniquement',
        ),

        // Menu de tri
        PopupMenuButton<AddressSortType>(
          onSelected: (type) => setState(() => _sortType = type),
          icon: const Icon(Icons.sort),
          tooltip: 'Trier',
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder: (context) => [
            _buildSortMenuItem(
              AddressSortType.recent,
              'Récemment utilisées',
              Icons.schedule,
            ),
            _buildSortMenuItem(
              AddressSortType.name,
              'Nom (A-Z)',
              Icons.sort_by_alpha,
            ),
            _buildSortMenuItem(
              AddressSortType.distance,
              'Distance',
              Icons.straighten,
            ),
            _buildSortMenuItem(
              AddressSortType.type,
              'Type',
              Icons.category,
            ),
          ],
        ),
      ],
    );
  }

  PopupMenuEntry<AddressSortType> _buildSortMenuItem(
    AddressSortType type,
    String label,
    IconData icon,
  ) {
    final isSelected = _sortType == type;
    return PopupMenuItem(
      value: type,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(
              Icons.check,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(AddressService addressService) {
    var addresses = _filterAddresses(addressService.addresses);
    addresses = _sortAddresses(addresses);

    return Column(
      children: [
        // Barre de recherche. Le seuil était de « plus de 3 adresses » : sous
        // ce nombre, une recherche déjà saisie restait active sans plus aucun
        // moyen de l'effacer, et la liste semblait vide sans raison visible.
        if (addressService.addresses.length > 3 || _searchQuery.isNotEmpty)
          _buildSearchBar(),

        // Stats card
        _buildStatsCard(addressService),

        // Active filters chips
        if (_hasActiveFilters) _buildActiveFiltersChips(),

        // Liste des adresses
        Expanded(
          child: addresses.isEmpty
              ? _buildNoResults()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: addresses.length,
                  itemBuilder: (context, index) {
                    final address = addresses[index];
                    final isSelected =
                        addressService.selectedAddress?.id == address.id;

                    return AddressCard(
                      address: address,
                      isSelected: isSelected,
                      onTap: () => _selectAddress(address),
                      onEdit: () => _showEditAddressSheet(address),
                      onDelete: () => _deleteAddress(address),
                      onToggleFavorite: () => _toggleFavorite(address),
                      onSetDefault: () => _setDefault(address),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Nom, quartier, repère…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSearch,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildStatsCard(AddressService addressService) {
    final total = addressService.addresses.length;
    final favorites = addressService.favoriteAddresses.length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.location_on,
            value: '$total',
            label: 'Adresses',
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          _buildStatItem(
            icon: Icons.star,
            value: '$favorites',
            label: 'Favoris',
            iconColor: Colors.amber.shade600,
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          _buildStatItem(
            icon: Icons.check_circle,
            value: addressService.defaultAddress != null ? '1' : '0',
            label: 'Défaut',
            iconColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    Color? iconColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context)
                .colorScheme
                .onPrimaryContainer
                .withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  bool get _hasActiveFilters => _searchQuery.isNotEmpty || _favoritesOnly;

  Widget _buildActiveFiltersChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        children: [
          if (_searchQuery.isNotEmpty)
            Chip(
              avatar: const Icon(Icons.search, size: 18),
              label: Text('Recherche: "$_searchQuery"'),
              onDeleted: _clearSearch,
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
          if (_favoritesOnly)
            Chip(
              avatar: const Icon(Icons.star, size: 18, color: Colors.amber),
              label: const Text('Favoris uniquement'),
              onDeleted: () => setState(() => _favoritesOnly = false),
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Aucune adresse trouvée',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez de modifier vos filtres',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off,
            size: 100,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'Aucune adresse enregistrée',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Ajoutez votre première adresse pour faciliter vos commandes',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade500,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _showAddAddressSheet,
            icon: const Icon(Icons.add_location),
            label: const Text('Ajouter une adresse'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  List<Address> _filterAddresses(List<Address> addresses) {
    var filtered = addresses;

    if (_searchQuery.isNotEmpty) {
      filtered = _addressService.searchAddresses(_searchQuery);
    }

    if (_favoritesOnly) {
      filtered = filtered.where((a) => a.isFavorite).toList();
    }

    return filtered;
  }

  List<Address> _sortAddresses(List<Address> addresses) {
    // `LocationService` est un singleton : cette position est celle relevée
    // par le reste de l'application. L'écran en construisait auparavant une
    // instance neuve, dont `currentPosition` valait toujours `null` — le tri
    // par distance ne triait donc jamais.
    final origin = _locationService.currentPosition;

    return sortAddressesForDisplay(
      addresses,
      sortType: _sortType,
      distanceFrom: origin == null ? null : (a) => _distanceFrom(origin, a),
    );
  }

  /// Distance à vol d'oiseau, en kilomètres.
  double _distanceFrom(Position origin, Address address) {
    return _calculateDistance(
      origin.latitude,
      origin.longitude,
      address.latitude,
      address.longitude,
    );
  }

  /// Recharge le carnet depuis le serveur.
  ///
  /// Appelait `initialize()`, qui sort immédiatement une fois le service
  /// initialisé : le geste « tirer pour rafraîchir » animait son indicateur
  /// sans jamais rien recharger.
  Future<void> _refresh() async {
    await _addressService.refresh();
  }

  void _showAddAddressSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddressDetailBottomSheet(
        onSave: (draft) async {
          await _addressService.addAddress(draft);
          if (mounted) _showSnack('Adresse ajoutée', Colors.green);
        },
      ),
    );
  }

  void _showEditAddressSheet(Address address) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddressDetailBottomSheet(
        address: address,
        onSave: (draft) async {
          await _addressService.updateAddress(address.id, draft);
          if (mounted) _showSnack('Adresse modifiée', Colors.green);
        },
      ),
    );
  }

  // Ces trois actions étaient lancées sans être attendues : leur échec
  // remontait en exception non capturée, et le message de confirmation
  // s'affichait de toute façon — y compris quand rien n'avait été enregistré.

  Future<void> _selectAddress(Address address) async {
    try {
      await _addressService.selectAddress(address.id);
      if (mounted) {
        _showSnack('Adresse sélectionnée : ${address.name}', Colors.green);
      }
    } catch (e) {
      if (mounted) _showSnack(_messageFor(e), Colors.red);
    }
  }

  Future<void> _toggleFavorite(Address address) async {
    try {
      await _addressService.toggleFavorite(address.id);
    } catch (e) {
      if (mounted) _showSnack(_messageFor(e), Colors.red);
    }
  }

  Future<void> _setDefault(Address address) async {
    try {
      await _addressService.setDefaultAddress(address.id);
      if (mounted) {
        _showSnack(
          '${address.name} définie comme adresse par défaut',
          Colors.blue,
        );
      }
    } catch (e) {
      if (mounted) _showSnack(_messageFor(e), Colors.red);
    }
  }

  /// Message destiné au client.
  ///
  /// Les écrans affichaient `'Erreur : $e'`, ce qui met un `DioException` ou
  /// une trace d'exception sous les yeux de quelqu'un qui voulait enregistrer
  /// son adresse. Le serveur, lui, renvoie déjà une phrase utilisable
  /// (RFC 9457, champ `detail`) — c'est elle qu'on montre.
  String _messageFor(Object error) {
    if (error is AddressSessionRequired) return error.toString();
    if (error is eccore.ApiException) return error.detail;
    return 'Opération impossible pour le moment. Réessayez.';
  }

  void _showSnack(String message, Color background) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Confirme avant de supprimer.
  ///
  /// Le geste était immédiat et sans retour en arrière : une adresse saisie
  /// avec son repère disparaissait sur une pression, et la suppression est
  /// dure côté serveur (droit à l'effacement — `AddressViewSet`), donc
  /// définitive.
  Future<void> _deleteAddress(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: Colors.orange),
        title: const Text('Supprimer cette adresse ?'),
        content: Text('« ${address.name} » sera définitivement effacée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _addressService.deleteAddress(address.id);
      if (mounted) {
        _showSnack('Adresse supprimée : ${address.name}', Colors.orange);
      }
    } catch (e) {
      if (mounted) _showSnack(_messageFor(e), Colors.red);
    }
  }

  /// Calcule la distance en kilomètres entre deux points GPS
  /// Utilise la formule de Haversine pour calculer la distance
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Rayon de la Terre en km

    // Convertir les degrés en radians
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distance = earthRadius * c;

    return distance;
  }

  /// Convertit des degrés en radians
  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
}
