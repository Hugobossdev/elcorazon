import 'package:elcora_fast/models/address.dart';
import 'package:elcora_fast/services/api/api_client.dart';

/// Accès aux adresses de l'utilisateur via l'API Laravel.
///
/// La gestion de l'adresse par défaut (un seul `is_default`) est assurée côté
/// serveur de façon transactionnelle.
class AddressApi {
  AddressApi._internal();
  static final AddressApi _instance = AddressApi._internal();
  factory AddressApi() => _instance;

  final ApiClient _client = ApiClient();

  Future<List<Address>> getAddresses() async {
    final response = await _client.get('/addresses');
    final list = (response['data'] as List? ?? []);
    return list.map((e) => Address.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Address> createAddress({
    required String name,
    required String address,
    required String city,
    required String postalCode,
    required AddressType type,
    required bool isDefault,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _client.post('/addresses', body: {
      'name': name,
      'address': address,
      'city': city,
      'postal_code': postalCode,
      'type': type.name,
      'is_default': isDefault,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return Address.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Address> updateAddress({
    required String addressId,
    String? name,
    String? address,
    String? city,
    String? postalCode,
    AddressType? type,
    bool? isDefault,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _client.put('/addresses/$addressId', body: {
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (postalCode != null) 'postal_code': postalCode,
      if (type != null) 'type': type.name,
      if (isDefault != null) 'is_default': isDefault,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return Address.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> deleteAddress(String addressId) async {
    await _client.delete('/addresses/$addressId');
  }
}
