// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// ⚠️ **Valeurs de remplissage, pas des identifiants réels.**
///
/// Aucun projet Firebase n'existe encore pour El Corazón — c'est le dernier
/// prérequis backend ouvert (`docs/architecture/04-migration-flutter.md` §3.0 :
/// « Valider FCM en conditions réelles »). Ce fichier a la forme exacte de ce
/// que génère la CLI FlutterFire, avec des valeurs factices, pour que le
/// câblage push soit écrit, compilé et relu dès maintenant.
///
/// À remplacer intégralement par `flutterfire configure` une fois le projet
/// Firebase créé — ne pas éditer les valeurs à la main. Tant que c'est le cas,
/// `Firebase.initializeApp()` échoue au démarrage : `main()` et
/// `PushNotificationService` traitent cet échec comme non fatal (l'app tourne,
/// sans notifications push), plutôt que de bloquer le lancement.
///
/// `El corazon dely/lib/firebase_options.dart` est dans le même état.
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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions ne couvre pas ${defaultTargetPlatform.name} — '
          'relancer `flutterfire configure` pour cette plateforme.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'PLACEHOLDER-VOIR-DOC-EN-TETE',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'elcorazon-placeholder',
    authDomain: 'elcorazon-placeholder.firebaseapp.com',
    storageBucket: 'elcorazon-placeholder.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PLACEHOLDER-VOIR-DOC-EN-TETE',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'elcorazon-placeholder',
    storageBucket: 'elcorazon-placeholder.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'PLACEHOLDER-VOIR-DOC-EN-TETE',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'elcorazon-placeholder',
    storageBucket: 'elcorazon-placeholder.appspot.com',
    iosBundleId: 'com.elcorazon.fastfood',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'PLACEHOLDER-VOIR-DOC-EN-TETE',
    appId: '1:000000000000:macos:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'elcorazon-placeholder',
    storageBucket: 'elcorazon-placeholder.appspot.com',
    iosBundleId: 'com.elcorazon.fastfood',
  );
}
