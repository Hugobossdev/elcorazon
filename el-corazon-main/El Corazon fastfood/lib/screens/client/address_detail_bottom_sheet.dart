import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:elcora_fast/models/address.dart';
import 'package:elcora_fast/widgets/custom_text_field.dart';
import 'package:elcora_fast/screens/client/address_map_picker_screen.dart';
import 'package:elcora_fast/services/geocoding_service.dart';
import 'package:elcora_fast/services/places_service.dart';
import 'package:geolocator/geolocator.dart';

/// Bottom Sheet moderne pour ajouter ou éditer une adresse
class AddressDetailBottomSheet extends StatefulWidget {
  final Address? address; // null pour ajout, non-null pour édition
  final Function(Map<String, dynamic>) onSave;

  const AddressDetailBottomSheet({
    required this.onSave,
    super.key,
    this.address,
  });

  @override
  State<AddressDetailBottomSheet> createState() =>
      _AddressDetailBottomSheetState();
}

class _AddressDetailBottomSheetState extends State<AddressDetailBottomSheet>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();

  late TabController _tabController;
  final GeocodingService _geocodingService = GeocodingService();
  final PlacesService _placesService = PlacesService();

  LatLng? _pickedLatLng;
  AddressType _selectedType = AddressType.home;
  bool _isDefault = false;
  bool _isFavorite = false;
  bool _isLocating = false;
  bool _isSearching = false;
  List<PlaceSuggestion> _placeSuggestions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    if (widget.address != null) {
      _loadExistingAddress();
    } else {
      _cityController.text = 'Abidjan'; // Valeur par défaut
    }
  }

  void _loadExistingAddress() {
    final addr = widget.address!;
    _nameController.text = addr.name;
    _addressController.text = addr.address;
    _cityController.text = addr.city;
    _postalCodeController.text = addr.postalCode;
    _selectedType = addr.type;
    _isDefault = addr.isDefault;
    _isFavorite = addr.isFavorite;

    if (addr.latitude != null && addr.longitude != null) {
      _pickedLatLng = LatLng(addr.latitude!, addr.longitude!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildDragHandle(),
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFormTab(scrollController),
                    _buildMapTab(),
                    _buildSearchTab(scrollController),
                  ],
                ),
              ),
              _buildActionButtons(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.address == null
                  ? 'Nouvelle adresse'
                  : 'Modifier l\'adresse',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Material(
      color: Colors.transparent,
      child: TabBar(
        controller: _tabController,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: Theme.of(context).colorScheme.primary,
        tabs: const [
          Tab(icon: Icon(Icons.edit), text: 'Formulaire'),
          Tab(icon: Icon(Icons.map), text: 'Carte'),
          Tab(icon: Icon(Icons.search), text: 'Rechercher'),
        ],
      ),
    );
  }

  Widget _buildFormTab(ScrollController scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nom de l'adresse
            CustomTextField(
              controller: _nameController,
              label: 'Nom de l\'adresse',
              hint: 'Ex: Maison, Travail, etc.',
              validator: (value) =>
                  value?.isEmpty == true ? 'Nom requis' : null,
            ),
            const SizedBox(height: 16),

            // Adresse complète avec bouton GPS
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _addressController,
                    label: 'Adresse',
                    hint: 'Rue, numéro, quartier',
                    maxLines: 2,
                    validator: (value) =>
                        value?.isEmpty == true ? 'Adresse requise' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: IconButton(
                    onPressed: _isLocating ? null : _getCurrentLocation,
                    icon: _isLocating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    tooltip: 'Utiliser ma position',
                    style: IconButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),

            // Coordonnées GPS si disponibles
            if (_pickedLatLng != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Position GPS: ${_pickedLatLng!.latitude.toStringAsFixed(5)}, ${_pickedLatLng!.longitude.toStringAsFixed(5)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Ville et code postal
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: CustomTextField(
                    controller: _cityController,
                    label: 'Ville',
                    hint: 'Abidjan',
                    validator: (value) =>
                        value?.isEmpty == true ? 'Ville requise' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    controller: _postalCodeController,
                    label: 'Code postal',
                    hint: 'Optionnel',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Type selector
            _buildTypeSelector(),
            const SizedBox(height: 24),

            // Options
            _buildOptions(),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Sélectionnez votre position',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Placez le marqueur sur la carte',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _openMapPicker,
            icon: const Icon(Icons.map),
            label: const Text('Ouvrir la carte'),
          ),
          if (_pickedLatLng != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(height: 8),
                  Text(
                    'Position sélectionnée',
                    style: TextStyle(
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchTab(ScrollController scrollController) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher une adresse...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            onChanged: _searchPlaces,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _placeSuggestions.isEmpty
                ? _buildSearchEmptyState()
                : ListView.builder(
                    controller: scrollController,
                    itemCount: _placeSuggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _placeSuggestions[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on),
                        title: Text(suggestion.description),
                        onTap: () => _selectPlace(suggestion),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Recherchez une adresse',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(AddressType type) {
    switch (type) {
      case AddressType.home:
        return Colors.green;
      case AddressType.work:
        return Colors.blue;
      case AddressType.other:
        return Colors.orange;
    }
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type d\'adresse',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AddressType.values.map((type) {
            final isSelected = _selectedType == type;
            final color = _getColor(type);
            return InkWell(
              onTap: () => setState(() => _selectedType = type),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.15)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? color : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(type.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      type.displayName,
                      style: TextStyle(
                        color: isSelected ? color : Colors.grey.shade700,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
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

  Widget _buildOptions() {
    return Column(
      children: [
        SwitchListTile(
          value: _isDefault,
          onChanged: (value) => setState(() => _isDefault = value),
          title: const Text('Adresse par défaut'),
          subtitle: const Text('Utilisée automatiquement pour les commandes'),
          secondary: const Icon(Icons.check_circle),
        ),
        SwitchListTile(
          value: _isFavorite,
          onChanged: (value) => setState(() => _isFavorite = value),
          title: const Text('Ajouter aux favoris'),
          subtitle: const Text('Accès rapide à cette adresse'),
          secondary: Icon(Icons.star, color: Colors.amber.shade600),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
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
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Annuler'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _saveAddress,
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _pickedLatLng = latLng;
      });

      // Reverse geocode
      final address = await _geocodingService.reverseGeocode(latLng);
      if (address != null && mounted) {
        setState(() {
          _addressController.text = address;
          if (address.contains('Abidjan')) {
            _cityController.text = 'Abidjan';
          }
        });
      }

      // Passer à l'onglet formulaire
      _tabController.animateTo(0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _openMapPicker() async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => EnhancedMapPickerScreen(initialLocation: _pickedLatLng),
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _pickedLatLng = picked.location;
        if (picked.formattedAddress != null) {
          _addressController.text = picked.formattedAddress!;
          if (picked.formattedAddress!.contains('Abidjan')) {
            _cityController.text = 'Abidjan';
          }
        }
      });

      // Retour à l'onglet formulaire
      _tabController.animateTo(0);
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() => _placeSuggestions = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final suggestions = await _placesService.autocomplete(
        query,
        language: 'fr',
        countryCode: 'ci',
      );

      if (mounted) {
        setState(() {
          _placeSuggestions = suggestions;
        });
      }
    } catch (e) {
      debugPrint('Erreur recherche Places: $e');
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _selectPlace(PlaceSuggestion suggestion) async {
    try {
      final coords =
          await _geocodingService.geocodeAddress(suggestion.description);

      if (coords != null && mounted) {
        setState(() {
          _pickedLatLng = coords;
          _addressController.text = suggestion.description;
          if (suggestion.description.contains('Abidjan')) {
            _cityController.text = 'Abidjan';
          }
        });

        // Retour à l'onglet formulaire
        _tabController.animateTo(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _saveAddress() {
    if (!_formKey.currentState!.validate()) {
      _tabController.animateTo(0); // Aller au formulaire pour voir les erreurs
      return;
    }

    if (_pickedLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une position sur la carte'),
          backgroundColor: Colors.red,
        ),
      );
      _tabController.animateTo(1); // Aller à l'onglet carte
      return;
    }

    final addressData = {
      'name': _nameController.text,
      'address': _addressController.text,
      'city': _cityController.text,
      'postalCode': _postalCodeController.text,
      'type': _selectedType,
      'isDefault': _isDefault,
      'isFavorite': _isFavorite,
      'latitude': _pickedLatLng!.latitude,
      'longitude': _pickedLatLng!.longitude,
    };

    widget.onSave(addressData);
    Navigator.of(context).pop();
  }
}
