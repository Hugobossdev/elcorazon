import 'package:elcorazon_core/src/directions/geo_point.dart';

/// Le geste qu'une étape d'itinéraire demande au conducteur.
///
/// Miroir du champ `maneuver` de Google Directions. Une **énumération** ici,
/// contrairement aux statuts de course qui restent des chaînes : la liste est
/// fermée et documentée par Google, elle ne bouge pas au rythme de notre
/// backend, et surtout c'est elle qui choisit la phrase prononcée — un
/// `switch` non exhaustif sur une chaîne se traduirait par un silence dans
/// l'oreille du livreur, au carrefour.
///
/// [aucune] couvre les deux cas où Google ne rend pas de manœuvre : la
/// première étape d'un trajet (« prendre la rue X »), et les continuations sur
/// la même voie. Ce n'est pas une valeur d'erreur.
enum Manoeuvre {
  aucune,
  toutDroit,
  legerementAGauche,
  aGauche,
  serreAGauche,
  legerementADroite,
  aDroite,
  serreADroite,
  demiTour,
  rondPoint,
  bretelleAGauche,
  bretelleADroite,
  insertion,
  fourcheAGauche,
  fourcheADroite,
  bac;

  /// Depuis la valeur rendue par Google.
  ///
  /// Une manœuvre inconnue — Google en ajoute — devient [aucune] plutôt que de
  /// faire échouer la lecture de l'itinéraire : le livreur entendra
  /// l'instruction textuelle de Google, qui reste juste, au lieu de n'avoir
  /// aucun itinéraire du tout.
  factory Manoeuvre.depuisGoogle(String? valeur) => switch (valeur) {
        'straight' => Manoeuvre.toutDroit,
        'turn-slight-left' => Manoeuvre.legerementAGauche,
        'turn-left' => Manoeuvre.aGauche,
        'turn-sharp-left' => Manoeuvre.serreAGauche,
        'turn-slight-right' => Manoeuvre.legerementADroite,
        'turn-right' => Manoeuvre.aDroite,
        'turn-sharp-right' => Manoeuvre.serreADroite,
        'uturn-left' || 'uturn-right' => Manoeuvre.demiTour,
        'roundabout-left' || 'roundabout-right' => Manoeuvre.rondPoint,
        'ramp-left' => Manoeuvre.bretelleAGauche,
        'ramp-right' => Manoeuvre.bretelleADroite,
        'merge' => Manoeuvre.insertion,
        'fork-left' => Manoeuvre.fourcheAGauche,
        'fork-right' => Manoeuvre.fourcheADroite,
        'ferry' || 'ferry-train' => Manoeuvre.bac,
        _ => Manoeuvre.aucune,
      };
}

/// Une étape d'itinéraire : un geste, à un endroit, au bout d'une distance.
///
/// ## Ce qui manquait
///
/// `DirectionsRepository` ne lisait que le tracé d'ensemble et la distance
/// totale de la course. Les étapes voyageaient dans la même réponse et étaient
/// jetées : c'est pour cela qu'aucune instruction de navigation n'était
/// possible, et non par choix d'implémentation. Les demander ne coûte pas une
/// requête de plus — elles sont déjà là.
class RouteStep {
  const RouteStep({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.start,
    required this.end,
    required this.instruction,
    required this.manoeuvre,
    this.polylinePoints = const [],
  });

  /// Longueur de l'étape, en mètres.
  final int distanceMeters;

  /// Durée estimée de l'étape, en secondes.
  final int durationSeconds;

  /// Début de l'étape.
  final GeoPoint start;

  /// Point où la manœuvre s'exécute — le carrefour, la bretelle, la porte.
  final GeoPoint end;

  /// L'instruction telle que Google la rédige, **balises retirées**.
  ///
  /// Elle arrive en HTML (`Prendre <b>Rue de la Paix</b>`) parce qu'elle est
  /// prévue pour être affichée dans une page. Prononcée telle quelle, un
  /// moteur de synthèse lit les balises.
  final String instruction;

  final Manoeuvre manoeuvre;

  /// Tracé propre à l'étape. Sert à recaler l'étape courante sur le tracé
  /// d'ensemble sans refaire correspondre des coordonnées à la virgule près.
  final List<GeoPoint> polylinePoints;

  /// Lit une étape de la réponse de Google.
  ///
  /// [decoder] est le décodeur de tracé du dépôt : le passer plutôt que de le
  /// recopier ici garde une seule implémentation du format, celle qui est déjà
  /// testée.
  factory RouteStep.fromJson(
    Map<String, dynamic> json, {
    required List<GeoPoint> Function(String) decoder,
  }) {
    final depart = json['start_location'] as Map<String, dynamic>;
    final arrivee = json['end_location'] as Map<String, dynamic>;
    final trace = (json['polyline'] as Map<String, dynamic>?)?['points'] as String?;

    return RouteStep(
      distanceMeters: _valeur(json['distance']),
      durationSeconds: _valeur(json['duration']),
      start: GeoPoint(
        (depart['lat'] as num).toDouble(),
        (depart['lng'] as num).toDouble(),
      ),
      end: GeoPoint(
        (arrivee['lat'] as num).toDouble(),
        (arrivee['lng'] as num).toDouble(),
      ),
      instruction: texteSansBalises(json['html_instructions'] as String? ?? ''),
      manoeuvre: Manoeuvre.depuisGoogle(json['maneuver'] as String?),
      polylinePoints:
          trace == null || trace.isEmpty ? const [] : decoder(trace),
    );
  }

  static int _valeur(Object? mesure) =>
      ((mesure as Map<String, dynamic>?)?['value'] as num?)?.toInt() ?? 0;

  /// Retire les balises et rend leurs caractères aux entités HTML.
  ///
  /// Google sépare deux instructions d'une même étape par un `<div>` sans
  /// espace autour : « Continuer<div>Prendre à droite ». Recoller les deux
  /// morceaux sans séparateur donnerait « ContinuerPrendre », qu'un moteur de
  /// synthèse prononce comme un seul mot. Les balises deviennent donc une
  /// espace, et les espaces multiples sont ensuite réduites.
  ///
  /// Publique et testée : c'est la seule transformation dont l'erreur
  /// s'entendrait plutôt que de se voir.
  static String texteSansBalises(String html) {
    const entites = {
      '&amp;': '&',
      '&nbsp;': ' ',
      '&quot;': '"',
      '&#39;': "'",
      '&apos;': "'",
      '&lt;': '<',
      '&gt;': '>',
    };

    var texte = html.replaceAll(RegExp('<[^>]*>'), ' ');
    entites.forEach((entite, caractere) {
      texte = texte.replaceAll(entite, caractere);
    });
    return texte.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
