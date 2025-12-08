import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/models/address.dart';
import 'package:elcora_fast/widgets/custom_button.dart';
import 'package:elcora_fast/widgets/custom_text_field.dart';

class AddressSelectorScreen extends StatefulWidget {
  final Address? currentAddress;
  final Function(Address) onAddressSelected;

  const AddressSelectorScreen({
    required this.onAddressSelected, super.key,
    this.currentAddress,
  });

  @override
  State<AddressSelectorScreen> createState() => _AddressSelectorScreenState();
}

class _AddressSelectorScreenState extends State<AddressSelectorScreen> {
  final AddressService _addressService = AddressService();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sélectionner une adresse'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            onPressed: () => _showAddAddressDialog(),
            icon: const Icon(Icons.add_location),
            tooltip: 'Ajouter une adresse',
          ),
        ],
      ),
      body: Consumer<AddressService>(
        builder: (context, addressService, child) {
          final addresses = _searchQuery.isEmpty
              ? addressService.addresses
              : addressService.searchAddresses(_searchQuery);

          if (!addressService.hasAddresses) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              // Barre de recherche
              Container(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher une adresse...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),

              // Liste des adresses
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: addresses.length,
                  itemBuilder: (context, index) {
                    final address = addresses[index];
                    final isSelected = widget.currentAddress?.id == address.id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: address.type.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Center(
                            child: Text(
                              address.type.emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                address.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            if (address.isDefault)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4,),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Défaut',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(address.fullAddress),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2,),
                                  decoration: BoxDecoration(
                                    color: address.type.color
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    address.type.displayName,
                                    style: TextStyle(
                                      color: address.type.color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                                size: 28,
                              )
                            : null,
                        onTap: () {
                          widget.onAddressSelected(address);
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: CustomButton(
          onPressed: () => _showAddAddressDialog(),
          text: 'Ajouter une nouvelle adresse',
          icon: Icons.add_location,
        ),
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
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune adresse enregistrée',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez votre première adresse pour continuer',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddAddressDialog(),
            icon: const Icon(Icons.add_location),
            label: const Text('Ajouter une adresse'),
          ),
        ],
      ),
    );
  }

  void _showAddAddressDialog() {
    showDialog(
      context: context,
      builder: (context) => _QuickAddressDialog(
        onSave: (addressData) => _addAddress(addressData),
      ),
    );
  }

  Future<void> _addAddress(Map<String, dynamic> addressData) async {
    try {
      await _addressService.addAddress(
        name: addressData['name'],
        address: addressData['address'],
        city: addressData['city'],
        postalCode: addressData['postalCode'],
        type: addressData['type'],
        isDefault: addressData['isDefault'] ?? false,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Adresse ajoutée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _QuickAddressDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;

  const _QuickAddressDialog({required this.onSave});

  @override
  State<_QuickAddressDialog> createState() => _QuickAddressDialogState();
}

class _QuickAddressDialogState extends State<_QuickAddressDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();

  AddressType _selectedType = AddressType.home;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter une adresse'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: _nameController,
                label: 'Nom de l\'adresse',
                hint: 'Ex: Maison, Travail, etc.',
                validator: (value) =>
                    value?.isEmpty == true ? 'Nom requis' : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _addressController,
                label: 'Adresse',
                hint: 'Rue, numéro, quartier',
                validator: (value) =>
                    value?.isEmpty == true ? 'Adresse requise' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _cityController,
                      label: 'Ville',
                      hint: 'Abidjan',
                      validator: (value) =>
                          value?.isEmpty == true ? 'Ville requise' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      controller: _postalCodeController,
                      label: 'Code postal',
                      hint: '00225',
                      validator: (value) =>
                          value?.isEmpty == true ? 'Code postal requis' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTypeSelector(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _saveAddress,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type d\'adresse',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: AddressType.values.map((type) {
            final isSelected = _selectedType == type;
            return GestureDetector(
              onTap: () => setState(() => _selectedType = type),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(type.emoji),
                    const SizedBox(width: 4),
                    Text(
                      type.displayName,
                      style: TextStyle(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[700],
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _saveAddress() {
    if (_formKey.currentState!.validate()) {
      final addressData = {
        'name': _nameController.text,
        'address': _addressController.text,
        'city': _cityController.text,
        'postalCode': _postalCodeController.text,
        'type': _selectedType,
        'isDefault':
            false, // La première adresse sera automatiquement définie comme défaut
      };

      widget.onSave(addressData);
      Navigator.of(context).pop();
    }
  }
}

// Extension pour obtenir la couleur du type d'adresse
extension AddressTypeExtension on AddressType {
  Color get color {
    switch (this) {
      case AddressType.home:
        return Colors.green;
      case AddressType.work:
        return Colors.blue;
      case AddressType.other:
        return Colors.orange;
    }
  }
}
