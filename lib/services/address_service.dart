import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:elcora_fast/models/address.dart';
import 'package:elcora_fast/services/database_service.dart';

class AddressService extends ChangeNotifier {
  static final AddressService _instance = AddressService._internal();
  factory AddressService() => _instance;
  AddressService._internal();

  List<Address> _addresses = [];
  Address? _selectedAddress;
  bool _isInitialized = false;
  String? _userId;

  final DatabaseService _databaseService = DatabaseService();
  final Uuid _uuid = const Uuid();

  // Getters
  List<Address> get addresses => List.unmodifiable(_addresses);
  Address? get selectedAddress => _selectedAddress;
  Address? get defaultAddress =>
      _addresses.where((a) => a.isDefault).firstOrNull;
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
          'AddressService: Initialisé avec ${_addresses.length} adresses',);
    } catch (e) {
      debugPrint('AddressService: Erreur d\'initialisation - $e');
    }
  }

  Future<void> initializeForUser(String userId) async {
    _userId = userId;
    await _loadAddresses();
    await _loadAddressesFromDatabase();
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
            _selectedAddressStorageKey, _selectedAddress!.id,);
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
      final remoteAddresses =
          await _databaseService.fetchUserAddresses(_userId!);
      _addresses = remoteAddresses;

      if (_addresses.isNotEmpty) {
        _selectedAddress =
            defaultAddress ?? _addresses.first;
      } else {
        _selectedAddress = null;
      }

      await _saveAddresses();
      notifyListeners();
      debugPrint(
          'AddressService: Synchronisation Supabase (${_addresses.length} adresses)',);
    } catch (e) {
      debugPrint('AddressService: Erreur de synchronisation Supabase - $e');
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
  }) async {
    try {
      final shouldBeDefault = _addresses.isEmpty || isDefault;
      Address newAddress;

      if (_userId != null) {
        if (shouldBeDefault && _addresses.isNotEmpty) {
          await _databaseService.unsetDefaultAddresses(_userId!);
          _addresses =
              _addresses.map((a) => a.copyWith(isDefault: false)).toList();
        }

        newAddress = await _databaseService.createAddress(
          userId: _userId!,
          name: name,
          address: address,
          city: city,
          postalCode: postalCode,
          type: type,
          isDefault: shouldBeDefault,
          latitude: latitude,
          longitude: longitude,
        );
      } else {
        newAddress = Address(
          id: _uuid.v4(),
          userId: 'guest',
          name: name,
          address: address,
          city: city,
          postalCode: postalCode,
          latitude: latitude,
          longitude: longitude,
          type: type,
          isDefault: shouldBeDefault,
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
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) async {
    try {
      final index = _addresses.indexWhere((a) => a.id == addressId);
      if (index == -1) {
        throw Exception('Adresse non trouvée');
      }

      Address updatedAddress;

      if (_userId != null) {
        if (isDefault == true) {
          await _databaseService.unsetDefaultAddresses(_userId!);
        }
        updatedAddress = await _databaseService.updateAddress(
          addressId: addressId,
          name: name,
          address: address,
          city: city,
          postalCode: postalCode,
          type: type,
          isDefault: isDefault,
          latitude: latitude,
          longitude: longitude,
        );
      } else {
        updatedAddress = _addresses[index].copyWith(
          name: name,
          address: address,
          city: city,
          postalCode: postalCode,
          latitude: latitude,
          longitude: longitude,
          type: type,
          isDefault: isDefault,
          updatedAt: DateTime.now(),
        );
      }

      if (isDefault == true) {
        _addresses = _addresses
            .map((a) => a.id == addressId
                ? updatedAddress.copyWith(isDefault: true)
                : a.copyWith(isDefault: false),)
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
          'AddressService: Adresse mise à jour - ${updatedAddress.name}',);
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

      if (_userId != null) {
        await _databaseService.deleteAddress(addressId);
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
          'AddressService: Erreur de définition d\'adresse par défaut - $e',);
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
        .where((address) =>
            address.name.toLowerCase().contains(lowercaseQuery) ||
            address.address.toLowerCase().contains(lowercaseQuery) ||
            address.city.toLowerCase().contains(lowercaseQuery),)
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
    required String postalCode,
  }) {
    return name.isNotEmpty &&
        address.isNotEmpty &&
        city.isNotEmpty &&
        postalCode.isNotEmpty;
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
