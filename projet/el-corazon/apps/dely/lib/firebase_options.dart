// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Configuration Firebase du projet **elcorazon-9595**.
///
/// ## Ce que cet en-tête disait, et pourquoi il a changé
///
/// Il annonçait des « valeurs de remplissage » et un projet inexistant
/// (`fastfoodgo-deliver`), au motif qu'aucun projet Firebase n'avait été créé.
/// Ce n'est plus vrai : le projet existe, les enregistrements web, Android,
/// iOS et macOS sont réels, et `Firebase.initializeApp()` aboutit. Laisser
/// l'avertissement coûtait dans les deux sens — on croyait les notifications
/// push impossibles alors qu'elles fonctionnent, et on croyait ces clés sans
/// valeur alors qu'elles identifient un vrai projet.
///
/// ## Ces clés sont publiques, et ce n'est pas une fuite
///
/// Une clé d'API Firebase côté client part dans l'APK, dans l'IPA et dans le
/// HTML : la cacher est impossible, et ce n'est pas ce qui protège le projet.
/// Ce qui le protège, ce sont les règles de sécurité et la restriction de la
/// clé à ses applications déclarées. La clé **Google Maps** relève du même
/// raisonnement et de la même action à mener : `docs/security/google_maps.md`.
///
/// ## Ne pas éditer à la main
///
/// Ce fichier se régénère par `flutterfire configure` (voir `docs/firebase.md`).
/// L'entrée `windows` reprend l'enregistrement **web** du projet, ce que fait
/// l'outil lui-même : Firebase n'a pas de plateforme Windows distincte.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAbt_ZYvbzUwmcflqiHH8GL8BdAlAImlqI',
    appId: '1:574529156682:web:47024d329f15b37c8458b3',
    messagingSenderId: '574529156682',
    projectId: 'elcorazon-9595',
    authDomain: 'elcorazon-9595.firebaseapp.com',
    storageBucket: 'elcorazon-9595.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyByYPmtsEhRXWbmHQDtNLpHkw7IKpTwo10',
    appId: '1:574529156682:android:5af0f6aee41c72f28458b3',
    messagingSenderId: '574529156682',
    projectId: 'elcorazon-9595',
    storageBucket: 'elcorazon-9595.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC-_u76eEunEsbuCJFqE3juV9RrwWeJ-CU',
    appId: '1:574529156682:ios:eb4472f9af7287998458b3',
    messagingSenderId: '574529156682',
    projectId: 'elcorazon-9595',
    storageBucket: 'elcorazon-9595.firebasestorage.app',
    iosBundleId: 'com.elcorazon.dely',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyC-_u76eEunEsbuCJFqE3juV9RrwWeJ-CU',
    appId: '1:574529156682:ios:11c28630bcd706398458b3',
    messagingSenderId: '574529156682',
    projectId: 'elcorazon-9595',
    storageBucket: 'elcorazon-9595.firebasestorage.app',
    iosBundleId: 'com.example.elcoraDely',
  );
  // Reprend l'enregistrement web de cette application, comme le fait
  // `flutterfire configure`. L'entrée précédente visait un projet qui n'existe
  // pas : démarrer sur Windows échouait à l'initialisation, sur une erreur qui
  // ne nommait pas la cause.
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAbt_ZYvbzUwmcflqiHH8GL8BdAlAImlqI',
    appId: '1:574529156682:web:47024d329f15b37c8458b3',
    messagingSenderId: '574529156682',
    projectId: 'elcorazon-9595',
    authDomain: 'elcorazon-9595.firebaseapp.com',
    storageBucket: 'elcorazon-9595.firebasestorage.app',
  );
}
