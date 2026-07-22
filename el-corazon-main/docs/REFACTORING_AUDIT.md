# 🔍 Audit de Refactoring — El Corazón

> **Date** : 21 juillet 2026  
> **Auditeur** : Claude Code  
> **Scope** : Monorepo complet (3 apps Flutter + Supabase)  
> **Lignes de code analysées** : ~430 fichiers Dart (~176 000 lignes)

---

## 📊 Executive Summary

| Catégorie | Score | Problèmes | Priorité |
|-----------|-------|-----------|----------|
| **Sécurité** | 🟠 6/10 | ~~Secrets hardcodés~~ ✅, ~~.env commité~~ ✅, ~~clés placeholder~~ ✅, rotation manuelle ⚠️ | HAUTE |
| **Architecture** | 🟠 4/10 | God classes, code dupliqué, coupling | HAUTE |
| **Qualité Code** | 🟡 5/10 | Gestion d'erreurs, casts non-sûrs, parse unsafe | MOYENNE |
| **Tests** | 🔴 1/10 | ~0% de couverture, 1 test qui échoue | CRITIQUE |
| **CI/CD** | 🔴 1/10 | Aucun pipeline, aucun workflow | CRITIQUE |
| **State Management** | 🟠 4/10 | Provider + Riverpod non initialisé, 106 singletons | HAUTE |

---

## 1. 🔐 Sécurité (🔴 CRITIQUE)

### 1.1 Secrets Exposés en Clair

**Fichier** : `El corazon dely/lib/config/api_config.dart`

```dart
// LIGNES 6-8 — SUPABASE URL + ANON KEY EN CLAIR
static const String supabaseUrl = "https://vsdmcqldshttrbilcvle.supabase.co";
static const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';

// LIGNES 11-12 — GOOGLE MAPS API KEY EN CLAIR
static const String googleMapsApiKey =
    'AIzaSyCtSGHbgwiNKhblSK7NpU7aVUvuxz-w-tM';
```

**Impact** : Ces clés sont dans le binaire de l'application. N'importe qui peut les extraire.

**Actions** :
- [ ] Rotater IMMÉDIATEMENT toutes les clés exposées
- [ ] Remplacer `const` par des lectures `flutter_dotenv`
- [ ] Ajouter `.env` au `.gitignore` de `El corazon dely/`

### 1.2 Fichier .env Commité dans Git

**Statut** : `el corazon dely/.env` est **tracké par git** (confirmé via `git ls-files`)

```
El Corazon fastfood/.env.example   ← OK (example seulement)
El corazon dely/.env               ← CRITIQUE (fichier réel avec secrets)
docs/env/admin.env.example         ← OK (example)
docs/env/elcora_dely.env.example   ← OK (example)
docs/env/elcora_fast.env.example   ← OK (example)
```

**Actions** :
- [x] `git rm --cached "El corazon dely/.env"` — ✅ **FAIT**
- [x] Vérifier le `.gitignore` de dely — ✅ **FAIT** (ajouté `.env` exclusion)
- [ ] Rotater toutes les clés du .env exposé — ⚠️ **À FAIRE MANUELLEMENT**

### 1.3 Clés PayDunya en Placeholder

**Fichiers** :
- `El corazon dely/lib/services/paydunya_service.dart:18-20` — `'YOUR_PAYDUNYA_MASTER_KEY'`
- ~~`El corazon dely/lib/config/api_config.dart:18-20`~~ — ✅ **CORRIGÉ** (maintenant via dotenv)

**Impact** : Le paiement ne fonctionne pas en production.

**Actions** :
- [x] Charger les clés depuis `.env` — ✅ **FAIT** (api_config.dart corrigé)
- [ ] Ajouter une vérification au démarrage — 🟡 Voir Phase 6 (Laravel)

### 1.4 Clés Agora en Placeholder

**Fichier** : ~~`El corazon dely/lib/config/api_config.dart:15`~~ — ✅ **CORRIGÉ** (maintenant via dotenv)

**Actions** :
- [x] Charger depuis `.env` — ✅ **FAIT**
- [ ] Implémenter la génération de tokens côté serveur (Laravel) — 🟡 Voir Phase 6

### 1.5 Rotation Manuelle des Clés (CRITIQUE)

Les clés suivantes ont été **exposées** et doivent être **rotatées immédiatement** dans leurs dashboards respectifs :

| Service | Projet | Où exposé | Action |
|---------|--------|-----------|--------|
| **Supabase** | `bbmrhsbmcmmsrzafszfi` | `dely/.env` (commité git) + `fastfood/.env` + `admin/.env` | 🔄 Rotater l'anon key |
| **Supabase** | `vsdmcqldshttrbilcvle` | `dely/lib/config/api_config.dart` (hardcodé) | 🔄 Rotater l'anon key |
| **Google Maps** | `AIzaSyCtSGHbgwiNKhblSK7NpU7aVUvuxz-w-tM` | `dely/lib/config/api_config.dart` (hardcodé) | 🔄 Rotater la clé API |

> **Note** : La rotation doit être effectuée manuellement dans les dashboards Supabase et Google Cloud. Les nouvelles clés doivent être mises dans les fichiers `.env` locaux (non commités).

### 1.5 Clé Supabase Anon Key Exposée

**Fichiers** :
- `El Corazon fastfood/.env` — clé en clair
- `El Corazon admin/.env` — clé en clair (identique à fastfood)

**Note** : La clé anon est "publique" par conception Supabase, mais elle ne devrait pas être commitée non plus.

**Actions** :
- [ ] Rotater les clés
- [ ] Vérifier le `.gitignore`

---

## 2. 📦 Duplication de Code (🟠 HAUTE)

### 2.1 Fichiers Dupliqués entre Apps

**Modèles dupliqués** (mêmes noms, champs parfois divergents) :

| Fichier | Apps concernées | Divergence |
|---------|-----------------|------------|
| `user.dart` | fastfood, admin, dely | Champs non alignés |
| `order.dart` | fastfood, admin, dely | Divergences de modélisation |
| `cart_item.dart` | fastfood, admin, dely | 3 versions |
| `address.dart` | fastfood, dely | 2 versions |
| `menu_item.dart` | fastfood, dely | 2 versions |
| `notification_model.dart` | fastfood, dely | 2 versions |
| `promo_code.dart` | fastfood, dely | 2 versions |
| `cart_service.dart` | fastfood, admin, dely | 3 versions + `enhanced_cart_service.dart` = 4 |

**Services dupliqués** :

| Service | Apps | Divergence |
|---------|------|------------|
| `database_service.dart` | fastfood (2255 lignes), dely (1683 lignes), admin (7 lignes) | 3 versions différentes |
| `paydunya_service.dart` | fastfood, admin, dely | URLs de base différentes |
| `app_service.dart` | fastfood (1339 lignes), dely (1333 lignes) | ~95% similaires |
| `social_service.dart` | fastfood (1382 lignes), admin, dely | Logique copiée |
| `offline_sync_service.dart` | fastfood, admin, dely | 3 versions |
| `geocoding_service.dart` | fastfood, admin, dely | 3 versions |
| `gamification_service.dart` | fastfood, admin, dely | 3 versions |
| `wallet_service.dart` | fastfood, admin, dely | 3 versions |

**Total** : ~40 fichiers dupliqués avec divergences silencieuses

### 2.2 Divergences Silencieuses Exemples

```dart
// price_formatter.dart
// fastfood → "1.000 CFA" (point)
// admin → "1 000 CFA" (espace)

// database_service.dart
// fastfood → 72 méthodes, signature A
// dely → signature B (légèrement différente)
// admin → 7 méthodes seulement

// paydunya_service.dart
// fastfood → URL: https://app.paydunya.com
// dely → URL: https://app-sandbox.paydunya.com (mais ne résout pas)
```

**Actions** :
- [ ] Créer `packages/elcora_shared/`
- [ ] Déplacer tous les modèles communs
- [ ] Déplacer tous les services communs
- [ ] Unifier les formatters et utilitaires
- [ ] Supprimer les copies locales

---

## 3. 🏗️ Architecture (🟠 HAUTE)

### 3.1 God Classes — Fichiers > 1000 lignes

| Rang | Fichier | Lignes | App | Problème |
|------|---------|--------|-----|----------|
| 1 | `advanced_order_management_screen.dart` | **3 016** | admin | Écran + logique métier + widgets |
| 2 | `group_order_screen.dart` | **2 867** | fastfood | Écran + logique + widgets |
| 3 | `cake_order_screen.dart` | **2 799** | fastfood | Écran + logique + widgets |
| 4 | `order_management_screen.dart` | **2 655** | admin | Doublon de advanced_ |
| 5 | `database_service.dart` | **2 255** | fastfood | 72 méthodes, 73 catch |
| 6 | `enhanced_admin_dashboard.dart` | **2 002** | admin | Écran + logique + widgets |
| 7 | `gamification_management_screen.dart` | **1 933** | admin | Écran + logique + widgets |
| 8 | `database_service.dart` | **1 683** | dely | 53 catch |
| 9 | `delivery_tracking_screen.dart` | **1 669** | fastfood | Écran + logique + widgets |
| 10 | `social_service.dart` | **1 382** | fastfood | 43 unsafe casts |
| 11 | `app_service.dart` | **1 339** | fastfood | 31 catch, importe 18 services |
| 12 | `app_service.dart` | **1 333** | dely | 50 catch, importe 18 services |
| 13 | `item_customization_screen.dart` | **1 332** | fastfood | Code mort (remplacé par enhanced_) |
| 14 | `shared_payment_screen.dart` | **1 257** | fastfood | Écran + logique + widgets |
| 15 | `auth_screen.dart` | **1 255** | fastfood | Écran + logique + widgets |
| 16 | `customization_service.dart` | **1 226** | fastfood | Service + logique métier |
| 17 | `delivery_home_screen.dart` | **1 157** | dely | Écran + logique + widgets |
| 18 | `admin_navigation_screen.dart` | **1 138** | admin | Navigation + logique |
| 19 | `delivery_orders_screen.dart` | **1 124** | dely | Écran + logique + widgets |
| 20 | `enhanced_item_customization_screen.dart` | **1 098** | fastfood | Variante enhanced |
| 21 | `order_management_service.dart` | **1 080** | admin | 55 catch |
| 22 | `admin_dashboard_screen.dart` | **1 077** | admin | Doublon de enhanced_ |
| 23 | `analytics_screen.dart` | **1 043** | admin | Écran + logique + widgets |
| 24 | `driver_map_screen.dart` | **1 000** | admin | Écran + logique + widgets |

**Total** : 24 fichiers dépassent 1 000 lignes

### 3.2 Singletons Manuels (106 fichiers)

**Pattern anti-cathédrale** :
```dart
class SomeService extends ChangeNotifier {
  static final SomeService _instance = SomeService._internal();
  factory SomeService() => _instance;
  SomeService._internal();
}
```

**106 fichiers** utilisent ce pattern, contournant complètement l'arbre Provider.

**Actions** :
- [ ] Remplacer par l'injection de dépendances via Provider/Riverpod
- [ ] Diviser les god classes en sous-composants

### 3.3 Coupling Excessif

**AppService** (fastfood, 1339 lignes) importe **~18 services** directement :
```
AppService → CartService, OrderService, AuthService, NotificationService,
  LocationService, GamificationService, WalletService, SocialService,
  MarketingService, OfflineSyncService, RealtimeTrackingService, etc.
```

**Actions** :
- [ ] Diviser AppService en : SessionManager, NotificationManager, ThemeManager, WalletManager
- [ ] Utiliser l'injection de dépendances

---

## 4. 🛡️ Qualité du Code (🟡 MOYENNE)

### 4.1 Gestion d'Erreurs — Swallowing

| Métrique | Total | Fichiers concernés |
|----------|-------|-------------------|
| `catch (e)` sans stack trace | **1 303** | 225 fichiers |
| `debugPrint` brut | **2 133** | 201 fichiers |
| `double.parse()` / `int.parse()` unsafe | **33** | 12 fichiers |
| `as Type` cast non-sûr | **877** | 128 fichiers |

**Exemples** :
```dart
// ❌ Mauvais — swallowing
catch (e) {
  debugPrint('Erreur: $e');
}

// ✅ Bon — avec stack trace et log structuré
catch (e, st) {
  _logger.error('Erreur dans X', error: e, stackTrace: st);
}
```

**Fichiers les pires** :
- `database_service.dart` (fastfood) : 73 catch, 55 debugPrint
- `app_service.dart` (fastfood) : 31 catch
- `app_service.dart` (dely) : 50 catch
- `order_management_service.dart` (admin) : 55 catch
- `offline_sync_service.dart` (fastfood) : 66 debugPrint

**Actions** :
- [ ] Remplacer `catch (e)` par `catch (e, st)` + Logger structuré
- [ ] Remplacer `debugPrint` par un Logger avec niveaux
- [ ] Remplacer `parse()` par `tryParse()`
- [ ] Remplacer `as Type` par `as? Type` + garde

### 4.2 setState après dispose

- **188 `setState()`** dans fastfood vs **115 `mounted` guards**
- Le lint `use_build_context_synchronously` est activé mais violé

**Actions** :
- [ ] Ajouter `if (!mounted) return;` avant chaque `setState` après `await`

### 4.3 Casts non-sûrs dans les routeurs

- `fastfood/lib/navigation/app_router.dart:217` — `args?['item'] as MenuItem`
- `fastfood/lib/navigation/app_router.dart:231` — `args?['order'] as Order`
- `dely/lib/main.dart:170` — `settings.arguments as Map<String, dynamic>`

**Actions** :
- [ ] Remplacer par `as? Type` + garde null

---

## 5. 💀 Code Mort (🟡 MOYENNE)

### 5.1 Fichiers "enhanced_"/"advanced_"/"modern_" (22 fichiers)

| Original | Variante | App |
|----------|----------|-----|
| `admin_dashboard_screen.dart` | `enhanced_admin_dashboard.dart` | admin |
| `order_management_screen.dart` | `advanced_order_management_screen.dart` | admin |
| `order_management_screen.dart` | `updated_order_management_screen.dart` | admin |
| `cart_service.dart` | `enhanced_cart_service.dart` | fastfood |
| `item_customization_screen.dart` | `enhanced_item_customization_screen.dart` | fastfood |
| `orders_screen.dart` | `enhanced_orders_screen.dart` | fastfood |

### 5.2 Fichiers non-importés

- `fastfood/lib/screens/client/item_customization_screen.dart` (1332 lignes) — **code mort**, le routeur utilise `enhanced_` à la place
- `fastfood/lib/screens/client/riverpod_example_screen.dart` — **exemple mort**, Riverpod non activé
- `admin/lib/main_web.dart` — doublon de `main.dart`

### 5.3 Services redondants

- `fastfood/lib/services/database_service.dart` (2255 lignes) — **redondant** avec `repositories/`
- `fastfood/lib/services/optimized_database_service.dart` — variante optimisée
- `fastfood/lib/services/promo_code_service.dart` + `promo_code_service_supabase.dart` — 2 versions

**Actions** :
- [ ] Pour chaque paire, décider : garder original ou variante
- [ ] Supprimer les fichiers morts
- [ ] Unifier les services redondants

---

## 6. 🧪 Tests & CI/CD (🔴 CRITIQUE)

### 6.1 Couverture de Tests

| App | Répertoire `test/` | Tests | Couverture |
|-----|-------------------|-------|------------|
| fastfood | ❌ N'existe pas | 0 | ~0% |
| dely | ❌ N'existe pas | 0 | ~0% |
| admin | ✅ Existe | 1 | ~0% (échoue) |

**Le seul test** (`admin/test/widget_test.dart`) **échoue** car il n'initialise pas dotenv/Supabase.

### 6.2 CI/CD

- ❌ Aucun fichier `.github/workflows/`
- ❌ Aucun pipeline d'intégration continue
- ❌ Aucun pipeline de déploiement continu
- ❌ `analysis_options.yaml` strict de fastfood non appliqué en CI

**Actions** :
- [ ] Créer `.github/workflows/flutter.yml` (analyze + test)
- [ ] Créer `.github/workflows/laravel.yml` (test + lint)
- [ ] Appliquer les lints en CI

---

## 7. ⚙️ State Management (🟠 HAUTE)

### 7.1 Situation Actuelle

| Tool | Status | Détails |
|------|--------|---------|
| Provider (ChangeNotifier) | ✅ Actif | 108 usages dans 6 fichiers (main.dart + lazy_service_provider) |
| Riverpod | ⚠️ Partiellement installé | `flutter_riverpod: ^3.0.3` dans fastfood, **aucun `ProviderScope`** à la racine |

### 7.2 Problèmes

1. **Riverpod non initialisé** : Aucun `ProviderScope` à la racine de `main.dart`
2. **Singletons manuels** : 106 fichiers contournent Provider avec `factory ... => _instance`
3. **Mix de patterns** : Provider + Riverpod + Singletons = confusion

**Actions** :
- [ ] Décider : Riverpod 3 (recommandé) ou Provider uniquement
- [ ] Si Riverpod : ajouter `ProviderScope` à la racine, migrer progressivement
- [ ] Si Provider : supprimer les fichiers Riverpod morts

---

## 8. 🗄️ Schéma de Base de Données (🟡 MOYENNE)

### 8.1 Migrations Éparses

| Emplacement | Fichiers |
|-------------|----------|
| `supabase/migrations/` | 2 SQL |
| `El Corazon admin/lib/database/` | 6 SQL (`fix_admin_schema.sql`, `force_fix_admin_roles.sql`, etc.) |
| `El corazon dely/supabase/migrations/` | 4 SQL |

**Problème** : Le schéma est dispersé dans le code Dart, pas centralisé.

**Actions** :
- [ ] Centraliser tout dans `supabase/migrations/`
- [ ] Supprimer les `.sql` des `lib/`
- [ ] Nommer les migrations avec timestamps (`YYYYMMDDHHMMSS_description.sql`)

---

## 9. 🔌 Services Externes (🟠 HAUTE)

### 9.1 PayDunya

**Problème** : La logique de paiement est dans le client Flutter, avec des clés placeholder.

**Fichiers** :
- `fastfood/lib/services/paydunya_service.dart` — 8 catch, 11 debugPrint
- `dely/lib/services/paydunya_service.dart` — 11 catch, 11 debugPrint
- `admin/lib/services/paydunya_service.dart` — 6 catch, 8 debugPrint

**Actions** :
- [ ] Déplacer la logique vers Laravel (clés secrètes serveur-only)
- [ ] Implémenter les webhooks côté Laravel
- [ ] Mettre à jour les apps pour appeler l'API Laravel

### 9.2 Agora

**Problème** : L'App ID est dans le code, mais surtout, **aucune génération de token RTC côté serveur**.

**Fichiers** :
- `fastfood/lib/services/agora_service.dart` — 17 debugPrint
- `fastfood/lib/services/agora_token_service.dart` — existe mais ?
- `dely/lib/services/agora_call_service.dart` — 28 debugPrint

**Actions** :
- [ ] Générer les tokens RTC côté Laravel (App Certificate)
- [ ] Ne jamais exposer l'App Certificate dans le client

### 9.3 Google Maps

**Statut** : Correctement intégré via `google_maps_flutter` + `geolocator`

**Amélioration** : Le geocoding serveur devrait passer par Laravel pour éviter de dépasser les quotas côté client.

---

## 10. 📋 Priorisation & Plan d'Action

### Phase 1 — Sécurité Critique (1-2 jours) 🔴

| # | Action | Fichiers | Effort | Statut |
|---|--------|----------|--------|--------|
| 1.1 | Rotater toutes les clés exposées | `dely/lib/config/api_config.dart`, `.env` | 2h | ⚠️ À faire (rotation Supabase) |
| 1.2 | Ajouter `.env` au `.gitignore` de dely | `.gitignore` | 15m | ✅ **FAIT** |
| 1.3 | `git rm --cached` le .env de dely | git | 15m | ✅ **FAIT** |
| 1.4 | Remplacer `const` par `flutter_dotenv` | `api_config.dart` (dely) | 4h | ✅ **FAIT** |
| 1.5 | Créer `backend/.env.example` | `backend/` | 1h | ✅ **FAIT** |
| 1.6 | Créer `.env.example` pour dely | `El corazon dely/` | 1h | ✅ **FAIT** |

### Phase 2 — Package Partagé (3-5 jours) 🟠

| # | Action | Fichiers | Effort |
|---|--------|----------|--------|
| 2.1 | Créer `packages/elcora_shared/` | nouveau | 4h |
| 2.2 | Déplacer modèles (user, order, cart_item, etc.) | ~15 fichiers | 8h |
| 2.3 | Déplacer services communs (database, paydunya, etc.) | ~20 fichiers | 12h |
| 2.4 | Déplacer formatters/utilitaires | ~10 fichiers | 6h |
| 2.5 | Unifier versions de dépendances | 3 `pubspec.yaml` | 4h |
| 2.6 | Supprimer les copies locales | ~40 fichiers | 6h |

### Phase 3 — God Classes (5-7 jours) 🟡

| # | Action | Fichiers | Effort |
|---|--------|----------|--------|
| 3.1 | Splitter `advanced_order_management_screen.dart` (3016 lignes) | admin | 2j |
| 3.2 | Splitter `group_order_screen.dart` (2867 lignes) | fastfood | 2j |
| 3.3 | Splitter `cake_order_screen.dart` (2799 lignes) | fastfood | 2j |
| 3.4 | Splitter `database_service.dart` (2255 lignes) → Repository pattern | fastfood | 2j |
| 3.5 | Splitter `enhanced_admin_dashboard.dart` (2002 lignes) | admin | 1j |
| 3.6 | Splitter `app_service.dart` (1339 lignes) → 4 sous-services | fastfood | 1j |
| 3.7 | Supprimer les 22 fichiers enhanced_/advanced_/modern_ | toutes | 1j |

### Phase 4 — Qualité Code (3-4 jours) 🟡

| # | Action | Scope | Effort |
|---|--------|-------|--------|
| 4.1 | Remplacer `catch (e)` par `catch (e, st)` + Logger | 225 fichiers | 2j |
| 4.2 | Remplacer `debugPrint` par Logger structuré | 201 fichiers | 1j |
| 4.3 | Remplacer `parse()` par `tryParse()` | 12 fichiers | 2h |
| 4.4 | Remplacer `as Type` par `as? Type` + garde | 128 fichiers | 1j |
| 4.5 | Ajouter `if (!mounted) return;` | 188 setState | 1j |
| 4.6 | Unifier `analysis_options.yaml` | 3 apps | 4h |

### Phase 5 — Tests & CI/CD (3-4 jours) 🟢

| # | Action | Scope | Effort |
|---|--------|-------|--------|
| 5.1 | Tests unitaires sur `elcora_shared` | package partagé | 1j |
| 5.2 | Tests de modèles (sérialisation JSON) | ~15 modèles | 1j |
| 5.3 | Tests de services (mock Supabase) | ~20 services | 1j |
| 5.4 | Widget tests (checkout, login, cart) | 3 écrans | 1j |
| 5.5 | Créer `.github/workflows/flutter.yml` | CI | 4h |
| 5.6 | Créer `.github/workflows/laravel.yml` | CI | 4h |

### Phase 6 — Laravel Backend (5-7 jours) 🟠

| # | Action | Scope | Effort |
|---|--------|-------|--------|
| 6.1 | Initialiser Laravel skeleton | `backend/` | 4h |
| 6.2 | Configurer auth Laravel ↔ Supabase | auth | 1j |
| 6.3 | Migrer PayDunya vers Laravel | PaymentService | 2j |
| 6.4 | Migrer Agora token generation | AgoraService | 1j |
| 6.5 | Centraliser notifications (FCM) | NotificationService | 1j |
| 6.6 | Mettre à jour apps Flutter pour API Laravel | 3 apps | 2j |

---

## 📈 Métriques Récapitulatives

| Métrique | Valeur |
|----------|--------|
| Fichiers Dart total | ~430 |
| Lignes de code total | ~176 000 |
| Fichiers > 1000 lignes | 24 |
| Fichiers > 2000 lignes | 5 |
| `catch (e)` sans stack trace | 1 303 |
| `debugPrint` brut | 2 133 |
| `parse()` unsafe | 33 |
| `as Type` unsafe | 877 |
| Singletons manuels | 106 |
| Fichiers dupliqués | ~40 |
| Fichiers enhanced_/advanced_/modern_ | 22 |
| Fichiers .env commités | ~~1 (dely)~~ ✅ 0 |
| Secrets hardcodés | ~~4+ (clés API)~~ ✅ 0 |
| Tests existants | 1 (échoue) |
| Pipelines CI/CD | 0 |

---

## 🎯 Recommandations Prioritaires

### Immédiat (🔴 CRITIQUE — 1-2 jours)
1. **Rotater manuellement les clés Supabase et Google Maps** — les clés exposées doivent être invalidées dans leurs dashboards
2. **Initialiser le projet Laravel** — skeleton de base
3. **Mettre en place la CI minimale** — `flutter analyze` + `php test`

### Court terme (🟠 HAUTE — 1-2 semaines)
5. **Créer le package partagé** — éliminer la duplication
6. **Migrer PayDunya vers Laravel** — sécuriser les paiements
7. **Migrer Agora tokens vers Laravel** — sécuriser les appels

### Moyen terme (🟡 MOYENNE — 2-3 semaines)
8. **Splitter les god classes** — améliorer la maintenabilité
9. **Améliorer la gestion d'erreurs** — Logger structuré
10. **Ajouter des tests** — couverture minimale sur le package partagé

---

*Ce document est généré par analyse statique du codebase. Chaque recommandation doit être validée par l'équipe avant mise en œuvre.*
