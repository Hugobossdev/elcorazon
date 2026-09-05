import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'package:elcora_dely/services/realtime_tracking_service.dart';

/// D'où la navigation tire les positions du livreur.
///
/// ## Pourquoi cette interface, et pourquoi elle est en lecture seule
///
/// Il n'existe qu'**une** source de position dans l'application : le flux que
/// `RealtimeTrackingService` ouvre pour la durée d'une course. Un audit
/// précédent a supprimé un second `getPositionStream` que l'écran de suivi
/// ouvrait pour bouger un repère — deux flux haute précision sur le même
/// appareil, c'est deux fois le poste le plus lourd d'un téléphone, et une
/// carte qui peut afficher une position pendant que le vrai suivi est en panne.
///
/// Cette interface **ne crée pas** une seconde source : elle nomme la première,
/// en lecture. Elle n'expose aucun moyen d'ouvrir ou de fermer un flux, et
/// c'est délibéré — la porte reste celle de la course, tenue par `AppService`.
///
/// Ce qu'elle rend possible : vérifier une navigation sans capteur. Le moteur
/// se teste déjà sans plateforme (`MoteurDeNavigation`) ; il manquait de
/// pouvoir exercer l'assemblage — bascule du restaurant vers le client,
/// recalcul après sortie d'itinéraire, phrases réellement envoyées à la
/// synthèse — sans monter de greffon.
abstract class SourceDePosition implements Listenable {
  /// La dernière position connue, ou `null` — « pas encore localisé », jamais
  /// « immobile ».
  Position? get positionCourante;

  /// Ce qui empêche le relevé, en une phrase pour le livreur. `null` si rien.
  String? get obstacle;

  /// Le flux de position est-il ouvert ?
  bool get suitLaPosition;
}

/// La source réelle : le service de suivi, vu en lecture.
class SuiviCommeSource implements SourceDePosition {
  SuiviCommeSource([RealtimeTrackingService? suivi])
      : _suivi = suivi ?? RealtimeTrackingService();

  final RealtimeTrackingService _suivi;

  @override
  Position? get positionCourante => _suivi.currentPosition;

  @override
  String? get obstacle => _suivi.trackingUnavailableReason;

  @override
  bool get suitLaPosition => _suivi.isTrackingLocation;

  @override
  void addListener(VoidCallback ecouteur) => _suivi.addListener(ecouteur);

  @override
  void removeListener(VoidCallback ecouteur) => _suivi.removeListener(ecouteur);
}
