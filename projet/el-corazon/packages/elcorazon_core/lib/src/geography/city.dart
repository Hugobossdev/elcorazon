/// Ville desservie — miroir de `CitySerializer`
/// (`backend/apps/geography/serializers.py`). Le pays et le centroïde ne sont
/// pas repris ici : cette tranche n'en a besoin que pour résoudre l'id d'une
/// ville par son slug.
class City {
  const City({required this.id, required this.name, required this.slug});

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
    );
  }

  final String id;
  final String name;
  final String slug;
}
