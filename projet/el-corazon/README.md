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

**El Corazón** est un écosystème complet de livraison de repas : **3 applications Flutter** (client, livreur, back-office) et un **backend Django** qui porte l'intégralité des règles métier.

> **Le serveur décide, les applications affichent.** Prix, remises, statuts de commande, éligibilité d'un livreur, points de fidélité, remboursements : tout est établi côté serveur. Les applications n'accèdent à aucune base de données et ne détiennent aucune clé de prestataire.

### 🎯 Objectif

Créer une plateforme de livraison de repas moderne, intuitive et riche en fonctionnalités, avec un focus sur :
- 🚀 **Performance** : Applications optimisées et réactives
- 🎨 **UX/UI** : Interfaces modernes et intuitives
- 🔒 **Sécurité** : Authentification et gestion des données sécurisées
- 📊 **Analytics** : Tableaux de bord complets pour la gestion
- 🎮 **Engagement** : Gamification et système de récompenses

---

## 🏗️ Architecture

Trois applications distinctes, un socle Dart partagé, un backend commun :

```
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │  Client  │    │ Livreur  │    │  Admin   │
    │(fastfood)│    │  (dely)  │    │(back-off)│
    └────┬─────┘    └────┬─────┘    └────┬─────┘
         └───────────────┼───────────────┘
                         ▼
         ┌───────────────────────────────┐
         │  packages/elcorazon_core      │
         │  client HTTP · session ·      │
         │  dépôts par domaine           │
         └───────────────┬───────────────┘
                         ▼  HTTPS + WebSocket
    ┌─────────────────────────────────────────────┐
    │        Backend Django (ASGI) — backend/     │
    │  DRF /api/v1/*  ·  Channels /ws/*  ·  Celery│
    │  19 apps métier · invariants en contraintes │
    └─────────────────────┬───────────────────────┘
                          ▼
    ┌─────────────────────────────────────────────┐
    │  PostgreSQL 17 + PostGIS · Redis · MinIO    │
    └─────────────────────────────────────────────┘
                          ▼
    Services externes (serveur uniquement) :
    PayDunya · Agora RTC · Firebase · Google Maps
```

Les applications ne parlent **qu'**à l'API. Aucune n'ouvre de connexion à une
base de données, et aucune ne détient de secret de prestataire : le certificat
Agora signe les jetons d'appel côté serveur, les clés marchandes PayDunya ne
quittent pas le backend.

📖 Détail : [`docs/architecture/`](./docs/architecture/) — analyse
fonctionnelle, architecture générale, modèle de données, plan de migration, et
les ADR qui justifient les choix structurants.

---

## 📱 Applications

### 1. 📱 **elcora_fast** - Application Client

Application mobile pour les clients finaux permettant de commander des repas, suivre les livraisons et gérer leur compte.

**Fonctionnalités principales :**
- 🛒 Catalogue de produits avec recherche avancée
- 🎨 Personnalisation avancée des produits (burgers, pizzas, gâteaux)
- 👥 Commandes groupées avec partage des frais
- 💰 Paiement mobile et paiement partagé entre convives — encaissement côté serveur
- 📍 Suivi de livraison en temps réel
- 🎮 Gamification (points, badges, niveaux)
- 🌐 Mode hors-ligne
- ⭐ Avis et notes


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


---

## 🚀 Installation

### Prérequis

- **Flutter SDK** : ^3.5.0
- **Dart SDK** : compatible avec la version Flutter
- **Docker + Docker Compose** : pour le backend (PostgreSQL + PostGIS, Redis,
  API, workers)
- **Clé Google Maps** : cartes et géocodage côté application

Les clés PayDunya, Agora et Firebase se configurent **côté backend**
(`backend/.env`) : elles n'ont rien à faire dans une application distribuée.

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

#### 📱 Les trois applications

Chaque application n'a besoin que de l'adresse de l'API et, pour les cartes,
d'une clé Google Maps :

```env
# Backend Django — la seule source de données de l'application
API_BASE_URL=http://localhost:8000/api/v1

# Cartes et géocodage
GOOGLE_MAPS_API_KEY=votre_cle_google_maps
```

> **Ce qui n'y est plus, et pourquoi.** Les versions précédentes demandaient d'y
> placer les clés Supabase, le certificat Agora et les **quatre clés marchandes
> PayDunya**. Une clé dans un `.env` d'application est une clé dans le binaire
> distribué : l'extraire suffisait à fabriquer ses propres jetons d'appel, ou à
> déclencher un remboursement sans permission, sans rattachement, sans trace et
> sans plafond. Ces secrets vivent désormais dans `backend/.env`.

#### 🖥️ Backend (`backend/.env`)

C'est là que se configurent la base, Redis, les jetons JWT et **tous** les
prestataires. Voir [`docs/env/`](./docs/env/) et
`backend/config/settings/base.py`.

### Démarrer le backend

```bash
cd backend
docker compose up          # PostgreSQL + PostGIS, Redis, API, workers
docker compose exec api python manage.py migrate
docker compose exec api python manage.py seed_demo   # jeu de données de démonstration
```

L'API écoute sur `http://localhost:8000/api/v1/`, son schéma OpenAPI sur
`/api/v1/schema/` et sa documentation interactive sur `/api/v1/docs/` (en mode
`DEBUG`).

### Obtention des Clés API

| Service | Où l'obtenir | Où la clé se configure |
| --- | --- | --- |
| Google Maps | https://console.cloud.google.com/apis/credentials | Application **et** serveur |
| PayDunya | https://app.paydunya.com/developers | **Serveur uniquement** |
| Firebase | https://console.firebase.google.com | **Serveur uniquement** |
| Agora RTC | https://console.agora.io | **Serveur uniquement** — l'app reçoit un jeton borné à un canal et à une durée |

> ⚠️ Ne commitez jamais les fichiers `.env`. Ils sont dans `.gitignore`.

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

| Application | Services | Écrans | Tests | Analyse |
|------------|---------:|-------:|------:|---------|
| **elcora_fast** | 55 | 42 | 15 | 0 erreur, 0 avertissement |
| **elcora_dely** | 25 | 15 | 9 | 0 erreur, 0 avertissement |
| **admin** | 39 | 38 | 15 | 0 erreur, 0 avertissement |
| **elcorazon_core** (socle) | 23 domaines | — | 121 | 0 erreur |

Le backend porte **1 230 tests** pour **95,4 %** de couverture (plancher CI :
92 %), `ruff` et `mypy` sans écart. Les deux workflows GitHub Actions sont
bloquants : un test rouge arrête la CI.

> Les taux de complétion en pourcentage ont été retirés de ce tableau : ils
> étaient invérifiables et n'ont jamais rien mesuré. Les colonnes ci-dessus se
> recomptent en une commande.

> 📖 Détail fonctionnel : [ETAT_FONCTIONNALITES.md](./ETAT_FONCTIONNALITES.md) ·
> Mise en service : [docs/deploiement.md](./docs/deploiement.md) ·
> Sécurité : [docs/security/](./docs/security/)

---

## 🛠️ Technologies

### Frontend
- **Flutter** : Framework multiplateforme
- **Dart** : Langage de programmation
- **Provider** : State management
- **Riverpod** : State management (elcora_fast)

### Backend & Services
- **Django 5.2 + DRF + Channels** : API REST, WebSockets, authentification JWT
- **PostgreSQL 17 + PostGIS** : données et géospatial ; les invariants métier
  sont défendus par des contraintes de base
- **Redis** : cache, courtier Celery, couche de canaux
- **MinIO** : stockage privé, URL signées expirantes
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
- **[docs/architecture/](./docs/architecture/)** : architecture, modèle de données, ADR et plan de migration
- **[docs/deploiement.md](./docs/deploiement.md)** : mise en service — compose de production, TLS, sauvegarde et restauration
- **[docs/security/](./docs/security/)** : rotation des clés du prestataire de paiement, restriction de la clé Google Maps
- **[SCHEMA_BDD_COMPLET.md](./SCHEMA_BDD_COMPLET.md)** : schéma de la base — **document historique**, antérieur au backend Django

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

#### L'application affiche des listes vides
- Vérifier que le backend tourne (`cd backend && docker compose ps`)
- Vérifier `API_BASE_URL` dans le `.env` de l'application
- Regarder la réponse de l'API : un `403` signale une **permission manquante**
  sur le compte, pas une panne (voir ADR-005)

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

### Fait

- [x] Backend Django : 19 domaines, 343 routes, contrat OpenAPI, 1 230 tests
- [x] Les trois applications sur le backend Django — Supabase et Node retirés
- [x] Clés du prestataire de paiement sorties des applications
- [x] Tests et analyse bloquants en CI sur les trois applications
- [x] Domaines `social` et commande groupée branchés côté client
- [x] Déploiement de production écrit (compose, Nginx TLS, sauvegarde)

### Ce qui reste

Rien de tout cela n'est de la construction : c'est de l'**éprouvement** et de
l'exploitation.

- [ ] **Exécuter un déploiement réel** — la procédure est écrite, elle n'a jamais
      tourné sur une infrastructure. Voir [docs/deploiement.md](./docs/deploiement.md)
- [ ] **Régénérer les clés PayDunya** — celles qui ont été publiées dans des
      binaires sont compromises. Voir [docs/security/paydunya_rotation.md](./docs/security/paydunya_rotation.md)
- [ ] **Restreindre la clé Google Maps** — empreinte Android, Bundle ID iOS,
      référent HTTP, quotas. Voir [docs/security/google_maps.md](./docs/security/google_maps.md)
- [ ] **Valider le push FCM** contre un vrai projet Firebase
- [ ] **Sauvegarde hors site** — `backup.sh` écrit sur le serveur sauvegardé
- [ ] **Supervision** — ni métriques, ni alertes, ni agrégation de journaux
- [ ] Géocodage côté web : Google n'autorise pas l'appel navigateur (CORS), il
      demande un relais serveur qui n'existe pas encore

---

## 🙏 Remerciements

Merci d'utiliser El Corazón ! ❤️

---

<div align="center">

**Fait avec ❤️ par l'équipe El Corazón**

[⬆ Retour en haut](#-el-corazón---écosystème-de-livraison-de-repas)

</div>


