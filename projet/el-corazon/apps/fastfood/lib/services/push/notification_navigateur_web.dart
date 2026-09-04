/// Affichage d'une notification de premier plan sur le Web.
///
/// Voir `notification_navigateur.dart` pour la raison d'être de ce module.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Le navigateur sait-il afficher une notification, et l'utilisateur a-t-il
/// accepté ?
///
/// La permission est celle du navigateur, distincte de celle que
/// `FirebaseMessaging.requestPermission()` a obtenue — c'est en réalité la même
/// invite, mais elle se relit ici sans passer par Firebase.
bool get supporteNotificationsNavigateur =>
    web.Notification.permission == 'granted';

/// État du service worker que Firebase Messaging enregistre pour le push.
///
/// Trois choses distinctes décident si le Web reçoit : la permission du
/// navigateur, l'enregistrement du worker, et l'obtention du jeton. Elles
/// échouaient jusqu'ici sous un même message — « activation impossible » — qui
/// ne disait pas laquelle. Ce relevé permet de les lire séparément.
///
/// La portée interrogée est celle que le SDK JS impose lui-même :
/// `/firebase-cloud-messaging-push-scope`.
Future<String> etatDuServiceWorkerPush() async {
  try {
    final registration = await web.window.navigator.serviceWorker
        .getRegistration('/firebase-cloud-messaging-push-scope')
        .toDart;

    if (registration == null) return 'aucun';
    if (registration.active != null) return 'actif';
    if (registration.installing != null) return 'en cours d’installation';
    if (registration.waiting != null) return 'en attente';
    return 'enregistré';
  } catch (e) {
    return 'illisible ($e)';
  }
}

/// Affiche une notification par le service worker enregistré.
///
/// Rend `false` quand rien n'a pu être affiché — permission refusée, aucun
/// worker actif — pour que l'appelant puisse le tracer plutôt que de croire le
/// message délivré.
Future<bool> afficherNotificationNavigateur({
  required String titre,
  required String corps,
  String? etiquette,
}) async {
  if (!supporteNotificationsNavigateur) return false;

  try {
    // `ready` attend un worker **actif**. Le résoudre plutôt que d'utiliser
    // `controller` évite la fenêtre du tout premier chargement, où le worker
    // est enregistré mais pas encore installé — et où `controller` est nul.
    final registration =
        await web.window.navigator.serviceWorker.ready.toDart;

    await registration
        .showNotification(
          titre,
          web.NotificationOptions(
            body: corps,
            icon: '/icons/Icon-192.png',
            badge: '/icons/Icon-192.png',
            // Même étiquette que le worker d'arrière-plan : un message reçu au
            // premier plan puis rouvert en arrière-plan remplace le bandeau
            // précédent au lieu d'en empiler un second.
            tag: etiquette ?? 'elcorazon',
          ),
        )
        .toDart;
    return true;
  } catch (_) {
    return false;
  }
}
