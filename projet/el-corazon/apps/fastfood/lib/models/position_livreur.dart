import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Relevé de position d'un livreur, à un instant.
///
/// ## Pourquoi ce n'est plus une `Map<String, dynamic>`
///
/// Le canal émettait une carte non typée, et l'écran de suivi la relisait à
/// coups de conversions. L'une d'elles était fausse : le service écrivait
/// `DateTime.parse(...)` — donc un `DateTime` — et l'écran relisait
/// `DateTime.parse(carte['timestamp'] as String)`. Convertir un `DateTime` en
/// `String` lève, et cela levait **à chaque position reçue** : le bloc entier
/// échouait avant son `setState`, si bien que le repère du livreur restait
/// figé sur sa position initiale pendant toute la livraison. Rien ne
/// paraissait à l'écran, l'erreur partant dans un écouteur asynchrone.
///
/// La même carte portait `speed`, converti par `as double` alors que le
/// serveur peut rendre un entier — seconde conversion prête à lever.
///
/// Un type nommé rend ces deux fautes impossibles : le compilateur les refuse.
@immutable
class PositionLivreur {
  const PositionLivreur({
    required this.commandeId,
    required this.latitude,
    required this.longitude,
    required this.releveeA,
    this.precisionMetres,
    this.vitesseMetresParSeconde,
    this.capDegres,
  });

  /// Construit un relevé à partir d'un message `tracking.position`.
  ///
  /// Rend `null` si le message ne porte pas ce qu'il faut, plutôt que de
  /// lever au fond d'un écouteur où personne ne rattrape : une trame
  /// malformée ne doit pas interrompre le suivi des suivantes.
  static PositionLivreur? depuisDiffusion(
    String commandeId,
    Map<String, dynamic> charge,
  ) {
    final latitude = (charge['lat'] as num?)?.toDouble();
    final longitude = (charge['lon'] as num?)?.toDouble();
    final horodatage = charge['recorded_at'];

    if (latitude == null || longitude == null || horodatage is! String) {
      eccore.Journal.trace('Relevé de position ignoré, trame incomplète : $charge');
      return null;
    }

    final releveeA = DateTime.tryParse(horodatage);
    if (releveeA == null) {
      eccore.Journal.trace('Relevé de position ignoré, date illisible : $horodatage');
      return null;
    }

    return PositionLivreur(
      commandeId: commandeId,
      latitude: latitude,
      longitude: longitude,
      releveeA: releveeA,
      // `speed` et `heading` ne sont pas relayés par ce canal côté serveur
      // (`apps/tracking/consumers.py OrderTrackingConsumer`) : le livreur les
      // émet, la diffusion ne les porte pas.
      precisionMetres: (charge['accuracy'] as num?)?.toDouble(),
      vitesseMetresParSeconde: (charge['speed'] as num?)?.toDouble(),
      capDegres: (charge['heading'] as num?)?.toDouble(),
    );
  }

  final String commandeId;
  final double latitude;
  final double longitude;
  final DateTime releveeA;
  final double? precisionMetres;
  final double? vitesseMetresParSeconde;
  final double? capDegres;

  LatLng get point => LatLng(latitude, longitude);

  /// Vitesse en km/h, ou `null` si le relevé n'en porte pas. Zéro est une
  /// vitesse — celle d'un livreur à l'arrêt —, l'absence n'en est pas une.
  double? get vitesseKmH {
    final vitesse = vitesseMetresParSeconde;
    return vitesse == null ? null : vitesse * 3.6;
  }
}
