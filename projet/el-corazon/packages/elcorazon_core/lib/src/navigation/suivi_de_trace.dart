import 'package:elcorazon_core/src/directions/geo_point.dart';
import 'package:elcorazon_core/src/navigation/geo_calcul.dart';

/// Où en est le livreur **sur** son itinéraire — et non par rapport à sa
/// destination à vol d'oiseau.
///
/// La différence n'est pas cosmétique. Un livreur séparé de son client par un
/// fleuve en est à 300 mètres à vol d'oiseau et à 4 kilomètres par le pont :
/// afficher la première valeur, c'est annoncer une arrivée dans une minute
/// pendant un quart d'heure. Toutes les mesures que la navigation affiche —
/// distance restante, durée, heure d'arrivée — se lisent donc le long du
/// tracé.
class PositionSurItineraire {
  const PositionSurItineraire({
    required this.indexSegment,
    required this.pointProjete,
    required this.ecartMetres,
    required this.distanceRestanteMetres,
    required this.distanceParcourueMetres,
  });

  /// Segment du tracé sur lequel le livreur se trouve — `trace[i]` à
  /// `trace[i + 1]`.
  final int indexSegment;

  /// Sa position ramenée sur le tracé. C'est elle qu'on mesure, pas la
  /// position brute : sur une deux-fois-deux-voies, le capteur pose le livreur
  /// à dix mètres du trait, et compter cet écart dans la distance restante le
  /// ferait osciller.
  final GeoPoint pointProjete;

  /// Ce qui sépare la position réelle du tracé, en mètres. C'est cette valeur,
  /// et elle seule, qui dit si le livreur a quitté l'itinéraire.
  final double ecartMetres;

  /// Ce qu'il reste à parcourir jusqu'au dernier point du tracé.
  final double distanceRestanteMetres;

  /// Ce qui a déjà été parcouru depuis le premier point du tracé.
  final double distanceParcourueMetres;
}

/// Un tracé prêt à être suivi : ses distances cumulées sont calculées une fois.
///
/// Sans cette pré-mesure, chaque relevé de position — un toutes les quelques
/// secondes pendant toute une course — reparcourrait les quelques centaines de
/// sommets d'un itinéraire urbain pour en sommer les longueurs. Le calcul est
/// fait à la réception de l'itinéraire, et les relevés suivants n'y touchent
/// plus.
class TraceSuivie {
  TraceSuivie(List<GeoPoint> points)
      : points = List.unmodifiable(points),
        _cumulDepuisLeDebut = _cumuler(points);

  final List<GeoPoint> points;

  /// `_cumulDepuisLeDebut[i]` = distance du premier point jusqu'à `points[i]`.
  final List<double> _cumulDepuisLeDebut;

  /// Longueur totale du tracé, en mètres.
  double get longueurMetres =>
      _cumulDepuisLeDebut.isEmpty ? 0 : _cumulDepuisLeDebut.last;

  bool get estVide => points.length < 2;

  static List<double> _cumuler(List<GeoPoint> points) {
    final cumul = List<double>.filled(points.length, 0);
    for (var i = 1; i < points.length; i++) {
      cumul[i] =
          cumul[i - 1] + GeoCalcul.distanceMetres(points[i - 1], points[i]);
    }
    return cumul;
  }

  /// Distance depuis le début du tracé jusqu'à `points[index]`.
  double cumulJusquA(int index) =>
      _cumulDepuisLeDebut[index.clamp(0, _cumulDepuisLeDebut.length - 1)];

  /// Situe [position] sur le tracé.
  ///
  /// [depuisLeSegment] borne la recherche vers l'avant. C'est ce qui empêche un
  /// itinéraire qui repasse près de lui-même — un aller-retour dans une
  /// impasse, un rond-point pris en entier, deux rues parallèles à trente
  /// mètres — de faire « reculer » le livreur de plusieurs centaines de mètres
  /// parce qu'un segment déjà parcouru se trouve marginalement plus proche.
  /// La distance restante ferait alors des bonds, et l'instruction reviendrait
  /// à une manœuvre déjà passée.
  ///
  /// [fenetreArriere] laisse malgré tout regarder un peu en arrière : un
  /// relevé imprécis peut faire franchir un sommet trop tôt, et refuser
  /// absolument de reculer figerait le suivi sur le mauvais segment.
  PositionSurItineraire? situer(
    GeoPoint position, {
    int depuisLeSegment = 0,
    int fenetreArriere = 2,
  }) {
    if (estVide) return null;

    final premier =
        (depuisLeSegment - fenetreArriere).clamp(0, points.length - 2);

    var meilleurIndex = premier;
    var meilleureDistance = double.infinity;
    var meilleurePosition = points[premier];
    var meilleureFraction = 0.0;

    for (var i = premier; i < points.length - 1; i++) {
      final projection =
          GeoCalcul.projeterSurSegment(position, points[i], points[i + 1]);
      if (projection.distanceMetres < meilleureDistance) {
        meilleureDistance = projection.distanceMetres;
        meilleurIndex = i;
        meilleurePosition = projection.point;
        meilleureFraction = projection.fraction;
      }
    }

    final longueurDuSegment =
        _cumulDepuisLeDebut[meilleurIndex + 1] - _cumulDepuisLeDebut[meilleurIndex];
    final parcouru =
        _cumulDepuisLeDebut[meilleurIndex] + longueurDuSegment * meilleureFraction;

    return PositionSurItineraire(
      indexSegment: meilleurIndex,
      pointProjete: meilleurePosition,
      ecartMetres: meilleureDistance,
      distanceRestanteMetres: (longueurMetres - parcouru).clamp(0, longueurMetres),
      distanceParcourueMetres: parcouru,
    );
  }
}
