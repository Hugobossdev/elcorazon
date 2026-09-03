import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clé Google Maps du back-office.
//
// ## Pourquoi elle passe par ici et non par le manifeste
//
// Le SDK Maps natif la lit dans le manifeste, pas dans le `.env` de Flutter :
// celui-ci est un *asset*, chargé après le démarrage du processus, quand la
// carte est déjà construite. Les deux applications mobiles l'ont donc écrite
// en clair dans leur manifeste, et elle est partie dans l'historique Git.
//
// Le back-office, lui, n'en avait **aucune** : `google_maps_flutter` est bien
// déclaré et `driver_map_screen` construit bien une `GoogleMap`, mais le
// manifeste fusionné ne portait pas `com.google.android.geo.API_KEY` — la
// carte de supervision rendait une tuile grise sur Android, sans erreur ni
// message. Le défaut ne se voit pas dans le code Dart, seulement dans le
// manifeste fusionné.
//
// La valeur vient de `local.properties` (ignoré par Git, comme le veut la
// configuration Flutter par défaut) ou de l'environnement de build. Vide, la
// carte reste grise — exactement l'état d'aujourd'hui, donc aucune régression
// possible — mais le chemin pour la renseigner existe et ne passe pas par un
// fichier versionné.
val cleMaps: String = run {
    val local = Properties()
    val fichier = rootProject.file("local.properties")
    if (fichier.exists()) {
        fichier.inputStream().use(local::load)
    }
    local.getProperty("maps.apiKey")
        ?: System.getenv("GOOGLE_MAPS_API_KEY")
        ?: ""
}

android {
    namespace = "com.example.admin"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_21.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.admin"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Injectée dans le manifeste à la fusion : voir `cleMaps` ci-dessus et
        // le `<meta-data>` de `src/main/AndroidManifest.xml`.
        manifestPlaceholders["mapsApiKey"] = cleMaps
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
