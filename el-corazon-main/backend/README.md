# 🍔 El Corazón — Backend API (Laravel + Supabase)

API serveur de l'écosystème **El Corazón** (apps Flutter : client `elcora_fast`,
livreur `elcora_dely`, `admin`). Le backend s'appuie sur la base **Supabase
PostgreSQL** partagée et fournit la logique métier côté serveur : commandes,
livraison, paiements PayDunya, tokens RTC Agora, notifications, promotions.

> ℹ️ L'authentification (email/mot de passe, OAuth) reste gérée par **Supabase
> Auth** côté client. Le backend **vérifie** les JWT Supabase (guard `supabase`)
> et rattache chaque requête à la ligne applicative `users`.

---

## 🧱 Stack

| Élément | Choix |
|---|---|
| Framework | Laravel 12 (PHP 8.2+) |
| Base de données | PostgreSQL (Supabase) via Eloquent |
| Auth | Jetons **Sanctum** émis par Laravel (pont Supabase optionnel) |
| Paiement | PayDunya (Checkout Invoice API) |
| Appels | Agora RTC (tokens « 006 ») |
| Push | Firebase Cloud Messaging (HTTP v1) |

---

## 🚀 Installation

Prérequis : **PHP ≥ 8.2**, **Composer**, accès au projet Supabase.

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate

# Renseigner .env : SUPABASE_URL, SUPABASE_JWT_SECRET, DB_*, PAYDUNYA_*, AGORA_*, FIREBASE_*
# Puis (optionnel) semer les catégories/achievements de référence :
php artisan db:seed

php artisan serve   # http://localhost:8000
```

### Variables `.env` clés

- `SUPABASE_JWT_SECRET` — *Project Settings → API → JWT Secret*. Indispensable
  pour authentifier les requêtes.
- `SUPABASE_SERVICE_ROLE_KEY` — opérations serveur (Auth Admin, Storage signé).
  **Ne jamais exposer au client.**
- `DB_HOST` / `DB_PASSWORD` — connexion PostgreSQL directe à Supabase.
- `PAYDUNYA_*`, `AGORA_*`, `FIREBASE_*` — services externes (facultatifs pour
  démarrer ; chaque endpoint renvoie 503 si son service n'est pas configuré).

> Les drivers `cache/queue/session` sont en `file`/`sync` par défaut pour éviter
> de créer des tables supplémentaires sur Supabase. Passez à Redis en production.

---

## 🔐 Authentification (Sanctum)

L'authentification est **émise par Laravel** via Laravel Sanctum.

- `POST /api/auth/register` — inscription (client ou livreur) → renvoie un jeton
- `POST /api/auth/login` — connexion → renvoie un jeton
- `POST /api/auth/logout` / `logout-all` — révocation du/des jeton(s)
- `POST /api/auth/change-password`

Chaque requête protégée porte ensuite le jeton :

```
Authorization: Bearer <token>
```

Le guard `auth:sanctum` authentifie la requête ; `role:admin` / `role:delivery`
restreint par rôle applicatif.

> **Pont de migration** : `POST /api/auth/exchange` (middleware `supabase.auth`)
> échange un jeton **Supabase Auth** contre un jeton **Sanctum**, sans mot de
> passe. Les apps continuent de se connecter via Supabase et obtiennent un jeton
> API pour la bascule progressive. Nécessite `SUPABASE_JWT_SECRET`. À retirer
> une fois la migration terminée.

### Migrations à appliquer

Deux migrations Laravel préparent Supabase à l'auth Sanctum :

```bash
php artisan migrate
```

- `personal_access_tokens` (jetons Sanctum, `uuidMorphs` car `users.id` est UUID)
- ajout de `password` / `remember_token` sur `users` + `auth_user_id` rendu
  optionnel (les comptes créés via Laravel n'ont pas de compte Supabase Auth)

---

## 📡 Aperçu des routes

Base : `/api`

### Public
- `GET /menu/categories`, `GET /menu/items`, `GET /menu/items/{id}`
- `GET /menu/items/{id}/reviews`
- `POST /webhooks/paydunya` — IPN PayDunya (revérifié côté serveur)

### Authentifié (tous rôles)
- `POST /auth/register|login|logout|change-password`
- `GET /me`, `PUT /me`, `POST /me/heartbeat`
- `GET|POST|PUT|DELETE /addresses`
- `GET /cart`, `POST /cart/items`, `PUT|DELETE /cart/items/{id}`, `DELETE /cart`
- `GET /orders`, `POST /orders`, `GET /orders/{id}`,
  `POST /orders/{id}/status`, `POST /orders/{id}/cancel`
- `POST /menu/items/{id}/reviews`, `DELETE /reviews/{id}`
- `POST /orders/{id}/pay/paydunya`
- `GET /promotions`, `POST /promotions/validate`
- `GET /notifications`, `POST /notifications/{id}/read`, `POST /notifications/read-all`
- `POST /rtc/token` — token Agora pour un canal

### Livreur (`role:delivery`), préfixe `/delivery`
- `POST /profile`, `GET /available-orders`, `GET /my-deliveries`
- `POST /orders/{id}/accept`, `POST /deliveries/{id}/status`
- `POST /location`, `POST /availability`

### Admin (`role:admin`), préfixe `/admin`
- Menu : `POST/PUT/DELETE /menu/categories`, `/menu/items`, `/menu/items/{id}/toggle`
- Livreurs : `GET /drivers`, `POST /drivers/{id}/verify`
- Promotions : `POST/PUT/DELETE /promotions`

---

## 🗂️ Architecture

```
app/
├── Http/
│   ├── Controllers/Api/      # Contrôleurs REST par domaine
│   └── Middleware/           # SupabaseAuthenticate, EnsureUserRole
├── Models/                   # Eloquent mappés sur les tables Supabase (UUID)
├── Providers/                # Guard `supabase` (viaRequest)
├── Services/
│   ├── Supabase/             # Auth Admin + Storage (service_role)
│   ├── Payment/              # PaydunyaService
│   ├── Rtc/                  # AgoraTokenService
│   ├── Push/                 # FcmService
│   └── Notifications/        # NotificationService
└── Support/                  # SupabaseJwt (vérification des tokens)
```

**Modèle de données** : les tables sont la propriété de Supabase (source de
vérité). Les modèles Eloquent s'y mappent sans les recréer — voir
`../SCHEMA_BDD_COMPLET.md`. On ne fournit pas de migrations de création de
tables pour éviter toute divergence avec le schéma Supabase existant.

---

## 🧪 Tests

```bash
php artisan test        # ou ./vendor/bin/phpunit
```

Les tests tournent sur une base SQLite en mémoire (voir `phpunit.xml`).

---

## ✅ État & prochaines étapes

**Implémenté** : auth Supabase, profils, menu (CRUD + avis), panier, adresses,
commandes (création/statuts/annulation + promos + notifications), livraison
(acceptation, statuts, tracking, disponibilité), vérification livreurs,
paiement PayDunya (init + webhook), notifications, promotions, token Agora,
**fidélité** (points, récompenses, échange), **gamification** (succès, défis,
badges), **abonnements VIP**, **social** (groupes, adhésion, posts, likes,
commentaires), **support** (tickets + messages, réclamations, retours).

### Routes des modules additionnels

- `GET /loyalty/summary|rewards|transactions`, `POST /loyalty/rewards/{id}/redeem`
- `GET /gamification/achievements|challenges|badges`
- `GET|POST /subscriptions`, `POST /subscriptions/{id}/status|cancel`
- `GET|POST /social/groups`, `POST /social/groups/join`, `POST /social/groups/{id}/leave`
- `GET|POST /social/posts`, `POST /social/posts/{id}/like`, `.../comments`
- `GET|POST /support/tickets`, `POST /support/tickets/{id}/messages|status`
- `GET|POST /complaints`, `POST /complaints/{id}/resolve`
- `GET|POST /return-requests`, `POST /return-requests/{id}/decide`
- **Paiements partagés** : `POST /orders/{id}/group-payment`, `GET /group-payments/{id}`,
  `POST /group-payments/participants/{id}/pay`
- **Analytics (admin)** : `GET /admin/analytics/dashboard|revenue|top-items`,
  `POST /analytics/events`
- **Push (admin)** : `GET /admin/push/status`, `POST /admin/push/test`

### Push FCM

`NotificationService::notify()` accepte un paramètre optionnel `pushTokens` : si
des tokens sont fournis et FCM configuré, un push est envoyé en plus de la
notification en base. Le schéma Supabase ne stocke pas encore les tokens : pour
un push **automatique**, ajouter une table `device_tokens (user_id, token,
platform)` et charger les tokens dans le service.

**À étendre** : reporting avancé (cohortes, rétention), et stockage des tokens
FCM pour le push automatique sur chaque évènement de commande/livraison.
