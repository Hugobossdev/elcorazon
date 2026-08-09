import 'package:flutter/material.dart';

enum AddressType {
  home('Maison', '🏠'),
  work('Travail', '💼'),
  other('Autre', '📍');

  const AddressType(this.displayName, this.emoji);
  final String displayName;
  final String emoji;

  Color get color {
    switch (this) {
      case AddressType.home:
        return Colors.green;
      case AddressType.work:
        return Colors.blue;
      case AddressType.other:
        return Colors.orange;
    }
  }

  /// Type correspondant à `kind` côté serveur (`AddressKind`), `other` pour une
  /// valeur inconnue — un `kind` ajouté au serveur ne doit pas faire échouer la
  /// lecture de tout le carnet.
  static AddressType fromKind(String kind) =>
      AddressType.values.firstWhere((t) => t.name == kind, orElse: () => other);
}

/// Adresse du carnet, telle que le serveur la détient.
///
/// **Une adresse est toujours un point.** `location` est obligatoire côté
/// serveur (`AddressSerializer`), et c'est ce point — pas la ligne de texte —
/// qui décide de la zone de livraison, des frais, et de l'endroit où le livreur
/// se rend. Les coordonnées ne sont donc pas optionnelles ici : une adresse
/// sans point n'est pas une adresse incomplète, c'est une adresse qui n'existe
/// pas.
///
/// C'était l'inverse avant, et cela coûtait cher : `latitude`/`longitude`
/// nullables laissaient créer des adresses que le serveur refusait, qui
/// vivaient alors dans le seul cache local avec un identifiant fabriqué par le
/// client. Elles s'affichaient normalement dans le carnet, et le refus ne
/// tombait qu'à la commande — `POST /orders/` ne pouvant résoudre un
/// identifiant qu'il n'a jamais émis.
///
/// [id] est **toujours** un identifiant serveur. Rien, dans cette application,
/// ne fabrique d'identifiant d'adresse.
@immutable
class Address {
  const Address({
    required this.id,
    required this.userId,
    required this.name,
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
    this.postalCode = '',
    this.landmark = '',
    this.deliveryInstructions = '',
    this.isFavorite = false,
  });

  /// Relit une adresse du cache local.
  ///
  /// Tolérante aux champs absents — le cache a pu être écrit par une version
  /// antérieure — mais **pas** aux coordonnées absentes : sans point, l'entrée
  /// n'est pas une adresse et [AddressService] la traite à part (reprise des
  /// carnets locaux). Lève [FormatException] dans ce cas, plutôt que de
  /// fabriquer un point de complaisance.
  factory Address.fromJson(Map<String, dynamic> json) {
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      throw const FormatException('Adresse sans coordonnées.');
    }

    return Address(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      city: json['city'] as String,
      postalCode: json['postal_code'] as String? ?? '',
      landmark: json['landmark'] as String? ?? '',
      deliveryInstructions: json['delivery_instructions'] as String? ?? '',
      latitude: latitude,
      longitude: longitude,
      type: AddressType.fromKind(json['type'] as String? ?? ''),
      isDefault: json['is_default'] as bool? ?? false,
      isFavorite: json['is_favorite'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Identifiant serveur (UUID). Jamais fabriqué côté client.
  final String id;
  final String userId;
  final String name;
  final String address;
  final String city;
  final String postalCode;

  /// Repère visible depuis la rue — « en face de la pharmacie du Golfe ».
  ///
  /// À Lomé, c'est ce que le livreur suit réellement : l'adressage postal ne
  /// désigne pas une porte.
  final String landmark;

  /// Consignes pour la remise — étage, code de portail, appeler à l'arrivée.
  final String deliveryInstructions;

  final double latitude;
  final double longitude;
  final AddressType type;
  final bool isDefault;

  /// Purement local : le serveur n'a pas ce champ. Porté par le modèle pour
  /// l'affichage, mais c'est [AddressService] qui le conserve, indexé par [id].
  final bool isFavorite;

  final DateTime createdAt;
  final DateTime updatedAt;

  Address copyWith({
    String? id,
    String? userId,
    String? name,
    String? address,
    String? city,
    String? postalCode,
    String? landmark,
    String? deliveryInstructions,
    double? latitude,
    double? longitude,
    AddressType? type,
    bool? isDefault,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Address(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      landmark: landmark ?? this.landmark,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'address': address,
      'city': city,
      'postal_code': postalCode,
      'landmark': landmark,
      'delivery_instructions': deliveryInstructions,
      'latitude': latitude,
      'longitude': longitude,
      'type': type.name,
      'is_default': isDefault,
      'is_favorite': isFavorite,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Adresse d'une seule ligne, sans séparateur vide.
  ///
  /// La concaténation précédente (`'$address, $city $postalCode'`) laissait une
  /// virgule ou une espace orpheline dès qu'un champ manquait — code postal
  /// vide dans la quasi-totalité des cas ici.
  String get fullAddress =>
      [address, city, postalCode].where((part) => part.trim().isNotEmpty).join(', ');

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Address && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Address(id: $id, name: $name, address: $address, type: $type)';
  }
}

/// Ce qu'un formulaire produit : une adresse **pas encore créée**, donc sans
/// identifiant ni horodatage — ceux-ci n'existent qu'une fois le serveur
/// saisi.
///
/// Ce type existe pour que la différence entre « ce que le client a saisi » et
/// « ce que le serveur détient » soit visible dans les signatures. Auparavant
/// les deux étaient le même `Address`, construit avec `id: ''` à la création :
/// rien n'empêchait de faire circuler une adresse sans identifiant là où un
/// identifiant était attendu, et c'est exactement ce que faisait le carnet.
@immutable
class AddressDraft {
  const AddressDraft({
    required this.name,
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.postalCode = '',
    this.landmark = '',
    this.deliveryInstructions = '',
    this.isDefault = false,
    this.isFavorite = false,
  });

  /// Brouillon reprenant une adresse existante — pour la modifier, ou pour
  /// représenter une adresse locale à créer côté serveur.
  factory AddressDraft.from(Address address) {
    return AddressDraft(
      name: address.name,
      address: address.address,
      city: address.city,
      postalCode: address.postalCode,
      landmark: address.landmark,
      deliveryInstructions: address.deliveryInstructions,
      latitude: address.latitude,
      longitude: address.longitude,
      type: address.type,
      isDefault: address.isDefault,
      isFavorite: address.isFavorite,
    );
  }

  final String name;
  final String address;
  final String city;
  final String postalCode;
  final String landmark;
  final String deliveryInstructions;
  final double latitude;
  final double longitude;
  final AddressType type;
  final bool isDefault;
  final bool isFavorite;

  AddressDraft copyWith({bool? isDefault}) {
    return AddressDraft(
      name: name,
      address: address,
      city: city,
      postalCode: postalCode,
      landmark: landmark,
      deliveryInstructions: deliveryInstructions,
      latitude: latitude,
      longitude: longitude,
      type: type,
      isDefault: isDefault ?? this.isDefault,
      isFavorite: isFavorite,
    );
  }
}
