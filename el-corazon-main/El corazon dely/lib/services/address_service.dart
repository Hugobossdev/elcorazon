import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/address.dart';

class AddressService extends ChangeNotifier {
  static final AddressService _instance = AddressService._internal();
  factory AddressService() => _instance;
  AddressService._internal();

  List<Address> _addresses = [];
  Address? _selectedAddress;
  bool _isInitialized = false;

  // Getters
  List<Address> get addresses => List.unmodifiable(_addresses);
  Address? get selectedAddress => _selectedAddress;
  Address? get defaultAddress =>
      _addresses.where((a) => a.isDefault).firstOrNull;
  bool get isInitialized => _isInitialized;
  bool get hasAddresses => _addresses.isNotEmpty;

  /// Initialise le service et charge les adresses depuis le stockage local
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadAddresses();
      _isInitialized = true;
      notifyListeners();
      debugPrint(
          'AddressService: Initialisé avec ${_addresses.length} adresses');
    } catch (e) {
      debugPrint('AddressService: Erreur d\'initialisation - $e');
    }
  }

  /// Charge les adresses depuis le stockage local
  Future<void> _loadAddresses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final addressesJson = prefs.getStringList('user_addresses') ?? [];

      _addresses = addressesJson
          .map((json) => Address.fromJson(jsonDecode(json)))
          .toList();

      // Charger l'adresse sélectionnée
      final selectedAddressId = prefs.getString('selected_address_id');
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

      await prefs.setStringList('user_addresses', addressesJson);

      if (_selectedAddress != null) {
        await prefs.setString('selected_address_id', _selectedAddress!.id);
      }
    } catch (e) {
      debugPrint('AddressService: Erreur de sauvegarde des adresses - $e');
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
      var newAddress = Address(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId:
            'current_user_id', // À récupérer depuis le service d'authentification
        name: name,
        address: address,
        city: city,
        postalCode: postalCode,
        latitude: latitude,
        longitude: longitude,
        type: type,
        isDefault: isDefault,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Si c'est la première adresse ou si c'est marqué comme défaut, la définir comme défaut
      if (_addresses.isEmpty || isDefault) {
        newAddress = newAddress.copyWith(isDefault: true);
        // Retirer le statut défaut des autres adresses
        _addresses =
            _addresses.map((a) => a.copyWith(isDefault: false)).toList();
      }

      _addresses.add(newAddress);

      // Si c'est la première adresse, la sélectionner automatiquement
      if (_addresses.length == 1) {
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

      final updatedAddress = _addresses[index].copyWith(
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

      // Si cette adresse devient la défaut, retirer le statut des autres
      if (isDefault == true) {
        _addresses = _addresses
            .map((a) => a.id == addressId
                ? updatedAddress
                : a.copyWith(isDefault: false))
            .toList();
      } else {
        _addresses[index] = updatedAddress;
      }

      // Mettre à jour l'adresse sélectionnée si c'est celle-ci
      if (_selectedAddress?.id == addressId) {
        _selectedAddress = updatedAddress;
      }

      await _saveAddresses();
      notifyListeners();

      debugPrint(
          'AddressService: Adresse mise à jour - ${updatedAddress.name}');
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
          'AddressService: Erreur de définition d\'adresse par défaut - $e');
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
            address.city.toLowerCase().contains(lowercaseQuery))
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

