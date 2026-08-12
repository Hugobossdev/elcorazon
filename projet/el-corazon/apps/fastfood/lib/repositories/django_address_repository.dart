import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/presentation/adresse.dart';

/// Ce qu'un client saisit pour créer ou corriger une adresse.
///
/// Distinct d'`eccore.Address` pour une raison qui tient : le brouillon ne
/// porte **pas** d'identifiant, et l'écriture ne peut donc pas envoyer au
/// serveur une adresse censée déjà exister chez lui. Il ne porte pas non plus
/// l'identifiant de la ville, que le dépôt résout.
///
/// `estFavorite` n'a pas de contrepartie serveur : c'est un marquage local,
/// que [AddressService] retient dans sa propre table. Il voyage ici parce que
/// le formulaire le pose en même temps que le reste.
class BrouillonAdresse {
  const BrouillonAdresse({
    required this.nom,
    required this.ligne1,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.ligne2 = '',
    this.repere = '',
    this.consignes = '',
    this.estParDefaut = false,
    this.estFavorite = false,
  });

  /// Reprend une adresse existante — pour la corriger.
  factory BrouillonAdresse.depuis(
    eccore.Address adresse, {
    bool estFavorite = false,
  }) {
    return BrouillonAdresse(
      nom: adresse.label,
      ligne1: adresse.line1,
      ligne2: adresse.line2,
      repere: adresse.landmark,
      consignes: adresse.deliveryInstructions,
      latitude: adresse.latitude,
      longitude: adresse.longitude,
      type: adresse.type,
      estParDefaut: adresse.isDefault,
      estFavorite: estFavorite,
    );
  }

  final String nom;
  final String ligne1;

  /// Seconde ligne — appartement, bâtiment, étage.
  final String ligne2;

  final String repere;
  final String consignes;
  final double latitude;
  final double longitude;
  final TypeAdresse type;
  final bool estParDefaut;
  final bool estFavorite;

  BrouillonAdresse copyWith({bool? estParDefaut}) {
    return BrouillonAdresse(
      nom: nom,
      ligne1: ligne1,
      ligne2: ligne2,
      repere: repere,
      consignes: consignes,
      latitude: latitude,
      longitude: longitude,
      type: type,
      estParDefaut: estParDefaut ?? this.estParDefaut,
      estFavorite: estFavorite,
    );
  }
}

/// Ce qu'`AddressService` attend d'un carnet.
///
/// Interface plutôt que classe concrète pour une raison précise : la seule
/// implémentation réelle passe par `apiClient`, qui vit dans `main.dart` et
/// entraîne avec lui l'initialisation de Firebase. Sans cette coupure, aucun
/// test du carnet n'est possible — et c'est bien l'absence de test qui a laissé
/// [DjangoAddressRepository] injoignable pendant toute une version.
abstract class AddressBookRepository {
  Future<List<eccore.Address>> list();
  Future<eccore.Address> create(BrouillonAdresse brouillon);
  Future<eccore.Address> update(String id, BrouillonAdresse brouillon);
  Future<void> delete(String id);
}

/// Carnet d'adresses contre le backend Django — `/api/v1/profiles/addresses/`.
///
/// C'est la **seule** source d'adresses de l'application : rien d'autre n'en
/// fabrique, et en particulier aucun identifiant n'est généré côté client.
///
/// Il ne traduit plus rien depuis le lot 3 : `eccore.Address` est ce que les
/// écrans lisent. Ce qui reste ici est le travail que le socle ne fait pas —
/// résoudre l'identifiant de la ville, et refuser une écriture sans point.
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
  Future<List<eccore.Address>> list() => _addresses.list();

  @override
  Future<eccore.Address> create(BrouillonAdresse brouillon) async {
    return _addresses.create(await _versServeur(brouillon));
  }

  @override
  Future<eccore.Address> update(String id, BrouillonAdresse brouillon) async {
    return _addresses.update(id, await _versServeur(brouillon));
  }

  @override
  Future<void> delete(String id) => _addresses.delete(id);

  Future<eccore.Address> _versServeur(BrouillonAdresse brouillon) async {
    return eccore.Address(
      label: brouillon.nom,
      kind: brouillon.type.versServeur,
      line1: brouillon.ligne1,
      line2: brouillon.ligne2,
      landmark: brouillon.repere,
      deliveryInstructions: brouillon.consignes,
      city: await _cityId(),
      latitude: brouillon.latitude,
      longitude: brouillon.longitude,
      isDefault: brouillon.estParDefaut,
    );
  }
}
