import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcora_fast/models/delivery_fee_breakdown.dart';
import 'package:elcora_fast/services/delivery_fee_service.dart';
import 'package:elcora_fast/services/geocoding_service.dart';
import 'package:elcora_fast/services/location_service.dart';
import 'package:elcora_fast/services/places_service.dart';
import 'package:elcora_fast/utils/price_formatter.dart';

/// Résultat de la sélection de position
class PickedLocation {
  final LatLng location;
  final String? formattedAddress;

  /// Couverture au moment de la validation — l'écran appelant n'a pas à la
  /// redemander pour savoir si le point est desservi.
  final DeliveryFeeBreakdown? breakdown;

  PickedLocation({
    required this.location,
    this.formattedAddress,
    this.breakdown,
  });
}

/// Map Picker : on déplace la carte, le repère central désigne le point de
/// livraison, et le serveur répond « desservi ou non » à chaque arrêt.
class EnhancedMapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const EnhancedMapPickerScreen({super.key, this.initialLocation});

  @override
  State<EnhancedMapPickerScreen> createState() =>
      _EnhancedMapPickerScreenState();
}

class _EnhancedMapPickerScreenState extends State<EnhancedMapPickerScreen> {
  GoogleMapController? _mapController;
  final GeocodingService _geocodingService = GeocodingService();
  final DeliveryFeeService _deliveryFeeService = DeliveryFeeService();
  final PlacesService _placesService = PlacesService();
  final LocationService _locationService = LocationService();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  /// Établissement — les coordonnées de `AppConstants`, seule position de
  /// restaurant du projet. Cet écran en portait une seconde, écrite en dur, et
  /// qui pointait sur Abidjan : les cercles de couverture qu'il dessinait
  /// étaient centrés à 600 km du restaurant.
  static const LatLng _restaurantLocation = LatLng(
    AppConstants.restaurantLatitude,
    AppConstants.restaurantLongitude,
  );

  /// Point visé par la caméra.
  ///
  /// Il était auparavant reconstitué en prenant le milieu de `getVisibleRegion()`,
  /// c'est-à-dire la moyenne des latitudes des coins. En projection de
  /// Mercator cette moyenne **n'est pas** le centre de l'écran : l'écart
  /// grandit avec le zoom arrière, si bien que le repère dessiné au centre et
  /// le point réellement validé n'étaient pas le même endroit — à Lomé,
  /// plusieurs centaines de mètres au zoom d'un quartier.
  late LatLng _target;

  String? _formattedAddress;
  DeliveryFeeBreakdown? _feeBreakdown;
  bool _isResolving = false;
  bool _isCameraMoving = false;
  bool _hasLocationPermission = false;

  Timer? _cameraDebounce;
  Timer? _searchDebounce;

  /// Numéro de la dernière requête émise. Les réponses d'un point qu'on a déjà
  /// quitté sont ignorées : sans ce jeton, un géocodage lent revenant après
  /// un déplacement réécrivait l'adresse et la couverture d'un autre endroit,
  /// et le client validait un point sur la foi de la réponse d'un voisin.
  int _resolveToken = 0;

  List<PlaceSuggestion> _suggestions = [];
  bool _isSearching = false;
  int _searchToken = 0;

  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _target = widget.initialLocation ?? _restaurantLocation;
    _markers.add(
      const Marker(
        markerId: MarkerId('restaurant'),
        position: _restaurantLocation,
        infoWindow: InfoWindow(title: 'El Corazon'),
      ),
    );
    _initialize();
  }

  @override
  void dispose() {
    _cameraDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // Aucun cercle de couverture n'est dessiné, et c'est délibéré. Les deux
  // qui l'étaient — un rayon de 25 km autour du restaurant, puis un second à
  // 30 km — décrivaient une couverture qui n'existe nulle part : une zone
  // réelle est un contour dessiné à la main, souvent discontinu (un fleuve,
  // une voie ferrée, une enclave non desservie), et c'est PostGIS qui teste
  // l'appartenance d'un point. Le serveur ne rend pas ce contour aux
  // applications ; il répond « ce point-ci est desservi ». C'est donc le
  // repère lui-même qui porte la réponse, à chaque déplacement de la carte.

  Future<void> _initialize() async {
    // La permission est demandée d'emblée, mais son refus n'empêche rien : on
    // ouvre alors sur le restaurant, et le client déplace la carte lui-même.
    _hasLocationPermission = await _locationService.requestLocationPermission();
    if (mounted) setState(() {});

    if (widget.initialLocation == null && _hasLocationPermission) {
      await _goToCurrentLocation(animate: false);
    } else {
      await _resolve(_target);
    }
  }

  // ---------------------------------------------------------------- caméra

  void _onCameraMove(CameraPosition position) {
    _target = position.target;
    _cameraDebounce?.cancel();

    // Pendant le déplacement, la couverture affichée est celle du point qu'on
    // vient de quitter : elle est effacée, sans quoi le repère resterait vert
    // au-dessus d'un endroit non desservi.
    if (!_isCameraMoving) {
      setState(() {
        _isCameraMoving = true;
        _feeBreakdown = null;
        _formattedAddress = null;
      });
    }
  }

  void _onCameraIdle() {
    _cameraDebounce?.cancel();
    _cameraDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _resolve(_target),
    );
  }

  /// Interroge le serveur pour ce point : adresse lisible, puis couverture.
  Future<void> _resolve(LatLng position) async {
    final token = ++_resolveToken;

    setState(() {
      _isResolving = true;
      _isCameraMoving = false;
    });

    // Les deux questions sont posées en parallèle mais échouent séparément :
    // un libellé d'adresse indisponible n'a aucune raison d'emporter la
    // réponse de couverture, qui est la seule dont dépend la validation.
    final addressFuture = _geocodingService
        .reverseGeocode(position)
        .catchError((Object e) {
      debugPrint('Géocodage inverse indisponible : $e');
      return null;
    });

    // Couverture et barème : la question est posée au serveur, point par
    // point. Lui seul connaît les contours et les tarifs, qui se modifient
    // depuis le back-office sans republier l'application.
    DeliveryFeeBreakdown? breakdown;
    String? error;
    try {
      breakdown = await _deliveryFeeService.breakdownForPoint(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      debugPrint('Couverture non résolue : $e');
      error = 'Impossible de vérifier la couverture de ce point.';
    }

    final address = await addressFuture;

    if (!mounted || token != _resolveToken) return;

    setState(() {
      _formattedAddress = address;
      _feeBreakdown = breakdown;
      _isResolving = false;
    });

    if (error != null) _showMessage(error);
  }

  Future<void> _goToCurrentLocation({bool animate = true}) async {
    // `Geolocator.getCurrentPosition()` était appelé sans vérifier ni la
    // permission ni l'activation du GPS : sur un premier lancement Android il
    // levait une exception, avalée par un `catch` qui recentrait
    // silencieusement sur le restaurant. Le client ne comprenait pas pourquoi
    // le bouton « ma position » ne faisait rien.
    final granted = await _locationService.requestLocationPermission();
    if (!mounted) return;

    setState(() => _hasLocationPermission = granted);

    if (!granted) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      _showMessage(
        serviceEnabled
            ? 'Autorisez la localisation pour utiliser votre position.'
            : 'Activez la localisation de votre téléphone pour l\'utiliser.',
      );
      return;
    }

    final position = await _locationService.getCurrentLocation();
    if (!mounted) return;

    if (position == null) {
      _showMessage('Position introuvable pour le moment.');
      return;
    }

    final latLng = LatLng(position.latitude, position.longitude);
    _target = latLng;
    await _moveCamera(latLng, animate: animate);
    await _resolve(latLng);
  }

  Future<void> _moveCamera(LatLng position, {bool animate = true}) async {
    final controller = _mapController;
    final update = CameraUpdate.newLatLngZoom(position, 16);
    if (controller == null) return;
    if (animate) {
      await controller.animateCamera(update);
    } else {
      await controller.moveCamera(update);
    }
  }

  // -------------------------------------------------------------- recherche

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    final query = value.trim();
    if (query.length < 3) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }

    // Une requête par frappe coûtait un appel facturé à chaque lettre, et les
    // réponses revenaient dans le désordre.
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchPlaces(query),
    );
  }

  Future<void> _searchPlaces(String query) async {
    final token = ++_searchToken;
    setState(() => _isSearching = true);

    try {
      final results = await _placesService.autocomplete(
        query,
        language: 'fr',
        countryCode: AppConstants.countryCode,
        // Biaisé autour de l'établissement : sans cela, « rue du marché »
        // proposait des résultats de l'autre bout du pays avant ceux d'ici.
        locationBias: _restaurantLocation,
        radiusMeters: AppConstants.placesBiasRadiusMeters,
      );

      if (!mounted || token != _searchToken) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Recherche de lieu indisponible : $e');
      if (!mounted || token != _searchToken) return;
      setState(() => _isSearching = false);
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    _searchFocus.unfocus();
    setState(() {
      _suggestions = [];
      _isSearching = true;
      _searchController.text = suggestion.description;
    });

    // `getDetails` rend directement le point du lieu choisi. Le géocodage de
    // la description, utilisé auparavant, repassait par une recherche
    // textuelle : un second appel facturé, et un résultat parfois différent
    // de la suggestion que le client venait de toucher.
    final details = await _placesService.getDetails(
      suggestion.placeId,
      language: 'fr',
    );

    if (!mounted) return;
    setState(() => _isSearching = false);

    if (details == null) {
      _showMessage('Ce lieu n\'a pas pu être localisé.');
      return;
    }

    _target = details.location;
    await _moveCamera(details.location);
    await _resolve(details.location);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ------------------------------------------------------------------- vue

  bool get _isServiceable => _feeBreakdown?.isInServiceableZone ?? false;

  Color get _pinColor {
    if (_isCameraMoving || _isResolving || _feeBreakdown == null) {
      return Colors.grey.shade700;
    }
    return _isServiceable ? Colors.green : Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              controller.moveCamera(CameraUpdate.newLatLngZoom(_target, 16));
            },
            initialCameraPosition: CameraPosition(target: _target, zoom: 16),
            markers: _markers,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            onTap: (_) => _searchFocus.unfocus(),
            myLocationEnabled: _hasLocationPermission,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Repère central. Décalé d'une demi-hauteur pour que sa pointe, et
          // non son milieu, tombe sur le point visé.
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: Icon(
                  Icons.location_on,
                  size: 48,
                  color: _pinColor,
                  shadows: [
                    Shadow(
                      blurRadius: 4,
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(child: _buildSearchBar()),
          _buildMyLocationButton(),
          _buildInfoSheet(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Rechercher un lieu, une rue, un quartier…',
                prefixIcon: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Retour',
                ),
                suffixIcon: _buildSearchSuffix(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
          if (_suggestions.isNotEmpty) _buildSuggestions(),
        ],
      ),
    );
  }

  Widget? _buildSearchSuffix() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_searchController.text.isEmpty) return null;
    return IconButton(
      icon: const Icon(Icons.clear),
      tooltip: 'Effacer',
      onPressed: () {
        _searchDebounce?.cancel();
        setState(() {
          _searchController.clear();
          _suggestions = [];
        });
      },
    );
  }

  Widget _buildSuggestions() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(
              suggestion.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _selectSuggestion(suggestion),
          );
        },
      ),
    );
  }

  Widget _buildMyLocationButton() {
    return Positioned(
      right: 16,
      bottom: 240,
      child: FloatingActionButton(
        onPressed: _goToCurrentLocation,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.primary,
        tooltip: 'Ma position',
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Widget _buildInfoSheet() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Point de livraison',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 2),
                        _buildAddressLine(),
                      ],
                    ),
                  ),
                ],
              ),
              if (_feeBreakdown != null) ...[
                const SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                _buildFeeInfo(_feeBreakdown!),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isServiceable ? _confirmLocation : null,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Utiliser cette position'),
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
      ),
    );
  }

  Widget _buildAddressLine() {
    if (_isCameraMoving) {
      return Text(
        'Déplacez la carte…',
        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
      );
    }
    if (_isResolving) {
      return const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Text(
      // Sans adresse lisible, le point reste valide : ce sont ses coordonnées
      // qui servent à livrer, pas son libellé.
      _formattedAddress ??
          '${_target.latitude.toStringAsFixed(5)}, '
              '${_target.longitude.toStringAsFixed(5)}',
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.bold),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFeeInfo(DeliveryFeeBreakdown breakdown) {
    if (!breakdown.isInServiceableZone) {
      return _buildBanner(
        icon: Icons.cancel,
        color: Colors.red,
        title: 'Zone non desservie',
        subtitle: 'Aucune de nos zones de livraison ne couvre ce point.',
      );
    }

    if (breakdown.isFreeDelivery) {
      return _buildBanner(
        icon: Icons.card_giftcard,
        color: Colors.green,
        title: 'Livraison gratuite ! 🎉',
      );
    }

    // Le barème de la zone, pas un prix ferme : la part liée à la distance et
    // l'effet du panier ne se connaissent qu'au devis, à la validation de la
    // commande. « À partir de » est ce que l'écran sait honnêtement dire ici.
    return Column(
      children: [
        if (breakdown.zoneName != null) ...[
          _buildInfoRow(
            icon: Icons.map_outlined,
            label: 'Zone',
            value: breakdown.zoneName!,
          ),
          const SizedBox(height: 8),
        ],
        _buildInfoRow(
          icon: Icons.payments,
          label: 'Livraison à partir de',
          value: PriceFormatter.format(breakdown.totalFee),
          bold: true,
        ),
        if (breakdown.minOrderAmount != null) ...[
          const SizedBox(height: 8),
          _buildInfoRow(
            icon: Icons.shopping_basket_outlined,
            label: 'Commande minimum',
            value: PriceFormatter.format(breakdown.minOrderAmount!),
          ),
        ],
        if (breakdown.freeDeliveryThreshold != null) ...[
          const SizedBox(height: 8),
          _buildInfoRow(
            icon: Icons.card_giftcard,
            label: 'Offerte dès',
            value: PriceFormatter.format(breakdown.freeDeliveryThreshold!),
          ),
        ],
        if (breakdown.estimatedDeliveryTime != null) ...[
          const SizedBox(height: 8),
          _buildInfoRow(
            icon: Icons.schedule,
            label: 'Temps estimé',
            value: '~${breakdown.estimatedDeliveryTime} min',
          ),
        ],
      ],
    );
  }

  Widget _buildBanner({
    required IconData icon,
    required MaterialColor color,
    required String title,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color.shade900,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: color.shade800),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool bold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: bold
                  ? Theme.of(context).colorScheme.primary
                  : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  void _confirmLocation() {
    Navigator.of(context).pop(
      PickedLocation(
        location: _target,
        formattedAddress: _formattedAddress,
        breakdown: _feeBreakdown,
      ),
    );
  }
}
