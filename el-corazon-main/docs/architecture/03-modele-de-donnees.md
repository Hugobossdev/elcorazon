# Phase 3 — Modèle de données

**Statut** : en cours · **Date** : 2026-07-25 · **Entrée** : [Phase 2](02-architecture-generale.md)

Le schéma n'est pas une transposition de l'existant. L'ancien modèle Supabase
(45 tables) sert de référence fonctionnelle ; sa structure, elle, est refaite —
notamment parce qu'il n'a ni hiérarchie géographique, ni notion d'établissement,
ni devise sur les montants.

---

## 1. Principes appliqués partout

| Principe | Mise en œuvre | ADR |
|---|---|---|
| Clé primaire opaque et ordonnée | `UUIDModel` — UUIDv7 sur tous les modèles métier | 007 |
| Montants exacts et situés | `MoneyField` — `<champ>_minor BIGINT` + `<champ>_currency CHAR(3)` | 007 |
| Le schéma est la dernière ligne de défense | `CheckConstraint` générée depuis la machine à états | 010 |
| Rattachement géographique dès l'origine | Clé `restaurant` **non nulle** sur commandes, catalogue, flotte | 006 |
| Traçabilité | `created_at` / `updated_at` sur toute entité mutable | — |

### Suppression : dure ou logique

La suppression logique (`SoftDeleteModel`) est réservée aux entités auxquelles
une **écriture comptable renvoie**. Un article retiré du catalogue doit rester
lisible depuis les commandes passées, sinon l'historique devient incohérent.

À l'inverse, une adresse supprimée par un client l'est réellement : le RGPD
impose un droit à l'effacement, et une adresse ne porte aucune écriture
financière — la commande, elle, en conserve une copie figée.

> Le critère est : *une écriture financière y renvoie-t-elle ?* Pas
> « est-ce important ? », qui conduirait à ne jamais rien supprimer.

---

## 2. Ce qui est livré

### `accounts` — identité et accès

```
User          id, email✦, phone✦, full_name, user_type, avatar,
              is_active, is_superuser, email_verified_at, phone_verified_at,
              last_seen_at, password
Role          id, name✦, description, permissions[], is_system
User↔Role     table de liaison
Device        id, user→, token✦, platform, last_used_at
```

`user_type` ∈ `customer | courier | staff`. Les permissions (`ArrayField`) ne
sont lues que pour le personnel — un rôle attaché par erreur à un compte client
n'accorde rien, ce qui est vérifié par test.

Contrainte notable : `superuser_is_staff` — un superutilisateur ne peut pas être
d'un autre type. Elle empêche en base ce que le gestionnaire empêche en Python.

`Device` porte un `token` **unique globalement**, non pas unique par
utilisateur : c'est ce qui réattribue correctement un téléphone qui change de
compte. Sans cela, deux comptes s'abonnent au même appareil et le second reçoit
les notifications du premier.

### `geography` — socle multi-pays

```
Country       id, iso_code✦, name, currency, phone_prefix, timezone,
              default_language, is_active
City          id, country→, name, slug, centroid:point(geography), is_active
              unique(country, slug)
DeliveryZone  id, city→, name, boundary:multipolygon(geography),
              base_fee, fee_per_km, free_delivery_threshold?, min_order_amount?,
              max_distance_km, estimated_delivery_minutes, is_active
              unique(city, name) · index GiST sur boundary
```

Trois choix méritent justification.

**`geography` et non `geometry`.** PostGIS raisonne alors sur l'ellipsoïde : une
distance sort directement en mètres, sans projection à choisir, et sans erreur
qui croît avec la latitude. Le produit vise plusieurs pays d'Afrique de l'Ouest ;
une projection locale figée deviendrait fausse au premier pays suivant.

**`MultiPolygon` et non `Polygon`.** Une zone réelle est fréquemment discontinue —
un fleuve, une voie ferrée, une enclave non desservie la coupent. Le test
`test_une_zone_peut_etre_discontinue` vérifie que le corridor entre deux
morceaux n'est pas livrable.

**Un barème, pas une constante.** L'existant portait `delivery_fee` à `5.00` sur
la commande et `500.0` sur le panier — deux valeurs contradictoires, sans devise,
ce qui trahissait l'absence de toute règle. La zone porte désormais un tarif de
base, un tarif kilométrique, un éventuel seuil de franco et un plafond de
distance. `max_distance_km` est distinct du contour : un point peut être dans le
polygone tout en étant trop loin du restaurant.

### `restaurants` — point de rattachement du multi-site

```
Restaurant    id, name, slug✦, description, zone→, address,
              location:point(geography), phone, email, cover_image,
              is_active, accepts_orders, default_preparation_minutes
              index GiST sur location
OpeningHours  id, restaurant→, weekday, opens_at, closes_at
              unique(restaurant, weekday, opens_at)
```

`is_active` et `accepts_orders` sont volontairement distincts. Le premier est
structurel — l'établissement existe-t-il ? — le second conjoncturel : un coup de
feu en cuisine, une panne de four. Les confondre obligerait à désactiver un
restaurant pour suspendre les commandes une heure, ce qui le ferait disparaître
de l'application.

`Weekday` est aligné sur `date.weekday()` (lundi = 0), ce qui supprime la
conversion manuelle qui est la source classique du décalage d'un jour.

Une plage franchissant minuit est représentée par `closes_at < opens_at` plutôt
que par deux plages sur deux jours — la saisie reste conforme à ce qu'un
restaurateur a en tête.

---

## 3. Ce qui vient ensuite

| App | Entités | Points d'attention |
|---|---|---|
| `profiles` | `Address`, `Preference` | Suppression **dure** (RGPD) ; la commande garde une copie figée de l'adresse |
| `catalog` | `Category`, `MenuItem`, `OptionGroup`, `Option`, `Review` | Prix relus serveur (C1) ; `is_verified_purchase` calculé serveur (S1) |
| `inventory` | `StockItem`, `StockMovement` | Décrément lié au cycle de commande — absent de l'existant |
| `carts` | `Cart`, `CartItem` | Revalidation des prix à chaque lecture ; fusion invité → client |
| `orders` | `Order`, `OrderLine`, `StatusEvent`, `IdempotencyKey` | Machine à états + `CHECK` ; devise figée ; clé d'idempotence (ADR-009) |
| `payments` | `Transaction`, `SplitPayment`, `SplitShare`, `Refund` | Part adossée à une transaction vérifiée (P2) ; remboursement plafonné (P3) |
| `delivery` | `CourierProfile`, `Assignment` | Verrou d'acceptation (L2) ; dossier repassé en `pending` (L5) |
| `tracking` | `LocationPing` | Écriture échantillonnée ; partitionnement à prévoir |

---

## 4. Index — ce qui est indexé et pourquoi

Un index se justifie par une requête réelle, pas par principe.

| Index | Requête servie |
|---|---|
| GiST sur `DeliveryZone.boundary` | Résoudre la zone d'un point au passage de commande. Sans lui, chaque commande balaie toute la table. |
| GiST sur `Restaurant.location` | Distance restaurant → client pour le calcul de frais et l'ETA. |
| `(user_type, is_active)` sur `User` | Listes du back-office : clients actifs, livreurs en ligne — deux filtres toujours combinés. |
| `(user, -last_used_at)` sur `Device` | Résolution des appareils d'un destinataire à chaque notification. |
| `(city, is_active)` sur `DeliveryZone` | Zones desservies d'une ville. |
| `created_at` (via `TimeStampedModel`) | Tris chronologiques. Redondant avec la clé primaire UUIDv7 sur la plupart des tables — à retirer si le volume le justifie. |

---

## 5. Vérification

Le schéma géospatial n'est pas vérifiable par approximation : c'est PostGIS qui
répond, pas Python. Les tests correspondants portent le marqueur `postgis` et
s'exécutent contre le conteneur `postgis/postgis:17-3.5` — en local via
`docker compose up -d db`, et en CI via un service GitHub Actions.
