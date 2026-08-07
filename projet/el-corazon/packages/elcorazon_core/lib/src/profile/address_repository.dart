import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/profile/address.dart';

/// Accès à `/api/v1/profiles/addresses/` — voir
/// `backend/apps/profiles/{serializers,views}.py`. Carnet du client
/// authentifié (l'appartenance est un filtre côté serveur, pas une
/// permission : une adresse d'autrui renvoie 404).
class AddressRepository {
  AddressRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<Address>> list() async {
    final addresses = <Address>[];
    String? path = '/profiles/addresses/';

    while (path != null) {
      final response = await apiClient.get(path);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      addresses.addAll(results.map((json) => Address.fromJson(json as Map<String, dynamic>)));
      path = body['next'] as String?;
    }

    return addresses;
  }

  Future<Address> create(Address draft) async {
    final response = await apiClient.post('/profiles/addresses/', data: draft.toJson());
    return Address.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Address> update(String id, Address draft) async {
    final response = await apiClient.patch('/profiles/addresses/$id/', data: draft.toJson());
    return Address.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await apiClient.delete('/profiles/addresses/$id/');
  }
}
