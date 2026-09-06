// Service worker des notifications push Web (Firebase Cloud Messaging).
//
// ## Ce qui n'allait pas
//
// Ce fichier existait, mais il déclarait le projet `fastfoodgo-deliver` avec la
// clé `AIzaSyDummyKeyForTesting` — un projet qui n'existe pas. C'est le reste
// d'un gabarit, resté en place quand `El Cora Fast` a été remis d'aplomb sur le
// projet réel. Conséquence pour le livreur : `getToken()` s'adressait à un
// projet inconnu, l'appareil Web n'était jamais enregistré auprès de
// `/auth/devices/`, et **aucune offre de course n'arrivait** sur la version
// navigateur. Rien ne le signalait : le SDK échoue en silence, et l'application
// traite l'absence de jeton comme un cas normal.
//
// Deux autres défauts venaient du même gabarit, et sont corrigés ici :
//
// * la version du SDK (`9.22.0`) ne correspondait pas à celle que FlutterFire
//   injecte dans la page. Le worker et la page doivent parler la même : un
//   écart de version majeure donne des jetons que l'un des deux ne sait pas
//   relire ;
// * `onBackgroundMessage` appelait `showNotification` sans condition, alors
//   que le serveur envoie toujours un bloc `notification`
//   (`FcmSender._payload`, `backend/apps/notifications/fcm.py`) que le SDK
//   affiche déjà lui-même. Le livreur aurait vu **deux bandeaux** par offre.
//   Et `payload.notification.title` lu sans garde levait sur un message envoyé
//   en données seules.
//
// ## Pourquoi ce fichier doit exister, et à cet emplacement exact
//
// `FirebaseMessaging.getToken()` sur le Web enregistre lui-même un service
// worker, qu'il va chercher à `/firebase-messaging-sw.js` (portée
// `/firebase-cloud-messaging-push-scope`). Le nom n'est pas configurable sans
// passer une `ServiceWorkerRegistration` explicite. Tout ce que contient `web/`
// est copié tel quel dans `build/web/` par `flutter build web`.
//
// ## Version du SDK
//
// `12.15.0` n'est pas un choix libre : c'est `supportedFirebaseJsSdkVersion` de
// `firebase_core_web` 3.9.1, la version que FlutterFire injecte dans la page. À
// mettre à jour **en même temps** que `firebase_core` / `firebase_messaging`.
//
// Le build `compat` est obligatoire : un service worker n'a pas de système de
// modules ES et ne dispose que d'`importScripts`.
importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-messaging-compat.js');

// Recopie de `DefaultFirebaseOptions.web` (`lib/firebase_options.dart`).
//
// Le worker s'exécute hors de la page : il ne voit ni les variables Dart, ni
// `.env`, ni rien de ce que l'application a chargé. Cette duplication est
// inévitable — mais elle doit rester une copie fidèle, sans quoi le jeton
// délivré au worker désignerait un autre projet que celui de la page. C'est
// exactement la panne qu'on répare ici.
//
// Aucun secret : ce sont les identifiants publics du client Web, ceux-là mêmes
// que le navigateur télécharge déjà dans `main.dart.js`.
firebase.initializeApp({
  apiKey: 'AIzaSyAbt_ZYvbzUwmcflqiHH8GL8BdAlAImlqI',
  appId: '1:574529156682:web:47024d329f15b37c8458b3',
  messagingSenderId: '574529156682',
  projectId: 'elcorazon-9595',
  authDomain: 'elcorazon-9595.firebaseapp.com',
  storageBucket: 'elcorazon-9595.firebasestorage.app',
});

const messaging = firebase.messaging();

// Messages reçus onglet fermé ou en arrière-plan.
//
// Le SDK affiche seul les messages porteurs d'un bloc `notification` — c'est-à-
// dire tous ceux que le serveur émet aujourd'hui. La branche manuelle ne sert
// qu'aux envois *data-only*, que le SDK ne sait pas afficher, pour qu'un tel
// message ne disparaisse pas sans laisser de trace.
messaging.onBackgroundMessage((payload) => {
  if (payload.notification) return;

  const data = payload.data || {};
  const titre = data.title;
  if (!titre) return;

  self.registration.showNotification(titre, {
    body: data.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    // Regroupe les rappels successifs d'une même course : sans étiquette,
    // quatre changements de statut empilent quatre bandeaux.
    tag: data.order || data.kind || 'elcorazon-dely',
    data: data,
  });
});

// Volontairement **aucun** écouteur `notificationclick`.
//
// Le SDK en installe déjà un : il ramène l'onglet existant au premier plan puis
// transmet le message à la page, où `NotificationService` l'écoute pour ouvrir
// la bonne course. En ajouter un second ferait cohabiter deux routages
// concurrents pour un seul clic, et celui-ci ne saurait rien des routes de
// l'application.
