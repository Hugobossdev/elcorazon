import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/models/address.dart';

/// Carnet d'adresses contre le backend Django (Phase 6). Pas d'interface
/// abstraite préexistante ici (contrairement au menu) — expose directement
/// les méthodes dont `AddressService` a besoin.
///
/// `location` étant obligatoire côté serveur (`AddressSerializer.location`),
/// [create]/[update] n'acceptent qu'une adresse dont `latitude`/`longitude`
/// sont déjà renseignés — à l'appelant de ne pas synchroniser tant que le
/// géocodage n'a pas réussi (voir `AddressService.migrateMissingCoordinates`).
class DjangoAddressRepository {
  DjangoAddressRepository()
    : _addresses = eccore.AddressRepository(apiClient: apiClient),
      _geography = eccore.GeographyRepository(apiClient: apiClient);

  final eccore.AddressRepository _addresses;
  final eccore.GeographyRepository _geography;

  /// Id Django de la ville configurée (`AppConstants.citySlug`) — résolu une
  /// fois puis mis en cache : une seule ville en base aujourd'hui, inutile de
  /// la redemander à chaque écriture.
  static String? _cachedCityId;

  Future<String> _cityId() async {
    final cached = _cachedCityId;
    if (cached != null) return cached;

    final cities = await _geography.getCities();
    final city = cities.firstWhere(
      (c) => c.slug == AppConstants.citySlug,
      orElse: () => throw StateError(
        'Aucune ville avec le slug "${AppConstants.citySlug}" côté backend.',
      ),
    );
    return _cachedCityId = city.id;
  }

  Future<List<Address>> list({required String userId}) async {
    final remote = await _addresses.list();
    return remote.map((address) => _toLocal(address, userId: userId)).toList();
  }

  Future<Address> create(Address local) async {
    final draft = await _toRemoteDraft(local);
    final created = await _addresses.create(draft);
    return _toLocal(created, userId: local.userId);
  }

  Future<Address> update(String remoteId, Address local) async {
    final draft = await _toRemoteDraft(local);
    final updated = await _addresses.update(remoteId, draft);
    return _toLocal(updated, userId: local.userId);
  }

  Future<void> delete(String remoteId) => _addresses.delete(remoteId);

  Future<eccore.Address> _toRemoteDraft(Address local) async {
    assert(
      local.latitude != null && local.longitude != null,
      'DjangoAddressRepository requiert des coordonnées géocodées.',
    );
    return eccore.Address(
      label: local.name,
      kind: local.type.name,
      line1: local.address,
      line2: local.postalCode,
      city: await _cityId(),
      latitude: local.latitude!,
      longitude: local.longitude!,
      isDefault: local.isDefault,
    );
  }

  Address _toLocal(eccore.Address remote, {required String userId}) {
    return Address(
      id: remote.id!,
      userId: userId,
      name: remote.label,
      address: remote.line1,
      city: remote.cityName ?? '',
      postalCode: remote.line2,
      latitude: remote.latitude,
      longitude: remote.longitude,
      type: AddressType.values.firstWhere(
        (t) => t.name == remote.kind,
        orElse: () => AddressType.other,
      ),
      isDefault: remote.isDefault,
      createdAt: remote.createdAt!,
      updatedAt: remote.updatedAt!,
    );
  }
}
