import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/models/address.dart';
import 'package:elcora_fast/widgets/custom_text_field.dart';

class AddressManagementScreen extends StatefulWidget {
  const AddressManagementScreen({super.key});

  @override
  State<AddressManagementScreen> createState() =>
      _AddressManagementScreenState();
}

class _AddressManagementScreenState extends State<AddressManagementScreen> {
  final AddressService _addressService = AddressService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Adresses'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            onPressed: () => _showAddAddressDialog(),
            icon: const Icon(Icons.add),
            tooltip: 'Ajouter une adresse',
          ),
        ],
      ),
      body: Consumer<AddressService>(
        builder: (context, addressService, child) {
          if (!addressService.hasAddresses) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: addressService.addresses.length,
            itemBuilder: (context, index) {
              final address = addressService.addresses[index];
              final isSelected =
                  addressService.selectedAddress?.id == address.id;
              final isDefault = address.isDefault;

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
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      if (isDefault)
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
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4,),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Sélectionnée',
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
                              color: address.type.color.withValues(alpha: 0.1),
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
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _handleAddressAction(value, address),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'select',
                        child: ListTile(
                          leading: Icon(Icons.check_circle),
                          title: Text('Sélectionner'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'set_default',
                        child: ListTile(
                          leading: Icon(Icons.star),
                          title: Text('Définir par défaut'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Modifier'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text('Supprimer',
                              style: TextStyle(color: Colors.red),),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _selectAddress(address),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAddressDialog(),
        icon: const Icon(Icons.add_location),
        label: const Text('Ajouter'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
            'Ajoutez votre première adresse pour faciliter vos commandes',
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

  void _handleAddressAction(String action, Address address) {
    switch (action) {
      case 'select':
        _selectAddress(address);
        break;
      case 'set_default':
        _setDefaultAddress(address);
        break;
      case 'edit':
        _showEditAddressDialog(address);
        break;
      case 'delete':
        _showDeleteAddressDialog(address);
        break;
    }
  }

  void _selectAddress(Address address) {
    _addressService.selectAddress(address.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Adresse sélectionnée : ${address.name}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _setDefaultAddress(Address address) {
    _addressService.setDefaultAddress(address.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Adresse définie comme défaut : ${address.name}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showAddAddressDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddressDialog(
        title: 'Ajouter une adresse',
        onSave: (addressData) => _addAddress(addressData),
      ),
    );
  }

  void _showEditAddressDialog(Address address) {
    showDialog(
      context: context,
      builder: (context) => _AddressDialog(
        title: 'Modifier l\'adresse',
        initialData: {
          'name': address.name,
          'address': address.address,
          'city': address.city,
          'postalCode': address.postalCode,
          'type': address.type,
          'isDefault': address.isDefault,
        },
        onSave: (addressData) => _updateAddress(address.id, addressData),
      ),
    );
  }

  void _showDeleteAddressDialog(Address address) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'adresse'),
        content: Text(
            'Êtes-vous sûr de vouloir supprimer l\'adresse "${address.name}" ?',),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAddress(address);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
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

  Future<void> _updateAddress(
      String addressId, Map<String, dynamic> addressData,) async {
    try {
      await _addressService.updateAddress(
        addressId: addressId,
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
            content: Text('Adresse modifiée avec succès'),
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

  Future<void> _deleteAddress(Address address) async {
    try {
      await _addressService.deleteAddress(address.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Adresse supprimée : ${address.name}'),
            backgroundColor: Colors.orange,
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

class _AddressDialog extends StatefulWidget {
  final String title;
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>) onSave;

  const _AddressDialog({
    required this.title,
    required this.onSave, this.initialData,
  });

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();

  AddressType _selectedType = AddressType.other;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['name'] ?? '';
      _addressController.text = widget.initialData!['address'] ?? '';
      _cityController.text = widget.initialData!['city'] ?? '';
      _postalCodeController.text = widget.initialData!['postalCode'] ?? '';
      _selectedType = widget.initialData!['type'] ?? AddressType.other;
      _isDefault = widget.initialData!['isDefault'] ?? false;
    }
  }

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
      title: Text(widget.title),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _isDefault,
                    onChanged: (value) =>
                        setState(() => _isDefault = value ?? false),
                  ),
                  const Text('Définir comme adresse par défaut'),
                ],
              ),
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
        'isDefault': _isDefault,
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
