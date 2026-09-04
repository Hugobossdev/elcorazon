/// Affichage d'une notification par le **navigateur**, sur le Web seulement.
///
/// ## Pourquoi ce détour existe
///
/// `flutter_local_notifications` n'a pas d'implémentation Web : son `show()`
/// commence par `if (kIsWeb) return;` (voir
/// `flutter_local_notifications-19.5.0/lib/src/flutter_local_notifications_plugin.dart`).
/// Sur le Web, un message reçu **application ouverte** passait donc par
/// `_handleForegroundMessage`, appelait `show()`… et ne produisait rien du
/// tout. Aucune erreur, aucun bandeau : le message était simplement perdu.
///
/// Le service worker ne couvre pas ce cas — il ne reçoit que l'arrière-plan.
/// Le premier plan est à la charge de la page, et c'est ce que fait ce module.
///
/// ## Pourquoi passer par le service worker plutôt que `new Notification()`
///
/// Le constructeur `Notification` est interdit sur Chrome Android, où il lève
/// une `TypeError` (« Failed to construct 'Notification' : Illegal
/// constructor »). `ServiceWorkerRegistration.showNotification()` fonctionne
/// partout où un worker est enregistré — et depuis que
/// `web/firebase-messaging-sw.js` existe, il y en a un.
library;

export 'notification_navigateur_stub.dart'
    if (dart.library.js_interop) 'notification_navigateur_web.dart';
