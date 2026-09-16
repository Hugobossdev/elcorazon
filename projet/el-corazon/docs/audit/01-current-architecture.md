# 01 — Architecture actuelle

> Relevé du 11 septembre 2026, sur `redesign-client-ui` à `50d0cea`.
> **Source de vérité : le code et les migrations.** Les documents existants
> (`README.md`, `ETAT_FONCTIONNALITES.md`, `SCHEMA_BDD_COMPLET.md`) ont servi de
> carte, jamais de preuve.

---

## 1. Ce que le dépôt contient réellement

| Composant | Chemin | Volume |
|---|---|---|
| Backend Django | `backend/` | 39 464 lignes Python, 20 apps, 51 migrations |
| Tests backend | `backend/tests/` | 28 599 lignes, 99 fichiers, **1 695 cas** |
| Application client | `apps/fastfood/` | 49 802 lignes Dart |
| Application livreur | `apps/dely/` | 19 424 lignes Dart |
| Back-office | `apps/admin/` | 41 711 lignes Dart |
| Socle partagé Flutter | `packages/elcorazon_core/` | 14 960 lignes Dart |

Total : **≈ 166 000 lignes** de code applicatif, hors migrations et générés.

Le plancher de couverture est posé à `fail_under = 92` dans
`backend/pyproject.toml:282`. La CI (`backend/.github/workflows/backend-ci.yml`)
enchaîne `ruff check`, `ruff format --check`, `mypy --strict` sur
`common config apps`, puis les tests sur PostGIS 17-3.5 et Redis.

**Conclusion préliminaire, et elle oriente tout le reste de cet audit : il ne
s'agit pas d'un prototype.** Le brief de refonte suppose un système truffé de
données simulées et de logique contradictoire. La mesure ne le confirme pas :

```
grep -rn "TODO|FIXME|HACK|XXX"  backend/apps backend/common backend/config  →  0
grep -rn "TODO|FIXME"           apps/*/lib packages/*/lib                    →  0
grep -rln "mock|fake|dummy"     apps/*/lib packages/*/lib                    →  0 fichier
```

Le travail à faire n'est donc pas un redressement. C'est une **extension du
domaine** vers ce qu'une dark kitchen exige et que ce code n'a jamais eu.

---

## 2. Le graphe de domaine, tel qu'il est en base

```
Country ──< City ──< DeliveryZone ──< Restaurant
                                          │
                            ┌─────────────┼──────────────┬──────────────┐
                            │             │              │              │
                       Category ──< MenuItem        StaffMembership  OpeningHours
                                        │                            
                                  OptionGroup ──< Option             
                                        
Restaurant ──< Cart ──< CartLine ──< CartLineOption
Restaurant ──< Order ──< OrderLine            Order ──< OrderStatusEvent
                           │
              Order ──< Transaction ──< Refund          Order ──1 SplitPayment ──< SplitShare
              Order ──< Assignment >── CourierProfile ──< CourierShift
```

`AreaMembership` (pays **ou** ville, contrainte `CHECK` exclusive) complète
`StaffMembership` pour le cloisonnement à trois étages : siège / périmètre
géographique / établissement.

### Ce que ce graphe n'a pas

Vérifié par recherche exhaustive sur `backend/apps`, `backend/common`,
`backend/config` — **zéro occurrence** de chacun :

`Ingredient` · `Recipe` · `RecipeIngredient` · `Inventory` · `StockMovement` ·
`Station` · `ProductionTask` · `Menu` (l'entité) · `Variant` · `Kitchen`

Le stock se résume à deux colonnes sur `MenuItem`
(`backend/apps/catalog/models.py:110-126`) : `tracks_stock` et
`stock_quantity`. La décrémentation est correcte — `UPDATE ... WHERE
stock_quantity >= n` évalué par la base, sans lecture préalable
(`backend/apps/catalog/services.py:73-74`) — mais elle compte des **plats
finis**, jamais des ingrédients. Une cuisine qui partage un pain entre trois
burgers ne peut rien en dire.

C'est l'écart central de ce projet et le sujet des documents 02, 03 et 10.

---

## 3. Couches backend

Le découpage suit les ADR de `docs/architecture/adr/` et il est tenu :

```
views.py        HTTP, permissions, sérialisation       — aucune règle métier
serializers.py  contrat d'entrée/sortie
services.py     règles métier, transactions, verrous   — le cœur
states.py       machines à états déclaratives
queries.py      accès lecture optimisé
models.py       schéma + invariants en contraintes
```

Trois mécanismes transverses méritent d'être nommés, parce qu'ils portent la
robustesse de l'ensemble :

**`common/state_machine.py`** — les transitions sont déclarées en table, le
graphe est validé à l'import (un cycle ou une cible inconnue fait échouer le
démarrage, donc la CI), et `state_check_constraint()` **génère la contrainte
`CHECK` PostgreSQL depuis la même table**. Le schéma ne peut pas accepter un
statut que le code ignore. C'est la bonne façon de faire, et elle est rare.

**`common/money.py`** — montants en entiers mineurs (`MoneyField` →
`*_minor`), jamais en flottant, devise portée par le pays.

**`common/observabilite.py`** — `MiddlewareDIdentifiant` pose un identifiant de
corrélation, `FiltreDeCorrelation` l'injecte dans chaque enregistrement de log.
`/health/` (liveness, sans base) et `/ready/` (readiness, avec base et cache)
sont distincts et documentés dans `backend/config/urls.py:31-92`.

---

## 4. Surface d'API

Tout est monté sous `/api/v1/` (`backend/config/urls.py:167`), schéma OpenAPI
publié par drf-spectacular. Vingt préfixes fonctionnels : `auth`,
`administration`, `geography`, `restaurants`, `catalog`, `profiles`, `carts`,
`group-carts`, `promotions`, `orders`, `payments`, `delivery`, `tracking`,
`calls`, `notifications`, `loyalty`, `gamification`, `social`, `support`,
`analytics`, `search`.

Six canaux WebSocket (`backend/config/routing.py`) :

```
ws/orders/<uuid>/tracking/        suivi client
ws/orders/<uuid>/chat/            messagerie commande
ws/group-carts/<uuid>/            panier partagé
ws/couriers/me/                   flux livreur
ws/me/                            flux utilisateur
ws/restaurants/<uuid>/dashboard/  flux établissement — alimente le poste de cuisine
```

Sept tâches Celery, réparties sur `groupcarts`, `loyalty`, `notifications`,
`orders`, `tracking`.

---

## 5. Le socle Flutter

`packages/elcorazon_core` expose 29 domaines de dépôts et de modèles partagés
par les trois applications ; 216 fichiers Dart l'importent. La séparation
dépôt / écran est réelle, et `apps/fastfood/lib/presentation/` isole dix-huit
modules de logique de présentation testables hors widget.

**Un seul domaine partagé est réellement partagé côté design** :
`packages/elcorazon_core/lib/src/design/` ne contient que `emojis`. Les
couleurs, la typographie et les espacements sont réécrits dans chaque
application — 1 975 lignes réparties sur six fichiers. Voir document 05.

---

## 6. Lecture d'ensemble

Le socle technique est solide et, par endroits, meilleur que la moyenne du
secteur : machines à états contraintes en base, verrous explicites sur tous les
chemins financiers, idempotence des commandes et des webhooks, cloisonnement à
trois étages, montants entiers, typage strict, 1 695 cas de test.

Ce qui manque n'est pas de la qualité. C'est un **étage de domaine** : la
production. Le système sait vendre un plat et le faire livrer ; il ne sait pas
le **fabriquer**. Tant que « préparer » reste un simple changement de statut
sans consommation de matière ni ordonnancement de poste, El Corazón est une
place de marché de restauration, pas une dark kitchen.
