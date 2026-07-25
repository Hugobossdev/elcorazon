import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/services/location_service.dart';
import 'package:elcora_fast/models/address.dart';
import 'package:elcora_fast/widgets/address_card.dart';
import 'package:elcora_fast/screens/client/address_detail_bottom_sheet.dart';

enum AddressSortType {
  name,
  distance,
  recent,
  type,
}

class AddressManagementScreen extends StatefulWidget {
  const AddressManagementScreen({super.key});

  @override
  State<AddressManagementScreen> createState() =>
      _AddressManagementScreenState();
}

class _AddressManagementScreenState extends State<AddressManagementScreen> {
  final AddressService _addressService = AddressService();
  String _searchQuery = '';
  AddressSortType _sortType = AddressSortType.recent;
  bool _favoritesOnly = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Consumer<AddressService>(
        builder: (context, addressService, child) {
          if (!addressService.hasAddresses) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: _buildContent(addressService),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAddressSheet,
        icon: const Icon(Icons.add_location),
        label: const Text('Ajouter'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
        // Barre de recherche
        if (addressService.addresses.length > 3) _buildSearchBar(),

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
        decoration: InputDecoration(
          hintText: 'Rechercher une adresse...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _searchQuery = ''),
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
              onDeleted: () => setState(() => _searchQuery = ''),
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
    final sorted = [...addresses];

    switch (_sortType) {
      case AddressSortType.name:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case AddressSortType.distance:
        // Trier par distance depuis la position actuelle
        try {
          final locationService = LocationService();
          if (locationService.currentPosition != null) {
            final currentLat = locationService.currentPosition!.latitude;
            final currentLng = locationService.currentPosition!.longitude;

            sorted.sort((a, b) {
              // Calculer la distance pour chaque adresse
              final distanceA = a.latitude != null && a.longitude != null
                  ? _calculateDistance(
                      currentLat,
                      currentLng,
                      a.latitude!,
                      a.longitude!,
                    )
                  : double.infinity;

              final distanceB = b.latitude != null && b.longitude != null
                  ? _calculateDistance(
                      currentLat,
                      currentLng,
                      b.latitude!,
                      b.longitude!,
                    )
                  : double.infinity;

              return distanceA.compareTo(distanceB);
            });
          }
        } catch (e) {
          // Si on ne peut pas obtenir la position, ne pas trier
          debugPrint('Erreur lors du tri par distance: $e');
        }
        break;
      case AddressSortType.recent:
        sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case AddressSortType.type:
        sorted.sort((a, b) => a.type.index.compareTo(b.type.index));
        break;
    }

    // Favoris toujours en premier
    sorted.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return 0;
    });

    // Adresse par défaut en premier
    sorted.sort((a, b) {
      if (a.isDefault && !b.isDefault) return -1;
      if (!a.isDefault && b.isDefault) return 1;
      return 0;
    });

    return sorted;
  }

  Future<void> _refresh() async {
    await _addressService.initialize();
  }

  void _showAddAddressSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddressDetailBottomSheet(
        onSave: (addressData) => _addAddress(addressData),
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
        onSave: (addressData) => _updateAddress(address.id, addressData),
      ),
    );
  }

  void _selectAddress(Address address) {
    _addressService.selectAddress(address.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Adresse sélectionnée : ${address.name}'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _toggleFavorite(Address address) {
    _addressService.toggleFavorite(address.id);
  }

  void _setDefault(Address address) {
    _addressService.setDefaultAddress(address.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${address.name} définie comme adresse par défaut'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _deleteAddress(Address address) async {
    try {
      await _addressService.deleteAddress(address.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Adresse supprimée : ${address.name}'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _addAddress(Map<String, dynamic> addressData) async {
    try {
      await _addressService.addAddress(
        name: addressData['name'],
        address: addressData['address'],
        city: addressData['city'],
        postalCode: addressData['postalCode'] ?? '',
        type: addressData['type'],
        isDefault: addressData['isDefault'] ?? false,
        isFavorite: addressData['isFavorite'] ?? false,
        latitude: addressData['latitude'],
        longitude: addressData['longitude'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Adresse ajoutée avec succès'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _updateAddress(
    String addressId,
    Map<String, dynamic> addressData,
  ) async {
    try {
      await _addressService.updateAddress(
        addressId: addressId,
        name: addressData['name'],
        address: addressData['address'],
        city: addressData['city'],
        postalCode: addressData['postalCode'],
        type: addressData['type'],
        isDefault: addressData['isDefault'],
        isFavorite: addressData['isFavorite'],
        latitude: addressData['latitude'],
        longitude: addressData['longitude'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Adresse modifiée avec succès'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
