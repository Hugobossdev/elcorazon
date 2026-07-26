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

- **Node.js** >= 16.x (optionnel)  
  Si vous souhaitez lancer le backend localement

### Comptes et Clés API nécessaires

1. **Supabase** (Base de données et authentification)
   - Créer un compte sur [supabase.com](https://supabase.com)
   - Créer un nouveau projet
   - Récupérer l'URL et la clé anonyme

2. **Google Maps API** (Cartographie et géolocalisation)
   - Console Google Cloud: [console.cloud.google.com](https://console.cloud.google.com)
   - Activer "Maps SDK for Android" et "Maps SDK for iOS"
   - Créer une clé API

3. **PayDunya** (Paiements Mobile Money)
   - Créer un compte sur [paydunya.com](https://paydunya.com)
   - Mode Sandbox pour les tests

4. **Agora** (Appels audio/vidéo - optionnel)
   - Compte sur [agora.io](https://www.agora.io)
   - Créer un projet et récupérer l'App ID

## 🚀 Installation

### 1. Cloner le projet

```bash
git clone <repository-url>
cd "El Corazon fastfood"
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
# Supabase
SUPABASE_URL=https://votre-projet.supabase.co
SUPABASE_ANON_KEY=votre-cle-anon

# Backend
BACKEND_URL=https://backend-qbwe.onrender.com

# PayDunya (Mode test au départ)
PAYDUNYA_MASTER_KEY=votre-master-key
PAYDUNYA_PRIVATE_KEY=votre-private-key
PAYDUNYA_TOKEN=votre-token
PAYDUNYA_IS_SANDBOX=true

# Google Maps
GOOGLE_MAPS_API_KEY=votre-cle-google-maps

# Agora (optionnel)
AGORA_APP_ID=votre-app-id
```

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

## 🗄️ Configuration Supabase

### 1. Créer les tables

Exécutez les scripts SQL suivants dans l'éditeur SQL de Supabase :

**Tables principales** :
- `users` - Utilisateurs (clients, livreurs, admin)
- `menu_categories` - Catégories du menu
- `menu_items` - Plats du menu
- `orders` - Commandes
- `order_items` - Éléments de commande
- `addresses` - Adresses de livraison
- `driver_ratings` - Évaluations des livreurs
- `dish_ratings` - Évaluations des plats

> **💡 Conseil** : Les schémas SQL peuvent être trouvés dans le backend ou générés depuis le dashboard Supabase.

### 2. Configurer les règles RLS (Row Level Security)

Activer RLS sur toutes les tables sensibles :

```sql
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
-- etc.
```

### 3. Configurer l'authentification

Dans Supabase Dashboard → Authentication :
- Activer "Email" provider
- Configurer les redirections

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
3. **Voir le menu** : Les plats doivent se charger depuis Supabase
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

### Supabase "Unauthorized"
- Vérifier que la clé ANON est correcte
- Vérifier les règles RLS dans Supabase

## 📞 Support

Pour toute question d'installation, consulter :
- [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) - Guide développeur
- [API_GUIDE.md](API_GUIDE.md) - Documentation des APIs
- Issues GitHub du projet

---

**Prochaine étape** : Consultez [ARCHITECTURE.md](ARCHITECTURE.md) pour comprendre la structure du projet.
