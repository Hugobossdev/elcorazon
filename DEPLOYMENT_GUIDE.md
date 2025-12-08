# Guide de Déploiement - elcora_fast

## ⚠️ Problème Actuel

Il y a un problème de compatibilité avec **Flutter 3.39.0-beta** et le système Gradle qui empêche le build. L'erreur est:
```
Cannot run Project.afterEvaluate(Action) when the project is already evaluated
```

## ✅ Solutions pour Résoudre le Problème

### Option 1: Passer au canal Stable (Recommandé pour Production)

```powershell
# Sauvegardez d'abord vos modifications Flutter SDK si vous en avez
# Puis exécutez:
flutter channel stable
flutter upgrade
flutter clean
flutter pub get
```

### Option 2: Mettre à jour Flutter Beta (Alternative)

```powershell
flutter upgrade
flutter clean
flutter pub get
```

### Option 3: Attendre un correctif

Le problème est connu avec Flutter 3.39.0-beta. Vous pouvez suivre les mises à jour:
- https://github.com/flutter/flutter/issues

## 🚀 Une fois le Problème Résolu

### Méthode 1: Utiliser le Script de Déploiement Automatique

```powershell
.\deploy.ps1
```

Ce script automatise toutes les étapes:
- ✅ Nettoyage du projet
- ✅ Récupération des dépendances
- ✅ Vérification du projet
- ✅ Construction de l'APK
- ✅ Option pour créer l'AAB (Google Play Store)

### Méthode 2: Déploiement Manuel

#### Étape 1: Nettoyer le projet
```powershell
flutter clean
flutter pub get
```

#### Étape 2: Construire l'APK (pour installation directe)
```powershell
flutter build apk --release
```

**Fichier créé:** `build/app/outputs/flutter-apk/app-release.apk`

#### Étape 3: Construire l'AAB (pour Google Play Store)
```powershell
flutter build appbundle --release
```

**Fichier créé:** `build/app/outputs/bundle/release/app-release.aab`

## 🔐 Configuration de Signature pour Production

**Important:** Actuellement, l'app utilise des clés de debug. Pour la production:

1. **Créer une clé de signature:**
   ```powershell
   keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. **Créer `android/key.properties`:**
   ```properties
   storePassword=votre_mot_de_passe
   keyPassword=votre_mot_de_passe
   keyAlias=upload
   storeFile=upload-keystore.jks
   ```

3. **Modifier `android/app/build.gradle.kts`** pour utiliser cette clé (voir documentation Flutter)

## 📋 Fichiers de Déploiement

- **APK**: Pour installation directe sur appareils Android
- **AAB**: Pour publication sur Google Play Store (recommandé)

## 🔍 Vérifications Avant Déploiement

```powershell
# Vérifier la version Flutter
flutter --version

# Vérifier la configuration
flutter doctor -v

# Vérifier les dépendances
flutter pub outdated
```

## 📱 Installation de l'APK

Une fois l'APK créé, vous pouvez l'installer:

```powershell
# Via ADB (si appareil connecté)
adb install build/app/outputs/flutter-apk/app-release.apk

# Ou transférer le fichier manuellement sur l'appareil
```

## 🎯 Publication sur Google Play Store

1. Connectez-vous à [Google Play Console](https://play.google.com/console)
2. Créez une nouvelle application
3. Téléchargez le fichier `.aab` (pas l'APK)
4. Remplissez les informations de l'application
5. Soumettez pour révision

## 🆘 Support

Si vous rencontrez des problèmes:
- ✅ Vérifiez que vous êtes sur un canal compatible: `flutter channel`
- ✅ Vérifiez les dépendances: `flutter pub get`
- ✅ Nettoyez le projet: `flutter clean`
- ✅ Vérifiez `flutter doctor -v` pour les problèmes de configuration

## 📝 Notes

- Version actuelle: 1.0.0+1 (définie dans `pubspec.yaml`)
- Application ID: com.example.elcora_fast
- Pour changer la version, modifiez `pubspec.yaml` ligne 19
