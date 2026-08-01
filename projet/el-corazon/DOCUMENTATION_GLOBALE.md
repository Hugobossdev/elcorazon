# 🍔 Écosystème El Corazón - Documentation Technique Complète

Cette documentation détaille l'architecture et les fonctionnalités des 3 projets composant l'écosystème de livraison **El Corazón**.

🔗 **[VOIR LES FONCTIONNALITÉS DÉTAILLÉES (Technique & Logique Métier)](./FONCTIONNALITES_DETAILLEES.md)**

---

## 🌍 Vue d'ensemble de l'écosystème

Le projet est divisé en trois applications distinctes, adossées à un backend
Django commun (`backend/`) et à un socle Dart partagé
(`packages/elcorazon_core`) :

1.  **📱 elcora_fast (Customer App)** : L'application client pour commander des repas.
2.  **🚚 elcora_dely (Driver App)** : L'application pour les livreurs.
3.  **💻 admin (Admin Panel)** : Le tableau de bord de gestion pour les administrateurs et restaurateurs.

---

## 1. 📱 Projet : `elcora_fast` (Application Client)

C'est l'application principale destinée aux clients finaux pour passer commande.

### 📋 Description
Une application Flutter riche en fonctionnalités permettant aux utilisateurs de parcourir les menus, personnaliser leurs commandes, payer via diverses méthodes et suivre leur livraison en temps réel.

### 🛠️ Stack Technique
*   **Framework** : Flutter (SDK ^3.5.0)
*   **Accès aux données** : `elcorazon_core` → API Django `/api/v1/*` (REST + WebSocket)
*   **State Management** : Provider & Riverpod
*   **Cartes & Localisation** : `google_maps_flutter`, `geolocator`
*   **Temps Réel** : `socket_io_client`, `agora_rtc_engine` (Communication)
*   **Paiement** : PayDunya (via services), Wallet interne
*   **Stockage Local** : `shared_preferences`, `flutter_secure_storage`, `sqflite`

### ✨ Fonctionnalités Clés
*   **Commandes Groupées** : Plusieurs utilisateurs peuvent ajouter des articles à un même panier.
*   **Personnalisation Avancée** : Interface dédiée pour les produits complexes (ex: gâteaux sur mesure).
*   **Suivi Temps Réel** : Visualisation du livreur sur la carte en direct.
*   **Gamification** : Système de points et récompenses pour la fidélité.
*   **Paiement Partagé** : Possibilité de diviser l'addition entre plusieurs utilisateurs.
*   **Mode Hors-ligne** : Support partiel pour consulter le menu sans connexion.
*   **Social** : Fonctionnalités de partage et d'interaction.

### 📂 Structure Principale
*   `lib/screens` : Interfaces utilisateur (Home, Cart, Profile, etc.).
*   `lib/services` : Logique métier (CartService, OrderService, PaymentService).
*   `lib/models` : Modèles de données.
*   `lib/providers` : Gestion d'état.

---

## 2. 💻 Projet : `admin` (Panneau d'Administration)

Le centre de contrôle pour gérer toute l'activité de la plateforme.

### 📋 Description
Une application Flutter (optimisée pour Desktop/Web) permettant la gestion complète du restaurant, des utilisateurs, des commandes et des statistiques.

### 🛠️ Stack Technique
*   **Framework** : Flutter (SDK >=3.0.0 <4.0.0)
*   **Accès aux données** : `elcorazon_core` → API Django `/api/v1/*`
*   **State Management** : Provider, BLoC
*   **Graphiques** : `fl_chart`, `syncfusion_flutter_charts`
*   **Rapports** : `pdf`, `printing`
*   **UI** : `flex_color_scheme`, `animations`

### ✨ Fonctionnalités Clés
*   **Dashboard Analytics** : Vues graphiques des revenus, commandes, et performances (Fl_chart).
*   **Gestion des Produits** : CRUD complet, gestion des stocks, upload d'images, catégories.
*   **Gestion des Commandes** : Vue Kanban/Liste, changement de statuts, gestion des remboursements.
*   **Gestion des Livreurs** : Suivi de flotte en temps réel, attribution des zones.
*   **Rôles & Permissions** : Système granulaire (Super Admin, Manager, Opérateur).
*   **Marketing** : Gestion des promotions et notifications push.

### 📂 Structure Principale
*   `lib/screens/admin` : Écrans spécifiques à l'administration (Dashboard, ProductForm, etc.).
*   `lib/services` : Services partagés et spécifiques (AdminAuth, Analytics, Report).
*   `lib/models` : Modèles étendus pour l'administration.

---

## 3. 🚚 Projet : `elcora_dely` (Application Livreur)

L'outil de travail pour les coursiers partenaires.

### 📋 Description
Application dédiée aux livreurs pour recevoir, gérer et effectuer les livraisons efficacement.

### 🛠️ Stack Technique
*   **Framework** : Flutter (SDK ^3.9.2) - *Note: Version plus récente spécifiée*
*   **Accès aux données** : `elcorazon_core` → API Django ; Firebase Cloud Messaging pour le push
*   **Navigation** : `google_maps_flutter`, `geolocator`
*   **Communication** : `agora_rtc_engine` (Appels), `speech_to_text` (Commandes vocales)
*   **Notifications** : `firebase_messaging`, `flutter_local_notifications`

### ✨ Fonctionnalités Clés
*   **Gestion des Courses** : Acceptation/Refus des commandes entrantes.
*   **Navigation Intelligente** : Itinéraires optimisés vers le restaurant et le client.
*   **Communication** : Chat et appels intégrés avec le client/support via Agora.
*   **Suivi des Gains** : Tableau de bord des revenus et historique des courses.
*   **Mode "En Ligne/Hors Ligne"** : Gestion de la disponibilité.
*   **Gamification Livreur** : Objectifs et récompenses pour la performance.

### 📂 Structure Principale
*   `lib/screens/delivery` : Écrans de livraison (Home, Navigation, Earnings).
*   `lib/screens/communication` : Chat et appels.
*   `lib/services` : Services de géolocalisation, tracking, et communication.

---

## 🗄️ Infrastructure Commune

Les trois projets partagent une infrastructure backend unifiée.

### Backend Django (`backend/`)
*   **API REST** `/api/v1/*` (DRF) — contrat versionné, schéma OpenAPI, erreurs
    RFC 9457 (ADR-009). **Les applications n'accèdent à aucune base.**
*   **WebSockets** `/ws/*` (Channels) — suivi de course, file du livreur,
    signalisation d'appel.
*   **18 applications métier** — un domaine par app, graphe de dépendances
    acyclique vérifié en CI (ADR-002).
*   **Authentification** : JWT (ADR-004). Le type de compte est porté par le
    jeton ; les permissions du personnel par des rôles cumulables, nommés
    `domaine.action` (ADR-005).
*   **PostgreSQL 17 + PostGIS** — les invariants métier (prix, exclusivité
    d'affectation, plafond de remboursement) sont défendus par des contraintes
    de base, pas seulement par du code applicatif.
*   **Redis** (cache, Celery, canaux) et **MinIO** (stockage privé, URL signées
    qui expirent).

### Services Externes

Tous rattachés **côté serveur** : aucune clé de prestataire ne voyage dans une
application distribuée.

*   **Google Maps Platform** : Pour la géolocalisation, le géocodage et les itinéraires.
*   **Firebase Cloud Messaging (FCM)** : Pour les notifications push (commandes, statuts).
*   **Agora** : Pour les fonctionnalités d'appel audio/vidéo.
*   **PayDunya** : Pour le traitement des paiements en Afrique de l'Ouest.

---

## 🚀 Guide de Démarrage Rapide

### Prérequis
*   Flutter SDK installé.
*   Docker + Docker Compose, pour le backend (`cd backend && docker compose up`).
*   `API_BASE_URL` renseignée dans le `.env` de chaque application.
*   Clé Google Maps pour les cartes. Les clés PayDunya, Agora et Firebase se
    configurent **côté backend** : elles n'ont rien à faire dans un binaire
    distribué.

### Installation
Pour chaque projet (`admin`, `elcora_fast`, `elcora_dely`) :

1.  Accédez au dossier du projet :
    ```bash
    cd nom_du_projet
    ```
2.  Installez les dépendances :
    ```bash
    flutter pub get
    ```
3.  Configurez l'environnement (créez un fichier `.env` à la racine si nécessaire avec vos clés).
4.  Lancez l'application :
    ```bash
    flutter run
    ```

### Commandes Utiles
*   **Générer les icônes** : `flutter pub run flutter_launcher_icons`
*   **Vérifier l'état** : `flutter doctor`
