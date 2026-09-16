# 06 — Audit de l'API

98 routes déclarées, toutes sous `/api/v1/` (`backend/config/urls.py:167`),
réparties sur 21 préfixes fonctionnels. Six canaux WebSocket.

**Verdict : le contrat est le volet le plus abouti du backend.** Rien à refondre.
Ce document sert surtout à établir les règles que les routes du lot 2 devront
respecter, plutôt qu'à corriger l'existant.

---

## 1. Conventions tenues

### Format d'erreur — RFC 9457

`backend/common/exceptions.py` implémente `application/problem+json` (ADR-009),
avec une discipline rare : `RESERVED_MEMBERS` interdit à une exception métier de
réutiliser un membre réservé de la RFC (`code`, `detail`, `errors`, `headers`,
`status`, `title`, `type`). Une collision lève à la construction, pas en
production.

La distinction entre `code` (stable, machine) et `detail` (traduisible,
susceptible de changer sans préavis) est explicitée — c'est ce qui permet à
Flutter de brancher un comportement sur `code` sans dépendre d'une phrase
française.

Hiérarchie métier : `BusinessRuleViolation` → 409, avec `InsufficientStock`,
`InsufficientBalance`, `ConcurrentModification`, `RequestInFlight`,
`IncompleteConfiguration`. Un refus métier n'est jamais rendu en 400 générique,
et le client peut distinguer « impossible maintenant » de « mal formé ».

### Pagination — bornée

`common/pagination.py` :

| Classe | Taille | Plafond |
|---|---|---|
| `StandardPagination` | 20 | **100** |
| `HighVolumeCursorPagination` | 50 | **200** |

Le plafond est le point qui compte : sans `max_page_size`, `?page_size=100000`
transforme n'importe quelle liste en déni de service. Il est posé.

Le curseur pour les gros volumes (mouvements, journaux) est le bon choix : la
pagination par numéro de page dégrade en `OFFSET` lointain.

### Permissions — garanties par la CI

Trois tests d'architecture (`tests/architecture/test_layers.py`) :

```
test_aucune_route_n_est_sans_permission
test_la_liste_des_routes_ouvertes_est_exactement_celle_declaree
test_les_vues_a_permissions_dynamiques_sont_declarees
```

**La liste des routes publiques est déclarée et vérifiée.** Publier une route
sans permission casse le build. C'est la garantie la plus utile de tout l'audit,
et elle vaudra automatiquement pour les routes du lot 2.

### Idempotence — sur les deux chemins qui comptent

| Chemin | Mécanisme | Tests |
|---|---|---|
| Création de commande | `IdempotencyKey` (clé, utilisateur, endpoint) + corps rejoué | `test_un_rejeu_ne_cree_pas_une_seconde_commande`, `test_la_cle_est_prise_avant_toute_ecriture`, `test_deux_clients_peuvent_tirer_la_meme_cle` |
| Webhook prestataire | `WebhookEvent.event_id` + `provider_reference` unique | `test_le_meme_evenement_ne_passe_pas_deux_fois`, `test_un_rejeu_ne_rejoue_rien` |

`test_la_cle_est_prise_avant_toute_ecriture` mérite d'être signalé : il vérifie
l'ordre, pas seulement le résultat. Une clé posée après l'écriture laisserait
une fenêtre où deux requêtes concurrentes créent deux commandes avant que l'une
ne réserve la clé. C'est le défaut classique de l'idempotence naïve, et il est
testé.

### Schéma — publié

drf-spectacular sur `/api/v1/schema/`. `config/settings/base.py:393-397` nomme
explicitement les énumérations pour éviter les `Status5c8Enum` que le générateur
produit par défaut — un client généré depuis ce schéma a des types lisibles.

Des tests de contrat existent (`tests/contract/test_api_contract.py`,
`test_cors.py`).

---

## 2. Le temps réel — six canaux, six usages

```
ws/orders/<uuid>/tracking/         suivi client
ws/orders/<uuid>/chat/             messagerie de commande
ws/group-carts/<uuid>/             panier partagé
ws/couriers/me/                    flux livreur
ws/me/                             flux utilisateur
ws/restaurants/<uuid>/dashboard/   flux établissement — alimente le KDS
```

La phase 27 du brief demande de ne pas ouvrir de WebSocket inutilement. Chacun
de ces six a un consommateur identifié. Aucun canal spéculatif.

L'authentification est faite **avant** l'acceptation de la connexion, avec des
codes de fermeture distincts pour « non authentifié » et « interdit »
(`common/consumers.py:51-59`) — le client peut donc réagir différemment à une
session expirée et à un accès refusé, au lieu de boucler sur une reconnexion qui
ne réussira jamais.

---

## 3. Les trois réserves

Aucune n'est bloquante. Toutes concernent l'extension à venir.

### R1 — Le KDS n'a pas de route dédiée, et c'est provisoirement juste

`42f24b0` a livré le poste de cuisine **sans ajouter de route serveur**, en
réemployant `ws/restaurants/<id>/dashboard/` et
`POST /orders/manage/<id>/status/`. Le commit en fait un argument, et il a
raison : `Order.allowedTransitions` est calculé par le serveur, donc la machine
à états n'est pas rejouée côté client — ce qui évite d'avoir trois écrans, trois
`switch` et trois trous différents.

**Cette économie cesse d'être juste au lot 2.** Une file de production par poste
n'est pas une liste de commandes filtrée : elle porte des tâches, leurs
dépendances et leur poste d'affectation. Le canal `dashboard` ne peut pas la
transporter sans devenir un fourre-tout.

À prévoir : `ws/kitchens/<id>/production/`, distinct, avec son propre contrat.
Pas avant que `ProductionTask` existe.

### R2 — Pas de route de disponibilité composée — *traité au lot 1*

Aucun endpoint ne répondait à « ce client peut-il commander cet article
maintenant, et sinon pourquoi ». Flutter interrogeait le catalogue,
l'établissement et la zone séparément, puis recomposait.

C'est l'incohérence I2 du document 03 vue depuis le transport.

**Ce qui a été fait, et en quoi cela diverge de ce qui était proposé.** Le juge
existe (`apps.availability`) et rend partout **un verdict et un motif stable**
(`unavailable_code`, `unavailable_reason`). Mais il ne s'expose pas par une route
de plus : il répond **sur les routes que les applications lisent déjà**.

| Route | Ce qu'elle porte désormais |
|---|---|
| `GET /restaurants/`, `/restaurants/<slug>/` | `can_order_now` rendu par le juge, et son motif |
| `GET /catalog/items/`, `/catalog/items/<id>/` | `is_available` **devient le verdict** — matière comprise —, et son motif |
| `GET /carts/<slug>/`, `/group-carts/<id>/` | motif de la cuisine sur le panier, motif de chaque ligne |
| `POST /orders/preview/` | premier motif bloquant |
| `POST /orders/` | refus `409 kitchen_not_orderable`, ou `unavailable_codes` par ligne |

Une route dédiée aurait obligé l'application à fusionner deux réponses — la
carte d'un côté, les verdicts de l'autre —, c'est-à-dire à recomposer encore.
Et elle n'aurait servi qu'aux applications mises à jour : porter le verdict sur
`is_available`, que les applications installées lisent déjà pour griser un plat,
retire un plat en rupture de leur écran **sans attendre leur mise à jour**.

### R3 — Versionnement présent, dépréciation absente

`/api/v1/` existe, mais aucune convention n'est écrite pour retirer une route.
La question se posera au lot 3, quand l'entité `Menu` changera la forme du
catalogue : les trois applications Flutter ne se mettent pas à jour le même
jour, et un client ancien doit continuer de fonctionner.

À décider **avant** le lot 3, pas pendant : un en-tête `Sunset`, une durée de
survie, et un test qui vérifie qu'une route dépréciée l'annonce.

---

## 4. Règles pour les routes du lot 2

Ce que les nouvelles routes devront respecter, pour rester homogènes :

1. **Permission déclarée** — sinon la CI casse, ce qui est le comportement voulu.
2. **Cloisonnement par cuisine** dans `get_queryset()`, au même titre que les
   commandes. Un mouvement de stock est aussi sensible qu'une commande.
3. **Erreurs en RFC 9457**, avec un `code` stable. `InsufficientStock` existe
   déjà et servira tel quel.
4. **Pagination par curseur** pour `StockMovement` — c'est un journal, il ne
   cesse pas de grandir.
5. **Idempotence sur les écritures de valeur** — une réception de marchandise
   rejouée ne doit pas créditer deux fois. Le mécanisme d'`IdempotencyKey`
   existe ; il n'est aujourd'hui branché que sur la commande.
6. **Aucune règle métier dans la vue.** `test_les_services_ne_connaissent_pas_le_transport`
   veille déjà sur le sens inverse.

**État au lot 2-bo.** Les six règles sont tenues par les routes
`/inventory/manage/*` et `/production/manage/recipes/*`, avec une nuance sur la
cinquième : le mécanisme d'`IdempotencyKey` vit dans `orders` et pointe vers une
commande, si bien que l'inventaire ne peut pas l'importer. Les écritures de
stock portent donc leur propre clé (`request_key`), arbitrée par une contrainte
d'unicité, et l'en-tête `Idempotency-Key` est **exigé** sur une réception, une
perte et une correction. Une réponse rejouée n'est pas mémorisée comme pour la
commande : le serveur rend l'écriture d'origine, relue en base.

Un défaut du socle est apparu en écrivant ces routes : `DimensionMismatch`
n'étant pas une erreur métier, « 20 ml » d'un ingrédient pesé sortait en **500**.
Il sort désormais en `400 dimension_mismatch`, par le gestionnaire commun.

---

## Synthèse

| Volet | État |
|---|---|
| Versionnement | `/api/v1/` — **présent**, dépréciation à définir (lot 3) |
| Format d'erreur | RFC 9457, membres réservés protégés — **abouti** |
| Pagination | bornée, curseur disponible — **abouti** |
| Permissions | garanties par la CI — **abouti** |
| Idempotence | commande + webhook, ordre testé — **abouti** |
| Schéma | OpenAPI publié, énumérations nommées — **abouti** |
| WebSocket | 6 canaux, 6 usages, auth avant acceptation — **abouti** |
| Disponibilité | verdict et motif sur les routes existantes — **lot 1, fait** |
| Back-office inventaire et recettes | permissions, cloisonnement, refus testés — **lot 2-bo, fait** |
| Canal production | **manquant** — lot 2 |

Rien ne justifie de refondre cette API. Elle doit **s'étendre selon ses propres
règles**, qui sont bonnes et pour l'essentiel vérifiées automatiquement.
