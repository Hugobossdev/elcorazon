import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:elcora_fast/services/location_service.dart';
import 'package:elcora_fast/services/geocoding_service.dart';
import 'package:elcora_fast/models/address.dart';
import 'package:elcora_fast/models/delivery_fee_breakdown.dart';
import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcora_fast/config/delivery_config.dart';

/// Service de calcul dynamique des frais de livraison basé sur la distance
class DeliveryFeeService extends ChangeNotifier {
  static final DeliveryFeeService _instance = DeliveryFeeService._internal();
  factory DeliveryFeeService() => _instance;
  DeliveryFeeService._internal();

  // Position du restaurant (coordonnées par défaut - Lomé, Togo)
  // Note: Coordonnées centralisées dans AppConstants
  static const double _restaurantLatitude = AppConstants.restaurantLatitude;
  static const double _restaurantLongitude = AppConstants.restaurantLongitude;

  // Tarifs de livraison (en FCFA)
  static const double _baseFee = 500.0; // Frais de base
  static const double _feePerKilometer = 200.0; // Tarif par kilomètre
  static const double _defaultFee = 1000.0; // Frais par défaut en cas d'erreur
  static const double _maxFee = 5000.0; // Frais maximum
  static const double _freeDeliveryThreshold =
      10000.0; // Livraison gratuite au-dessus de ce montant

  final LocationService _locationService = LocationService();
  final GeocodingService _geocodingService = GeocodingService();

  bool _isInitialized = false;
  double? _lastCalculatedFee;
  double? _lastCalculatedDistance;
  DeliveryFeeBreakdown? _lastBreakdown;
  final Map<String, DeliveryFeeBreakdown> _feeCache = {};

  bool get isInitialized => _isInitialized;
  double? get lastCalculatedFee => _lastCalculatedFee;
  double? get lastCalculatedDistance => _lastCalculatedDistance;
  DeliveryFeeBreakdown? get lastBreakdown => _lastBreakdown;

  /// Initialise le service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // S'assurer que LocationService est initialisé
      if (!_locationService.isInitialized) {
        await _locationService.initialize();
      }

      _isInitialized = true;
      notifyListeners();
      debugPrint('✅ DeliveryFeeService: Service initialisé');
    } catch (e) {
      debugPrint('❌ DeliveryFeeService: Erreur d\'initialisation - $e');
      _isInitialized = false;
    }
  }

  /// Calcule les frais de livraison basés sur la distance
  ///
  /// [deliveryAddress] : Adresse de livraison (texte)
  /// [deliveryLatitude] : Latitude de l'adresse (optionnel, sera calculé si non fourni)
  /// [deliveryLongitude] : Longitude de l'adresse (optionnel, sera calculé si non fourni)
  /// [orderSubtotal] : Sous-total de la commande (pour la livraison gratuite)
  /// [isVip] : Si l'utilisateur est VIP (livraison gratuite)
  ///
  /// Retourne les frais de livraison en FCFA
  Future<double> calculateDeliveryFee({
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    double orderSubtotal = 0.0,
    bool isVip = false,
  }) async {
    try {
      // Vérifier si la livraison est gratuite (commande importante ou VIP)
      if (isVip) {
        debugPrint('✅ DeliveryFeeService: Livraison gratuite (Client VIP)');
        _lastCalculatedFee = 0.0;
        _lastCalculatedDistance = null;
        notifyListeners();
        return 0.0;
      }

      if (orderSubtotal >= _freeDeliveryThreshold) {
        debugPrint(
          '✅ DeliveryFeeService: Livraison gratuite (commande >= $_freeDeliveryThreshold FCFA)',
        );
        _lastCalculatedFee = 0.0;
        _lastCalculatedDistance = null;
        notifyListeners();
        return 0.0;
      }

      // Obtenir les coordonnées de livraison
      double? lat = deliveryLatitude;
      double? lon = deliveryLongitude;

      // Si les coordonnées ne sont pas fournies, essayer de les obtenir depuis l'adresse
      if (lat == null || lon == null) {
        if (deliveryAddress != null && deliveryAddress.isNotEmpty) {
          try {
            final latLng =
                await _geocodingService.geocodeAddress(deliveryAddress);
            if (latLng != null) {
              lat = latLng.latitude;
              lon = latLng.longitude;
              debugPrint(
                '✅ DeliveryFeeService: Coordonnées obtenues depuis l\'adresse: $lat, $lon',
              );
            }
          } catch (e) {
            debugPrint('⚠️ DeliveryFeeService: Erreur géocodage adresse - $e');
          }
        }

        // Si toujours pas de coordonnées, essayer d'utiliser la position actuelle
        if (lat == null || lon == null) {
          try {
            final currentPosition = await _locationService.getCurrentLocation();
            if (currentPosition != null) {
              lat = currentPosition.latitude;
              lon = currentPosition.longitude;
              debugPrint(
                '✅ DeliveryFeeService: Coordonnées obtenues depuis la position actuelle: $lat, $lon',
              );
            }
          } catch (e) {
            debugPrint('⚠️ DeliveryFeeService: Erreur position actuelle - $e');
          }
        }
      }

      // Si toujours pas de coordonnées, utiliser le prix par défaut
      if (lat == null || lon == null) {
        debugPrint(
          '⚠️ DeliveryFeeService: Impossible d\'obtenir les coordonnées, utilisation du prix par défaut',
        );
        _lastCalculatedFee = _defaultFee;
        _lastCalculatedDistance = null;
        notifyListeners();
        return _defaultFee;
      }

      // Calculer la distance
      final distance = _calculateDistance(
        _restaurantLatitude,
        _restaurantLongitude,
        lat,
        lon,
      );

      _lastCalculatedDistance = distance;

      // Calculer les frais basés sur la distance
      double fee = _baseFee + (distance * _feePerKilometer);

      // Arrondir à la dizaine supérieure
      fee = (fee / 10).ceil() * 10;

      // Limiter au maximum
      if (fee > _maxFee) {
        fee = _maxFee;
      }

      // S'assurer que le minimum est respecté
      if (fee < _baseFee) {
        fee = _baseFee;
      }

      _lastCalculatedFee = fee;

      debugPrint(
        '✅ DeliveryFeeService: Distance calculée: ${distance.toStringAsFixed(2)} km',
      );
      debugPrint(
        '✅ DeliveryFeeService: Frais de livraison calculés: ${fee.toStringAsFixed(0)} FCFA',
      );

      notifyListeners();
      return fee;
    } catch (e) {
      debugPrint('❌ DeliveryFeeService: Erreur calcul frais - $e');
      // En cas d'erreur, retourner le prix par défaut
      _lastCalculatedFee = _defaultFee;
      _lastCalculatedDistance = null;
      notifyListeners();
      return _defaultFee;
    }
  }

  /// Calcule les frais de livraison depuis une adresse Address
  Future<double> calculateDeliveryFeeFromAddress({
    required Address address,
    double orderSubtotal = 0.0,
    bool isVip = false,
  }) async {
    return calculateDeliveryFee(
      deliveryAddress: address.fullAddress,
      deliveryLatitude: address.latitude,
      deliveryLongitude: address.longitude,
      orderSubtotal: orderSubtotal,
      isVip: isVip,
    );
  }

  /// Calcule la distance entre deux points en kilomètres
  double _calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    try {
      final distanceInMeters = Geolocator.distanceBetween(
        startLatitude,
        startLongitude,
        endLatitude,
        endLongitude,
      );

      // Convertir en kilomètres
      final distanceInKm = distanceInMeters / 1000.0;

      return distanceInKm;
    } catch (e) {
      debugPrint('❌ DeliveryFeeService: Erreur calcul distance - $e');
      // En cas d'erreur, retourner une distance par défaut (5 km)
      return 5.0;
    }
  }

  /// Obtient la distance estimée en kilomètres
  Future<double?> getEstimatedDistance({
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
  }) async {
    try {
      double? lat = deliveryLatitude;
      double? lon = deliveryLongitude;

      // Si les coordonnées ne sont pas fournies, essayer de les obtenir
      if (lat == null || lon == null) {
        if (deliveryAddress != null && deliveryAddress.isNotEmpty) {
          try {
            final latLng =
                await _geocodingService.geocodeAddress(deliveryAddress);
            if (latLng != null) {
              lat = latLng.latitude;
              lon = latLng.longitude;
            }
          } catch (e) {
            debugPrint(
              '⚠️ DeliveryFeeService: Erreur géocodage pour distance - $e',
            );
          }
        }

        if (lat == null || lon == null) {
          final currentPosition = await _locationService.getCurrentLocation();
          if (currentPosition != null) {
            lat = currentPosition.latitude;
            lon = currentPosition.longitude;
          }
        }
      }

      if (lat == null || lon == null) {
        return null;
      }

      final distance = _calculateDistance(
        _restaurantLatitude,
        _restaurantLongitude,
        lat,
        lon,
      );

      return distance;
    } catch (e) {
      debugPrint('❌ DeliveryFeeService: Erreur estimation distance - $e');
      return null;
    }
  }

  /// Obtient le temps de livraison estimé en minutes
  /// Basé sur la distance (environ 30 km/h de moyenne)
  Future<int?> getEstimatedDeliveryTime({
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
  }) async {
    try {
      final distance = await getEstimatedDistance(
        deliveryAddress: deliveryAddress,
        deliveryLatitude: deliveryLatitude,
        deliveryLongitude: deliveryLongitude,
      );

      if (distance == null) {
        return null;
      }

      // Temps de préparation de base : 15 minutes
      const int basePreparationTime = 15;

      // Vitesse moyenne : 30 km/h (0.5 km/min)
      const double averageSpeedKmPerMin = 0.5;

      // Temps de trajet en minutes
      final int travelTime = (distance / averageSpeedKmPerMin).round();

      // Temps total = préparation + trajet
      final int totalTime = basePreparationTime + travelTime;

      return totalTime;
    } catch (e) {
      debugPrint('❌ DeliveryFeeService: Erreur estimation temps - $e');
      return null;
    }
  }

  /// Réinitialise les valeurs calculées
  void reset() {
    _lastCalculatedFee = null;
    _lastCalculatedDistance = null;
    notifyListeners();
  }

  /// Obtient les informations complètes de livraison
  Future<Map<String, dynamic>> getDeliveryInfo({
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    double orderSubtotal = 0.0,
    bool isVip = false,
  }) async {
    try {
      final fee = await calculateDeliveryFee(
        deliveryAddress: deliveryAddress,
        deliveryLatitude: deliveryLatitude,
        deliveryLongitude: deliveryLongitude,
        orderSubtotal: orderSubtotal,
        isVip: isVip,
      );

      final distance = await getEstimatedDistance(
        deliveryAddress: deliveryAddress,
        deliveryLatitude: deliveryLatitude,
        deliveryLongitude: deliveryLongitude,
      );

      final time = await getEstimatedDeliveryTime(
        deliveryAddress: deliveryAddress,
        deliveryLatitude: deliveryLatitude,
        deliveryLongitude: deliveryLongitude,
      );

      return {
        'fee': fee,
        'distance': distance,
        'estimatedTime': time,
        'isFreeDelivery': isVip || orderSubtotal >= _freeDeliveryThreshold,
        'restaurantLocation': {
          'latitude': _restaurantLatitude,
          'longitude': _restaurantLongitude,
        },
      };
    } catch (e) {
      debugPrint('❌ DeliveryFeeService: Erreur getDeliveryInfo - $e');
      return {
        'fee': _defaultFee,
        'distance': null,
        'estimatedTime': null,
        'isFreeDelivery': false,
        'restaurantLocation': {
          'latitude': _restaurantLatitude,
          'longitude': _restaurantLongitude,
        },
      };
    }
  }

  /// Calcule les frais de livraison avec décomposition détaillée
  ///
  /// Version améliorée qui retourne un objet DeliveryFeeBreakdown
  /// avec tous les détails du calcul
  Future<DeliveryFeeBreakdown> calculateDetailedDeliveryFee({
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    double orderSubtotal = 0.0,
    bool isVip = false,
  }) async {
    try {
      // Créer une clé de cache si activé
      String? cacheKey;
      if (DeliveryConfig.enableFeeCache &&
          deliveryLatitude != null &&
          deliveryLongitude != null) {
        cacheKey =
            '${deliveryLatitude.toStringAsFixed(6)}_${deliveryLongitude.toStringAsFixed(6)}';

        // Vérifier le cache
        final cached = _feeCache[cacheKey];
        if (cached != null) {
          debugPrint(
            '✅ DeliveryFeeService: Utilisation du cache pour $cacheKey',
          );
          return cached;
        }
      }

      // Vérifier si la livraison est gratuite (VIP)
      if (isVip) {
        final breakdown = DeliveryFeeBreakdown.free(
          reason: DeliveryConfig.freeDeliveryVipMessage,
        );
        _lastBreakdown = breakdown;
        _lastCalculatedFee = 0.0;
        _lastCalculatedDistance = 0.0;
        notifyListeners();
        return breakdown;
      }

      // Vérifier si la livraison est gratuite (montant)
      if (orderSubtotal >= DeliveryConfig.freeDeliveryThreshold) {
        final breakdown = DeliveryFeeBreakdown.free(
          reason: DeliveryConfig.freeDeliveryAmountMessage,
        );
        _lastBreakdown = breakdown;
        _lastCalculatedFee = 0.0;
        _lastCalculatedDistance = 0.0;
        notifyListeners();
        return breakdown;
      }

      // Obtenir les coordonnées de livraison
      double? lat = deliveryLatitude;
      double? lon = deliveryLongitude;

      // Si les coordonnées ne sont pas fournies, essayer de les obtenir
      if (lat == null || lon == null) {
        if (deliveryAddress != null && deliveryAddress.isNotEmpty) {
          try {
            final latLng =
                await _geocodingService.geocodeAddress(deliveryAddress);
            if (latLng != null) {
              lat = latLng.latitude;
              lon = latLng.longitude;
              debugPrint(
                '✅ DeliveryFeeService: Coordonnées obtenues depuis l\'adresse',
              );
            }
          } catch (e) {
            debugPrint('⚠️ DeliveryFeeService: Erreur géocodage - $e');
          }
        }

        // Essayer la position actuelle en dernier recours
        if (lat == null || lon == null) {
          try {
            final currentPosition = await _locationService.getCurrentLocation();
            if (currentPosition != null) {
              lat = currentPosition.latitude;
              lon = currentPosition.longitude;
              debugPrint(
                '✅ DeliveryFeeService: Coordonnées obtenues depuis la position actuelle',
              );
            }
          } catch (e) {
            debugPrint('⚠️ DeliveryFeeService: Erreur position actuelle - $e');
          }
        }
      }

      // Si toujours pas de coordonnées, retourner une erreur
      if (lat == null || lon == null) {
        debugPrint(
          '⚠️ DeliveryFeeService: Impossible d\'obtenir les coordonnées',
        );
        final breakdown = DeliveryFeeBreakdown(
          distance: 0.0,
          baseFee: DeliveryConfig.baseFee,
          distanceFee: 0.0,
          totalFee: _defaultFee,
          isInServiceableZone: false,
        );
        _lastBreakdown = breakdown;
        notifyListeners();
        return breakdown;
      }

      // Calculer la distance
      final distance = _calculateDistance(
        _restaurantLatitude,
        _restaurantLongitude,
        lat,
        lon,
      );

      // Vérifier la distance maximale
      if (distance > DeliveryConfig.maxDeliveryDistance) {
        debugPrint(
          '❌ DeliveryFeeService: Distance trop importante: ${distance.toStringAsFixed(2)} km',
        );
        final breakdown = DeliveryFeeBreakdown.notServiceable(
          distance: distance,
        );
        _lastBreakdown = breakdown;
        _lastCalculatedDistance = distance;
        notifyListeners();
        return breakdown;
      }

      // Calculer les frais
      const baseFee = DeliveryConfig.baseFee;
      final distanceFee = distance * DeliveryConfig.pricePerKm;
      double totalFee = baseFee + distanceFee;

      // Arrondir à la dizaine supérieure si configuré
      if (DeliveryConfig.roundToNearestTen) {
        totalFee = (totalFee / 10).ceil() * 10;
      }

      // Limiter au maximum
      if (totalFee > DeliveryConfig.maxFee) {
        totalFee = DeliveryConfig.maxFee;
      }

      // S'assurer que le minimum est respecté
      if (totalFee < baseFee) {
        totalFee = baseFee;
      }

      // Calculer le temps estimé
      final estimatedTime = _calculateEstimatedTime(distance);

      // Créer le breakdown
      final breakdown = DeliveryFeeBreakdown(
        distance: distance,
        baseFee: baseFee,
        distanceFee: distanceFee,
        totalFee: totalFee,
        estimatedDeliveryTime: estimatedTime,
        restaurantLocation: {
          'latitude': _restaurantLatitude,
          'longitude': _restaurantLongitude,
        },
        deliveryLocation: {
          'latitude': lat,
          'longitude': lon,
        },
      );

      // Mettre à jour le cache
      if (cacheKey != null && DeliveryConfig.enableFeeCache) {
        _feeCache[cacheKey] = breakdown;
        // Nettoyer le cache après la durée configurée
        Future.delayed(
          const Duration(minutes: DeliveryConfig.feeCacheDuration),
          () => _feeCache.remove(cacheKey),
        );
      }

      _lastBreakdown = breakdown;
      _lastCalculatedFee = totalFee;
      _lastCalculatedDistance = distance;

      debugPrint('✅ DeliveryFeeService: Calcul détaillé complet');
      debugPrint('   Distance: ${distance.toStringAsFixed(2)} km');
      debugPrint('   Frais base: ${baseFee.toStringAsFixed(0)} FCFA');
      debugPrint('   Frais distance: ${distanceFee.toStringAsFixed(0)} FCFA');
      debugPrint('   Total: ${totalFee.toStringAsFixed(0)} FCFA');
      debugPrint('   Temps estimé: $estimatedTime min');

      notifyListeners();
      return breakdown;
    } catch (e) {
      debugPrint('❌ DeliveryFeeService: Erreur calcul détaillé - $e');
      final breakdown = DeliveryFeeBreakdown(
        distance: 0.0,
        baseFee: DeliveryConfig.baseFee,
        distanceFee: 0.0,
        totalFee: _defaultFee,
        isInServiceableZone: false,
      );
      _lastBreakdown = breakdown;
      notifyListeners();
      return breakdown;
    }
  }

  /// Calcule les frais détaillés depuis une adresse Address
  Future<DeliveryFeeBreakdown> calculateDetailedDeliveryFeeFromAddress({
    required Address address,
    double orderSubtotal = 0.0,
    bool isVip = false,
  }) async {
    return calculateDetailedDeliveryFee(
      deliveryAddress: address.fullAddress,
      deliveryLatitude: address.latitude,
      deliveryLongitude: address.longitude,
      orderSubtotal: orderSubtotal,
      isVip: isVip,
    );
  }

  /// Calcule le temps estimé de livraison
  int _calculateEstimatedTime(double distance) {
    // Temps de préparation de base
    const baseTime = DeliveryConfig.basePreparationTime;

    // Vitesse moyenne en km/min
    const speedKmPerMin = DeliveryConfig.averageSpeedKmH / 60.0;

    // Temps de trajet
    final travelTime = (distance / speedKmPerMin).round();

    return baseTime + travelTime;
  }

  /// Vide le cache des frais
  void clearCache() {
    _feeCache.clear();
    debugPrint('🗑️ DeliveryFeeService: Cache vidé');
  }

  /// Vérifie si une adresse est desservie
  Future<bool> isAddressServiceable({
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
  }) async {
    final breakdown = await calculateDetailedDeliveryFee(
      deliveryAddress: deliveryAddress,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
    );
    return breakdown.isInServiceableZone;
  }
}
