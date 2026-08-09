import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/models/address.dart';

/// Ce qu'[AddressService] attend d'un carnet.
///
/// Interface plutôt que classe concrète pour une raison précise : la seule
/// implémentation réelle passe par `apiClient`, qui vit dans `main.dart` et
/// entraîne avec lui l'initialisation de Firebase. Sans cette coupure, aucun
/// test du carnet n'est possible — et c'est bien l'absence de test qui a laissé
/// [DjangoAddressRepository] injoignable pendant toute une version.
abstract class AddressBookRepository {
  Future<List<Address>> list({required String userId});
  Future<Address> create(AddressDraft draft, {required String userId});
  Future<Address> update(String id, AddressDraft draft, {required String userId});
  Future<void> delete(String id);
}

/// Carnet d'adresses contre le backend Django — `/api/v1/profiles/addresses/`.
///
/// C'est la **seule** source d'adresses de l'application : rien d'autre n'en
/// fabrique, et en particulier aucun identifiant n'est généré côté client. Les
/// écritures prennent un [AddressDraft] et rendent une [Address], ce qui rend
/// impossible d'envoyer au serveur une adresse censée déjà exister chez lui.
class DjangoAddressRepository implements AddressBookRepository {
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

  @override
  Future<List<Address>> list({required String userId}) async {
    final remote = await _addresses.list();
    return remote.map((address) => _toLocal(address, userId: userId)).toList();
  }

  @override
  Future<Address> create(AddressDraft draft, {required String userId}) async {
    final created = await _addresses.create(await _toRemote(draft));
    return _toLocal(created, userId: userId);
  }

  @override
  Future<Address> update(
    String id,
    AddressDraft draft, {
    required String userId,
  }) async {
    final updated = await _addresses.update(id, await _toRemote(draft));
    return _toLocal(updated, userId: userId);
  }

  @override
  Future<void> delete(String id) => _addresses.delete(id);

  Future<eccore.Address> _toRemote(AddressDraft draft) async {
    return eccore.Address(
      label: draft.name,
      kind: draft.type.name,
      line1: draft.address,
      // `line2` porte le code postal, faute d'un champ dédié côté serveur.
      line2: draft.postalCode,
      landmark: draft.landmark,
      deliveryInstructions: draft.deliveryInstructions,
      city: await _cityId(),
      latitude: draft.latitude,
      longitude: draft.longitude,
      isDefault: draft.isDefault,
    );
  }

  /// `isFavorite` reste à sa valeur par défaut : le serveur ne connaît pas ce
  /// champ, et c'est [AddressService] qui le rétablit depuis sa propre table
  /// d'ids favoris. Le reporter ici demanderait à ce repository de connaître un
  /// état qu'il ne détient pas.
  Address _toLocal(eccore.Address remote, {required String userId}) {
    return Address(
      id: remote.id!,
      userId: userId,
      name: remote.label,
      address: remote.line1,
      city: remote.cityName ?? AppConstants.defaultCityName,
      postalCode: remote.line2,
      landmark: remote.landmark,
      deliveryInstructions: remote.deliveryInstructions,
      latitude: remote.latitude,
      longitude: remote.longitude,
      type: AddressType.fromKind(remote.kind),
      isDefault: remote.isDefault,
      createdAt: remote.createdAt!,
      updatedAt: remote.updatedAt!,
    );
  }
}
