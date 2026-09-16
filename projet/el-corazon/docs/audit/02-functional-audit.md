# 02 — Audit fonctionnel

Statuts employés : `PRODUCTION_READY` · `EXISTS` · `PARTIAL` · `BROKEN` ·
`MOCKED` · `DUPLICATED` · `INCONSISTENT` · `MISSING`.

`PRODUCTION_READY` n'est accordé qu'à ce qui est **implémenté côté serveur,
contraint en base, couvert par des tests, et consommé par une interface
réelle**. `EXISTS` signale ce qui fonctionne mais dont un maillon manque.

---

## Cycle de valeur — DISCOVER → ORDER → PAY → PRODUCE → PACK → DELIVER → TRACK

| Étape | Statut | Preuve |
|---|---|---|
| DISCOVER | `PRODUCTION_READY` | `catalog`, `search` (180 l. de service, 12 tests), `geography` |
| ORDER | `PRODUCTION_READY` | machine à états + `CHECK` généré, idempotence, instantané de ligne |
| PAY | `PRODUCTION_READY` | webhook signé et idempotent, verrous, remboursements |
| **PRODUCE** | **`MISSING`** | **aucune entité de production — voir §3** |
| **PACK** | **`MISSING`** | **aucune étape d'assemblage ni de conditionnement** |
| DELIVER | `PRODUCTION_READY` | affectation atomique, preuve de livraison, tarification zone |
| TRACK | `PRODUCTION_READY` | `ws/orders/<id>/tracking/`, 48 tests |

**Le cycle est rompu en son milieu.** Cinq des sept étapes sont solides — mais
`PRODUCE` et `PACK`, qui sont la raison d'être d'une dark kitchen, n'existent
pas comme domaine.

---

## 1. Socle — commande, paiement, livraison

### Commande — `PRODUCTION_READY`, avec une réserve de nommage

`backend/apps/orders/`

- Machine à états déclarative (`states.py`), graphe validé à l'import.
- `state_check_constraint(ORDER_MACHINE, "status", ...)` — la contrainte
  PostgreSQL est **générée depuis la table de transitions**. Le schéma ne peut
  pas diverger du code.
- Instantané complet sur `OrderLine` : `item_name`, `item_image`, prix
  unitaire, options et leurs prix figés (`models.py:138-171`). Modifier le
  catalogue ne réécrit pas l'historique. **Phase 10 du brief : déjà satisfaite.**
- Adresse copiée, pas référencée — survit à une suppression RGPD.
- `IdempotencyKey` (clé, utilisateur, endpoint) avec corps de réponse rejoué.
- `OrderStatusEvent` journalise chaque transition avec son acteur.
- Trois contraintes `CHECK` sur les montants, dont
  `discount ≤ subtotal + delivery_fee`.

**Réserve.** Les états sont `pending → confirmed → preparing → ready →
picked_up → on_the_way → delivered`. Le brief demande `PENDING_PAYMENT → PAID →
CONFIRMED → QUEUED`. La différence est réelle mais **modeste** : `pending`
couvre déjà l'attente de paiement, et `confirmed` est posé par
`PaymentService._confirm_order` (`payments/services.py:349`). Ce qui manque
vraiment est `QUEUED` — l'état « acceptée, en file de production » — et il n'a
de sens qu'une fois la production existante. À traiter avec elle, pas avant.

### Panier — `PRODUCTION_READY`

`backend/apps/carts/` — **le panier ne stocke aucun prix.** `Cart`, `CartLine`,
`CartLineOption` ne portent que produit, quantité, options, note. Le prix est
recalculé à **chaque lecture** depuis le catalogue (`services.py:143-184`).

C'est exactement la cible de la phase 11 du brief, et elle est déjà en place. Le
prix envoyé par Flutter n'est pas « ignoré » : il n'est pas envoyé du tout.

### Paiement — `PRODUCTION_READY`

`backend/apps/payments/` — `Transaction`, `WebhookEvent`, `SplitPayment`,
`SplitShare`, `Refund`, `Withdrawal`.

- Webhook authentifié par **signature du corps**, pas par jeton porteur
  (`views.py:1-10`).
- `WebhookEvent` avec `event_id` et `signature_verified` : rejouer le même
  événement ne produit pas un second encaissement.
- `select_for_update()` sur toutes les écritures d'argent — initiation, reprise
  de webhook, remboursement, règlement, retrait livreur.
- `provider_reference` unique : le prestataire ne peut pas créer deux fois la
  même transaction.
- Paiement partagé : une part n'est réglée que liée à une `Transaction` vérifiée
  (`SplitShare.transaction`, OneToOne). **Phase 18 : satisfaite.**

### Livraison et livreurs — `PRODUCTION_READY`

`backend/apps/delivery/` — `CourierProfile`, `Assignment`, `CourierRating`,
`CourierShift`.

- `AssignmentService.accept` verrouille la commande **avant** de lire
  l'affectation (`services.py:481-490`) : deux livreurs ne peuvent pas accepter
  la même course. **Phase 16 : satisfaite.**
- `_engaged_for` interdit l'engagement concurrent sur une course incompatible.
- Vérification de profil (`verification_status`, pièces justificatives,
  validateur et horodatage).
- `delivery_fee_gross` distingué de `delivery_fee` : la commission du livreur se
  calcule sur la **valeur** de la course, pas sur ce que le client paie après
  franco. Détail rare, et juste.

### Géographie et multi-pays — `PRODUCTION_READY`

`Country → City → DeliveryZone → Restaurant`, tous les maillons en clé étrangère
non nulle. Devise, fuseau, préfixe et langue portés par `Country` ; `Restaurant`
les **hérite** par propriété et ne peut pas les contredire. PostGIS pour les
frontières, index GiST sur `location`. Conversion centre/rayon → polygone à
64 côtés en place.

Aucun `XOF`, `GMT` ni nom de pays codé en dur dans la logique métier — le
commit `9cb4596` a précisément traité ce défaut. **Phase 14 : satisfaite.**

---

## 2. Établissement — `EXISTS`, à étendre

`backend/apps/restaurants/models.py`

Déjà conforme à une partie de la phase 2 du brief :

- Machine à états à cinq états — `DRAFT`, `CONFIGURING`, `READY`, `ACTIVE`,
  `INACTIVE` (« Suspendu ») — avec garde de complétude : `IncompleteConfiguration`
  rend la **liste** de ce qui manque, pas un booléen.
- **`is_active` séparé de `accepts_orders`** — et pour la bonne raison, écrite
  dans le code : suspendre les commandes une heure ne doit pas faire disparaître
  l'établissement de l'application. Le brief demande cette séparation ; elle est
  faite.
- `is_open_at()` convertit dans le fuseau du pays et gère les plages à cheval
  sur minuit.
- Cloisonnement à trois étages : `StaffMembership` (établissement),
  `AreaMembership` (ville **ou** pays, `CHECK` exclusif), siège.

Manquent, pour une `Kitchen` au sens du brief : `code` (seul `slug` existe),
`production_capacity`, `stations`, `menus`, `inventory`, et les statuts
`TEMPORARILY_CLOSED` et `MAINTENANCE` — le premier étant toutefois couvert en
pratique par `accepts_orders`, qui est le bon mécanisme pour une fermeture d'une
heure. `country` et `city` existent mais s'atteignent par `zone.city.country`.

**Le renommage `Restaurant` → `Kitchen` n'est pas l'enjeu.** Voir document 10.

---

## 3. Production — `MISSING`

C'est le trou principal, et il est total. Recherche exhaustive sur
`backend/apps`, `backend/common`, `backend/config` :

| Entité attendue | Occurrences |
|---|---|
| `Ingredient` | 0 |
| `Recipe`, `RecipeIngredient` | 0 |
| `Inventory`, `StockMovement` | 0 |
| `Station` | 0 |
| `ProductionTask` | 0 |
| `Menu` (entité), `Variant` | 0 |

Conséquences concrètes, non théoriques :

1. **Le stock ne descend jamais au niveau de la matière.** `MenuItem.tracks_stock`
   / `stock_quantity` compte des plats finis. La décrémentation est pourtant
   bien écrite — `UPDATE … WHERE stock_quantity >= n`, évalué par la base sans
   lecture préalable (`catalog/services.py:73-74`) : la technique est juste, la
   granularité ne l'est pas. Un pain partagé entre trois recettes ne peut pas
   être suivi ; une rupture de sauce n'invalide rien.
2. **`CONFIRMED → PREPARING → READY` n'a aucun contenu opérationnel.** Ce sont
   trois écritures de colonne. Rien n'est ordonnancé, rien n'est consommé, aucun
   poste n'est chargé.
3. **La capacité de production n'existe pas.** `default_preparation_minutes` est
   une constante par établissement — vingt minutes, que la cuisine ait deux
   commandes ou quarante.
4. **Aucune traçabilité matière.** Ni perte, ni ajustement, ni réception, ni
   transfert. L'inventaire d'une dark kitchen est son poste de coût principal.

### Kitchen Display System — `PARTIAL`

Contrairement au reste de cette section, le KDS **existe** : commit `42f24b0`,
poste de travail cuisine dans `apps/admin`, quatre colonnes (confirmées,
préparation, prêtes, remises), tri par ancienneté, seuil de retard mesuré sur
`default_preparation_minutes` et non sur l'ETA client, bascule de disponibilité
en rupture de service. Il consomme `ws/restaurants/<id>/dashboard/` sans ajouter
de route.

Il est `PARTIAL` pour une seule raison : **il affiche des commandes, pas des
tâches de production.** Sans `Station` ni `ProductionTask`, il ne peut ni router
vers un poste, ni afficher un temps par étape, ni montrer une file par poste.
C'est le bon écran branché sur un domaine incomplet.

---

## 4. Disponibilité — `EXISTS` depuis le lot 1 (était `BROKEN`, non `INCONSISTENT`)

> **Mise à jour, lot 1.** Le relevé ci-dessous décrivait une dispersion. Il
> manquait le plus grave : la création de commande **n'appliquait ni les
> horaires ni la suspension** des commandes — une cuisine fermée encaissait.
> Détail et preuve au document 03, I2. Le juge unique existe désormais
> (`apps.availability`) et s'applique à la carte, au panier, au devis, à la
> fiche d'établissement et à la commande. Il reste `EXISTS` et non
> `PRODUCTION_READY` pour une raison : la capacité de production n'y entre pas,
> faute de postes.

État relevé avant le lot 1 — aucun `AvailabilityService` central (phase 12 du
brief). Les règles étaient réparties :

| Question | Répondue par |
|---|---|
| cuisine ouverte ? | `Restaurant.is_open_at()` |
| publiée ? | `Restaurant.is_active` / `status` |
| accepte les commandes ? | `Restaurant.accepts_orders` |
| article actif ? | `MenuItem.is_available`, `Category.is_active` |
| stock disponible ? | `carts/services.py:135` |
| zone desservie ? | `geography` — unifié par `50d0cea` |
| **capacité suffisante ?** | **nulle part** |

Chaque règle est correcte isolément. Aucune ne répond, en un appel, à « ce
client peut-il commander cet article maintenant, et sinon pourquoi ». La
réponse est recomposée par chaque appelant — et c'est le mécanisme exact qui a
produit la divergence de zone corrigée dans `50d0cea` : deux lieux, deux règles,
deux réponses individuellement cohérentes, un écran qui annonce un tarif et une
commande qui en applique un autre.

---

## 5. Domaines secondaires — tous `EXISTS`, aucun simulé

Contrôlés un par un ; aucun n'est une coquille.

| Domaine | Service | Tests | Statut |
|---|---|---|---|
| `loyalty` | 308 l. | 72 | `EXISTS` |
| `groupcarts` | 574 l. | 54 | `EXISTS` |
| `promotions` | 247 l. | 46 | `EXISTS` |
| `tracking` | 143 l. | 48 | `PRODUCTION_READY` |
| `analytics` | 388 l. de rapports | 49 | `EXISTS` |
| `social` | 220 l. | 34 | `EXISTS` |
| `gamification` | 162 l. | 30 | `EXISTS` |
| `calls` | 207 l. | 23 | `EXISTS` |
| `support` | 101 l. | 19 | `EXISTS` |

**Analytics ne simule rien** : 17 agrégations SQL réelles (`Sum`, `Count`,
`Avg`, `annotate`, `aggregate`) dans `apps/analytics/reports.py`, aucune
constante inventée. Le commit `50d0cea` a de plus cloisonné les rapports par
périmètre — un gérant de Lomé ne lit plus le chiffre d'affaires d'Abidjan.

La phase 29 du brief demande que ces domaines ne fragilisent pas le cœur. Ils ne
le fragilisent pas : apps séparées, aucune écriture sur la commande ni sur le
paiement. `promotions` est la seule à toucher au montant, et elle le fait
**côté serveur**, au devis.

---

## 6. Notifications et temps réel — `EXISTS`

`NotificationKind` centralise cinq familles (`order_status`, `delivery_offer`,
`payment`, `account`, `marketing`). Six canaux WebSocket, chacun avec un usage
identifié — aucun canal ouvert « au cas où », ce que demande la phase 27.

Le catalogue d'événements du brief (phase 26) est plus fin que
`NotificationKind` : `ORDER_PREPARING`, `ORDER_READY`, `COURIER_ASSIGNED` sont
aujourd'hui des variantes d'`order_status` distinguées par la charge utile. Ce
n'est pas un défaut tant qu'un seul producteur écrit ces messages ; ça le
deviendra quand la production en émettra aussi.

---

## 7. Mode hors ligne — `PARTIAL`, avec du code mort

`apps/fastfood/lib/services/offline_sync_service.dart` (914 lignes).

Ce qui marche : cache catalogue, reprise des mises à jour de profil et de
panier. La reprise de panier est **prudente et juste** — ni frais, ni remise, ni
code promo rejoués ; seuls les choix du client le sont (`:440-462`). Un seul
appel au contexte d'établissement pour toute la reprise, pour qu'un changement
en cours de route n'envoie pas la moitié du panier ailleurs.

Ce qui n'existe pas : **la commande hors ligne**. La table `offline_orders` est
créée, indexée deux fois, lue au démarrage, purgée — et **jamais écrite**.
Aucun `INSERT`, aucune routine de synchronisation. `_pendingOrders` est peuplée
depuis une table que rien ne remplit.

**Aucun risque financier.** La crainte de la phase 25 — une commande réputée
créée parce qu'elle est en base locale — ne peut pas se produire, faute
d'écriture. `_pendingOrders` n'est exposée à aucun écran (vérifié : zéro
référence hors du service).

C'est donc du **code mort qui décrit une capacité absente** : quatre-vingts
lignes de schéma, d'index et de chargement pour rien. À supprimer (document 09),
ou à compléter avec la machine `LOCAL_PENDING → SERVER_PENDING → CONFIRMED →
FAILED` du brief — mais c'est alors une fonctionnalité neuve, à décider, pas une
réparation.

---

## 8. Interfaces — `PARTIAL`

Détail au document 05. En résumé :

- États d'écran bien couverts côté client : chargement 29/34, vide 34/34,
  erreur 24/34.
- **Design system fragmenté** : `packages/elcorazon_core/lib/src/design/` ne
  contient que les emojis ; couleurs et typographie sont réécrites par
  application, 1 975 lignes sur six fichiers.
- **Deux écrans de commandes sous un même libellé** : l'onglet ouvrait
  `OrdersScreen` (260 l.), le profil ouvrait `EnhancedOrdersScreen` (660 l.),
  et les deux s'appelaient « Commandes ». `INCONSISTENT` — corrigé au lot 0.
  Il reste que le second lit une source de données parallèle.

---

## Synthèse

| Bloc | Statut |
|---|---|
| Commande, panier, paiement, livraison, géographie | `PRODUCTION_READY` |
| Établissement | `EXISTS` — à étendre en Kitchen |
| KDS | `PARTIAL` — bon écran, domaine incomplet |
| Disponibilité | `EXISTS` — juge unique (lot 1) ; était `BROKEN` : la commande ignorait les horaires |
| **Recettes, ingrédients, inventaire, production, postes** | **`MISSING`** |
| Domaines secondaires (9) | `EXISTS`, isolés, non simulés |
| Hors ligne | `PARTIAL` + code mort — vestige retiré au lot 0 |
| Interfaces | `PARTIAL` — design fragmenté, KDS sans porte (lot 0) |

**Le brief annonce une refonte. La mesure indique une extension.** Le cœur
transactionnel est en état de production ; c'est l'étage de fabrication qu'il
faut construire, et lui seul justifie du code neuf.
