/// Un point géographique, sans dépendance à une bibliothèque de cartographie.
///
/// `LatLng` de `google_maps_flutter` ferait le même travail, mais l'importer
/// obligerait le socle — dont les cinq dépendances servent l'API du serveur,
/// la session et le temps réel — à embarquer un moteur de cartes pour deux
/// nombres. Les écrans convertissent à la frontière, c'est une ligne.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  /// Forme attendue par les API Google : « latitude,longitude ».
  ///
  /// Sert de fragment de clé de cache autant que de paramètre de requête, et
  /// c'est voulu : deux points qui s'écrivent pareil désignent le même lieu.
  @override
  String toString() => '$latitude,$longitude';

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}
