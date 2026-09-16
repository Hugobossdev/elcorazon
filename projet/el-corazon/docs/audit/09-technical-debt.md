# 09 — Dette technique

**La dette de ce projet est faible et bien tenue.** Les indicateurs habituels
sont à zéro :

```
TODO / FIXME / HACK / XXX   backend   →  0
TODO / FIXME                Flutter   →  0
mock / fake / dummy         Flutter   →  0 fichier
```

Ce document ne cherche donc pas à dresser un catalogue. Il relève ce qui existe
réellement, et distingue soigneusement trois catégories que l'on confond
souvent : **le code mort**, **la dette assumée** et **ce qui n'est pas de la
dette du tout**.

---

## 1. Code mort — à supprimer

### D1 — Le vestige `offline_orders`

`apps/fastfood/lib/services/offline_sync_service.dart`

La table est créée (`:186-197`), indexée deux fois (`:246-247`), migrée
(`:259-260`), lue au démarrage (`:282-292`), purgée (`:863`, `:883`) — et
**jamais écrite**. Aucun `INSERT`, aucune routine de synchronisation. La liste
`_pendingOrders` est peuplée depuis une table que rien ne remplit, comptée dans
`totalPendingOperations`, exposée par un accesseur public — et lue par **zéro**
écran.

Environ 80 lignes qui décrivent une capacité absente. Un développeur qui les lit
conclut que la commande hors ligne existe.

**Aucun risque en production** : faute d'écriture, le danger que redoute la
phase 25 du brief — une commande réputée créée parce qu'elle est en base
locale — ne peut pas se produire.

**Action** : supprimer la table, ses index, sa migration, `_pendingOrders` et
son accesseur. Si la commande hors ligne est voulue, c'est une fonctionnalité
neuve à concevoir avec sa machine `LOCAL_PENDING → SERVER_PENDING → CONFIRMED →
FAILED` — pas une réparation de ce vestige.

### D2 — Une seconde source de données pour les commandes du client

`apps/fastfood/lib/screens/client/enhanced_orders_screen.dart`

**Ce n'est pas du code mort**, contrairement à ce que la première passe de cet
audit avançait. `EnhancedOrdersScreen` est atteignable par le bouton « Filtrer
et rechercher » de l'onglet (`orders_screen.dart:106`), qui l'ouvre
délibérément : l'onglet est la vue rapide, cet écran est l'historique complet
avec son tri. La recherche initiale, portant sur les littéraux de route, avait
manqué les appels passant par la constante `AppRouter.enhancedOrders`.

Ce qui reste de la dette, et qui est réel :

```dart
// enhanced_orders_screen.dart:39-40
final orderRepository = DjangoOrderRepository();
_orderHistoryService = OrderHistoryService(orderRepository);
```

L'écran construit **son propre** service sur une instance neuve du dépôt, au
lieu de lire `AppService.orders` comme le fait l'onglet. Deux vues de la même
liste, alimentées par deux chemins : elles peuvent diverger à l'écran, et une
commande annulée dans l'une peut rester affichée dans l'autre.

`OrderHistoryService` (223 lignes) n'a pas de test et n'a que cet appelant.

**Fait au lot 0** : les deux entrées du profil — « Commandes » et « Mes
commandes » — pointaient vers cet écran tandis que l'onglet du même nom ouvrait
`OrdersScreen`. Même libellé, deux écrans. Elles pointent désormais vers
`AppRouter.orders`.

**Reste à faire** : brancher l'écran filtré sur `AppService`, ce qui rend
`OrderHistoryService` superflu. C'est une modification de chemin de données —
elle demande de vérifier que le filtrage et le tri survivent au changement de
source, donc un test avant, pas un remplacement à vue.

---

## 2. Dette assumée — à documenter, pas à corriger

### D3 — `delivery_fee_gross` restera nullable

Ajouté après coup ; les commandes antérieures retombent sur `delivery_fee`.
Rétro-remplir aurait **inventé une donnée** — c'est la bonne décision. Le coût
est que chaque lecteur gère un `None`.

**Action** : aucune. À reclasser en dette permanente. Le champ pourra passer non
nul le jour où plus aucune commande antérieure n'est consultée, ce qui n'arrivera
peut-être jamais.

### D4 — Les horaires peuvent se chevaucher

`OpeningHours` contraint l'unicité (établissement, jour, ouverture) et interdit
la plage vide, mais rien n'empêche `08:00–14:00` et `12:00–18:00` le même jour.

L'effet est bénin — `is_open_at()` répond correctement — mais l'affichage client
montrera deux créneaux qui se recouvrent.

**Action** : soit une `ExclusionConstraint` avec `btree_gist`, soit une ligne de
documentation qui l'accepte. Pas les deux, et pas ni l'un ni l'autre.

### D5 — Le repli en icônes du pack d'emojis

30 jetons déclarés dans `packages/elcorazon_core/lib/src/design/emojis/`, **0
fichier SVG** dans le paquet. L'application tourne sur le repli en icônes
Material.

**Ce n'est pas de la dette technique.** L'en-tête d'`app_emoji.dart` est
explicite — « Le repli, et pourquoi il n'est pas provisoire » : le jeton peut
recevoir son illustration plus tard, sans toucher une ligne de code à ses points
d'appel, et le repli reste correct entre-temps.

**Action** : produire les 30 illustrations est une tâche de **contenu**, à
planifier avec un graphiste. Le code est fini.

---

## 3. Dette structurelle — traitée par les lots

Ces points sont de la vraie dette, mais leur correction est un chantier de
domaine, pas un nettoyage. Ils sont détaillés ailleurs et listés ici pour que le
tableau soit complet.

| # | Dette | Document | Lot |
|---|---|---|---|
| D6 | Jetons de design réécrits par application (1 975 l.) | 05 | 1 |
| D7 | 494 couleurs brutes dans le client, contre 232 accès au thème | 05 | 1-2 |
| D8 | **0 `semanticLabel`** sur 124 450 lignes de Dart | 05 | 2 |
| D9 | Huit écrans au-dessus de 1 200 lignes | 05 | continu |
| D10 | Règles de disponibilité dispersées sur sept lieux | 03 (I2) | 1 |
| D11 | Catalogue dupliqué par cuisine faute d'entité `Menu` | 03 (I3) | 3 |
| D12 | Un livreur rattaché à une seule cuisine | 03 (I4) | 3 |
| D13 | `MenuItem.preparation_minutes` stocké, jamais utilisé | 03 (I1) | 2 |

**D13 mérite d'être signalé à part** : c'est le seul cas de champ mort **côté
serveur**. Il est peuplé par deux commandes de seed, filtrable, triable,
sérialisé deux fois vers Flutter, recopié à la duplication de carte — et
n'entre dans aucun calcul d'engagement. Sa correction n'est pas sa suppression :
c'est de lui donner enfin le rôle que son nom annonce, ce qui suppose les postes
de travail (lot 2).

---

## 3 bis. La découverte du lot 2 : les portes de qualité dérivaient

Constat fait en exécutant les portes que le brief impose à chaque phase, sur un
arbre dont **seuls mes fichiers étaient modifiés**.

### D19 — Les outils de qualité n'étaient pas épinglés

```toml
"ruff==0.14.*"     # n'importe quelle 0.14.x
"mypy==1.*"        # n'importe quelle 1.x
```

Un formateur change de sortie entre deux versions correctives. Exemple mesuré :
ruff 0.14.14 replie sur une seule ligne un décorateur de 99 caractères que la
version employée lors du dernier commit gardait éclaté
(`apps/notifications/receivers.py:253`).

Conséquence : **`ruff format --check .` échouait sur neuf fichiers que personne
n'avait touchés**, et deux constructions du même commit pouvaient rendre l'une
verte et l'autre rouge. C'est la porte qui tombe, pas un avertissement.

`mypy==1.*` pose le même problème en pire : chaque version affine l'inférence,
et neuf erreurs de typage étaient présentes sur du code inchangé — toutes dans
les fichiers du dernier commit (`50d0cea`).

C'est la variante silencieuse de l'incident que raconte l'en-tête de
`backend/.github/workflows/backend-ci.yml` : ce qui est testé et ce qui est
déployé doivent être la même chose, et cela vaut aussi pour **ce qui teste**.

**Corrigé** : `ruff==0.14.14` et `mypy==1.19.1`, épinglés à la version exacte,
avec la raison écrite dans `pyproject.toml`. Relever ces versions devient un
commit, visible et réversible.

### D20 — Neuf erreurs de typage sur du code inchangé

Toutes corrigées, sans silence de complaisance :

| Fichier | Erreur | Correction |
|---|---|---|
| `apps/analytics/views.py` | `active_user` rend `User \| None` là où le périmètre exige un utilisateur | `authenticated_user`, l'assistant prévu pour ce cas |
| `apps/catalog/duplication.py` ×3 | django-stubs ne voit pas les champs posés par `contribute_to_class` | `# type: ignore[misc]`, convention déjà employée par `OrderService` et `PaymentService` |
| `apps/restaurants/serializers.py` ×2 | filtre sur `*_id` : le vérificateur ne narrowait pas | filtre sur l'**objet** — même sémantique, sans requête de plus |
| `apps/restaurants/serializers.py` | redéclaration volontaire d'un champ hérité | `# type: ignore[assignment]`, avec la raison (le cycle de graphe qu'elle évite) |
| `apps/restaurants/backoffice.py` ×2 | `DeliveryZone.restaurant` est nullable | `_etablissement_proprietaire()`, qui **dit** l'invariant du jeu de requête |

Le dernier méritait un examen : `perform_destroy` lisait `instance.restaurant.name`
sur une clé nullable. Vérification faite, le jeu de requête écarte les zones
municipales (`restaurant__isnull=False`) — **ce n'était donc pas un bug vivant**.
L'assistant rend l'invariant explicite, pour que l'élargissement du jeu de
requête rende un refus lisible plutôt qu'un 500.

S'y ajoute `config/settings/prod.py` : le rappel `before_send` de Sentry était
typé `dict[str, object]` au lieu des types du SDK, ce qui interdisait de rendre
`None` — c'est-à-dire de **supprimer** un événement, la seule chose qu'un
expurgateur puisse vouloir faire de plus.

---

## 4. Dette d'infrastructure

| # | Dette | Gravité |
|---|---|---|
| D14 | PostgreSQL de production sur `plan: free` | **bloquante** |
| D15 | Sauvegardes scriptées mais jamais planifiées ni testées | **bloquante** |
| D16 | Service web sur `plan: free` — démarrage à froid | élevée |
| D17 | Sentry intégré mais `SENTRY_DSN` vide | moyenne |
| D18 | **Backend dans deux dépôts distincts** | élevée |

D18 est la plus insidieuse : une migration écrite ici n'est pas déployée tant
qu'elle n'est pas dans `elcorazon-backend`, et un tableau de bord vert dans un
dépôt ne dit rien de l'autre. Le mécanisme a déjà produit un incident réel,
raconté dans l'en-tête de `backend/.github/workflows/backend-ci.yml`.

Le lot 2 ajoutera six à huit modèles et autant de migrations. **C'est avant lui
qu'il faut décider de fusionner les deux dépôts**, pas pendant.

Détail complet au document 08.

---

## 5. Dette documentaire

138 occurrences de « Restaurant » dans `docs/` et les documents racine. Si le
concept métier devient « Kitchen », la phase 35 du brief demande qu'aucune
documentation ne continue de parler de « Restaurant ».

**Nuance importante, et elle pèse sur le plan** : tant que le **code** dit
`Restaurant`, une documentation qui dirait `Kitchen` serait fausse — et une
documentation fausse coûte plus cher qu'une documentation au vocabulaire daté.
Le vocabulaire des documents doit suivre celui du code, jamais le précéder.

Le sujet est traité au document 10, § « Le renommage n'est pas le sujet ».

**À noter au crédit du projet** : le commit `4bb3385`
(« docs(dette) : retirer six affirmations fausses ») a retiré six fonctionnalités
annoncées qui n'existaient pas — reconnaissance vocale, gamification livreur,
chat support, validation de documents et deux autres —, **chacune vérifiée dans
le code avant correction**. C'est exactement la discipline que le présent audit
applique, et elle explique pourquoi si peu de fonctions fictives subsistent.

---

## Ce qui n'est pas de la dette

À protéger d'un « nettoyage » mal ciblé. Ces éléments ressemblent à de la dette
et n'en sont pas.

| Élément | Pourquoi c'est justifié |
|---|---|
| `catalog/duplication.py` | Nécessaire pour amorcer une cuisine neuve. Son défaut est d'être le **seul** mode d'existence du catalogue (D11), pas d'exister. |
| Commentaires longs en français | Ils portent le *pourquoi* — l'incident évité, l'alternative écartée. C'est la partie qu'un lecteur ne peut pas reconstituer. |
| Neuf domaines secondaires | Tous implémentés et testés, tous isolés du cœur. Les supprimer retirerait des fonctions qui marchent. |
| `MenuItem.stock_quantity` | La **technique** est juste (décrément évalué par la base). C'est la granularité qui est fausse (I6). Sera remplacé par l'inventaire, pas corrigé. |
| Le repli en icônes (D5) | Conçu pour durer, et documenté comme tel. |
| Deux sondes `/health/` et `/ready/` | Distinction délibérée qui évite une cascade de redémarrages. |

---

## Plan de traitement

### Lot 0 — une séance, sans risque

| # | Action | Effort |
|---|---|---|
| D1 | ✅ **Fait** — vestige `offline_orders` retiré, base locale en version 3 | 30 min |
| D2 | ✅ **Fait en partie** — le profil rejoint l'onglet ; la source parallèle demeure | 1 h |
| D4 | Contrainte d'exclusion horaire **ou** ligne de doc | 30 min |
| D17 | Renseigner `SENTRY_DSN` | 10 min |

S'y ajoute, hors dette mais dans la même séance : l'entrée « Poste de cuisine »
en tête d'**OPÉRATIONS** dans la navigation du back-office (document 05, §1).

### Immédiat — sans code

| # | Action |
|---|---|
| D14 | PostgreSQL en plan payant |
| D15 | Planifier la sauvegarde **et essayer la restauration une fois** |
| D16 | Service web en plan payant |

### Décision avant le lot 2

| # | Question |
|---|---|
| D18 | Fusionner `elcorazon` et `elcorazon-backend` ? |

### Lots 1 à 3

D6 à D13, selon le document 10.

### Jamais

D3 (`delivery_fee_gross` nullable), et D5 côté code — seules les illustrations
restent à produire.
