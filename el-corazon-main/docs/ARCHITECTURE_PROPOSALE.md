# 🏗️ Architecture Proposée — El Corazón

> **Document** : Proposition d'architecture complète  
> **Date** : 21 juillet 2026  
> **Scope** : Monorepo — 3 apps Flutter + Laravel API + Supabase

---

## 📑 Table des Matières

1. [Contexte & Problématique](#1-contexte--problématique)
2. [Principe Directeur](#2-principe-directeur)
3. [Architecture Cible](#3-architecture-cible)
4. [Rôles des Technologies](#4-rôles-des-technologies)
5. [Flux par Fonctionnalité](#5-flux-par-fonctionnalité)
6. [Structure du Monorepo](#6-structure-du-monorepo)
7. [Sécurité](#7-sécurité)
8. [CI/CD](#8-cicd)
9. [Migration depuis l'Architecture Actuelle](#9-migration-depuis-larchitecture-actuelle)
10. [Roadmap](#10-roadmap)

---

## 1. Contexte & Problématique

### État Actuel

| Couche | Technologie | État |
|--------|-------------|------|
| **Frontend** | Flutter (3 apps) | ✅ Fonctionnel, mais code dupliqué (~40 fichiers) |
| **Backend** | Supabase (direct) | ✅ Fonctionnel, mais logique métier côté client |
| **Laravel** | `backend/` | ❌ Vide — à créer |
| **BDD** | Supabase (PostgreSQL) | ✅ Fonctionnel |
| **Google Maps** | `google_maps_flutter` | ✅ Intégré |
| **Agora** | `agora_rtc_engine` | ✅ Intégré (tokens hardcodés) |
| **PayDunya** | HTTP direct | ⚠️ Clés placeholder, logique côté client |

### Problèmes Identifiés

1. **Secrets exposés** : Clés API hardcodées dans le code source (`api_config.dart` du dely)
2. **Logique métier côté client** : Paiement, génération de tokens Agora, validation métier
3. **Pas de backend dédié** : Toute la logique passe par Supabase directement
4. **Code dupliqué** : ~40 fichiers identiques ou similaires entre les 3 apps
5. **God classes** : `DatabaseService` (72 méthodes, 2255 lignes), `AppService` (1339 lignes)
6. **Pas de tests, pas de CI/CD**

### Objectif

Introduire **Laravel** comme **couche d'API et de logique métier** entre les apps Flutter et Supabase, tout en conservant Supabase pour :
- L'authentification (auth.users)
- La base de données (PostgreSQL)
- Le stockage de fichiers
- Les abonnements en temps réel

---

## 2. Principe Directeur

> **Supabase pour ce que c'est fait de mieux. Laravel pour ce que Supabase ne peut pas faire.**

### Supabase gère :
- ✅ Authentification des utilisateurs
- ✅ Base de données PostgreSQL (CRUD courant)
- ✅ Stockage de fichiers (images, documents)
- ✅ Abonnements en temps réel (WebSocket)
- ✅ Edge Functions (légères)

### Laravel gère :
- 🔐 **Opérations sensibles** : paiement, génération de tokens, webhooks
- 🔄 **Logique métier complexe** : calculs, validations, orchestrations
- ⏱️ **Tâches planifiées** : rapports, notifications, nettoyage
- 📡 **Webhooks externes** : callbacks PayDunya, événements Agora
- 🛡️ **Validation serveur** : toutes les entrées utilisateurs critiques
- 📊 **Analytics agrégés** : calculs lourds non temps réel

---

## 3. Architecture Cible

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        📱 Applications Flutter                         │
│                                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                   │
│  │  elcora_fast │  │  elcora_dely │  │    admin     │                   │
│  │  (Client)    │  │  (Livreur)   │  │  (Admin)     │                   │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘                   │
│         │                 │                 │                          │
└─────────┼─────────────────┼─────────────────┼──────────────────────────┘
          │                 │                 │
          │  Toutes les requêtes passent par Laravel (API REST + Auth)
          │
          ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          🔐 Laravel API Layer                           │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  API Routes (api.php) — Authentification par JWT via Supabase     │   │
│  │  • /api/auth/*          — Login, register, password reset        │   │
│  │  • /api/menu/*          — CRUD menu, catégories, personnalisation│   │
│  │  • /api/orders/*        — Création, suivi, statut, historique     │   │
│  │  • /api/payments/*      — Paiement via PayDunya (proxy sécurisé)  │   │
│  │  • /api/calls/*         — Génération de tokens Agora RTC          │   │
│  │  • /api/drivers/*       — Gestion livreurs, localisation          │   │
│  │  • /api/analytics/*     — Métriques agrégées                      │   │
│  │  • /api/webhooks/*      — Callbacks PayDunya, Agora                 │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Services Métier                                                  │   │
│  │  • PaymentService       — Orchestration PayDunya                  │   │
│  │  • AgoraService         — Génération tokens RTC (server-side)     │   │
│  │  • NotificationService  — Envoi notifications (Firebase/FCM)      │   │
│  │  • OrderService         — Logique commande (statuts, validation)  │   │
│  │  • DriverService        — Assignment, géolocalisation             │   │
│  │  • AnalyticsService     — Agrégations, rapports                   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Jobs & Queues                                                    │   │
│  │  • ProcessPaymentJob        — Finalisation paiement async         │   │
│  │  • SendNotificationJob      — Envoi notifications en batch         │   │
│  │  • GenerateReportJob        — Rapports périodiques                 │   │
│  │  • UpdateDriverLocationJob  — Nettoyage positions expirées        │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
          │
          │  Laravel utilise le SDK Supabase (ou client PostgreSQL direct)
          │  pour accéder aux mêmes données que les apps Flutter
          │
          ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        🗄️ Supabase Infrastructure                      │
│                                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │ PostgreSQL   │  │ Auth         │  │ Storage      │  │ Realtime   │ │
│  │ (Tables)     │  │ (auth.users) │  │ (Bucket)     │  │ (WebSocket)│ │
│  └──────────────┘  └──────────────┘  └──────────────┘  └────────────┘ │
│                                                                         │
│  Migrations centralisées dans supabase/migrations/                     │
└─────────────────────────────────────────────────────────────────────────┘
          │
          │  Services externes (appelés par Laravel, jamais par Flutter)
          ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     🌐 Services Externes                               │
│                                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │ Google Maps  │  │ Agora RTC    │  │ PayDunya     │  │ Firebase   │ │
│  │ (Geocoding,  │  │ (Voice/Video │  │ (Mobile      │  │ (FCM)      │ │
│  │  Directions) │  │  Calls)      │  │  Money)      │  │            │ │
│  └──────────────┘  └──────────────┘  └──────────────┘  └────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Rôles des Technologies

### 4.1 Flutter (3 apps)

| App | Rôle | Target |
|-----|------|--------|
| **elcora_fast** | Client — commande, paiement, suivi | Mobile (iOS/Android) |
| **elcora_dely** | Livreur — gestion courses, navigation, appels | Mobile (iOS/Android) |
| **admin** | Admin — dashboard, gestion menu, analytics | Web/Desktop (Flutter Web) |

**Chaque app :**
- Consomme l'API Laravel via HTTP/REST
- S'abonne aux changements en temps réel via Supabase Realtime
- Stocke localement via `shared_preferences` / `sqflite` (mode hors-ligne)
- Affiche les cartes via `google_maps_flutter`
- Effectue les appels vocaux via `agora_rtc_engine` (en utilisant un token fourni par Laravel)

### 4.2 Laravel (API Layer)

**Version recommandée** : Laravel 11.x (LTS)

**Stack :**
```
Laravel 11.x
├── PHP 8.3+
├── Sanctum (JWT/API tokens) — ou Passport si besoin OAuth2
├── Eloquent ORM (ou Supabase client si préféré)
├── Redis (cache + queues)
├── Supervisor (queue worker)
└── Nginx + PHP-FPM
```

**Packages clés :**
| Package | Usage |
|---------|-------|
| `supabase/supabase-php` | Client Supabase pour PHP (accès DB, auth) |
| `guzzlehttp/guzzle` | Requêtes HTTP vers APIs externes |
| `predis/predis` | Client Redis pour les queues |
| `laravel/horizon` | Dashboard de monitoring des queues |
| `laravel/telescope` | Debugging en dev |
| `spatie/laravel-permission` | Gestion des rôles et permissions |
| `spatie/laravel-medialibrary` | Gestion des fichiers uploadés |
| `maatwebsite/excel` | Export Excel/PDF des rapports |

### 4.3 Supabase

**Version** : Supabase v2 (PostgreSQL 15+)

**Utilisation :**
- **Auth** : `auth.users` — gestion des comptes utilisateurs
- **Database** : PostgreSQL — toutes les tables métier
- **Storage** : Buckets pour images, documents
- **Realtime** : WebSocket pour les changements de statut en temps réel

### 4.4 Services Externes

| Service | Utilisation | Appel depuis |
|---------|-------------|--------------|
| **Google Maps** | Geocoding, directions, carte interactive | Flutter (clé publique) + Laravel (geocoding serveur) |
| **Agora RTC** | Appels vocaux/vidéo entre client et livreur | Flutter (SDK) + Laravel (token generation) |
| **PayDunya** | Paiement Mobile Money (Wave, Orange Money, etc.) | Laravel uniquement (clés secrètes) |
| **Firebase** | Notifications push (FCM) | Laravel (via FCM HTTP v1 API) |

---

## 5. Flux par Fonctionnalité

### 5.1 Authentification

```
1. Flutter → POST /api/auth/login (email, password)
2. Laravel → Supabase Auth API (signInWithPassword)
3. Laravel ← Retourne JWT + user data
4. Flutter → Stocke le JWT localement
5. Flutter → Abonnement aux changements utilisateur via Supabase Realtime
```

**Pourquoi pas directement Supabase Auth depuis Flutter ?**
- Centralise la logique d'authentification
- Permet d'ajouter des vérifications (compte banni, etc.)
- Uniformise le format de réponse entre les 3 apps

### 5.2 Paiement (PayDunya)

```
1. Flutter → POST /api/payments/initiate
   { order_id, amount, currency, customer_info }

2. Laravel → PayDunya API (create payment request)
   - Utilise les clés secrètes stockées en .env
   - Crée une transaction en base (payments table)
   - Retourne l'URL de paiement

3. Flutter → Redirige l'utilisateur vers l'URL PayDunya

4. PayDunya → Webhook → Laravel POST /api/webhooks/paydunya
   - Vérifie la signature
   - Met à jour le statut de la transaction
   - Notifie l'utilisateur via FCM

5. Flutter → Polling ou Realtime → Vérifie le statut du paiement
```

**Pourquoi Laravel pour les paiements ?**
- Les clés API PayDunya ne doivent JAMAIS être dans le client
- Les webhooks doivent être reçus par un serveur (pas un client mobile)
- Validation serveur du montant, de la devise, etc.

### 5.3 Appels Vocaux/Vidéo (Agora)

```
1. Flutter → POST /api/calls/token
   { channel_name, user_id, call_type }

2. Laravel → Génère un token RTC Agora
   - Utilise l'App ID et App Certificate (serveur uniquement)
   - Token valide 1 heure

3. Laravel → Retourne le token + channel_name

4. Flutter → Utilise le token avec agora_rtc_engine
   - Rejoint le canal
   - Établit l'appel

5. Événement d'appel → Supabase Realtime
   - Création d'un enregistrement dans la table `calls`
   - Les 2 participants reçoivent la notification en temps réel
```

**Pourquoi Laravel pour les tokens Agora ?**
- L'App Certificate ne doit jamais quitter le serveur
- Contrôle des permissions (qui peut appeler qui)
- Durée de validité contrôlée

### 5.4 Suivi de Livraison en Temps Réel

```
1. Driver Flutter → Met à jour la position toutes les 10s
   → POST /api/drivers/location { lat, lng, bearing }

2. Laravel → Met à jour Supabase (driver_locations table)
   → Broadcast via Supabase Realtime

3. Client Flutter → Abonné au Realtime
   → Reçoit les mises à jour de position en temps réel
   → Met à jour le marqueur sur Google Maps
```

### 5.5 Gestion de Commande

```
1. Client Flutter → POST /api/orders
   { items, total, address, payment_method }

2. Laravel → Valide la commande
   - Vérifie le stock
   - Vérifie les promotions
   - Calcule les frais de livraison
   - Crée la commande dans Supabase

3. Laravel → Notifie les livreurs disponibles via FCM

4. Livreur Flutter → Accepte la commande
   → POST /api/orders/{id}/accept

5. Laravel → Met à jour le statut
   → Broadcast via Supabase Realtime

6. Tous les clients concernés → Reçoivent la mise à jour en temps réel
```

---

## 6. Structure du Monorepo

```
el-corazon-main/
├── 📱 El Corazon fastfood/          # App Client
│   ├── lib/
│   │   ├── config/                  # Configuration (chargée depuis .env)
│   │   ├── models/                  # Modèles (depuis elcora_shared)
│   │   ├── screens/                 # Écrans UI
│   │   ├── services/                # Services (API client, etc.)
│   │   ├── widgets/                 # Widgets réutilisables
│   │   ├── navigation/              # Routes et navigation
│   │   ├── providers/               # State management (Riverpod)
│   │   └── main.dart
│   ├── .env.example
│   ├── .env
│   ├── pubspec.yaml
│   └── test/
│
├── 📱 El corazon dely/              # App Livreur
│   ├── lib/
│   │   ├── config/
│   │   ├── models/
│   │   ├── screens/
│   │   ├── services/
│   │   ├── widgets/
│   │   ├── navigation/
│   │   └── main.dart
│   ├── .env.example
│   ├── .env
│   ├── pubspec.yaml
│   └── test/
│
├── 💻 El Corazon admin/             # App Admin
│   ├── lib/
│   │   ├── core/                    # Core utilities, constants
│   │   ├── models/
│   │   ├── screens/
│   │   ├── services/
│   │   └── main.dart
│   ├── .env.example
│   ├── .env
│   ├── pubspec.yaml
│   └── test/
│
├── 🔐 backend/                      # Laravel API
│   ├── app/
│   │   ├── Http/
│   │   │   ├── Controllers/
│   │   │   │   ├── AuthController.php
│   │   │   │   ├── MenuController.php
│   │   │   │   ├── OrderController.php
│   │   │   │   ├── PaymentController.php
│   │   │   │   ├── CallController.php
│   │   │   │   ├── DriverController.php
│   │   │   │   ├── AnalyticsController.php
│   │   │   │   └── WebhookController.php
│   │   │   └── Middleware/
│   │   │       ├── EnsureUserRole.php
│   │   │       └── LogRequest.php
│   │   ├── Services/
│   │   │   ├── PaymentService.php
│   │   │   ├── AgoraService.php
│   │   │   ├── NotificationService.php
│   │   │   ├── OrderService.php
│   │   │   ├── DriverService.php
│   │   │   └── AnalyticsService.php
│   │   ├── Jobs/
│   │   │   ├── ProcessPaymentJob.php
│   │   │   ├── SendNotificationJob.php
│   │   │   ├── GenerateReportJob.php
│   │   │   └── UpdateDriverLocationJob.php
│   │   ├── Models/
│   │   │   ├── User.php
│   │   │   ├── Order.php
│   │   │   ├── MenuItem.php
│   │   │   ├── Payment.php
│   │   │   └── Driver.php
│   │   └── Exceptions/
│   │       └── Handler.php
│   ├── database/
│   │   ├── migrations/
│   │   └── seeders/
│   ├── routes/
│   │   ├── api.php
│   │   └── console.php
│   ├── config/
│   │   ├── supabase.php
│   │   ├── paydunya.php
│   │   ├── agora.php
│   │   └── firebase.php
│   ├── tests/
│   │   ├── Feature/
│   │   │   ├── AuthTest.php
│   │   │   ├── OrderTest.php
│   │   │   └── PaymentTest.php
│   │   └── Unit/
│   ├── .env.example
│   ├── .env
│   ├── composer.json
│   └── artisan
│
├── 📦 packages/                     # Package Dart partagé
│   └── elcora_shared/
│       ├── lib/
│       │   ├── src/
│       │   │   ├── models/          # Modèles partagés
│       │   │   ├── services/        # Services partagés
│       │   │   ├── utils/           # Utilitaires (formateurs, validateurs)
│       │   │   └── constants/       # Constantes globales
│       │   └── elcora_shared.dart   # Barrel file
│       ├── test/
│       ├── pubspec.yaml
│       └── README.md
│
├── 🗄️ supabase/                    # Migrations Supabase centralisées
│   └── migrations/
│       ├── 20251216_create_calls_table.sql
│       ├── 20251217_fix_calls_table_schema.sql
│       └── (futures migrations...)
│
├── 📚 docs/
│   ├── ARCHITECTURE_PROPOSALE.md    # Ce document
│   ├── schema.md                    # Schéma BDD documenté
│   └── env/                         # Templates .env
│
├── 🔄 .github/
│   └── workflows/
│       ├── flutter.yml              # CI Flutter (analyze + test)
│       ├── laravel.yml              # CI Laravel (test + lint)
│       └── deploy.yml               # CD (déploiement)
│
├── docker-compose.yml               # Développement local
├── docker-compose.prod.yml          # Production
├── README.md
└── REFACTORING_PLAN.md
```

---

## 7. Sécurité

### 7.1 Gestion des Secrets

| Secret | Où le stocker | Accès |
|--------|---------------|-------|
| **Supabase URL/Anon Key** | `.env` (Flutter + Laravel) | Public (anon = lecture limitée) |
| **Supabase Service Role Key** | `.env` (Laravel uniquement) | Serveur uniquement |
| **Google Maps API Key** | `.env` (Flutter + Laravel) | Restrictions HTTP + IP |
| **Agora App ID** | `.env` (Flutter) | Public |
| **Agora App Certificate** | `.env` (Laravel uniquement) | Serveur uniquement |
| **PayDunya Master/Private Key** | `.env` (Laravel uniquement) | Serveur uniquement |
| **Firebase Service Account** | `.env` (Laravel) | Serveur uniquement |
| **JWT Secret (Laravel)** | `.env` (Laravel uniquement) | Serveur uniquement |

### 7.2 Authentification & Autorisation

```
Flutter App
    │
    │ 1. POST /api/auth/login (credentials)
    │
    ▼
Laravel API
    │
    │ 2. Valide via Supabase Auth
    │ 3. Vérifie le rôle de l'utilisateur (client/admin/driver)
    │ 4. Génère un JWT signé (Sanctum)
    │
    ▼
Flutter App ← Retourne JWT + user info
    │
    │ 5. Toutes les requêtes suivantes incluent le JWT
    │    Authorization: Bearer <jwt>
    │
    ▼
Laravel Middleware
    │
    │ 6. Vérifie le JWT
    │ 7. Vérifie le rôle (EnsureUserRole middleware)
    │ 8. Autorise ou refuse
```

### 7.3 Row Level Security (Supabase)

Les politiques RLS sur Supabase doivent être configurées pour :
- Autoriser l'accès aux données via le `auth.uid()` (pour les apps Flutter qui utilisent Supabase directement pour le realtime)
- Autoriser l'accès via le Service Role (pour Laravel)

### 7.4 Validation des Entrées

**Toutes les entrées utilisateur doivent être validées côté Laravel :**

```php
// Exemple de validation dans OrderController
$validated = $request->validate([
    'items' => 'required|array|min:1',
    'items.*.menu_item_id' => 'required|exists:menu_items,id',
    'items.*.quantity' => 'required|integer|min:1|max:99',
    'total_amount' => 'required|numeric|min:0',
    'delivery_address' => 'required|string|max:500',
    'payment_method' => 'required|in:wave,orange_money,visa,wallet',
]);
```

---

## 8. CI/CD

### 8.1 GitHub Actions

```yaml
# .github/workflows/flutter.yml
name: Flutter CI
on: [push, pull_request]
jobs:
  analyze-and-test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        app: [elcora_fast, elcora_dely, admin]
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          sdk: '3.5.0'
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
```

```yaml
# .github/workflows/laravel.yml
name: Laravel CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: password
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with:
          php: '8.3'
          extensions: mbstring, pdo, pdo_pgsql, redis
      - run: composer install --no-interaction --prefer-dist
      - run: cp .env.example .env
      - run: php artisan key:generate
      - run: php artisan test
```

### 8.2 Déploiement

```
Docker Compose (développement) :
├── app (Laravel)         — port 8000
├── postgres (Supabase)   — port 5432
├── redis                 — port 6379
└── nginx                 — port 80

Production (Fly.io / DigitalOcean / AWS) :
├── Laravel App (PHP-FPM + Nginx)
├── PostgreSQL (géré par Supabase)
├── Redis (managed)
├── Queue Worker (Supervisor)
└── SSL (Let's Encrypt)
```

---

## 9. Migration depuis l'Architecture Actuelle

### Phase 1 : Sécurité (1-2 jours)
- [ ] Rotater toutes les clés exposées
- [ ] Ajouter `.env` au `.gitignore` de `El corazon dely/`
- [ ] Unifier la lecture de config via `flutter_dotenv`
- [ ] Créer `backend/.env.example`

### Phase 2 : Package Partagé (3-5 jours)
- [ ] Créer `packages/elcora_shared/`
- [ ] Déplacer modèles, services, formatters communs
- [ ] Ajouter la dépendance path dans les 3 apps
- [ ] Unifier les versions de dépendances

### Phase 3 : Laravel Skeleton (2-3 jours)
- [ ] Initialiser le projet Laravel (`composer create-project laravel/laravel backend`)
- [ ] Configurer l'authentification (Sanctum + Supabase)
- [ ] Créer les premiers endpoints (auth, menu)
- [ ] Mettre en place les tests

### Phase 4 : Migration des Services Sensibles (5-7 jours)
- [ ] **PayDunya** : déplacer la logique de paiement vers Laravel
  - Créer `PaymentController` + `PaymentService`
  - Implémenter les webhooks
  - Mettre à jour les apps Flutter pour appeler l'API Laravel
- [ ] **Agora** : déplacer la génération de tokens vers Laravel
  - Créer `CallController` + `AgoraService`
  - Implémenter la génération de tokens RTC
  - Mettre à jour les apps Flutter
- [ ] **Notifications** : centraliser l'envoi via Laravel
  - Créer `NotificationService`
  - Configurer Firebase Admin SDK

### Phase 5 : Nettoyage & Tests (3-4 jours)
- [ ] Supprimer le code mort (fichiers `enhanced_`/`advanced_`/`modern_`)
- [ ] Splitter les god classes
- [ ] Ajouter des tests unitaires et d'intégration
- [ ] Configurer la CI/CD

### Phase 6 : Documentation (1-2 jours)
- [ ] Mettre à jour le README
- [ ] Documenter l'architecture
- [ ] Créer un guide de démarrage

---

## 10. Roadmap

```
┌─────────────────────────────────────────────────────────────────┐
│  Sprint 1  (1-2 jours)  🔴 CRITIQUE                            │
│  ├─ Rotater les clés exposées                                    │
│  ├─ .env → .gitignore                                            │
│  ├─ Initialiser Laravel skeleton                                 │
│  └─ Pipeline CI minimale (analyze + test)                        │
├─────────────────────────────────────────────────────────────────┤
│  Sprint 2  (3-5 jours)  🟠 HAUTE PRIORITÉ                       │
│  ├─ Créer elcora_shared package                                  │
│  ├─ Déplacer modèles/services communs                            │
│  ├─ Unifier versions de dépendances                              │
│  └─ Configurer l'auth Laravel ↔ Supabase                         │
├─────────────────────────────────────────────────────────────────┤
│  Sprint 3  (5-7 jours)  🟡 MOYENNE                              │
│  ├─ Migrer PayDunya vers Laravel (API + webhooks)               │
│  ├─ Migrer Agora token generation vers Laravel                  │
│  ├─ Centraliser les notifications via Laravel                   │
│  └─ Mettre à jour les 3 apps pour utiliser l'API Laravel        │
├─────────────────────────────────────────────────────────────────┤
│  Sprint 4  (3-4 jours)  🟢 IMPORTANT                            │
│  ├─ Splitter les god classes                                     │
│  ├─ Supprimer le code mort                                       │
│  ├─ Tests unitaires (Flutter + Laravel)                          │
│  └─ Configurer la CI/CD complète                                │
├─────────────────────────────────────────────────────────────────┤
│  Sprint 5  (1-2 jours)  🟢 FAIBLE                               │
│  ├─ Documentation complète                                       │
│  ├─ Docker Compose pour dev                                      │
│  └─ Guide de démarrage                                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📝 Décisions Clés à Prendre

1. **State Management** : Finaliser sur **Riverpod 3** (plus moderne, mieux testé) ou rester sur **Provider** ?
   - *Recommandation* : Riverpod 3 — migration progressive via le package partagé

2. **Laravel ↔ Supabase** : Utiliser le **SDK PHP Supabase** ou **PostgreSQL direct** ?
   - *Recommandation* : SDK Supabase pour la cohérence, avec fallback PostgreSQL pour les requêtes complexes

3. **Authentification** : **Sanctum** (JWT simple) ou **Passport** (OAuth2 complet) ?
   - *Recommandation* : Sanctum — suffisant pour une architecture mobile + web

4. **Queue Driver** : **Redis** ou **Database** ?
   - *Recommandation* : Redis en production, Database en dev

5. **Déploiement** : **Fly.io** (simple) ou **AWS/Docker** (plus flexible) ?
   - *Recommandation* : Fly.io pour le MVP, migration vers AWS quand le trafic augmente

---

## 🎯 Bénéfices de cette Architecture

| Aspect | Avantage |
|--------|----------|
| **Sécurité** | Secrets serveur-only, validation côté serveur, tokens contrôlés |
| **Maintenabilité** | Code partagé via package Dart, backend centralisé |
| **Scalabilité** | Laravel peut scaler indépendamment, queues pour le traitement async |
| **Testabilité** | Tests unitaires sur Laravel + Flutter, mocking facilité |
| **Observabilité** | Telescope, Horizon, logs structurés |
| **Déploiement** | CI/CD automatisé, Docker pour la reproductibilité |
| **Productivité** | Un seul backend à maintenir, un seul package partagé |

---

*Ce document est vivant. Chaque décision d'architecture doit être consignée ici.*
