/// Un établissement tel qu'on le **choisit** — pas tel qu'on le consulte.
///
/// Volontairement pauvre : quatre champs pris de `RestaurantSerializer`
/// (`backend/apps/restaurants/serializers.py`), qui en rend dix-huit. Ce
/// modèle ne sert qu'à peupler une liste où l'on désigne un point de
/// rattachement — la carte, les horaires, les frais de livraison, la distance
/// n'y jouent aucun rôle, et les porter ferait de cette classe un second
/// modèle d'établissement à tenir à jour à côté de celui de l'app cliente.
///
/// Le [slug] est ce qui voyage vers l'API : c'est lui que
/// `CourierSelfApplicationSerializer` attend, et il est stable là où un nom
/// d'enseigne se retouche.
class RestaurantOption {
  const RestaurantOption({
    required this.slug,
    required this.name,
    required this.city,
    required this.address,
  });

  factory RestaurantOption.fromJson(Map<String, dynamic> json) {
    return RestaurantOption(
      slug: json['slug'] as String,
      name: json['name'] as String,
      city: json['city'] as String? ?? '',
      address: json['address'] as String? ?? '',
    );
  }

  final String slug;
  final String name;
  final String city;
  final String address;

  /// « El Corazón — Lomé », ou le seul nom quand la ville manque.
  String get label => city.isEmpty ? name : '$name — $city';
}
