import 'package:elcorazon_core/src/directions/route_step.dart';
import 'package:elcorazon_core/src/navigation/etat_navigation.dart';

/// Langue du guidage vocal.
///
/// Le français est la langue de travail des livreurs de Lomé ; l'anglais est
/// là parce que la frontière ghanéenne est à trente kilomètres et que
/// l'architecture ne doit pas rendre son ajout coûteux. Une langue de plus est
/// une classe de plus qui implémente [PhrasesNavigation], et rien d'autre à
/// toucher.
enum LangueNavigation {
  francais('fr', 'fr-FR'),
  anglais('en', 'en-US');

  const LangueNavigation(this.code, this.etiquetteVocale);

  /// Code passé à Google Directions, qui rédige les instructions.
  final String code;

  /// Étiquette passée au moteur de synthèse — la langue **et** la variante,
  /// qu'un moteur TTS demande pour choisir une voix.
  final String etiquetteVocale;

  static LangueNavigation depuisCode(String? code) => switch (code) {
        'en' => LangueNavigation.anglais,
        _ => LangueNavigation.francais,
      };
}

/// Tout ce que la navigation prononce, dans une langue.
///
/// ## Pourquoi les phrases ne sont pas dans les widgets
///
/// Parce qu'elles ne s'affichent pas : elles se prononcent. Une phrase écrite
/// dans un `Text` peut être approximative — l'œil recolle. Une phrase
/// prononcée dans un casque, à cinquante à l'heure, ne se relit pas. Les
/// regrouper permet aussi de les vérifier : le test qui compte les répétitions
/// n'a pas à monter d'interface.
///
/// Les noms de rue, eux, ne sont **pas** traduits ici : ils viennent de Google,
/// dans la langue demandée à la requête ([LangueNavigation.code]). Traduire
/// « Turn right onto Boulevard du 13 Janvier » côté application produirait un
/// mélange, et un moteur de synthèse français prononcerait le verbe anglais.
abstract class PhrasesNavigation {
  const PhrasesNavigation();

  factory PhrasesNavigation.pour(LangueNavigation langue) => switch (langue) {
        LangueNavigation.francais => const PhrasesFrancais(),
        LangueNavigation.anglais => const PhrasesAnglais(),
      };

  /// « Dans 300 mètres, tournez à droite. »
  String instructionADistance(RouteStep etape, int metres);

  /// « Tournez à droite. » — la manœuvre est imminente.
  String instructionImmediate(RouteStep etape);

  /// Annonce du départ vers une destination.
  String departVers(EtapeNavigation etape);

  /// « Vous êtes arrivé au restaurant. » / « Vous êtes arrivé à destination. »
  String arriveeA(EtapeNavigation etape);

  /// « Vous avez quitté l'itinéraire. Recalcul en cours. »
  String get sortieDItineraire;

  /// « Nouvel itinéraire. »
  String get itineraireRecalcule;

  /// « Position perdue. Recherche du signal. »
  String get positionPerdue;

  /// « Impossible de calculer l'itinéraire. »
  String get itineraireImpossible;

  /// Distance rendue lisible **à l'oreille**.
  ///
  /// « Dans 287 mètres » n'est pas une instruction, c'est un relevé : personne
  /// ne mesure 287 mètres en conduisant, et la fausse précision fait perdre le
  /// début de la phrase. Les paliers d'arrondi suivent ce qu'on sait estimer :
  /// la dizaine sous cent mètres, la cinquantaine sous cinq cents, la centaine
  /// au-delà, le kilomètre ensuite.
  String distanceParlee(int metres);
}

/// Guidage en français.
class PhrasesFrancais extends PhrasesNavigation {
  const PhrasesFrancais();

  @override
  String instructionADistance(RouteStep etape, int metres) =>
      'Dans ${distanceParlee(metres)}, ${_geste(etape)}.';

  @override
  String instructionImmediate(RouteStep etape) => _capitaliser(_geste(etape));

  @override
  String departVers(EtapeNavigation etape) => switch (etape) {
        EtapeNavigation.restaurant => 'Navigation vers le restaurant.',
        EtapeNavigation.client => 'Navigation vers le client.',
      };

  @override
  String arriveeA(EtapeNavigation etape) => switch (etape) {
        EtapeNavigation.restaurant => 'Vous êtes arrivé au restaurant.',
        EtapeNavigation.client => 'Vous êtes arrivé à destination.',
      };

  @override
  String get sortieDItineraire =>
      'Vous avez quitté l’itinéraire. Recalcul en cours.';

  @override
  String get itineraireRecalcule => 'Nouvel itinéraire.';

  @override
  String get positionPerdue => 'Position perdue. Recherche du signal.';

  @override
  String get itineraireImpossible =>
      'Impossible de calculer l’itinéraire. Vérifiez votre connexion.';

  @override
  String distanceParlee(int metres) {
    if (metres < 1000) return '${_arrondirMetres(metres)} mètres';

    // « 1 kilomètre » et non « 1,0 kilomètre » : la décimale d'un nombre rond
    // s'entend, et ne dit rien.
    final km = (metres / 100).round() / 10;
    final texte = km == km.roundToDouble()
        ? km.toStringAsFixed(0)
        : km.toStringAsFixed(1).replaceAll('.', ',');
    return '$texte ${km <= 1 ? 'kilomètre' : 'kilomètres'}';
  }

  /// Le geste, sans majuscule ni point : il s'insère dans les deux tournures.
  String _geste(RouteStep etape) => switch (etape.manoeuvre) {
        Manoeuvre.aGauche => 'tournez à gauche',
        Manoeuvre.aDroite => 'tournez à droite',
        Manoeuvre.legerementAGauche => 'serrez légèrement à gauche',
        Manoeuvre.legerementADroite => 'serrez légèrement à droite',
        Manoeuvre.serreAGauche => 'tournez franchement à gauche',
        Manoeuvre.serreADroite => 'tournez franchement à droite',
        Manoeuvre.demiTour => 'faites demi-tour',
        Manoeuvre.rondPoint => 'engagez-vous dans le rond-point',
        Manoeuvre.bretelleAGauche => 'prenez la bretelle à gauche',
        Manoeuvre.bretelleADroite => 'prenez la bretelle à droite',
        Manoeuvre.insertion => 'insérez-vous',
        Manoeuvre.fourcheAGauche => 'gardez la gauche',
        Manoeuvre.fourcheADroite => 'gardez la droite',
        Manoeuvre.bac => 'prenez le bac',
        Manoeuvre.toutDroit => 'continuez tout droit',
        // Google ne rend pas de manœuvre sur la première étape d'un trajet ni
        // sur une continuation. Son texte, lui, est toujours là et il est
        // juste : « Prendre la direction du nord sur le Boulevard… ». Le
        // remplacer par un geste inventé serait exactement ce qu'il ne faut
        // pas faire — dire « tournez à droite » là où Google n'a rien affirmé.
        Manoeuvre.aucune => etape.instruction.isEmpty
            ? 'continuez'
            : _sansPonctuationFinale(etape.instruction),
      };
}

/// Guidage en anglais.
class PhrasesAnglais extends PhrasesNavigation {
  const PhrasesAnglais();

  @override
  String instructionADistance(RouteStep etape, int metres) =>
      'In ${distanceParlee(metres)}, ${_geste(etape)}.';

  @override
  String instructionImmediate(RouteStep etape) => _capitaliser(_geste(etape));

  @override
  String departVers(EtapeNavigation etape) => switch (etape) {
        EtapeNavigation.restaurant => 'Navigating to the restaurant.',
        EtapeNavigation.client => 'Navigating to the customer.',
      };

  @override
  String arriveeA(EtapeNavigation etape) => switch (etape) {
        EtapeNavigation.restaurant => 'You have arrived at the restaurant.',
        EtapeNavigation.client => 'You have arrived at your destination.',
      };

  @override
  String get sortieDItineraire => 'You have left the route. Recalculating.';

  @override
  String get itineraireRecalcule => 'New route.';

  @override
  String get positionPerdue => 'Location lost. Searching for signal.';

  @override
  String get itineraireImpossible =>
      'Could not calculate the route. Check your connection.';

  @override
  String distanceParlee(int metres) {
    if (metres < 1000) return '${_arrondirMetres(metres)} meters';

    final km = (metres / 100).round() / 10;
    final texte =
        km == km.roundToDouble() ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
    return '$texte ${km <= 1 ? 'kilometer' : 'kilometers'}';
  }

  String _geste(RouteStep etape) => switch (etape.manoeuvre) {
        Manoeuvre.aGauche => 'turn left',
        Manoeuvre.aDroite => 'turn right',
        Manoeuvre.legerementAGauche => 'keep slightly left',
        Manoeuvre.legerementADroite => 'keep slightly right',
        Manoeuvre.serreAGauche => 'take a sharp left',
        Manoeuvre.serreADroite => 'take a sharp right',
        Manoeuvre.demiTour => 'make a U-turn',
        Manoeuvre.rondPoint => 'enter the roundabout',
        Manoeuvre.bretelleAGauche => 'take the ramp on the left',
        Manoeuvre.bretelleADroite => 'take the ramp on the right',
        Manoeuvre.insertion => 'merge',
        Manoeuvre.fourcheAGauche => 'keep left',
        Manoeuvre.fourcheADroite => 'keep right',
        Manoeuvre.bac => 'take the ferry',
        Manoeuvre.toutDroit => 'continue straight',
        Manoeuvre.aucune => etape.instruction.isEmpty
            ? 'continue'
            : _sansPonctuationFinale(etape.instruction),
      };
}

/// Arrondi audible : dizaine sous 100 m, cinquantaine sous 500 m, centaine
/// au-delà. Jamais zéro — « dans 0 mètre » ne veut rien dire.
int _arrondirMetres(int metres) {
  if (metres < 100) return (metres / 10).round().clamp(1, 10) * 10;
  if (metres < 500) return (metres / 50).round() * 50;
  return (metres / 100).round() * 100;
}

/// Majuscule initiale et point final — une phrase, pas un fragment.
String _capitaliser(String geste) {
  if (geste.isEmpty) return geste;
  return '${geste[0].toUpperCase()}${geste.substring(1)}.';
}

/// Retire le point final de l'instruction de Google avant de l'insérer dans
/// une phrase qui en pose déjà un.
String _sansPonctuationFinale(String texte) {
  final propre = texte.trimRight();
  return propre.endsWith('.') ? propre.substring(0, propre.length - 1) : propre;
}
