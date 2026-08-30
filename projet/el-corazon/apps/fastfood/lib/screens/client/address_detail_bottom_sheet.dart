import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:elcora_fast/theme.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcora_fast/presentation/adresse.dart';
import 'package:elcora_fast/repositories/django_address_repository.dart';
import 'package:elcora_fast/widgets/custom_text_field.dart';
import 'package:elcora_fast/screens/client/address_map_picker_screen.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/services/delivery_fee_service.dart';
import 'package:elcora_fast/services/geocoding_service.dart';
import 'package:elcora_fast/services/location_service.dart';
import 'package:elcora_fast/services/places_service.dart';

/// Feuille de saisie d'une adresse — création si [address] est nul, édition
/// sinon.
///
/// Rend un [BrouillonAdresse], et non plus une `Map<String, dynamic>` dont chaque
/// appelant relisait les clés à la main (`addressData['postalCode'] ?? ''`) :
/// une clé mal orthographiée d'un côté passait la compilation et arrivait nulle
/// de l'autre. Le point est obligatoire, et c'est le type qui le dit.
class AddressDetailBottomSheet extends StatefulWidget {
  final eccore.Address? address;
  final Future<void> Function(BrouillonAdresse) onSave;

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
  final _landmarkController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _searchController = TextEditingController();

  late TabController _tabController;
  final GeocodingService _geocodingService = GeocodingService();
  final PlacesService _placesService = PlacesService();
  final LocationService _locationService = LocationService();
  final DeliveryFeeService _deliveryFeeService = DeliveryFeeService();

  LatLng? _pickedLatLng;
  TypeAdresse _selectedType = TypeAdresse.maison;
  bool _isDefault = false;
  bool _isFavorite = false;
  bool _isLocating = false;
  bool _isSearching = false;
  bool _isSaving = false;
  List<PlaceSuggestion> _placeSuggestions = [];

  Timer? _searchDebounce;

  /// Jeton de la dernière recherche émise — les réponses d'une frappe
  /// antérieure, revenues plus tard, sont écartées.
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    if (widget.address != null) {
      _loadExistingAddress();
    } else {
      // La ville pré-remplie était « Abidjan », alors que le serveur n'accepte
      // que la ville de `AppConstants.citySlug` : toute adresse créée par
      // défaut décrivait un autre pays que celui où l'on livre.
      _cityController.text = AppConstants.defaultCityName;
    }
  }

  void _loadExistingAddress() {
    final addr = widget.address!;
    _nameController.text = addr.label;
    _addressController.text = addr.line1;
    _cityController.text = addr.city;
    _postalCodeController.text = addr.line2;
    _landmarkController.text = addr.landmark;
    _instructionsController.text = addr.deliveryInstructions;
    _selectedType = addr.type;
    _isDefault = addr.isDefault;
    _isFavorite = context.read<AddressService>().estFavorite(addr.id!);
    _pickedLatLng = LatLng(addr.latitude, addr.longitude);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _landmarkController.dispose();
    _instructionsController.dispose();
    _searchController.dispose();
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
            boxShadow: const [
              BoxShadow(
                color: Color(0x331A1A1A),
                blurRadius: 10,
                offset: Offset(0, -2),
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
        color: Theme.of(context).colorScheme.outlineVariant,
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
        unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Position GPS: ${_pickedLatLng!.latitude.toStringAsFixed(5)}, ${_pickedLatLng!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
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
                    hint: AppConstants.defaultCityName,
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
            const SizedBox(height: 16),

            // Repère et consignes : les deux champs que le livreur lit
            // réellement. Le serveur les accepte depuis toujours
            // (`AddressSerializer.landmark` / `delivery_instructions`) ; ce
            // formulaire ne les collectait pas, et ils partaient vides.
            CustomTextField(
              controller: _landmarkController,
              label: 'Repère',
              hint: 'Ex: en face de la pharmacie du Golfe',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _instructionsController,
              label: 'Consignes de livraison',
              hint: 'Ex: portail bleu, appeler en arrivant',
              maxLines: 2,
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
                  color: AppColors.textSecondary,
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
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: const Column(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success),
                  SizedBox(height: 8),
                  Text(
                    'Position sélectionnée',
                    style: TextStyle(
                      color: AppColors.success,
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
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Rechercher un lieu, une rue, un quartier…',
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
                  : (_searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Effacer',
                          onPressed: () {
                            _searchDebounce?.cancel();
                            setState(() {
                              _searchController.clear();
                              _placeSuggestions = [];
                            });
                          },
                        )),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
            ),
            onChanged: _onSearchChanged,
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
          Icon(
            Icons.search,
            size: 64,
            color: AppColors.textTertiary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          const Text(
            'Recherchez une adresse',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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
          children: TypeAdresse.values.map((type) {
            final isSelected = _selectedType == type;
            // Les teintes viennent du vocabulaire (`TypeAdresse`), les mêmes
            // que la carte d'adresse : un « Travail » orange dans la liste ne
            // peut pas être bleu dans le formulaire qui le crée.
            final fond = type.fond;
            final encre = type.encre;
            return InkWell(
              onTap: () => setState(() => _selectedType = type),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? fond
                      : Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected
                        ? encre
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(type.pastille, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      type.libelle,
                      style: TextStyle(
                        color: isSelected
                            ? encre
                            : Theme.of(context).colorScheme.onSurfaceVariant,
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
          secondary: const Icon(Icons.star, color: AppColors.secondary),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A1A1A1A),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
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
                onPressed: _isSaving ? null : _saveAddress,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Vérification…' : 'Enregistrer'),
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
      // La permission était supposée acquise : `Geolocator.getCurrentPosition()`
      // levait alors une exception dont le message technique s'affichait tel
      // quel au client, sans lui dire quoi faire.
      final position = await _locationService.getCurrentLocation();
      if (!mounted) return;

      if (position == null) {
        _showError(
          'Autorisez la localisation, ou placez le point sur la carte.',
        );
        return;
      }

      final latLng = LatLng(position.latitude, position.longitude);
      setState(() => _pickedLatLng = latLng);

      final address = await _geocodingService.reverseGeocode(latLng);
      if (!mounted) return;

      if (address != null) {
        setState(() => _applyResolvedAddress(address));
      }

      _tabController.animateTo(0);
    } catch (e) {
      eccore.Journal.trace('Position indisponible : $e');
      if (mounted) {
        _showError('Position indisponible pour le moment.');
      }
    } finally {
      // Sans ce garde, quitter la feuille pendant le relevé provoquait un
      // `setState` sur un State démonté.
      if (mounted) setState(() => _isLocating = false);
    }
  }

  /// Reporte une adresse résolue dans le formulaire.
  ///
  /// La ville était devinée par `address.contains('Abidjan')`, une ville d'un
  /// autre pays : la condition était toujours fausse ici, et le champ gardait
  /// ce qui s'y trouvait.
  ///
  /// [city] est la ville que Google a **classée** comme telle
  /// (`addressComponents`), disponible depuis la migration vers Places API
  /// (New). Quand elle manque — position relevée, retour du sélecteur de
  /// carte, qui passent par le géocodage —, on retombe sur la lecture du
  /// texte : la ville configurée est retenue si l'adresse la mentionne, sinon
  /// la saisie du client reste intacte.
  void _applyResolvedAddress(String formatted, {String? city}) {
    _addressController.text = formatted;

    if (city != null && city.isNotEmpty) {
      _cityController.text = city;
      return;
    }

    const configuree = AppConstants.defaultCityName;
    if (formatted.toLowerCase().contains(configuree.toLowerCase())) {
      _cityController.text = configuree;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
          _applyResolvedAddress(picked.formattedAddress!);
        }
      });

      // Retour à l'onglet formulaire
      _tabController.animateTo(0);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    final query = value.trim();
    if (query.length < 3) {
      setState(() {
        _placeSuggestions = [];
        _isSearching = false;
      });
      return;
    }

    // Un appel partait à chaque frappe — donc facturé à chaque lettre, et les
    // réponses arrivaient dans le désordre : la liste affichait par moments
    // les suggestions d'un préfixe déjà abandonné.
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchPlaces(query),
    );
  }

  Future<void> _searchPlaces(String query) async {
    final token = ++_searchToken;
    setState(() => _isSearching = true);

    try {
      final suggestions = await _placesService.autocomplete(
        query,
        language: 'fr',
        // `country:ci` bornait la recherche à la Côte d'Ivoire : un client de
        // Lomé ne recevait jamais la moindre suggestion.
        countryCode: AppConstants.countryCode,
        locationBias: const LatLng(
          AppConstants.restaurantLatitude,
          AppConstants.restaurantLongitude,
        ),
        radiusMeters: AppConstants.placesBiasRadiusMeters,
      );

      if (!mounted || token != _searchToken) return;
      setState(() {
        _placeSuggestions = suggestions;
        _isSearching = false;
      });
    } catch (e) {
      eccore.Journal.trace('Erreur recherche Places: $e');
      if (!mounted || token != _searchToken) return;
      setState(() => _isSearching = false);
    }
  }

  Future<void> _selectPlace(PlaceSuggestion suggestion) async {
    setState(() => _isSearching = true);

    try {
      // `getDetails` rend le point exact du lieu touché. Le géocodage de la
      // description repassait par une recherche textuelle : un appel de plus,
      // et un point qui pouvait ne pas être celui de la suggestion choisie.
      final details = await _placesService.getDetails(
        suggestion.placeId,
        language: 'fr',
      );

      if (!mounted) return;

      if (details == null) {
        _showError('Ce lieu n\'a pas pu être localisé.');
        return;
      }

      setState(() {
        _pickedLatLng = details.location;
        _applyResolvedAddress(details.formattedAddress, city: details.city);
      });

      // Retour à l'onglet formulaire
      _tabController.animateTo(0);
    } catch (e) {
      eccore.Journal.trace('Détail de lieu indisponible : $e');
      if (mounted) _showError('Ce lieu n\'a pas pu être localisé.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _saveAddress() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
      _tabController.animateTo(0); // Aller au formulaire pour voir les erreurs
      return;
    }

    final point = _pickedLatLng;
    if (point == null) {
      _showError('Veuillez sélectionner une position sur la carte');
      _tabController.animateTo(1); // Aller à l'onglet carte
      return;
    }

    setState(() => _isSaving = true);

    // La couverture est vérifiée ici, et non au moment de commander. Une
    // adresse hors zone s'enregistrait sans un mot, et le refus ne tombait
    // qu'au paiement, panier plein — le client devait alors tout reprendre.
    try {
      final breakdown = await _deliveryFeeService.breakdownForPoint(
        latitude: point.latitude,
        longitude: point.longitude,
      );

      if (!mounted) return;

      if (!breakdown.isInServiceableZone) {
        setState(() => _isSaving = false);
        final saveAnyway = await _confirmOutOfZone();
        if (!mounted || saveAnyway != true) return;
        setState(() => _isSaving = true);
      }
    } catch (e) {
      // Serveur injoignable : on n'empêche pas l'enregistrement pour autant.
      // Le devis de commande refera la vérification, et lui seul fait foi.
      eccore.Journal.trace('Couverture non vérifiée avant enregistrement : $e');
    }

    if (!mounted) return;

    final draft = BrouillonAdresse(
      nom: _nameController.text.trim(),
      ligne1: _addressController.text.trim(),
      // La ville n'est plus envoyée telle quelle : le serveur attend
      // l'identifiant d'une `City`, que le dépôt résout. La saisie sert à
      // l'affichage et au géocodage.
      ligne2: _postalCodeController.text.trim(),
      repere: _landmarkController.text.trim(),
      consignes: _instructionsController.text.trim(),
      type: _selectedType,
      estParDefaut: _isDefault,
      estFavorite: _isFavorite,
      latitude: point.latitude,
      longitude: point.longitude,
    );

    // L'enregistrement est **attendu**, et la feuille ne se ferme que s'il
    // aboutit. Elle se fermait auparavant sans attendre : l'écran affichait
    // « Adresse ajoutée » pendant que l'appel partait, et un refus du serveur
    // arrivait sur une feuille déjà disparue, avec la saisie perdue.
    try {
      await widget.onSave(draft);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError(_messageFor(e));
    }
  }

  String _messageFor(Object error) {
    if (error is AddressSessionRequired) return error.toString();
    if (error is eccore.ApiException) return error.detail;
    return 'Adresse non enregistrée. Réessayez.';
  }

  Future<bool?> _confirmOutOfZone() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.location_off, color: AppColors.warning),
        title: const Text('Adresse hors zone'),
        content: const Text(
          'Aucune de nos zones de livraison ne couvre ce point. '
          'Vous pouvez l\'enregistrer, mais aucune commande ne pourra y être '
          'livrée pour le moment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Modifier'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enregistrer quand même'),
          ),
        ],
      ),
    );
  }
}
