import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:elcora_fast/models/address.dart';
import 'package:elcora_fast/repositories/django_address_repository.dart';
import 'package:elcora_fast/services/geocoding_service.dart';

class AddressService extends ChangeNotifier {
  static final AddressService _instance = AddressService._internal();
  factory AddressService() => _instance;
  AddressService._internal();

  List<Address> _addresses = [];
  Address? _selectedAddress;
  bool _isInitialized = false;
  String? _userId;

  final DjangoAddressRepository _addressRepository = DjangoAddressRepository();
  final Uuid _uuid = const Uuid();
  final GeocodingService _geocodingService = GeocodingService();

  bool _isMigratingCoordinates = false;
  int _migrationTotal = 0;
  int _migrationDone = 0;

  bool get isMigratingCoordinates => _isMigratingCoordinates;
  int get migrationTotal => _migrationTotal;
  int get migrationDone => _migrationDone;

  // Getters
  List<Address> get addresses => List.unmodifiable(_addresses);
  Address? get selectedAddress => _selectedAddress;
  Address? get defaultAddress =>
      _addresses.where((a) => a.isDefault).firstOrNull;
  List<Address> get favoriteAddresses =>
      _addresses.where((a) => a.isFavorite).toList();
  bool get isInitialized => _isInitialized;
  bool get hasAddresses => _addresses.isNotEmpty;

  String get _addressesStorageKey {
    final key = _userId ?? 'guest';
    return 'user_addresses_$key';
  }

  String get _selectedAddressStorageKey {
    final key = _userId ?? 'guest';
    return 'selected_address_id_$key';
  }

  /// Initialise le service et charge les adresses depuis le stockage local
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadAddresses();
      _isInitialized = true;
      notifyListeners();
      debugPrint(
        'AddressService: Initialisé avec ${_addresses.length} adresses',
      );
    } catch (e) {
      debugPrint('AddressService: Erreur d\'initialisation - $e');
    }
  }

  Future<void> initializeForUser(String userId) async {
    _userId = userId;
    await _loadAddresses();
    await _loadAddressesFromDatabase();

    // Migration lat/lng en arrière-plan (ne pas bloquer l'UI)
    unawaited(migrateMissingCoordinates());
  }

  Future<void> clearSession() async {
    _addresses = [];
    _selectedAddress = null;
    _userId = null;
    notifyListeners();
  }

  /// Charge les adresses depuis le stockage local
  Future<void> _loadAddresses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final addressesJson = prefs.getStringList(_addressesStorageKey) ?? [];

      _addresses = addressesJson
          .map((json) => Address.fromJson(jsonDecode(json)))
          .toList();

      // Charger l'adresse sélectionnée
      final selectedAddressId = prefs.getString(_selectedAddressStorageKey);
      if (selectedAddressId != null) {
        _selectedAddress =
            _addresses.where((a) => a.id == selectedAddressId).firstOrNull;
      }

      // Si aucune adresse sélectionnée, utiliser l'adresse par défaut
      if (_selectedAddress == null && _addresses.isNotEmpty) {
        _selectedAddress = defaultAddress ?? _addresses.first;
      }
    } catch (e) {
      debugPrint('AddressService: Erreur de chargement des adresses - $e');
    }
  }

  /// Sauvegarde les adresses dans le stockage local
  Future<void> _saveAddresses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final addressesJson =
          _addresses.map((address) => jsonEncode(address.toJson())).toList();

      if (addressesJson.isEmpty) {
        await prefs.remove(_addressesStorageKey);
      } else {
        await prefs.setStringList(_addressesStorageKey, addressesJson);
      }

      if (_selectedAddress != null) {
        await prefs.setString(
          _selectedAddressStorageKey,
          _selectedAddress!.id,
        );
      } else {
        await prefs.remove(_selectedAddressStorageKey);
      }
    } catch (e) {
      debugPrint('AddressService: Erreur de sauvegarde des adresses - $e');
    }
  }

  Future<void> _loadAddressesFromDatabase() async {
    if (_userId == null) return;

    try {
      final remoteAddresses = await _addressRepository.list(userId: _userId!);

      // `isFavorite` n'existe pas côté Django (hors scope de cette tranche,
      // reste un concept purement local) — préservé depuis l'état local
      // existant plutôt que silencieusement réinitialisé à chaque rechargement.
      final previousFavorites = {
        for (final address in _addresses)
          if (address.isFavorite) address.id: true,
      };
      _addresses = remoteAddresses
          .map(
            (address) => previousFavorites.containsKey(address.id)
                ? address.copyWith(isFavorite: true)
                : address,
          )
          .toList();

      if (_addresses.isNotEmpty) {
        _selectedAddress = defaultAddress ?? _addresses.first;
      } else {
        _selectedAddress = null;
      }

      await _saveAddresses();
      notifyListeners();
      debugPrint(
        'AddressService: Synchronisation serveur (${_addresses.length} adresses)',
      );
    } catch (e) {
      debugPrint('AddressService: Erreur de synchronisation - $e');
    }
  }

  /// Migration: géocoder et remplir latitude/longitude si manquants.
  ///
  /// - Met à jour Supabase (si user connecté) + cache local.
  /// - Throttle pour éviter les quotas.
  /// - N'échoue pas en bloc si une adresse échoue.
  Future<void> migrateMissingCoordinates() async {
    if (_isMigratingCoordinates) return;
    if (_userId == null) return; // uniquement user connecté

    final missing = _addresses
        .where((a) => a.latitude == null || a.longitude == null)
        .toList();

    if (missing.isEmpty) return;

    _isMigratingCoordinates = true;
    _migrationTotal = missing.length;
    _migrationDone = 0;
    notifyListeners();

    try {
      for (final addr in missing) {
        final query = addr.fullAddress.trim();
        if (query.isEmpty) {
          _migrationDone++;
          notifyListeners();
          continue;
        }

        try {
          final coords = await _geocodingService.geocodeAddress(query);
          if (coords == null) {
            _migrationDone++;
            notifyListeners();
            continue;
          }

          // Update DB + local state
          final updated = await updateAddress(
            addressId: addr.id,
            latitude: coords.latitude,
            longitude: coords.longitude,
          );

          // Si l'adresse sélectionnée était celle-ci, la mettre à jour
          if (_selectedAddress?.id == updated.id) {
            _selectedAddress = updated;
          }
        } catch (e) {
          debugPrint(
            'AddressService: migration coords failed for ${addr.id}: $e',
          );
        } finally {
          _migrationDone++;
          notifyListeners();
          // petit délai pour throttling
          await Future.delayed(const Duration(milliseconds: 250));
        }
      }
    } finally {
      _isMigratingCoordinates = false;
      await _saveAddresses();
      notifyListeners();
    }
  }

  /// Ajoute une nouvelle adresse
  Future<Address> addAddress({
    required String name,
    required String address,
    required String city,
    required String postalCode,
    AddressType type = AddressType.other,
    double? latitude,
    double? longitude,
    bool isDefault = false,
    bool isFavorite = false,
  }) async {
    try {
      // Si les coordonnées ne sont pas fournies, géocoder l'adresse automatiquement
      double? finalLatitude = latitude;
      double? finalLongitude = longitude;

      if (finalLatitude == null || finalLongitude == null) {
        final fullAddress =
            '$address, $city${postalCode.isNotEmpty ? ', $postalCode' : ''}';
        debugPrint(
          'AddressService: Géocodage automatique de l\'adresse: $fullAddress',
        );

        try {
          final coords = await _geocodingService.geocodeAddress(fullAddress);
          if (coords != null) {
            finalLatitude = coords.latitude;
            finalLongitude = coords.longitude;
            debugPrint(
              'AddressService: Coordonnées obtenues - lat: $finalLatitude, lng: $finalLongitude',
            );
          } else {
            debugPrint(
              '⚠️ AddressService: Impossible de géocoder l\'adresse: $fullAddress',
            );
            // On continue quand même, mais l'adresse n'aura pas de coordonnées
          }
        } catch (e) {
          debugPrint('⚠️ AddressService: Erreur lors du géocodage: $e');
          // On continue quand même
        }
      }

      final shouldBeDefault = _addresses.isEmpty || isDefault;
      Address newAddress;

      // `location` est obligatoire côté serveur (`AddressSerializer`) : sans
      // coordonnées géocodées, l'adresse reste locale même pour un compte
      // connecté — `migrateMissingCoordinates` la créera côté Django dès que
      // le géocodage aboutira (voir plus bas, même invariant : une adresse
      // sans coordonnées n'existe pas encore côté serveur).
      if (_userId != null && finalLatitude != null && finalLongitude != null) {
        // Le serveur rétrograde lui-même l'ancien défaut
        // (`AddressViewSet.perform_create`) — pas besoin de le faire ici.
        newAddress = await _addressRepository.create(
          Address(
            id: '',
            userId: _userId!,
            name: name,
            address: address,
            city: city,
            postalCode: postalCode,
            latitude: finalLatitude,
            longitude: finalLongitude,
            type: type,
            isDefault: shouldBeDefault,
            isFavorite: isFavorite,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        if (shouldBeDefault) {
          _addresses =
              _addresses.map((a) => a.copyWith(isDefault: false)).toList();
        }
      } else {
        newAddress = Address(
          id: _uuid.v4(),
          userId: _userId ?? 'guest',
          name: name,
          address: address,
          city: city,
          postalCode: postalCode,
          latitude: finalLatitude,
          longitude: finalLongitude,
          type: type,
          isDefault: shouldBeDefault,
          isFavorite: isFavorite,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        if (shouldBeDefault) {
          _addresses =
              _addresses.map((a) => a.copyWith(isDefault: false)).toList();
        }
      }

      _addresses.add(newAddress);

      if (shouldBeDefault) {
        _selectedAddress = newAddress;
      } else if (_addresses.length == 1) {
        _selectedAddress = newAddress;
      }

      await _saveAddresses();
      notifyListeners();

      debugPrint('AddressService: Adresse ajoutée - ${newAddress.name}');
      return newAddress;
    } catch (e) {
      debugPrint('AddressService: Erreur d\'ajout d\'adresse - $e');
      rethrow;
    }
  }

  /// Met à jour une adresse existante
  Future<Address> updateAddress({
    required String addressId,
    String? name,
    String? address,
    String? city,
    String? postalCode,
    AddressType? type,
    bool? isDefault,
    bool? isFavorite,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final index = _addresses.indexWhere((a) => a.id == addressId);
      if (index == -1) {
        throw Exception('Adresse non trouvée');
      }

      final currentAddress = _addresses[index];

      // Déterminer les valeurs finales
      final finalAddress = address ?? currentAddress.address;
      final finalCity = city ?? currentAddress.city;
      final finalPostalCode = postalCode ?? currentAddress.postalCode;

      // Si l'adresse a changé ou si les coordonnées sont manquantes, géocoder
      double? finalLatitude = latitude;
      double? finalLongitude = longitude;

      final addressChanged =
          (address != null && address != currentAddress.address) ||
              (city != null && city != currentAddress.city) ||
              (postalCode != null && postalCode != currentAddress.postalCode);

      final coordinatesMissing = (finalLatitude == null ||
              finalLongitude == null) &&
          (currentAddress.latitude == null || currentAddress.longitude == null);

      if ((addressChanged || coordinatesMissing) &&
          (finalLatitude == null || finalLongitude == null)) {
        final fullAddress =
            '$finalAddress, $finalCity${finalPostalCode.isNotEmpty ? ', $finalPostalCode' : ''}';
        debugPrint(
          'AddressService: Géocodage automatique lors de la mise à jour: $fullAddress',
        );

        try {
          final coords = await _geocodingService.geocodeAddress(fullAddress);
          if (coords != null) {
            finalLatitude = coords.latitude;
            finalLongitude = coords.longitude;
            debugPrint(
              'AddressService: Coordonnées obtenues - lat: $finalLatitude, lng: $finalLongitude',
            );
          } else {
            debugPrint(
              '⚠️ AddressService: Impossible de géocoder l\'adresse: $fullAddress',
            );
            // Utiliser les coordonnées existantes si disponibles
            finalLatitude ??= currentAddress.latitude;
            finalLongitude ??= currentAddress.longitude;
          }
        } catch (e) {
          debugPrint('⚠️ AddressService: Erreur lors du géocodage: $e');
          // Utiliser les coordonnées existantes si disponibles
          finalLatitude ??= currentAddress.latitude;
          finalLongitude ??= currentAddress.longitude;
        }
      } else {
        // Utiliser les coordonnées existantes si non fournies
        finalLatitude ??= currentAddress.latitude;
        finalLongitude ??= currentAddress.longitude;
      }

      Address updatedAddress;

      // Une adresse sans coordonnées n'a jamais pu être créée côté Django
      // (`location` obligatoire) — sa présence sur `currentAddress` est donc
      // la preuve qu'elle existe déjà côté serveur (même invariant que dans
      // `addAddress`). Sans coordonnées finales, elle reste locale, comme
      // avant cette migration.
      final wasAlreadyRemote =
          currentAddress.latitude != null && currentAddress.longitude != null;

      if (_userId != null && finalLatitude != null && finalLongitude != null) {
        final mergedForRemote = currentAddress.copyWith(
          name: name,
          address: address,
          city: city,
          postalCode: postalCode,
          type: type,
          isDefault: isDefault,
          latitude: finalLatitude,
          longitude: finalLongitude,
        );
        updatedAddress = wasAlreadyRemote
            ? await _addressRepository.update(currentAddress.id, mergedForRemote)
            : await _addressRepository.create(mergedForRemote);
        // Le serveur rétrograde lui-même l'ancien défaut
        // (`AddressViewSet.perform_update`/`perform_create`).
      } else {
        updatedAddress = currentAddress.copyWith(
          name: name,
          address: address,
          city: city,
          postalCode: postalCode,
          latitude: finalLatitude,
          longitude: finalLongitude,
          type: type,
          isDefault: isDefault,
          updatedAt: DateTime.now(),
        );
      }

      if (isDefault == true) {
        _addresses = _addresses
            .map(
              (a) => a.id == addressId
                  ? updatedAddress.copyWith(isDefault: true)
                  : a.copyWith(isDefault: false),
            )
            .toList();
        _selectedAddress = updatedAddress;
      } else {
        _addresses[index] = updatedAddress;
        if (_selectedAddress?.id == addressId) {
          _selectedAddress = updatedAddress;
        }
      }

      await _saveAddresses();
      notifyListeners();

      debugPrint(
        'AddressService: Adresse mise à jour - ${updatedAddress.name}',
      );
      return updatedAddress;
    } catch (e) {
      debugPrint('AddressService: Erreur de mise à jour d\'adresse - $e');
      rethrow;
    }
  }

  /// Supprime une adresse
  Future<void> deleteAddress(String addressId) async {
    try {
      final index = _addresses.indexWhere((a) => a.id == addressId);
      if (index == -1) {
        throw Exception('Adresse non trouvée');
      }

      final deletedAddress = _addresses[index];
      _addresses.removeAt(index);

      // N'existe côté Django que si elle a des coordonnées (même invariant
      // que dans addAddress/updateAddress) — sinon rien à supprimer côté
      // serveur.
      if (_userId != null &&
          deletedAddress.latitude != null &&
          deletedAddress.longitude != null) {
        await _addressRepository.delete(addressId);
      }

      // Si l'adresse supprimée était sélectionnée, sélectionner une autre
      if (_selectedAddress?.id == addressId) {
        _selectedAddress =
            _addresses.isNotEmpty ? (defaultAddress ?? _addresses.first) : null;
      }

      // Si l'adresse supprimée était la défaut, définir une nouvelle adresse par défaut
      if (deletedAddress.isDefault && _addresses.isNotEmpty) {
        final newDefault = _addresses.first.copyWith(isDefault: true);
        _addresses[0] = newDefault;
      }

      await _saveAddresses();
      notifyListeners();

      debugPrint('AddressService: Adresse supprimée - ${deletedAddress.name}');
    } catch (e) {
      debugPrint('AddressService: Erreur de suppression d\'adresse - $e');
      rethrow;
    }
  }

  /// Sélectionne une adresse
  Future<void> selectAddress(String addressId) async {
    try {
      final address = _addresses.where((a) => a.id == addressId).firstOrNull;
      if (address == null) {
        throw Exception('Adresse non trouvée');
      }

      _selectedAddress = address;
      await _saveAddresses();
      notifyListeners();

      debugPrint('AddressService: Adresse sélectionnée - ${address.name}');
    } catch (e) {
      debugPrint('AddressService: Erreur de sélection d\'adresse - $e');
      rethrow;
    }
  }

  /// Définit une adresse comme défaut
  Future<void> setDefaultAddress(String addressId) async {
    try {
      await updateAddress(
        addressId: addressId,
        isDefault: true,
      );

      debugPrint('AddressService: Adresse définie comme défaut - $addressId');
    } catch (e) {
      debugPrint(
        'AddressService: Erreur de définition d\'adresse par défaut - $e',
      );
      rethrow;
    }
  }

  /// Bascule le statut favori d'une adresse
  Future<void> toggleFavorite(String addressId) async {
    try {
      final address = _addresses.where((a) => a.id == addressId).firstOrNull;
      if (address == null) {
        throw Exception('Adresse non trouvée');
      }

      await updateAddress(
        addressId: addressId,
        isFavorite: !address.isFavorite,
      );

      debugPrint(
        'AddressService: Favori basculé pour ${address.name} - ${!address.isFavorite}',
      );
    } catch (e) {
      debugPrint('AddressService: Erreur bascule favori - $e');
      rethrow;
    }
  }

  /// Obtient les adresses par type
  List<Address> getAddressesByType(AddressType type) {
    return _addresses.where((a) => a.type == type).toList();
  }

  /// Recherche des adresses
  List<Address> searchAddresses(String query) {
    if (query.isEmpty) return _addresses;

    final lowercaseQuery = query.toLowerCase();
    return _addresses
        .where(
          (address) =>
              address.name.toLowerCase().contains(lowercaseQuery) ||
              address.address.toLowerCase().contains(lowercaseQuery) ||
              address.city.toLowerCase().contains(lowercaseQuery),
        )
        .toList();
  }

  /// Obtient les statistiques des adresses
  Map<String, dynamic> getAddressStats() {
    final stats = <String, int>{};

    for (final type in AddressType.values) {
      stats[type.name] = _addresses.where((a) => a.type == type).length;
    }

    return {
      'total': _addresses.length,
      'default': defaultAddress?.id,
      'selected': _selectedAddress?.id,
      'by_type': stats,
    };
  }

  /// Valide une adresse
  bool validateAddress({
    required String name,
    required String address,
    required String city,
    String? postalCode,
    double? latitude,
    double? longitude,
  }) {
    return name.isNotEmpty &&
        address.isNotEmpty &&
        city.isNotEmpty &&
        latitude != null &&
        longitude != null;
  }

  /// Obtient les suggestions d'adresses populaires (pour les tests)
  List<Map<String, dynamic>> getPopularAddresses() {
    return [
      {
        'name': 'Cocody',
        'address': 'Cocody, Abidjan',
        'city': 'Abidjan',
        'postalCode': '00225',
        'type': AddressType.other,
      },
      {
        'name': 'Plateau',
        'address': 'Plateau, Abidjan',
        'city': 'Abidjan',
        'postalCode': '00225',
        'type': AddressType.work,
      },
      {
        'name': 'Marcory',
        'address': 'Marcory, Abidjan',
        'city': 'Abidjan',
        'postalCode': '00225',
        'type': AddressType.home,
      },
      {
        'name': 'Yopougon',
        'address': 'Yopougon, Abidjan',
        'city': 'Abidjan',
        'postalCode': '00225',
        'type': AddressType.home,
      },
    ];
  }

  /// Ajoute une adresse depuis les suggestions populaires
  Future<Address> addPopularAddress(Map<String, dynamic> popularAddress) async {
    return await addAddress(
      name: popularAddress['name'],
      address: popularAddress['address'],
      city: popularAddress['city'],
      postalCode: popularAddress['postalCode'],
      type: popularAddress['type'],
    );
  }

  /// Efface toutes les adresses (pour les tests)
  Future<void> clearAllAddresses() async {
    _addresses.clear();
    _selectedAddress = null;
    await _saveAddresses();
    notifyListeners();
  }
}
