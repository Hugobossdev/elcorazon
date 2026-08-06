import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clés de signature de production. Le fichier `android/key.properties` n'est pas
// versionné : il porte les mots de passe du keystore. Quand il est absent (CI,
// clone frais), la release retombe sur la clé debug pour rester compilable, mais
// l'APK produit n'est alors pas publiable.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.elcorazon.dely"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications s'appuie sur les API de date/heure de Java 8,
        // absentes des anciens Android : le desugaring les réimplémente à la
        // compilation. Sans lui, checkReleaseAarMetadata refuse de construire.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.elcorazon.dely"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    // Contrairement à l'app client, celle-ci fait de la vidéo : `AgoraCallService`
    // appelle `enableVideo()` et `startPreview()` pour `CallType.video`. Tout le
    // chemin codec reste donc embarqué (libvideo_enc, libvideo_dec, ffmpeg,
    // video_encoder), et seules sont exclues les extensions qu'aucun appel
    // n'active : embellissement, arrière-plan virtuel, analyse de visage,
    // traitements audio IA, audio spatial, partage d'écran.
    //
    // En l'état ces motifs ne retirent rien : agora_rtc_engine 6.5.3 ne livre pas
    // ces extensions, à la différence du 6.3.0 utilisé par l'app client. La liste
    // est gardée comme garde-fou — une montée de version qui les réintroduirait
    // ajouterait ~40 Mo par ABI sans elle. Si l'app active un jour l'une de ces
    // fonctions, retirer la ligne correspondante.
    packaging {
        jniLibs {
            excludes += listOf(
                // Traitement d'image jamais activé (beauté, fond virtuel, visages)
                "**/libagora_clear_vision_extension.so",
                "**/libagora_segmentation_extension.so",
                "**/libagora_face_capture_extension.so",
                "**/libagora_face_detection_extension.so",
                "**/libagora_lip_sync_extension.so",
                "**/libagora_content_inspect_extension.so",
                "**/libagora_video_quality_analyzer_extension.so",
                // Pas de partage d'écran dans l'app livreur
                "**/libagora_screen_capture_extension.so",
                // Traitements audio optionnels (l'AEC et l'ANS de base restent
                // dans libagora-rtc-sdk.so, ce sont les variantes IA qui partent)
                "**/libagora_ai_noise_suppression_extension.so",
                "**/libagora_ai_noise_suppression_ll_extension.so",
                "**/libagora_ai_echo_cancellation_extension.so",
                "**/libagora_ai_echo_cancellation_ll_extension.so",
                "**/libagora_audio_beauty_extension.so",
                "**/libagora_spatial_audio_extension.so",
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
