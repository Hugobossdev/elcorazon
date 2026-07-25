# 🍔 El Corazón - Écosystème de Livraison de Repas

<div align="center">

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.5.0+-02569B?logo=flutter)
![License](https://img.shields.io/badge/license-Private-red.svg)

**Application de livraison de repas avec amour comme ingrédient principal ❤️**

[Documentation](#-documentation) • [Installation](#-installation) • [Configuration](#-configuration) • [Fonctionnalités](#-fonctionnalités)

</div>

---

## 📋 Table des Matières

- [Vue d'ensemble](#-vue-densemble)
- [Architecture](#-architecture)
- [Applications](#-applications)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Fonctionnalités](#-fonctionnalités)
- [Technologies](#-technologies)
- [Structure du Projet](#-structure-du-projet)
- [Documentation](#-documentation)
- [Contribution](#-contribution)
- [Support](#-support)

---

## 🌍 Vue d'ensemble

**El Corazón** est un écosystème complet de livraison de repas composé de **3 applications Flutter** interconnectées via une base de données Supabase commune. Le projet offre une expérience utilisateur complète pour les clients, les livreurs et les administrateurs.

### 🎯 Objectif

Créer une plateforme de livraison de repas moderne, intuitive et riche en fonctionnalités, avec un focus sur :
- 🚀 **Performance** : Applications optimisées et réactives
- 🎨 **UX/UI** : Interfaces modernes et intuitives
- 🔒 **Sécurité** : Authentification et gestion des données sécurisées
- 📊 **Analytics** : Tableaux de bord complets pour la gestion
- 🎮 **Engagement** : Gamification et système de récompenses

---

## 🏗️ Architecture

Le projet suit une architecture modulaire avec **3 applications distinctes** partageant une infrastructure backend unifiée :

```
┌─────────────────────────────────────────────────────────┐
│              Infrastructure Commune (Supabase)           │
│  • Base de données PostgreSQL                          │
│  • Authentification                                     │
│  • Stockage de fichiers                                 │
│  • Realtime subscriptions                              │
└─────────────────────────────────────────────────────────┘
           │              │              │
           ▼              ▼              ▼
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │  Client  │    │ Livreur  │    │  Admin   │
    │   App    │    │   App    │    │  Panel   │
    └──────────┘    └──────────┘    └──────────┘
```

---

## 📱 Applications

### 1. 📱 **elcora_fast** - Application Client

Application mobile pour les clients finaux permettant de commander des repas, suivre les livraisons et gérer leur compte.

**Fonctionnalités principales :**
- 🛒 Catalogue de produits avec recherche avancée
- 🎨 Personnalisation avancée des produits (burgers, pizzas, gâteaux)
- 👥 Commandes groupées avec partage des frais
- 💰 Paiements multiples (PayDunya, Wallet, Paiement partagé)
- 📍 Suivi de livraison en temps réel
- 🎮 Gamification (points, badges, niveaux)
- 🌐 Mode hors-ligne
- ⭐ Avis et notes

**Taux de complétion : ~85%**

---

### 2. 🚚 **elcora_dely** - Application Livreur

Application dédiée aux livreurs pour recevoir, gérer et effectuer les livraisons.

**Fonctionnalités principales :**
- 📦 Gestion des commandes (acceptation, refus, statuts)
- 🗺️ Navigation GPS vers restaurant et client
- 💬 Communication (chat, appels vidéo)
- 💰 Tableau de bord des gains
- 📊 Statistiques de performance
- 🎮 Gamification livreur
- 📱 Notifications Firebase
- 🎤 Commandes vocales

**Taux de complétion : ~90%**

---

### 3. 💻 **admin** - Panneau d'Administration

Tableau de bord complet pour gérer toute l'activité de la plateforme.

**Fonctionnalités principales :**
- 📊 Dashboard avec métriques en temps réel
- 🛒 Gestion complète des commandes (Kanban, filtres)
- 🍔 Gestion du menu (CRUD, catégories, personnalisations)
- 🚚 Gestion des livreurs (validation, planning, statistiques)
- 👥 Gestion des clients
- 📈 Analytics avec graphiques interactifs (fl_chart)
- 🎁 Marketing et promotions
- 🔐 Gestion des rôles et permissions
- 📱 Notifications push

**Taux de complétion : ~95%**

---

## 🚀 Installation

### Prérequis

- **Flutter SDK** : ^3.5.0 (pour elcora_fast) ou >=3.0.0 (pour admin/elcora_dely)
- **Dart SDK** : Compatible avec la version Flutter
- **Compte Supabase** : Pour la base de données
- **Clés API** : Google Maps, PayDunya (optionnel), Agora (optionnel)

### Étapes d'installation

1. **Cloner le repository**
   ```bash
   git clone <repository-url>
   cd projet
   ```

2. **Installer les dépendances pour chaque application**
   ```bash
   # Application Client
   cd elcora_fast
   flutter pub get
   
   # Application Livreur
   cd ../elcora_dely
   flutter pub get
   
   # Application Admin
   cd ../admin
   flutter pub get
   ```

3. **Configurer les fichiers `.env`** (voir section Configuration)

4. **Lancer l'application**
   ```bash
   flutter run
   ```

---

## ⚙️ Configuration

### Fichiers `.env` requis

Chaque application nécessite un fichier `.env` à sa racine avec les clés de configuration.

#### 📱 `elcora_fast/.env`

```env
# Supabase
SUPABASE_URL=https://vsdmcqldshttrbilcvle.supabase.co
SUPABASE_ANON_KEY=votre_cle_anon

# Google Maps
GOOGLE_MAPS_API_KEY=votre_cle_google_maps

# PayDunya (Paiements)
PAYDUNYA_MASTER_KEY=votre_cle_master
PAYDUNYA_PRIVATE_KEY=votre_cle_private
PAYDUNYA_TOKEN=votre_token
PAYDUNYA_IS_SANDBOX=true

# Firebase (Notifications - optionnel)
FIREBASE_API_KEY=votre_cle_firebase
FIREBASE_AUTH_DOMAIN=votre_domaine
FIREBASE_PROJECT_ID=votre_project_id
FIREBASE_STORAGE_BUCKET=votre_bucket
FIREBASE_MESSAGING_SENDER_ID=votre_sender_id
FIREBASE_APP_ID=votre_app_id

# Agora RTC (Appels vidéo - optionnel)
AGORA_APP_ID=votre_app_id_agora

# Backend
BACKEND_URL=http://localhost:3000
ENVIRONMENT=development
```

#### 🚚 `elcora_dely/.env`

```env
# Supabase
SUPABASE_URL=https://vsdmcqldshttrbilcvle.supabase.co
SUPABASE_ANON_KEY=votre_cle_anon

# Google Maps
GOOGLE_MAPS_API_KEY=votre_cle_google_maps

# Agora RTC (optionnel)
AGORA_APP_ID=votre_app_id_agora

# PayDunya (optionnel)
PAYDUNYA_MASTER_KEY=votre_cle_master
PAYDUNYA_PRIVATE_KEY=votre_cle_private
PAYDUNYA_TOKEN=votre_token
```

#### 💻 `admin/.env`

```env
# Supabase
SUPABASE_URL=https://vsdmcqldshttrbilcvle.supabase.co
SUPABASE_ANON_KEY=votre_cle_anon

# Google Maps
GOOGLE_MAPS_API_KEY=votre_cle_google_maps
```

### Configuration de la Base de Données

1. **Créer un projet Supabase** : https://supabase.com
2. **Exécuter le script SQL** : `database_setup_complete.sql` dans le SQL Editor de Supabase
3. **Configurer les RLS (Row Level Security)** selon vos besoins

### Obtention des Clés API

- **Google Maps** : https://console.cloud.google.com/apis/credentials
- **PayDunya** : https://app.paydunya.com/developers
- **Firebase** : https://console.firebase.google.com
- **Agora RTC** : https://console.agora.io

> ⚠️ **Important** : Ne commitez jamais les fichiers `.env` dans Git. Ils sont déjà dans `.gitignore`.

---

## ✨ Fonctionnalités

### 🎯 Fonctionnalités Principales

#### Pour les Clients (elcora_fast)
- ✅ Authentification sécurisée
- ✅ Catalogue de produits avec recherche
- ✅ Personnalisation avancée (burgers, pizzas, gâteaux)
- ✅ Panier et commandes
- ✅ Paiements multiples
- ✅ Suivi de livraison en temps réel
- ✅ Commandes groupées
- ✅ Gamification (points, badges, niveaux)
- ✅ Mode hors-ligne
- ✅ Avis et notes

#### Pour les Livreurs (elcora_dely)
- ✅ Authentification livreur
- ✅ Gestion des livraisons
- ✅ Navigation GPS
- ✅ Communication client-livreur
- ✅ Tableau de bord des gains
- ✅ Statistiques de performance
- ✅ Notifications push

#### Pour les Admins (admin)
- ✅ Dashboard avec métriques
- ✅ Gestion complète des commandes
- ✅ Gestion du menu et produits
- ✅ Gestion des livreurs et clients
- ✅ Analytics avec graphiques
- ✅ Marketing et promotions
- ✅ Gestion des rôles et permissions

### 📊 État d'Implémentation

| Application | Taux de Complétion | Services | Écrans |
|------------|-------------------|----------|--------|
| **elcora_fast** | ~85% | 60+ | 30+ |
| **elcora_dely** | ~90% | 30+ | 15+ |
| **admin** | ~95% | 50+ | 20+ |

> 📖 Pour plus de détails, consultez [ETAT_FONCTIONNALITES.md](./ETAT_FONCTIONNALITES.md)

---

## 🛠️ Technologies

### Frontend
- **Flutter** : Framework multiplateforme
- **Dart** : Langage de programmation
- **Provider** : State management
- **Riverpod** : State management (elcora_fast)

### Backend & Services
- **Supabase** : Base de données, authentification, stockage, realtime
- **Firebase** : Notifications push (elcora_dely)
- **Google Maps** : Géolocalisation et cartes
- **PayDunya** : Paiements Mobile Money
- **Agora RTC** : Communication vidéo/audio

### Bibliothèques Principales
- `fl_chart` : Graphiques interactifs
- `google_maps_flutter` : Cartes et géolocalisation
- `geolocator` : Services de localisation
- `sqflite` : Base de données locale
- `shared_preferences` : Stockage local
- `flutter_secure_storage` : Stockage sécurisé
- `provider` : Gestion d'état
- `flutter_riverpod` : Gestion d'état avancée

---

## 📂 Structure du Projet

```
projet/
├── elcora_fast/          # Application Client
│   ├── lib/
│   │   ├── screens/      # Interfaces utilisateur
│   │   ├── services/     # Logique métier
│   │   ├── models/       # Modèles de données
│   │   └── config/       # Configuration
│   └── pubspec.yaml
│
├── elcora_dely/          # Application Livreur
│   ├── lib/
│   │   ├── screens/      # Interfaces utilisateur
│   │   ├── services/     # Logique métier
│   │   └── models/       # Modèles de données
│   └── pubspec.yaml
│
├── admin/                # Panneau d'Administration
│   ├── lib/
│   │   ├── screens/      # Interfaces utilisateur
│   │   ├── services/     # Logique métier
│   │   └── models/       # Modèles de données
│   └── pubspec.yaml
│
├── database_setup_complete.sql    # Script de création de la BDD
├── DOCUMENTATION_GLOBALE.md       # Documentation technique
├── ETAT_FONCTIONNALITES.md        # État des fonctionnalités
├── FONCTIONNALITES_DETAILLEES.md  # Détails techniques
└── README.md                      # Ce fichier
```

---

## 📚 Documentation

### Documentation Disponible

- **[DOCUMENTATION_GLOBALE.md](./DOCUMENTATION_GLOBALE.md)** : Vue d'ensemble technique complète
- **[ETAT_FONCTIONNALITES.md](./ETAT_FONCTIONNALITES.md)** : État détaillé de toutes les fonctionnalités
- **[FONCTIONNALITES_DETAILLEES.md](./FONCTIONNALITES_DETAILLEES.md)** : Détails techniques et logique métier
- **[SUPABASE_CONFIG_UPDATE.md](./SUPABASE_CONFIG_UPDATE.md)** : Guide de configuration Supabase
- **[SCHEMA_BDD_COMPLET.md](./SCHEMA_BDD_COMPLET.md)** : Schéma complet de la base de données

### Documentation par Application

- **elcora_fast** : Voir `elcora_fast/README.md`
- **elcora_dely** : Voir `elcora_dely/README.md`
- **admin** : Voir `admin/README.md`

---

## 🚧 Développement

### Commandes Utiles

```bash
# Vérifier l'état de Flutter
flutter doctor

# Analyser le code
flutter analyze

# Formater le code
dart format .

# Générer les icônes
flutter pub run flutter_launcher_icons

# Générer le splash screen
flutter pub run flutter_native_splash:create

# Lancer les tests
flutter test
```

### Structure des Services

Chaque application suit une architecture modulaire avec :
- **Services** : Logique métier et communication avec l'API
- **Models** : Modèles de données
- **Screens** : Interfaces utilisateur
- **Widgets** : Composants réutilisables
- **Utils** : Utilitaires et helpers

---

## 🐛 Dépannage

### Problèmes Courants

#### Erreur : "Supabase not initialized"
- Vérifier que le fichier `.env` existe
- Vérifier que les clés Supabase sont correctes
- Vérifier la connexion internet

#### Erreur : "Invalid API key" (Google Maps)
- Vérifier que la clé API est valide
- Vérifier que les restrictions de la clé API sont correctes
- Vérifier que la facturation est activée sur Google Cloud

#### Erreur : "PayDunya service unavailable"
- Vérifier que les clés PayDunya sont configurées
- Vérifier que le mode sandbox/production est correct

### Logs et Debug

Les applications utilisent `debugPrint` pour les logs. Activez le mode debug pour voir les logs détaillés.

---

## 🤝 Contribution

Ce projet est privé. Pour toute contribution ou suggestion, contactez l'équipe de développement.

### Standards de Code

- Suivre les conventions Dart/Flutter
- Commenter le code complexe
- Utiliser des noms de variables descriptifs
- Tester avant de commit

---

## 📞 Support

Pour toute question ou problème :
1. Consultez la documentation disponible
2. Vérifiez les logs de l'application
3. Contactez l'équipe de développement

---

## 📄 Licence

Ce projet est privé et propriétaire. Tous droits réservés.

---

## 🎯 Roadmap

### Prochaines Étapes

- [ ] Finaliser l'intégration PayDunya
- [ ] Compléter l'upload d'images produits
- [ ] Intégrer la carte interactive des livreurs
- [ ] Ajouter des tests unitaires
- [ ] Optimiser les performances
- [ ] Améliorer la documentation API

---

## 🙏 Remerciements

Merci d'utiliser El Corazón ! ❤️

---

<div align="center">

**Fait avec ❤️ par l'équipe El Corazón**

[⬆ Retour en haut](#-el-corazón---écosystème-de-livraison-de-repas)

</div>


