# 📦 Guide d'installation - El Corazon Fastfood

Guide pas à pas pour installer et configurer le projet El Corazon Fastfood.

## ⚡ Prérequis

### Logiciels requis

- **Flutter SDK** >= 3.0.0  
  [Installation Flutter](https://docs.flutter.dev/get-started/install)
  
- **Android Studio** ou **Xcode** (pour iOS)  
  Pour l'émulation et le build

- **Git**  
  Pour cloner le dépôt

- **Docker** et **Docker Compose**  
  Pour lancer le backend Django localement (`backend/docker-compose.yml`)

### Clés nécessaires à l'application

L'application ne détient **aucun secret de prestataire**. Elle ne parle qu'au
backend Django, qui encaisse, signe les jetons d'appel et garde les clés
marchandes. Une clé placée dans le `.env` d'une application est une clé dans le
binaire distribué.

Deux clés seulement, toutes deux clientes et publiques par nature :

1. **Google Maps** (cartographie et géolocalisation)
   - Console Google Cloud : [console.cloud.google.com](https://console.cloud.google.com)
   - Activer « Maps SDK for Android » et « Maps SDK for iOS »
   - Créer une clé, puis **la restreindre** par empreinte d'application et par
     API — sans quoi elle est utilisable par n'importe qui

2. **Agora** (appels audio/vidéo, facultatif)
   - Compte sur [agora.io](https://www.agora.io)
   - Récupérer l'**App ID** seulement. Le certificat reste côté backend
     (`AGORA_APP_CERTIFICATE`) : c'est lui qui signe les jetons d'appel

À quoi s'ajoute la configuration cliente **Firebase** pour les notifications
push, elle aussi publique — elle identifie le projet, elle n'y donne pas accès.

Ce qui se configure **côté backend, jamais ici** : les quatre clés marchandes
PayDunya, le certificat Agora, et les accès à la base.

## 🚀 Installation

### 1. Cloner le projet

```bash
git clone <repository-url>
cd projet/el-corazon/apps/fastfood
```

### 2. Installer les dépendances Flutter

```bash
flutter pub get
```

### 3. Configurer l'environnement

Copier le fichier d'exemple et le compléter :

```bash
cp .env.example .env
```

Éditer le fichier `.env` avec vos vraies clés :

```env
# Backend Django. 10.0.2.2 est l'alias de l'émulateur Android vers l'hôte ;
# utiliser localhost pour iOS, desktop et web.
API_BASE_URL=http://10.0.2.2:8000/api/v1

ENVIRONMENT=development

GOOGLE_MAPS_API_KEY=votre-cle-google-maps

# App ID seulement — le certificat vit côté backend.
AGORA_APP_ID=votre-app-id

# Configuration cliente Firebase, publique par nature.
FIREBASE_API_KEY=
FIREBASE_AUTH_DOMAIN=
FIREBASE_PROJECT_ID=
FIREBASE_STORAGE_BUCKET=
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_APP_ID=
```

`.env.example` fait foi : il ne liste que ce que le code lit.

### 4. Configuration Android

#### a. Ajouter la clé Google Maps

Le fichier `android/app/src/main/AndroidManifest.xml` contient déjà la configuration Google Maps.

Vérifiez que la clé API est bien présente :

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSyCtSGHbgwiNKhblSK7NpU7aVUvuxz-w-tM"/>
```

#### b. Générer le keystore (pour le build de production)

```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Créer `android/key.properties` :

```properties
storePassword=votre-store-password
keyPassword=votre-key-password
keyAlias=upload
storeFile=upload-keystore.jks
```

### 5. Configuration iOS (si développement iOS)

#### a. Installation des pods

```bash
cd ios
pod install
cd ..
```

#### b. Ajouter la clé Google Maps dans `ios/Runner/AppDelegate.swift`

La configuration est déjà en place, vérifiez le fichier.

## 🗄️ Lancer le backend

L'application ne crée aucune table et ne parle à aucune base : tout passe par
l'API Django. Le backend se lance avec Docker, depuis `backend/` :

```bash
cd ../../backend
docker compose up
```

Le schéma est celui des migrations Django (`backend/apps/*/migrations/`), et
l'authentification est celle du backend — il n'y a ni règles RLS ni fournisseur
tiers à configurer côté application.

📖 Détail : [docs/architecture/03-modele-de-donnees.md](../../docs/architecture/03-modele-de-donnees.md)

## 🔧 Lancer l'application

### Mode développement

```bash
# Android
flutter run

# iOS
flutter run -d ios

# Web (pour tests)
flutter run -d chrome
```

### Build de production

```bash
# Android APK
flutter build apk --release

# Android App Bundle (pour Play Store)
flutter build appbundle --release

# iOS
flutter build ios --release
```

## ✅ Vérification de l'installation

### Tests rapides :

1. **Lancer l'app** : L'écran de splash doit apparaître
2. **Créer un compte** : Tester l'inscription
3. **Voir le menu** : les plats doivent se charger depuis l'API
4. **Tester une commande** : Ajouter au panier
5. **Voir la map** : Google Maps doit s'afficher

### Commandes utiles :

```bash
# Vérifier l'environnement Flutter
flutter doctor

# Nettoyer et reconstruire
flutter clean
flutter pub get
flutter run

# Analyser le code
flutter analyze

# Formatter le code
dart format lib

# Voir les logs en temps réel
flutter logs
```

## 🐛 Problèmes courants

### Google Maps ne s'affiche pas
- Vérifier que la clé API est dans AndroidManifest.xml
- Vérifier que les APIs sont activées dans Google Cloud Console
- Vérifier les permissions de localisation

### Erreur "Failed to load environment"
- Vérifier que le fichier `.env` existe
- Vérifier la syntaxe du fichier .env (pas d'espaces autour du =)

### Build Android échoue
- Exécuter `flutter clean`
- Vérifier que `minSdkVersion` est >= 21 dans `android/app/build.gradle`

### L'API répond « 401 Unauthorized »
- Vérifier que le backend tourne (`docker compose ps` dans `backend/`)
- Vérifier `API_BASE_URL` : sur émulateur Android, l'hôte est `10.0.2.2`, pas
  `localhost`
- Se reconnecter : le jeton d'accès a une durée de vie courte, et son
  renouvellement échoue si le jeton de rafraîchissement a expiré

## 📞 Support

Pour toute question d'installation, consulter :
- [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) — guide développeur
- [docs/architecture/](../../docs/architecture/) — architecture, modèle de
  données, plan de migration et ADR
- l'API elle-même : le backend publie son schéma OpenAPI sur `/api/v1/schema/`

---

**Prochaine étape** : Consultez [ARCHITECTURE.md](ARCHITECTURE.md) pour comprendre la structure du projet.
