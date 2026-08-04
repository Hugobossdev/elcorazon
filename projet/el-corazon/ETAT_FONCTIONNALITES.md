# 📊 État des Fonctionnalités - Écosystème El Corazón

**Dernière révision** : 1er août 2026

> ⚠️ **Inventaire fonctionnel daté.** Le corps de ce document a été écrit en
> décembre 2024, quand les trois applications parlaient directement à Supabase.
> Les fonctionnalités listées existent toujours pour la plupart, mais **leur
> mise en œuvre a changé de fond en comble** : elles passent désormais par le
> backend Django (`backend/`), et plusieurs ont été retirées parce qu'elles ne
> tenaient pas — voir la liste plus bas.
>
> La référence à jour est **[docs/architecture/04-migration-flutter.md](docs/architecture/04-migration-flutter.md)**,
> qui trace domaine par domaine ce qui a été migré, construit ou supprimé.

## 🏗️ Ce qui a changé depuis cet inventaire

**Supabase a été retiré des trois applications** (1er août 2026). Elles ne
parlent plus qu'au backend Django : `supabase_flutter` a quitté les trois
`pubspec.yaml`, et `grep -rn "package:supabase" */lib` ne rend plus rien.

Le déplacement n'était pas cosmétique. Ce que le client décidait, le serveur le
décide :

- **les prix et les remises** (invariant C1) — le catalogue et les codes
  promotionnels ne se calculent plus à l'écran ;
- **les permissions** (ADR-005) — les rôles du back-office n'étaient appliqués
  que côté interface ; un « Opérateur » privé d'un module appelait quand même
  son API ;
- **le cloisonnement par établissement** — un opérateur de Kara lisait les
  commandes de Lomé ;
- **les secrets** — clés marchandes PayDunya, certificat Agora et clés Supabase
  vivaient dans des binaires distribués ; ils sont côté serveur.

**Fonctionnalités retirées**, faute d'équivalent et parce qu'elles ne
fonctionnaient pas comme annoncé : le portefeuille client, la validation
document par document des dossiers livreurs, les dates d'expiration de pièces,
les prévisions de vente et le « risque d'attrition » calculés dans le
navigateur, et l'auto-inscription des livreurs (un livreur s'embauche, il ne
s'inscrit pas).

## 🔄 Deuxième vague (3 août 2026)

**PayDunya a quitté les applications.** Elles embarquaient encore les clés
marchandes (`MASTER_KEY`, `PRIVATE_KEY`, `TOKEN`) et appelaient
`app.paydunya.com` depuis l'appareil : extraire ces clés d'un binaire distribué
permettait d'encaisser et de rembourser au nom de l'enseigne, sans permission,
sans trace et sans plafond. Le règlement passe maintenant par
`POST /payments/{commande}/initiate/`, et **seul le webhook signé fait avancer
une transaction** — le retour de l'utilisateur sur l'application n'écrit aucun
état.

> ⚠️ Les clés qui étaient dans les binaires publiés doivent être considérées
> comme compromises. Procédure : [docs/security/paydunya_rotation.md](docs/security/paydunya_rotation.md).

**Les reliquats de l'ancien backend Node ont disparu** : le mandataire
`localhost:3000` des API Google, le socket `10.0.2.2:3000` du back-office et la
dépendance `socket_io_client`.

**Deux domaines servis mais inexploités sont branchés.** `social` et
`group-carts` étaient complets et testés côté serveur depuis la Phase 4 sans
qu'aucune application ne les appelle :

- **Groupes** — création, adhésion par code d'invitation, sortie, fil de
  publications, j'aime, commentaires. Le code d'invitation vient du serveur et
  n'est servi qu'aux membres du groupe ;
- **Commande groupée** — ouverture, invitation, ajout d'articles, verrouillage,
  confirmation en commande, paiement partagé.

**Les trois applications ont des tests, et la CI les exécute.** `flutter test`
est bloquant sur `fastfood`, `dely` et `admin` en plus du socle partagé.

**Le déploiement de production est écrit** — `docker-compose.prod.yml`, Nginx
avec TLS et renouvellement Let's Encrypt, scripts `deploy.sh`, `backup.sh`,
`restore.sh`. Il n'a pas encore tourné sur une infrastructure réelle : voir
[docs/deploiement.md](docs/deploiement.md).

---

Ce document présente l'état d'implémentation des fonctionnalités des 3
applications de l'écosystème El Corazón.

---

## 📱 1. EL CORA FAST (Application Client)

### ✅ Fonctionnalités Complètement Implémentées

#### 🔐 Authentification & Profil
- ✅ Connexion/Inscription (Email/Mot de passe)
- ✅ Gestion du profil utilisateur
- ✅ Vérification OTP
- ✅ Mode invité (Guest mode)
- ✅ Gestion des adresses de livraison
- ✅ Sélecteur d'adresses multiples

#### 🛒 Catalogue & Menu
- ✅ Affichage du menu complet
- ✅ Catégorisation des produits
- ✅ Recherche avancée de produits
- ✅ Filtres par catégorie
- ✅ Détails des produits
- ✅ Cache local du menu (mode hors-ligne)

#### 🎨 Personnalisation de Produits
- ✅ Personnalisation avancée (burgers, pizzas, gâteaux)
- ✅ Options de personnalisation (taille, cuisson, sauce, garniture)
- ✅ Modification des prix selon les options
- ✅ Validation des personnalisations
- ✅ Interface dédiée pour gâteaux sur mesure

#### 🛍️ Panier & Commandes
- ✅ Gestion du panier (ajout, modification, suppression)
- ✅ Calcul automatique des totaux
- ✅ Application de codes promo
- ✅ Historique des commandes
- ✅ Détails des commandes
- ✅ Statuts de commande en temps réel

#### 💰 Paiements
- ✅ Intégration PayDunya (structure prête)
- ✅ Paiement partagé (split payment)
- ✅ Portefeuille interne (wallet)
- ✅ Historique des transactions
- ⚠️ **TODO** : Implémentation complète de l'API PayDunya (actuellement simulée)

#### 🚚 Suivi de Livraison
- ✅ Suivi en temps réel sur carte
- ✅ Position du livreur en direct
- ✅ Estimation du temps de livraison
- ✅ Notifications de statut
- ✅ Historique des livraisons

#### 👥 Commandes Groupées
- ✅ Création de groupes de livraison
- ✅ Rejoindre un groupe existant
- ✅ Partage des frais de livraison
- ✅ Gestion des participants
- ✅ Commandes planifiées avec récurrence

#### 🎮 Gamification
- ✅ Système de points (XP)
- ✅ Niveaux utilisateur (6 niveaux)
- ✅ Badges et achievements
- ✅ Challenges temporaires
- ✅ Streak (série de jours consécutifs)
- ✅ Récompenses échangeables
- ✅ Tableau des récompenses

#### 📱 Notifications
- ✅ Notifications locales
- ✅ Notifications push (structure)
- ✅ Centre de notifications
- ✅ Historique des notifications
- ⚠️ **TODO** : Configuration complète Firebase pour push notifications

#### 💬 Communication
- ✅ Chat avec le livreur
- ✅ Chat avec le support
- ✅ Appels vidéo/audio (Agora - structure)
- ⚠️ **TODO** : Configuration complète Agora RTC

#### 🌐 Mode Hors-Ligne
- ✅ Cache local (SQLite)
- ✅ Synchronisation automatique
- ✅ Consultation du menu hors-ligne
- ✅ Passage de commande hors-ligne (queue)
- ✅ Gestion de la connectivité

#### 🔍 Recherche & Découverte
- ✅ Recherche avancée
- ✅ Filtres multiples
- ✅ Suggestions intelligentes
- ✅ Recommandations IA (structure)
- ⚠️ **TODO** : Amélioration des recommandations IA

#### ⭐ Avis & Notes
- ✅ Notation des produits
- ✅ Notation des livreurs
- ✅ Commentaires et avis
- ✅ Affichage des notes moyennes

#### 🎁 Promotions & Codes Promo
- ✅ Application de codes promo
- ✅ Gestion des promotions
- ✅ Notifications de promotions
- ✅ Historique des codes utilisés

#### 🗺️ Géolocalisation
- ✅ Détection de position GPS
- ✅ Géocodage d'adresses
- ✅ Calcul d'itinéraires
- ✅ Estimation des frais de livraison
- ⚠️ **TODO** : Configuration Google Maps API Key

#### 📊 Autres Fonctionnalités
- ✅ Favoris
- ✅ Support client
- ✅ Réclamations et retours
- ✅ Thème clair/sombre
- ✅ Gestion des erreurs
- ✅ Performance monitoring
- ✅ Validation de formulaires

### ⚠️ Fonctionnalités Partiellement Implémentées

1. **Paiements PayDunya** — *migré, voir la deuxième vague en tête de document*
   - L'application appelle `POST /payments/{commande}/initiate/` et suit l'état
     rendu par le serveur. Elle ne joint plus le prestataire et ne porte plus
     ses clés.
   - **Action requise** : les clés dans le `.env` du **backend**, jamais dans
     celui d'une application.

2. **Notifications Push**
   - Service présent
   - Firebase non complètement configuré
   - **Action requise** : Configurer Firebase dans `.env`

3. **Appels Vidéo (Agora)**
   - Service présent
   - Configuration Agora manquante
   - **Action requise** : Configurer Agora App ID dans `.env`

4. **Recommandations IA**
   - Service de base présent
   - Algorithme à améliorer
   - **Action requise** : Affiner les algorithmes de recommandation

### 📈 Taux de Complétion : **~85%**

---

## 🚚 2. EL CORA DELY (Application Livreur)

### ✅ Fonctionnalités Complètement Implémentées

#### 🔐 Authentification
- ✅ Connexion livreur
- ✅ Inscription livreur
- ✅ Gestion du profil livreur
- ✅ Validation des documents

#### 📦 Gestion des Livraisons
- ✅ Réception des commandes
- ✅ Acceptation/Refus de commandes
- ✅ Liste des commandes actives
- ✅ Détails des commandes
- ✅ Changement de statut
- ✅ Mode En ligne/Hors ligne

#### 🗺️ Navigation
- ✅ Navigation GPS vers restaurant
- ✅ Navigation GPS vers client
- ✅ Calcul d'itinéraires
- ✅ Suivi de position en temps réel
- ✅ Carte interactive
- ⚠️ **TODO** : Configuration Google Maps API Key

#### 💬 Communication
- ✅ Chat avec le client
- ✅ Chat avec le support
- ✅ Appels vidéo/audio (Agora - structure)
- ⚠️ **TODO** : Configuration complète Agora RTC

#### 💰 Gains & Paiements
- ✅ Tableau de bord des gains
- ✅ Historique des livraisons
- ✅ Calcul des revenus
- ✅ Statistiques de performance
- ✅ Paiements (structure)

#### 📊 Analytics
- ✅ Statistiques personnelles
- ✅ Performance de livraison
- ✅ Temps moyen de livraison
- ✅ Nombre de livraisons

#### 🎮 Gamification Livreur
- ✅ Système de points
- ✅ Objectifs et récompenses
- ✅ Badges livreur
- ✅ Classements

#### 📱 Notifications
- ✅ Notifications Firebase (configuré)
- ✅ Notifications locales
- ✅ Notifications de nouvelles commandes
- ✅ Notifications de statut

#### 🎤 Commandes Vocales
- ✅ Reconnaissance vocale
- ✅ Commandes vocales
- ✅ Service de synthèse vocale

#### 📍 Géolocalisation
- ✅ Mise à jour position en temps réel
- ✅ Partage de position
- ✅ Géocodage d'adresses

### ⚠️ Fonctionnalités Partiellement Implémentées

1. **Appels Vidéo (Agora)**
   - Service présent
   - Configuration Agora manquante
   - **Action requise** : Configurer Agora App ID dans `.env`

2. **Google Maps**
   - Service présent
   - Clé API partiellement configurée
   - **Action requise** : Vérifier la clé dans `.env`

### 📈 Taux de Complétion : **~90%**

---

## 💻 3. ADMIN (Panneau d'Administration)

### ✅ Fonctionnalités Complètement Implémentées

#### 🔐 Authentification & Rôles
- ✅ Connexion admin sécurisée
- ✅ Gestion des rôles (Super Admin, Manager, Opérateur)
- ✅ Système de permissions granulaire
- ✅ Journal d'audit des actions
- ✅ Gestion des sessions

#### 📊 Tableau de Bord
- ✅ Vue d'ensemble des métriques
- ✅ Statistiques en temps réel
- ✅ Graphiques de revenus (structure)
- ✅ Graphiques de commandes (structure)
- ⚠️ **TODO** : Compléter les graphiques fl_chart

#### 🛒 Gestion des Commandes
- ✅ Vue Kanban des commandes
- ✅ Vue Liste des commandes
- ✅ Filtres avancés
- ✅ Changement de statut
- ✅ Attribution de livreurs
- ✅ Gestion des remboursements
- ✅ Notes internes
- ✅ Recherche globale

#### 🍔 Gestion du Menu
- ✅ CRUD complet des produits
- ✅ Gestion des catégories
- ✅ Upload d'images (structure)
- ✅ Gestion des stocks
- ✅ Personnalisations de produits
- ✅ Groupes d'options
- ⚠️ **TODO** : Compléter l'upload d'images (stockage serveur, URL signées)

#### 🚚 Gestion des Livreurs
- ✅ Liste des livreurs
- ✅ Ajout/Modification/Suppression
- ✅ Validation des documents
- ✅ Tableau de bord des documents
- ✅ Historique des validations
- ✅ Planning des livreurs
- ✅ Statistiques par livreur
- ✅ Carte des livreurs (structure)
- ✅ **COMPLÉTÉ** : Carte interactive Google Maps
  - ✅ Suivi en temps réel des positions des livreurs
  - ✅ Affichage des commandes actives sur la carte
  - ✅ Itinéraires pour les livreurs en livraison
  - ✅ Légende des statuts visible
  - ✅ Filtres par zone et statut
  - ✅ Mise à jour automatique toutes les 10 secondes
  - ✅ Info bulles détaillées pour livreurs et commandes
  - ✅ Bouton pour ajuster la vue sur tous les livreurs

#### 👥 Gestion des Clients
- ✅ Liste des clients
- ✅ Détails des clients
- ✅ Historique des commandes client
- ✅ Statistiques par client
- ✅ Gestion des rôles clients

#### 📈 Analytics & Rapports
- ✅ Analytics Service complet
- ✅ Métriques de revenus
- ✅ Performance des produits
- ✅ Performance des livreurs
- ✅ Engagement utilisateurs
- ✅ Graphiques fl_chart complétés (LineChart, BarChart, PieChart)
- ✅ Export de rapports (structure)

#### 🎁 Marketing & Promotions
- ✅ Gestion des promotions
- ✅ Gestion des campagnes marketing
- ✅ Codes promo
- ✅ Notifications push marketing
- ✅ Gamification management

#### ⚙️ Paramètres
- ✅ Paramètres généraux
- ✅ Configuration de l'application
- ✅ Gestion des zones de livraison
- ✅ Configuration des frais

#### 🔍 Recherche Globale
- ✅ Recherche unifiée
- ✅ Recherche dans toutes les entités
- ✅ Filtres avancés

#### 📱 Notifications
- ✅ Envoi de notifications
- ✅ Notifications push
- ✅ Historique des notifications

### ⚠️ Fonctionnalités Partiellement Implémentées

1. ~~**Graphiques Interactifs (fl_chart)**~~ ✅ **COMPLÉTÉ**
   - ✅ Tous les graphiques fl_chart sont maintenant implémentés
   - ✅ LineChart pour les revenus
   - ✅ BarChart pour les commandes et livreurs
   - ✅ PieChart pour les catégories

2. ~~**Upload d'Images Produits**~~ ✅ **COMPLÉTÉ**
   - ✅ Upload vers le stockage serveur implémenté (privé, URL signées)
   - ✅ Sélection depuis galerie ou caméra
   - ✅ Aperçu de l'image avant upload
   - ✅ Compression automatique (85% qualité, max 1920px)
   - ✅ Validation de taille (max 5MB)
   - ✅ Suppression automatique de l'ancienne image lors de la mise à jour
   - ✅ Gestion d'erreurs améliorée
   - ✅ Feedback utilisateur avec SnackBar

3. **Carte Interactive des Livreurs**
   - Données de position disponibles
   - Placeholder dans l'interface
   - **Action requise** : Intégrer google_maps_flutter

4. **Export de Rapports PDF**
   - Structure présente
   - Génération PDF partielle
   - **Action requise** : Compléter l'export PDF

### 📈 Taux de Complétion : **~97%** (graphiques fl_chart et upload d'images complétés)

---

## 🔧 Configuration Requise pour Fonctionnement Complet

### 🚨 CRITIQUE (Application ne démarre pas sans)

1. **Backend Django démarré**
   - `cd backend && docker compose up` — PostgreSQL + PostGIS, Redis, l'API et
     les workers.
   - Sans lui, les trois applications démarrent mais n'affichent rien : elles
     n'ont plus aucune source de données locale.

2. **Fichiers `.env` des applications**
   - `El Corazon fastfood/.env`, `El corazon dely/.env`, `El Corazon admin/.env`
   - Une seule variable indispensable : `API_BASE_URL`
     (`http://localhost:8000/api/v1` en développement).
   - **Plus aucune clé Supabase, ni clé marchande PayDunya, ni certificat
     Agora** : ces secrets vivent côté serveur. Les avoir dans une application
     revenait à les distribuer avec le binaire.

### ⚠️ IMPORTANT (Fonctionnalités essentielles)

1. **Google Maps API Key**
   - Nécessaire pour : géolocalisation, cartes, itinéraires
   - Où l'obtenir : https://console.cloud.google.com/apis/credentials
   - **Action** : dans le `.env` de chaque application. C'est une clé *cliente*,
     elle est visible dans le binaire par construction — elle doit donc être
     **restreinte** (empreinte Android, Bundle ID iOS, référent HTTP) et sous
     quota. Voir [docs/security/google_maps.md](docs/security/google_maps.md).

2. **PayDunya (Paiements)**
   - Nécessaire pour : paiements Mobile Money
   - Où l'obtenir : https://app.paydunya.com/developers
   - **Action** : dans le `.env` du **backend uniquement**. Ces clés permettent
     d'encaisser et de rembourser au nom de l'enseigne : dans un `.env`
     d'application, elles sont dans un binaire distribué au public. Les
     applications n'en ont pas besoin — elles appellent
     `POST /payments/{commande}/initiate/` et lisent la réponse.

### 📌 OPTIONNEL (Fonctionnalités avancées)

1. **Agora RTC (Appels vidéo)**
   - Nécessaire pour : communication client-livreur
   - Où l'obtenir : https://console.agora.io
   - **Action** : `AGORA_APP_ID` dans le `.env` des applications (identifiant
     public), `AGORA_APP_CERTIFICATE` dans celui du **backend uniquement** —
     c'est lui qui signe les jetons de canal. Le certificat dans une application
     permettrait de rejoindre n'importe quel appel.

2. **Firebase (Notifications push)**
   - Nécessaire pour : Notifications push
   - Où l'obtenir : https://console.firebase.google.com
   - **Note** : `elcora_dely` a déjà Firebase configuré
   - **Action** : Configurer pour `elcora_fast` si nécessaire

---

## 📊 Résumé Global

| Application | Taux de Complétion | Services | Écrans | État |
|------------|-------------------|----------|--------|------|
| **elcora_fast** | ~85% | 60+ | 30+ | ✅ Fonctionnel (config requis) |
| **elcora_dely** | ~90% | 30+ | 15+ | ✅ Fonctionnel (config requis) |
| **admin** | ~90% | 50+ | 20+ | ✅ Fonctionnel (config requis) |

### ✅ Points Forts

1. **Architecture solide** - Services bien structurés et modulaires
2. **Couverture fonctionnelle** - Toutes les fonctionnalités principales présentes
3. **Base de données complète** - Schéma PostgreSQL + PostGIS, invariants
   défendus par des contraintes (voir `docs/architecture/03-modele-de-donnees.md`)
4. **Multi-plateforme** - Support mobile et web
5. **Gestion d'erreurs** - Services d'erreur et validation présents
6. **Performance** - Optimisations et cache implémentés

### 🚧 Points à Améliorer

1. **Configuration** - Fichiers `.env` à créer
2. **Graphiques** - Compléter les graphiques fl_chart dans admin
3. **Upload d'images** - Stockage privé côté serveur, URL signées expirantes
4. **Carte interactive** - Intégrer Google Maps dans admin
5. **Tests** - Ajouter des tests unitaires et d'intégration
6. **Documentation** - Documenter les APIs des services

---

## 🎯 Priorités pour Finalisation

### 🔴 PRIORITÉ 1 (Blocage)
- [x] Créer les fichiers `.env` pour les 3 applications (`API_BASE_URL`)
- [x] ~~Configurer les clés Supabase~~ — Supabase retiré
- [ ] Configurer Google Maps API Key (géocodage, cartes)
- [ ] Déploiement réel : Nginx, TLS, MinIO, Celery beat (§3.6 du plan de migration)

### 🟡 PRIORITÉ 2 (Fonctionnalités essentielles)
- [ ] Configurer PayDunya pour les paiements
- [x] Compléter les graphiques fl_chart dans admin ✅
- [x] Finaliser l'upload d'images produits ✅

### 🟢 PRIORITÉ 3 (Améliorations)
- [ ] Configurer Agora RTC pour les appels
- [ ] Intégrer la carte interactive des livreurs
- [ ] Ajouter des tests unitaires
- [ ] Améliorer la documentation

---

## 📝 Notes Techniques

### Services Principaux par Application

**elcora_fast** :
- AppService, CartService, OrderService
- PaymentService, LocationService, TrackingService
- GamificationService, CustomizationService
- OfflineSyncService, NotificationService

**elcora_dely** :
- AppService, DeliveryService
- LocationService, TrackingService
- ChatService, AgoraCallService
- EarningsService, NotificationService

**admin** :
- AdminAuthService, OrderManagementService
- MenuService, DriverManagementService
- AnalyticsService, RoleManagementService
- MarketingService, PaymentsService, GlobalSearchService
- (`ReportService` et `AuditLogService` ont été supprimés : aucun écran ne les
  atteignait)

### Technologies Utilisées

- **Backend** : Django 5.2 + DRF + Channels (ASGI) — auth JWT, API REST,
  WebSockets, Celery. PostgreSQL 17 + PostGIS, Redis, MinIO
- **State Management** : Provider, Riverpod
- **Maps** : Google Maps Flutter
- **Paiements** : PayDunya
- **Notifications** : Firebase Cloud Messaging
- **Communication** : Agora RTC
- **Local Storage** : SQLite, SharedPreferences
- **Graphiques** : fl_chart, Syncfusion Charts

---

**Corps de l'inventaire** : décembre 2024 · **Révision d'architecture** : 1er août 2026

