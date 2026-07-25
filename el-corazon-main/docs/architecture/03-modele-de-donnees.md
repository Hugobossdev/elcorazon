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

### `catalog`, `carts`, `orders`, `payments`, `delivery`, `tracking`

Le reste du chemin critique. Plutôt que d'énumérer les colonnes, voici les
endroits où la **structure** porte un invariant — c'est là que se joue l'écart
avec l'implémentation précédente.

| Invariant | Mécanisme structurel |
|---|---|
| **C1** — le prix ne vient jamais du client | `carts` **ne possède aucune colonne de montant**. Le panier retient l'article, les options et la quantité ; le prix est relu au catalogue. Ne pas avoir la colonne est plus solide que de la valider. |
| **C2** — les montants d'une commande sont figés | `OrderLine` copie `item_name`, `unit_price` et les options. Un article renommé, repricé ou retiré du catalogue laisse la commande intacte. |
| **C4** — code et schéma ne divergent pas | `state_check_constraint(ORDER_MACHINE, …)` génère la contrainte `CHECK` **depuis la machine à états**. Une origine unique, donc aucune divergence possible. |
| — remise plafonnée | `order_discount_within_bounds` : au-delà du dû, le total deviendrait négatif et la commande rapporterait de l'argent au client. |
| **P1** — webhook idempotent | Unicité de `(provider, event_id)`. Un rejeu concurrent est arrêté par la base, pas par un `if déjà_traité` que deux workers franchiraient ensemble. |
| **P2** — part de paiement adossée à une transaction | `settled_share_requires_transaction` : une part `completed` sans transaction est **refusée en base**. C'est la faille de la commande gratuite, traitée à la racine et non par une restriction d'accès. |
| **L2** — acceptation exclusive | `one_active_assignment_per_order`, index unique partiel. Tient même si le verrou applicatif est contourné. |
| **L3** — pas de falsification du suivi | `LocationPing` est rattaché à une **course**, pas à un livreur : impossible d'écrire pour une commande qu'on ne dessert pas. |
| **S1** — « achat vérifié » calculé serveur | `editable=False` : le champ ne peut venir ni d'un formulaire, ni d'un sérialiseur généré. |
| **S5** — un avis par article et par client | `UniqueConstraint(menu_item, user)`. |

Deux choix qui méritent d'être explicités.

**Le panier vit dans `carts`, pas dans `orders`.** C'est un état éphémère,
réécrit en permanence ; la commande est une écriture comptable définitive. Les
héberger ensemble mélangerait deux cycles de vie opposés.

**Les options du panier sont des clés étrangères, celles de la commande du
JSON.** Ce n'est pas une incohérence : au panier, les options doivent être
revalidées — existent-elles encore, sont-elles disponibles, respectent-elles
les bornes de leur groupe ? Une clé étrangère rend cette vérification triviale.
À la commande, ce sont des copies figées, qui ne doivent plus rien à l'état du
catalogue.

**Le dossier livreur est la seule machine cyclique du produit**
(`require_acyclic=False`) : un dossier se ré-instruit après modification des
pièces (L5), quand une commande ne se re-livre pas.

### Vérification

Chaque contrainte est couverte par un test qui **contourne délibérément la
couche applicative** — `QuerySet.update()`, qui n'appelle ni `save()`, ni
`full_clean()`, ni le moindre code métier. Si la base laisse passer, l'invariant
n'est pas réellement tenu.

## 3. Ce qui vient ensuite

| App | Entités | Points d'attention |
|---|---|---|
| `inventory` | `StockItem`, `StockMovement` | Décrément lié au cycle de commande — absent de l'existant |
| `notifications` | `Notification`, `Preference` | Canal transactionnel jamais coupé par les préférences marketing |
| `promotions` | `Promotion`, `PromotionUsage` | Quota global **et** par utilisateur (F4) |
| `loyalty` | `PointsLedger`, `Reward`, `Redemption`, `Subscription` | Journal immuable (F5) ; débit conditionnel atomique (F1) ; catalogue de plans tarifés serveur (P4) |
| `gamification`, `social`, `support`, `analytics` | — | Second temps, après la mise en service du chemin critique |

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
