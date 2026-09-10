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

// Clé Google Maps **Android**, injectée au manifeste plutôt qu'écrite dedans.
//
// Elle y était en clair, suivie par git, et **partagée** avec l'application
// cliente et avec iOS. Google n'accepte qu'un seul type de restriction par clé :
// une clé qui sert Android, iOS et le web ne peut donc en porter aucune sans
// casser deux contextes sur trois — ce qui explique qu'elle n'en ait aucune. Une
// clé Maps non restreinte se relève dans l'APK et se facture à son propriétaire,
// Google Maps Platform facturant à l'appel sans plafond par défaut.
//
// La clé reste **publique** une fois l'application distribuée : ce fichier ne la
// cache pas, il l'empêche seulement d'entrer dans le dépôt, et rend possible
// d'en avoir une par plateforme. Ce qui la protège est la restriction
// (empreinte SHA-1 + nom de paquet), posée dans la console Google Cloud.
//
// Trois sources, dans l'ordre : `android/maps.properties` (poste de
// développement, non versionné), la variable d'environnement `MAPS_API_KEY`
// (CI et build de release), puis le vide.
//
// Vide, la carte s'affiche grise et le reste de l'application fonctionne. C'est
// une dégradation lisible, préférable à un échec de compilation qui bloquerait
// quelqu'un qui ne touche pas aux cartes.
val mapsProperties = Properties()
val mapsPropertiesFile = rootProject.file("maps.properties")
if (mapsPropertiesFile.exists()) {
    FileInputStream(mapsPropertiesFile).use { mapsProperties.load(it) }
}
val mapsApiKey: String =
    (mapsProperties["MAPS_API_KEY"] as String?)
        ?: System.getenv("MAPS_API_KEY")
        ?: ""

android {
    namespace = "com.elcorazon.fast"
    compileSdk = 36
    // ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // Repris par `AndroidManifest.xml` sous `${MAPS_API_KEY}`.
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.elcorazon.fast"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 34
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

    // L'app ne fait que de l'audio : `AgoraService` appelle `enableAudio()`, jamais
    // `enableVideo()`, et n'active aucune extension. Le SDK Agora livre pourtant
    // toutes ses extensions vidéo et ses traitements audio optionnels, soit ~53 Mo
    // de .so par ABI que rien ne charge. Elles sont chargées à la demande via
    // dlopen, donc leur absence est sans effet tant qu'aucun appel ne les réclame.
    // Si un jour l'app active la vidéo, la suppression de bruit IA ou l'audio
    // spatial, il faudra retirer d'ici la ligne correspondante.
    packaging {
        jniLibs {
            excludes += listOf(
                // Vidéo : rendu, encodage, décodage, capture d'écran
                "**/libagora_clear_vision_extension.so",
                "**/libagora_segmentation_extension.so",
                "**/libagora_video_av1_encoder_extension.so",
                "**/libagora_video_encoder_extension.so",
                "**/libagora_video_quality_analyzer_extension.so",
                "**/libagora_screen_capture_extension.so",
                "**/libvideo_enc.so",
                "**/libvideo_dec.so",
                "**/libagora_ffmpeg.so",
                // Analyse d'image : visages, lèvres, modération de contenu
                "**/libagora_face_capture_extension.so",
                "**/libagora_face_detection_extension.so",
                "**/libagora_lip_sync_extension.so",
                "**/libagora_content_inspect_extension.so",
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
