/// Version hors Web : il n'y a pas de navigateur à qui demander.
///
/// Android et iOS affichent leurs notifications de premier plan par
/// `flutter_local_notifications`, qui les prend en charge nativement. Ce fichier
/// n'existe que pour que l'import conditionnel ait une branche sur ces cibles —
/// `package:web` ne compile que pour le Web.
library;

/// Toujours faux ici : l'appelant retombe sur le greffon natif.
bool get supporteNotificationsNavigateur => false;

/// Sans objet hors Web : Android et iOS n'enregistrent pas de service worker.
Future<String> etatDuServiceWorkerPush() async => 'sans objet';

/// Jamais appelée hors Web ; présente pour tenir le contrat de l'import
/// conditionnel.
Future<bool> afficherNotificationNavigateur({
  required String titre,
  required String corps,
  String? etiquette,
}) async =>
    false;
