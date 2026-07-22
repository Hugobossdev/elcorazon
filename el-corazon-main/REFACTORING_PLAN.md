# 🏗️ Plan de Refactoring — El Corazón

> **Date** : 21 juillet 2026
> **Scope** : Monorepo — 3 apps Flutter, backend Supabase + Node.js
> **Total** : ~430 fichiers Dart, ~176 000 lignes de code

---

## Vue d'ensemble

| App | `pubspec name` | Rôle | Fichiers | Lignes | SDK |
|---|---|---|---|---|---|
| `El Corazon fastfood/` | `elcora_fast` | Client | ~194 | ~78 500 | `^3.5.0` |
| `El Corazon admin/` | `admin` | Admin panel | ~154 | ~65 000 | `>=3.5.0 <4.0.0` |
| `El corazon dely/` | `elcora_dely` | Livreur | ~82 | ~33 000 | `^3.9.2` |

---

## 🚨 Phase 1 — Sécurité Critique

> **Priorité** : 🔴 CRITIQUE — **Délai** : 1-2 jours

### 1.1 Secrets exposés en clair

- **`El corazon dely/lib/config/api_config.dart:6-20`** — Clé Google Maps API + URL Supabase + clé anon **hardcodées en `const`** dans le binaire.
- **`El corazon dely/.env`** est **commité dans git** — le `.gitignore` de dely ne le bloque pas (contrairement à fastfood et admin).
- **Config split-brain** : dely reference **2 projets Supabase différents** — `.env` pointe sur `bbmrhsbmcmmsrzafszfi`, `api_config.dart` sur `vsdmcqldshttrbilcvle`.

**Actions** :

1. Rotater **toutes** les clés exposées (Google Maps, Supabase anon) immédiatement.
2. Ajouter `.env` au `.gitignore` de `El corazon dely/`.
3. Supprimer `.env` de l'historique git si nécessaire (`git rm --cached`).
4. Unifier la lecture de config via `flutter_dotenv` (suivre le pattern de fastfood/admin).
5. Remplacer tout `const` contenant des secrets par des `String.fromEnvironment()` ou des lectures dotenv.

### 1.2 Clés PayDunya en placeholder

- **`El corazon dely/lib/services/paydunya_service.dart:13-14`** contient `'YOUR_PAYDUNYA_MASTER_KEY'`. Le paiement ne fonctionne pas tel quel en production.

**Actions** :

1. Charger les vraies clés depuis `.env`.
2. Ajouter une garde au démarrage : si les clés PayDunya sont manquantes, afficher un écran d'erreur explicite plutôt que d'échouer en production.

### 1.3 Fichiers `.env` live

- `El Corazon fastfood/.env` et `El Corazon admin/.env` sont **byte-identiques** et contiennent la même clé anon Supabase en clair.
- Le `.gitignore` de chaque app doit bloquer `.env` (déjà fait, vérifier l'historique pour s'assurer que la clé n'a pas été pushée).

---

## 📦 Phase 2 — Package Partagé

> **Priorité** : 🟠 HAUTE — **Délai** : 3-5 jours

### 2.1 Créer `packages/elcora_shared/`

**~40 fichiers sont copiés-collés** entre les 3 apps, avec des divergences silencieuses avérées :

| Fichier dupliqué | Divergence prouvée |
|---|---|
| `price_formatter.dart` | fastfood → `"1.000 CFA"` (point), admin → `"1 000 CFA"` (espace) |
| `database_service.dart` | 3 versions avec des signatures légèrement différentes |
| `cart_service.dart` | 3 versions + `enhanced_cart_service.dart` = **4 implémentations** |
| `user.dart` | Modèles dupliqués, champs non alignés |
| `order.dart` | Modèles dupliqués |
| `cart_item.dart` | Modèles dupliqués |
| `gamification_service.dart` | Logique copiée |
| `paydunya_service.dart` | URL base hardcodée différemment selon l'app |

**Actions** :

1. Créer `packages/elcora_shared/` avec sa propre `pubspec.yaml`.
2. Y déplacer :
 - **Modèles** : `user.dart`, `order.dart`, `cart_item.dart`, `menu_item.dart`, `address.dart`, `payment.dart`, `loyalty.dart`, `promotion.dart`, `notification.dart`, `review.dart`.
 - **Formatteurs/Utilitaires** : `price_formatter.dart`, `date_formatter.dart`, `validators.dart`.
 - **Services communs** : `database_service.dart`, `supabase_config.dart`, `paydunya_service.dart`, `gamification_service.dart`, `notification_service.dart`, `storage_service.dart`.
 - **Constantes** : `app_constants.dart` → unique source de vérité (dev, staging, prod).
3. Ajouter une dépendance de type `path` dans chaque `pubspec.yaml`.
4. Lancer un diff 3-ways sur chaque modèle/shared-service pour fusionner les divergences.
5. Supprimer les copies locales redondantes.

### 2.2 Unifier les versions de dépendances

| Package | fastfood | admin | dely | Choix |
|---|---|---|---|---|
| `supabase_flutter` | `^2.12.0` | `^2.5.6` | `^2.10.3` | `^2.12.0` (le plus récent) |
| `flutter_dotenv` | `^6.0.0` | `^6.0.0` | `^5.1.0` | `^6.0.0` |
| `flutter_lints` | `^6.0.0` | `^6.0.0` | `^5.0.0` | `^6.0.0` |

- Aligner toutes les apps sur les versions choisies.
- Mettre à jour le SDK minimum de dely (`^3.9.2`) ou le SDK maximum de fastfood pour garantir la compatibilité.

### 2.3 Nettoyer les contraintes `any`

- `El Corazon fastfood/pubspec.yaml` : `http: any`, `path: any`, `timezone: any`.
- Remplacer chaque `any` par une version explicite.

### 2.4 Uniformiser les constantes

- **`El Corazon fastfood/lib/config/app_constants.dart`** (9 lignes, monnaie `'FCFA'`) vs **`El Corazon admin/lib/core/constants/admin_constants.dart`** (161 lignes, monnaie `'CFA'`).
- Créer `elcora_shared/constants/app_constants.dart` unique, utiliser `FCFA` ou `CFA` de façon cohérente partout.

---

## 🏗️ Phase 3 — Réduction des God Classes

> **Priorité** : 🟡 MOYENNE — **Délai** : 5-7 jours

### 3.1 Fichils les plus volumineux

#### 24 fichiers dépassent les 1 000 lignes. Top des pires cas :

| Fichier | Lignes | Action |
|---|---|---|
| `admin/.../screens/admin/advanced_order_management_screen.dart` | **3016** | Extraire : `OrderFiltersWidget`, `OrderCard`, `OrderActionButtons`, `OrderStatsBanner`. Fusionner avec `order_management_screen.dart` ou supprimer l'ancien. |
| `fastfood/.../screens/client/group_order_screen.dart` | **2867** | Splitter en sous-écrans : `GroupInviteScreen`, `GroupVotingScreen`, `GroupSummaryScreen`. |
| `fastfood/.../screens/client/cake_order_screen.dart` | **2799** | Chaque étape de commande → widget séparé : `CakeDatePicker`, `CakeDesignPicker`, `CakeMessageField`, `CakeReviewStep`. |
| `admin/.../screens/admin/order_management_screen.dart` | **2655** | Déjà remplacé par `advanced_` ? Supprimer l'ancien, merger les fonctions uniques. |
| `fastfood/.../services/database_service.dart` | **2255** (72 méthodes) | Splitter : `AuthService`, `OrderRepository`, `MenuRepository`, `AddressRepository`, `LoyaltyRepository`, `PaymentRepository`. |
| `admin/.../screens/admin/enhanced_admin_dashboard.dart` | **2002** | Extraire : `DashboardKPIs`, `RevenueChart`, `RecentOrdersTable`, `StaffActivityPanel`. |
| `dely/.../services/database_service.dart` | **1683** | Même pattern que fastfood. |
| `fastfood/.../services/app_service.dart` | **1339** | Extraire : `SessionManager`, `NotificationManager`, `ThemeManager`, `WalletManager`. |
| `admin/.../admin_navigation_screen.dart` | **1138** | Extraire : `AdminSidebar`, `AdminTopBar`, `AdminBottomNav`. |
| `admin/.../screens/admin/admin_dashboard_screen.dart` | **1077** | Déjà remplacé par `enhanced_` ? Supprimer. |
| `fastfood/.../screens/client/widgets/enhanced_item_customization_screen.dart` | **1038** | Extraire : `SizeSelector`, `ToppingGrid`, `SpecialInstructionsField`. |
| `fastfood/.../screens/client/widgets/enhanced_payment_screen.dart` | **1017** | Extraire : `CartSummary`, `PaymentMethodSelector`, `AddressSelector`, `ConfirmButton`. |

### 3.2 Code mort — supprimer

Les fichiers suivants ne sont **importés par rien** :

| Fichier | Lignes | Statut |
|---|---|---|
| `fastfood/.../screens/client/item_customization_screen.dart` | 1332 | **Code mort** — le router utilise `enhanced_` à la place |
| `fastfood/.../screens/client/riverpod_example_screen.dart` | — | **Exemple mort** — Riverpod non activé |
| `admin/.../main.dart` **et** `main_web.dart` | — | 2 points d'entrée divergents → unifier |

#### 24 fichiers `enhanced_`/`advanced_`/`modern_`/`improved_` à côté de l'original

Pour chaque paire, **décider** :

| Original | Remplacement | Action |
|---|---|---|
| `admin_dashboard_screen.dart` | `enhanced_admin_dashboard.dart` | Supprimer l'original |
| `order_management_screen.dart` | `advanced_order_management_screen.dart` | Supprimer l'original ou merger |
| `cart_service.dart` | `enhanced_cart_service.dart` | Garder une seule version |
| `item_customization_screen.dart` | `enhanced_item_customization_screen.dart` | Supprimer l'original (déjà mort) |
| ... | ... | Analyser les imports pour confirmer |

### 3.3 Développer le couplage

#### AppService — pattern anti-cathédrale

- `AppService` (1339/1333 lignes) importe **~18 services** directement.
- Singletons manuels (`factory ... => _instance`) contournent l'arbre Provider.

**Solution** :
1. Remplacer les singletons par des constructeurs injectés.
2. Diviser `AppService` en `SessionManager` + `NotificationManager` + `ThemeManager` + `WalletManager`.

#### DatabaseService vs Repositories

- `fastfood/lib/repositories/` existe (pattern Repository abstrait + impl. Supabase).
- En parallèle, `database_service.dart` fait les mêmes appels Supabase directement.

**Solution** : garder **un seul** pattern. Recommandé : **Repository** car :
- Séparation interface / implémentation.
- Facilité de mock pour les tests.
- Supprimer `database_service.dart` au profit des repositories.

---

## 🛠️ Phase 4 — Qualité du Code

> **Priorité** : 🟡 MOYENNE — **Délai** : 3-4 jours

### 4.1 Gestion d'erreurs

| Problème | Occurrences | Fichier exemple |
|---|---|---|
| `catch (e)` qui swalow | **1 303** | Partout — log + pas de retry |
| `debugPrint` brut | **2 133** | Partout |
| `double.parse()` / `int.parse()` | **33** | Divers services |

**Actions** :

1. Remplacer `catch (e)` par `catch (e, st)` + log structuré (`Logger` avec niveaux, `LoggingService`).
2. Implémenter une stratégie de retry pour les appels réseau (ex: `retry()` de `retry` package).
3. Remplacer les 33 `parse()` par `double.tryParse()` / `int.tryParse()`.
4. `main.dart` : afficher un écran d'erreur explicite si l'initialisation Supabase échoue (au lieu de continuer en mode dégradé).

### 4.2 Safety — setState après dispose

- **188 `setState()`** dans fastfood vs **115 `mounted` guards**.
- Le lint `use_build_context_synchronously` est activé mais visiblement violé.

**Actions** :

1. Ajouter `if (!mounted) return;` avant chaque `setState` après un `await`.
2. Enforcer le lint en CI (voir Phase 5).

### 4.3 Casts non-sûrs dans les routeurs

- `fastfood/.../navigation/app_router.dart:217` — `args?['item'] as MenuItem`
- `fastfood/.../navigation/app_router.dart:231` — `args?['order'] as Order`
- `dely/.../main.dart:170` — `settings.arguments as Map<String, dynamic>` (pas de garde null)

**Action** : remplacer chaque `as T` par `as? T` + garde, ou utiliser `is T`.

### 4.4 State management — choisir un seul

| Tool | État |
|---|---|
| Provider (ChangeNotifier) | Actif dans les 3 apps |
| Riverpod | **Partiellement installé** fastfood, **aucun `ProviderScope`** à la racine |

**Décision à prendre** :

- **Option A** : Finir la migration vers Riverpod (recommandé à long terme). Ajouter `ProviderScope` à la racine de `main.dart`, migrer les providers un par un, supprimer les `ChangeNotifierProvider` morts.
- **Option B** : Supprimer les fichiers Riverpod morts (`providers/cart_providers.dart`, `providers/menu_providers.dart`, `riverpod_example_screen.dart`) et rester sur Provider.

### 4.5 Schéma de la base de données

| Emplacement | Fichiers |
|---|---|
| `supabase/migrations/` | 2 SQL |
| `El Corazon admin/lib/database/` | 6 SQL (`fix_admin_schema.sql`, `fix_admin_schema_v2.sql`, `force_fix_admin_roles.sql`…) |
| `El corazon dely/supabase/migrations/` | 4 SQL |

**Actions** :

1. Centraliser **tout** dans `supabase/migrations/` avec des noms datés (`YYYYMMDDHHMMSS_description.sql`).
2. Supprimer les `.sql` des `lib/` — le schéma ne devrait pas être dans le code Dart.
3. Vérifier l'ordre d'exécution et fusionner les corrections (`fix_`, `force_fix_`) dans des migrations propres.
4. Documenter le schéma final dans `docs/schema.md`.

### 4.6 Navigation — aligner dely sur le pattern fastfood

- **dely** : `onGenerateRoute` inline dans `main.dart` (2 routes + catch-all).
- **fastfood** : `AppRouter` dédié (501 lignes, 30+ routes, constantes nommées, extension `BuildContext.push()`).

**Action** : créer `dely/lib/navigation/app_router.dart` sur le modèle de fastfood.

---

## 🧪 Phase 5 — Tests & CI

> **Priorité** : 🟢 IMPORTANT — **Délai** : 3-4 jours

### 5.1 Tests

- **Couverture actuelle : ~0 %** — 1 fichier `widget_test.dart` (admin), qui échoue (pas d'initialisation dotenv/Supabase).
- fastfood et dely n'ont **aucun répertoire `test/`**.

**Actions — ordre** :

1. **Tests unitaires** sur `elcora_shared` :
 - `price_formatter_test.dart` — couvrir tous les cas (petit, grand, NaN, négatif).
 - `date_formatter_test.dart`.
 - `validators_test.dart`.
2. **Tests de modèles** : sérialisation/déserialisation JSON pour chaque modèle partagé.
3. **Tests de services** : mocker Supabase (`supabase_flutter` mock ou `Mockito`).
4. **Widget tests critiques** :
 - `checkout_screen.dart` — flux de paiement.
 - `login_screen.dart` — validation de formulaire.
 - `cart_screen.dart` — ajout/suppression d'items.
5. **Integration tests** : créer un pipeline `fastfood/integration_test/` pour les parcours principaux.

### 5.2 CI/CD

- `analysis_options.yaml` de fastfood est **strict mais non appliqué** en CI.
- Configurer un pipeline minimale (GitHub Actions recommandé) :

```yaml
# .github/workflows/analyze.yml (à créer)
# Pour chaque app :
#   flutter analyze
#   flutter test
```

**Actions** :

1. Créer `.github/workflows/` avec un workflow par app (ou un workflow unique avec matrix).
2. `flutter analyze` — bloquer le merge sur les erreurs de lint.
3. `flutter test` — exécuter les tests unitaires.
4. Vérifier que les lints activés sont respectés (supprimer ou corriger les violations).

### 5.3 Linter — harmoniser

- fastfood : linter strict et bien configuré (82 lignes de rules).
- admin / dely : linter plus léger.

**Action** : copier le `analysis_options.yaml` de fastfood (en adaptant les paths) dans admin et dely. Un seul niveau de qualité pour tout le monorepo.

---

## 📐 Phase 6 — Polish

> **Priorité** : 🟢 FAIBLE — **Délai** : 1-2 jours

### 6.1 Assets

- **dely** : fichier asset avec un **chemin Windows absolu** comme nom (`assets/c__Users_Administrateur_AppData_…png`).
- Supprimer, renommer, re-déclarer dans `pubspec.yaml`.

- Uniformiser :
 - `assets/logo/logo.png` — présent dans chaque app.
 - `assets/icons/` vs `assets/icon/` (fastfood vs admin).

### 6.2 Configuration des entrées

- `El Corazon admin/` possède **2 fichiers d'entrée divergents** : `lib/main.dart` et `lib/main_web.dart`.
- Les merger en un seul `main.dart` avec des flags de plateforme (`kIsWeb`).

### 6.3 `.env.example`

- Remplacer les clés live par des placeholders (`SUPABASE_URL=your_url_here`).
- S'assurer que `.env` est bien dans le `.gitignore` des 3 apps.

### 6.4 Documentation

- Mettre à jour le README :
 - Architecture du monorepo avec le package shared.
 - Guide de configuration locale (`.env`, Supabase, backend Node).
 - Roadmap mise à jour.
- Documenter dans `docs/architecture.md` :
 - Couche d'accès aux données (Repository pattern).
 - State management choisi.
 - Diagramme des dépendances du monorepo.

---

## 📅 Résumé — Ordre d'exécution

```
┌─────────────────────────────────────────────────────────────────┐
│  Phase 1  Sécurité Critique        1-2 j   🔴 CRITIQUE         │
│  ├─ Rotater les clés exposées                                         │
│  ├─ .env → .gitignore                                                  │
│  └─ Unifier la lecture de config                                      │
├─────────────────────────────────────────────────────────────────┤
│  Phase 2  Package Partagé         3-5 j   🟠 HAUTE PRIORITÉ     │
│  ├─ Créer elcora_shared                                                 │
│  ├─ Déplacer modèles, services, formatters                             │
│  ├─ Unifier versions de dépendances                                    │
│  └─ Supprimer les copies locales                                       │
├─────────────────────────────────────────────────────────────────┤
│  Phase 3  God Classes             5-7 j   🟡 MOYENNE            │
│  ├─ Splitter les écrans >1000 lignes                                   │
│  ├─ Supprimer 24+ fichiers redondants (enhanced_/advanced_)            │
│  ├- Migrer vers Repository (supprimer database_service.dart)            │
│  └- Désaccoupler AppService (18 imports → 4 sous-services)              │
├─────────────────────────────────────────────────────────────────┤
│  Phase 4  Qualité du Code          3-4 j   🟡 MOYENNE           │
│  ├─ Gestion d'erreurs structurée (1303 catch, 2133 debugPrint)         │
│  ├- 33 parse() → tryParse                                             │
│  ├- setState + mounted guards                                         │
│  ├- Casts sûrs dans les routeurs                                       │
│  ├- Décision Riverpod vs Provider                                     │
│  └─ Centraliser le schéma SQL                                         │
├─────────────────────────────────────────────────────────────────┤
│  Phase 5  Tests & CI              3-4 j   🟢 IMPORTANT          │
│  ├─ Tests unitaires sur le package shared                             │
│  ├─ Tests de mock sur les services                                    │
│  ├- Widget tests des parcours critiques                               │
│  ├- Pipeline CI (analyze + test)                                      │
│  └- Harmoniser analysis_options.yaml                                  │
├─────────────────────────────────────────────────────────────────┤
│  Phase 6  Polish                  1-2 j   🟢 FAIBLE             │
│  ├- Renommer les assets corrompus                                    │
│  ├- Unifier main.dart / main_web.dart (admin)                         │
│  ├- Netoyer .env.example                                              │
│  └- Mettre à jour la documentation                                    │
└─────────────────────────────────────────────────────────────────┘
                                                                    │
                  Total estimé : 16-24 jours de travail               │
└─────────────────────────────────────────────────────────────────┘
```

---

## Checklist de démarrage

### Avant de toucher au code

- [ ] Backup complet du dépôt (branch `refs/refactoring-backup`)
- [ ] Créer un projet Kanban / tableau de suivi (GitHub Projects recommandé)
- [ ] Décider Riverpod vs Provider (impacter toute la Phase 4)
- [ ] Rotater les clés exposées (même avant de commencer à coder)

### Première itération (Sprint 1)

- [ ] Phase 1.1 — Securer les secrets
- [ ] Phase 1.2 — Clés PayDunya
- [ ] Brancher le package shared vide, le déclarer dans les 3 `pubspec.yaml`
- [ ] Mettre en place le pipeline CI minimale (`flutter analyze` + `flutter test`)

---

*Ce document est vivant. Chaque phase doit être mise à jour au fur et à mesure de l'avancement.*
