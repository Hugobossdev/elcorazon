import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/models/address.dart';
import 'package:elcora_fast/widgets/address_card.dart';
import 'package:elcora_fast/screens/client/address_management_screen.dart';

/// Écran de sélection rapide d'adresse avec preview des frais
class AddressSelectorScreen extends StatefulWidget {
  final Address? currentAddress;
  final Function(Address) onAddressSelected;

  const AddressSelectorScreen({
    required this.onAddressSelected,
    super.key,
    this.currentAddress,
  });

  @override
  State<AddressSelectorScreen> createState() => _AddressSelectorScreenState();
}

class _AddressSelectorScreenState extends State<AddressSelectorScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sélectionner une adresse'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            onPressed: _navigateToManagement,
            icon: const Icon(Icons.settings),
            tooltip: 'Gérer les adresses',
          ),
        ],
      ),
      body: Consumer<AddressService>(
        builder: (context, addressService, child) {
          if (!addressService.hasAddresses) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              // Barre de recherche
              if (addressService.addresses.length > 2 ||
                  _searchQuery.isNotEmpty)
                _buildSearchBar(),

              // Aide contextuelle
              _buildHelpBanner(),

              // Liste des adresses
              Expanded(
                child: _buildAddressList(addressService),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Nom, quartier, repère…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  // Le champ gardait son texte : seul le filtre était remis à
                  // zéro, et l'écran paraissait ignorer le geste.
                  onPressed: () => setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  }),
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

  Widget _buildHelpBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Les frais de livraison sont calculés automatiquement',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressList(AddressService addressService) {
    var addresses = _searchQuery.isEmpty
        ? addressService.addresses
        : addressService.searchAddresses(_searchQuery);

    if (addresses.isEmpty) {
      return _buildNoResults();
    }

    // Trier: défaut > favoris > autres
    addresses = [...addresses];
    addresses.sort((a, b) {
      if (a.isDefault && !b.isDefault) return -1;
      if (!a.isDefault && b.isDefault) return 1;
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: addresses.length,
      itemBuilder: (context, index) {
        final address = addresses[index];
        final isSelected = widget.currentAddress?.id == address.id;

        return AddressCard(
          address: address,
          isSelected: isSelected,
          onTap: () => _selectAddress(address),
        );
      },
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
            'Essayez avec un autre terme',
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
            size: 80,
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
              'Ajoutez votre première adresse pour continuer',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade500,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _navigateToManagement,
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

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: FilledButton.tonalIcon(
          onPressed: _navigateToManagement,
          icon: const Icon(Icons.add_location),
          label: const Text('Ajouter une nouvelle adresse'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectAddress(Address address) async {
    // Le choix est aussi retenu par le service, et non seulement remonté à
    // l'écran appelant : sans cela, l'adresse choisie ici était oubliée dès
    // qu'on quittait la commande en cours.
    try {
      await context.read<AddressService>().selectAddress(address.id);
    } catch (e) {
      debugPrint('Sélection non mémorisée : $e');
    }
    if (mounted) widget.onAddressSelected(address);
  }

  void _navigateToManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddressManagementScreen(),
      ),
    );
  }
}
