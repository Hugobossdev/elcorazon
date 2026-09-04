// Service worker des notifications push Web (Firebase Cloud Messaging).
//
// ## Pourquoi ce fichier doit exister, et à cet emplacement exact
//
// `FirebaseMessaging.getToken()` sur le Web ne se contente pas d'appeler une
// API : le SDK JS enregistre lui-même un service worker, qu'il va chercher à
// `/firebase-messaging-sw.js` (portée `/firebase-cloud-messaging-push-scope`).
// Le nom n'est pas configurable sans passer une `ServiceWorkerRegistration`
// explicite.
//
// Ce fichier n'existait pas. Le serveur de développement Flutter — comme tout
// serveur d'application monopage — répond alors à l'URL inconnue par
// `index.html`, donc en `text/html`. La spécification des service workers
// impose un type JavaScript : le navigateur refuse l'enregistrement avec
// « The script has an unsupported MIME type ('text/html') », `getToken()`
// échoue en `failed-service-worker-registration`, et l'appareil Web n'est
// jamais enregistré côté serveur. Le MIME type n'était donc pas le problème
// mais son symptôme : il n'y avait pas de script à servir.
//
// Tout ce que contient `web/` est copié tel quel dans `build/web/` par
// `flutter build web` : le poser ici le rend disponible en développement comme
// en production, sans règle de serveur particulière.
//
// ## Version du SDK
//
// `12.15.0` n'est pas un choix libre : c'est `supportedFirebaseJsSdkVersion`
// de `firebase_core_web` 3.9.1 (voir `lib/src/firebase_sdk_version.dart` dans
// le paquet), la version que FlutterFire injecte dans la page. Le worker et la
// page doivent parler la même — un écart de version majeure entre les deux
// donne des jetons que l'un des deux ne sait pas relire.
//
// À mettre à jour **en même temps** que `firebase_core` / `firebase_messaging`.
//
// Le build `compat` est obligatoire ici : un service worker n'a pas de système
// de modules ES et ne dispose que d'`importScripts`.
importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-messaging-compat.js');

// Recopie de `DefaultFirebaseOptions.web` (`lib/firebase_options.dart`).
//
// Le worker s'exécute hors de la page : il ne voit ni les variables Dart, ni
// `.env`, ni rien de ce que l'application a chargé. Cette duplication est
// inévitable — mais elle doit rester une copie fidèle, sans quoi le jeton
// délivré au worker désignerait un autre projet Firebase que celui de la page.
//
// Aucun secret ici : ce sont les identifiants publics du client Web, ceux-là
// mêmes que le navigateur télécharge déjà dans `main.dart.js`.
firebase.initializeApp({
  apiKey: 'AIzaSyAbt_ZYvbzUwmcflqiHH8GL8BdAlAImlqI',
  appId: '1:574529156682:web:f5ebb766db3f851f8458b3',
  messagingSenderId: '574529156682',
  projectId: 'elcorazon-9595',
  authDomain: 'elcorazon-9595.firebaseapp.com',
  storageBucket: 'elcorazon-9595.firebasestorage.app',
});

const messaging = firebase.messaging();

// Messages reçus onglet fermé ou en arrière-plan.
//
// Le serveur envoie toujours un bloc `notification`
// (`FcmSender._payload`, `backend/apps/notifications/fcm.py`), et le SDK
// affiche **lui-même** ces messages-là. Rappeler `showNotification` ici en
// afficherait donc deux pour un seul envoi — le défaut le plus courant de ce
// fichier lorsqu'il est recopié depuis un exemple.
//
// La branche manuelle ne sert qu'aux messages *data-only*, que le SDK ne sait
// pas afficher seul. Le serveur n'en émet pas aujourd'hui ; elle est là pour
// qu'un envoi silencieux ne disparaisse pas sans laisser de trace.
messaging.onBackgroundMessage((payload) => {
  if (payload.notification) return;

  const data = payload.data || {};
  const titre = data.title;
  if (!titre) return;

  self.registration.showNotification(titre, {
    body: data.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    // Regroupe les rappels successifs d'une même commande : sans étiquette,
    // quatre changements de statut empilent quatre bandeaux.
    tag: data.order || data.kind || 'elcorazon',
    data: data,
  });
});

// Volontairement **aucun** écouteur `notificationclick` ici.
//
// Le SDK en installe déjà un : il ramène l'onglet existant au premier plan (ou
// en ouvre un) puis transmet le message à la page, où il ressort par
// `FirebaseMessaging.onMessageOpenedApp` — que `PushNotificationRouter` écoute
// déjà pour ouvrir le bon écran. En ajouter un second ferait cohabiter deux
// routages concurrents pour un seul clic, et celui-ci ne saurait rien des
// routes de l'application.
