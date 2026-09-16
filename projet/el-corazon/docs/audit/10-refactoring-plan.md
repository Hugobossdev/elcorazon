# 10 — Plan de refonte

Ce document propose un ordre d'exécution et le justifie. Il diverge de l'ordre
du brief sur un point important, et cette divergence est argumentée au §1.

---

## 0. Le principe qui gouverne l'ordre

> Ne cherche pas à avoir le plus grand nombre de fonctionnalités.
> Cherche à avoir un système cohérent.

C'est la règle finale du brief, et elle est la bonne. Appliquée à ce dépôt, elle
donne une conclusion que l'audit n'anticipait pas : **le système est déjà
cohérent, il est simplement incomplet.**

Le cœur transactionnel — commander, payer, livrer, suivre — est en état de
production : machines à états contraintes en base, verrous sur tous les chemins
d'argent, idempotence testée dans le bon ordre, cloisonnement à trois étages,
1 695 cas de test, plancher de couverture à 92 %.

Ce qui manque est un **étage de domaine** : la fabrication. C'est là que doit
aller l'essentiel de l'effort, et tout ce qui le retarde se paie deux fois.

---

## 1. Le renommage n'est pas le sujet — et il doit venir en dernier

La phase 36 du brief détaille une procédure en quinze étapes pour migrer
`Restaurant` vers `Kitchen`. La procédure est juste. **Sa place dans l'ordre ne
l'est pas.**

### Ce que coûte le renommage, mesuré

| Périmètre | Fichiers | Occurrences |
|---|---|---|
| Backend (apps, common, config) | 119 | 811 |
| Tests backend | 69 | — |
| Migrations existantes | 20 | — |
| Flutter (3 apps + socle) | 132 | 885 |
| **Total** | **340 fichiers** | **≈ 1 700** |

S'y ajoutent une migration de données, la réécriture du contrat d'API, et la
mise à jour de **trois applications Flutter déployées** qui ne se mettent pas à
jour le même jour — donc une période de compatibilité ascendante à concevoir,
alors qu'aucune convention de dépréciation n'existe encore (document 06, R3).

### Ce que le renommage apporte

Au client : rien. Au cuisinier : rien. À l'exploitant : rien. Au coût matière :
rien.

Il apporte de la **clarté de vocabulaire** — ce qui a une valeur réelle, mais
qui n'est pas du même ordre que « le système ne sait pas ce qu'il consomme ».

### Ce que le renommage coûte en plus, s'il vient en premier

Il fige le vocabulaire **avant** de savoir de quoi la `Kitchen` a besoin. Or
l'audit montre qu'il lui manque `code`, `production_capacity`, `stations`,
`menus`, `inventory` et le statut `MAINTENANCE`. Renommer d'abord, c'est
renommer une entité incomplète, puis rouvrir les 340 fichiers pour y ajouter ce
qui manque.

**Recommandation : lot 4, après la production.** L'entité sera alors connue, le
renommage se fera une fois, et le vocabulaire de la documentation suivra celui
du code — jamais l'inverse (document 09, §5).

**Si le renommage est néanmoins prioritaire pour le produit**, c'est une
décision légitime qui se prend en connaissance de ce chiffre : 340 fichiers,
trois applications déployées, zéro fonctionnalité gagnée. L'audit ne s'y oppose
pas ; il demande que le coût soit vu.

### Une alternative moins chère, disponible immédiatement

Le vocabulaire **visible** peut changer sans toucher au schéma : libellés
d'interface, messages d'erreur, documentation d'exploitation. `docs/ouvrir-une-cuisine.md`
le fait déjà, et `42f24b0` a nommé son écran « poste de cuisine » sans renommer
un seul modèle.

Coût : quelques heures. Gain de clarté : l'essentiel de celui du renommage
complet.

---

## 2. Les lots

### Immédiat — infrastructure, sans code

Ces quatre points ne dépendent d'aucun développement et conditionnent tout le
reste.

| # | Action | Effort |
|---|---|---|
| 1 | PostgreSQL de production en plan payant | facturation |
| 2 | Planifier `backup.sh` **et essayer `restore.sh` une fois** | 1 h |
| 3 | Renseigner `SENTRY_DSN` (SDK déjà intégré) | 10 min |
| 4 | Service web en plan payant | facturation |

Le point 2 se lit deux fois : une restauration jamais essayée est une
hypothèse, pas une sauvegarde.

---

### Lot 0 — une séance

Trois gestes à gain immédiat, sans risque de régression.

| # | Action | Pourquoi | État |
|---|---|---|---|
| 0.1 | **Entrée « Poste de cuisine »** en tête d'OPÉRATIONS | Le KDS existait et n'était atteignable que depuis l'écran qu'il remplace | ✅ fait |
| 0.2 | Faire converger le profil vers l'onglet de commandes | Deux écrans différents sous le libellé « Commandes » | ✅ fait |
| 0.3 | Supprimer le vestige `offline_orders` | 80 lignes décrivant une capacité absente | ✅ fait |

`0.1` est le meilleur rapport gain/coût du projet entier : une trentaine de
lignes, et le poste de travail cuisine cesse d'être caché derrière l'écran de
supervision de flotte.

`0.2` s'est révélé différent de ce que la première passe de l'audit annonçait :
`EnhancedOrdersScreen` n'était pas inatteignable — le bouton « Filtrer et
rechercher » de l'onglet l'ouvre délibérément. Le défaut était que le **profil**
y menait aussi, sous le même libellé que l'onglet, qui lui ouvre un autre écran.
Les deux entrées du profil pointent désormais vers l'onglet ; les filtres
restent à un tap. Ce qui subsiste est la source de données parallèle de l'écran
filtré — voir document 09, D2.

**Décision à prendre en parallèle** : fusionner `elcorazon` et
`elcorazon-backend` ? Le lot 2 ajoute six à huit migrations, et c'est là que le
double dépôt coûte le plus cher.

---

### Lot 1 — `AvailabilityService`

> **État : fait, et il a trouvé plus grave que prévu.** La commande n'appliquait
> ni les horaires ni la suspension : une cuisine fermée encaissait (document 03,
> I2). Juge dans `apps/availability`, un test par motif, 1 856 tests, couverture
> 92,68 %. Trois écarts avec les livrables ci-dessous, tous délibérés :
>
> * **ni `restaurants` ni `catalog`** : écrit après les recettes, le juge doit
>   voir la matière, et le graphe l'interdit à ces deux-là. Il vit dans sa propre
>   application, au-dessus de `production` ;
> * **pas de route dédiée** : le verdict et son motif sont portés par les routes
>   que les applications lisent déjà — raisons au document 06, R2 ;
> * **la capacité n'a pas de branchement vide** : une question qui répond
>   toujours « oui » ferait croire qu'elle est posée. Elle viendra avec les postes.

**Pourquoi en premier.** C'est la seule incohérence dont le mécanisme a **déjà**
produit un défaut en production (la divergence de zone, fermée par `50d0cea`).
Et le lot 2 ajoutera une huitième question — la capacité — à un ensemble qui n'a
pas encore de juge.

Poser le juge avant d'ajouter la question, plutôt que l'inverse.

**Contenu.**

Un service unique répondant à « ce client peut-il commander cet article
maintenant, et sinon pourquoi », rendant un **verdict et un motif**, jamais une
collection de booléens que l'appelant recombine.

Il compose les règles existantes sans les réécrire :

```
cuisine publiée        Restaurant.is_active
accepte les commandes  Restaurant.accepts_orders
ouverte maintenant     Restaurant.is_open_at()
catégorie active       Category.is_active
article disponible     MenuItem.is_available
stock                  MenuItem.stock_quantity   → remplacé au lot 2
zone desservie         resolve_zone()
capacité               ← branchement laissé vide, rempli au lot 2
```

**Livrables.**

- Service dans `apps/restaurants/` ou `apps/catalog/`, selon ce que le test
  d'architecture du graphe autorise — à vérifier avant d'écrire, pas après.
- **Une** route exposant le verdict (document 06, R2).
- Flutter appelle cette route au lieu de recomposer.
- Tests : un par motif de refus, plus un test qui vérifie qu'aucun autre lieu du
  code ne répond à la même question.

**Critère de fin.** Aucun écran Flutter ne décide seul si un article est
commandable.

---

### Lot 2 — La production *(le cœur du projet)*

C'est le lot qui transforme El Corazón en dark kitchen. Il mérite la plus grande
part du budget.

#### 2-bo — Le back-office de la matière *(ajouté après le lot 1, fait)*

> Recettes, stock, réservation et juge existaient, et **personne ne pouvait
> saisir une recette ni recevoir une livraison** autrement que par un `shell`.
> Ce sous-lot a été placé devant les postes (2c) pour cette raison.
>
> Livré : routes `/inventory/manage/*` et `/production/manage/recipes/*` ;
> sept permissions ; plafond de valeur par cuisine et seconde validation tenue
> en base ; idempotence des écritures de valeur ; écrans Stock, Validations,
> Recettes et Ingrédients dans l'administration ; plafond réglable sur la fiche
> d'établissement.
>
> Corrigé au passage, parce que le back-office allait l'exposer : le **coût
> unitaire était tenu au gramme**, en entiers d'une devise sans décimales — un
> oignon à 500 F le kilo coûtait 0 ou 1 F le gramme. Il se tient désormais au
> kilogramme, au litre ou à l'unité (`COST_UNIT`), sans migration : la colonne
> est la même, sa définition a changé avant qu'aucune donnée n'existe.

#### 2a — Ingrédients et recettes

> **État : socle inventaire livré et vérifié.** `common/quantities.py`,
> `common.fields.QuantityField`, et l'app `apps/inventory` (`Ingredient`,
> `StockItem`, `StockMovement`) avec sa migration. 83 tests neufs, suite à
> 1 778 (contre 1 695), couverture 92,43 %, ruff et mypy verts.
> Les recettes restent à écrire — elles vivront dans `production` (2c), qui
> fera le pont entre `catalog` et `inventory`.

```
Ingredient      nom, unité de base, catégorie, coût unitaire, kitchen
Recipe          product ─1:1─ recipe
RecipeIngredient recipe, ingredient, quantité, unité
```

**Point de conception à ne pas rater : les conversions d'unités.** Le brief
demande `g`, `kg`, `ml`, `l`, `unit`. Une recette saisie en grammes doit
consommer un stock tenu en kilogrammes sans erreur d'arrondi.

La réponse existe déjà dans ce dépôt, et il faut la réemployer : `common/money.py`
stocke les montants en **entiers d'unités mineures**, jamais en flottant. Les
quantités de matière posent exactement le même problème, et appellent la même
solution — une unité de base entière par dimension (le milligramme, le
millilitre), la conversion faite à la saisie et à l'affichage, jamais au milieu
d'un calcul.

Écrire `0.1 + 0.2 != 0.3` dans un stock produit les mêmes dérives que dans une
comptabilité, en moins visible.

#### 2b — Inventaire

```
Inventory       kitchen × ingredient → on_hand, reserved, seuil d'alerte
StockMovement   PURCHASE RECEIPT CONSUMPTION ADJUSTMENT WASTE
                TRANSFER RESERVATION RELEASE
```

Règles fixées au document 07, §4 :

- **`StockMovement` est un journal** : jamais d'`UPDATE`, jamais de `DELETE`.
  Une erreur se contre-passe.
- `on_hand` maintenu par `F()`, **avec un test de réconciliation** (somme des
  mouvements = `on_hand`) écrit en même temps que la colonne.
- `CheckConstraint(on_hand >= 0)`. Le négatif, s'il est voulu, est un **type de
  mouvement** qui l'autorise, pas une contrainte retirée.
- Pagination par curseur : la table ne cesse de grandir.
- `ADJUSTMENT` et `WASTE` sont des écritures de valeur — permission dédiée,
  cloisonnement par cuisine, plafond au-delà duquel une seconde validation est
  requise (document 04, point D).

`MenuItem.tracks_stock` / `stock_quantity` disparaît au profit du calcul par
recette. La **technique** du décrément atomique existant se transpose telle
quelle ; c'est la granularité qui change.

#### 2c — Postes et tâches

```
Station         kitchen, nom, code, capacité, statut, personnel
ProductionTask  order_line, station, statut, horodatages, séquence
```

`CONFIRMED → QUEUED → PREPARING → READY` prend enfin un contenu : la confirmation
engendre des tâches, les tâches consomment la matière, `READY` atteste d'étapes
franchies.

**C'est ici que se corrige I1** (les deux temps de préparation) : le temps promis
se calcule depuis les tâches et la charge des postes, pas depuis une constante
d'établissement. `MenuItem.preparation_minutes` reçoit enfin le rôle que son nom
annonce.

C'est ici aussi que `QUEUED` prend un sens, et que le brief de la phase 9 devient
réalisable sans migration gratuite.

#### 2d — Le KDS branché sur les tâches

L'écran existe (`42f24b0`) et son ergonomie a été pensée — tri par ancienneté,
seuil de retard sur le temps de préparation et non sur l'ETA client, `pending` et
`cancelled` volontairement sans colonne.

Il devient une file **par poste**, avec un canal dédié
`ws/kitchens/<id>/production/` (document 06, R1) — le canal `dashboard` ne peut
pas transporter des tâches et leurs dépendances sans devenir un fourre-tout.

**À vérifier sur tablette réelle** avant de déclarer le KDS opérationnel : quatre
colonnes sur 180 lignes, lues à un mètre, par quelqu'un qui a les mains
occupées.

#### 2e — Ce que le lot 2 débloque

- Coût matière connu → **marge réelle** dans `analytics`, aujourd'hui impossible.
- Rupture d'ingrédient → retrait automatique des plats concernés, au lieu d'une
  bascule manuelle plat par plat.
- Heure promise au client qui tient compte de ce qui a été commandé.
- Capacité de production → huitième question de l'`AvailabilityService`.

---

### Lot 3 — Le réseau

Les deux incohérences qui n'apparaissent qu'à partir de la deuxième cuisine.

| # | Sujet | Incohérence |
|---|---|---|
| 3.1 | **Entité `Menu`** — une carte se publie vers plusieurs cuisines, avec surcharge locale de prix et de disponibilité | I3 |
| 3.2 | **Périmètre de la flotte** — un livreur rattaché à une ville ou une zone, non à une cuisine | I4 |

`3.2` est notable : l'incohérence a été **créée** par `50d0cea`, qui a rendu
l'ouverture d'une cuisine accessible sans développeur. La capacité d'ouvrir un
réseau existe ; la flotte n'a pas suivi. Le reste du service d'affectation est
déjà conçu pour le réseau — tri PostGIS par distance réelle, exclusion des
livreurs engagés. **Une seule ligne bloque** (`services.py:373`), mais la
remplacer demande de choisir le bon périmètre et d'en tirer les conséquences sur
les permissions.

`3.1` impose une période de compatibilité ascendante : la forme du catalogue
change, et trois applications déployées ne se mettent pas à jour le même jour.
**C'est ici que la convention de dépréciation doit exister** (document 06, R3) —
à décider avant, pas pendant.

---

### Lot 4 — Design system, puis renommage

| # | Sujet |
|---|---|
| 4.1 | Monter les jetons de couleur dans `elcorazon_core/design`, sur le modèle sémantique du back-office |
| 4.2 | Unifier la couleur primaire (`#B51822` client vs `#E53E3E` livreur et admin) |
| 4.3 | Basculer client et livreur du brut vers le thème (494 et 307 couleurs en dur) |
| 4.4 | `semanticLabel` sur les composants partagés — 0 aujourd'hui sur 124 450 lignes |
| 4.5 | **`Restaurant` → `Kitchen`**, entité alors complète |

L'ordre interne compte : `4.1` conditionne `4.2`, `4.3` et `4.4`. Tant que les
jetons vivent dans chaque application, unifier une couleur signifie la corriger
trois fois, et poser un label d'accessibilité signifie le poser trois fois.

Le back-office montre déjà la cible : `AdminColorTokens` expose des couleurs
sémantiques **dérivées du `ColorScheme`**, et 25 fichiers l'utilisent. C'est ce
motif qu'il faut monter dans le socle, pas en inventer un nouveau.

---

## 3. Ce qu'il ne faut pas faire

| Tentation | Pourquoi s'en abstenir |
|---|---|
| `sed s/Restaurant/Kitchen/g` | 340 fichiers, 20 migrations, une migration de données, trois applications déployées. Le brief l'interdit déjà (phase 36) ; les chiffres disent pourquoi. |
| Réécrire le panier, la commande ou le paiement | Ils satisfont **déjà** les phases 9, 10, 11, 16, 17 et 18 du brief. Les rouvrir, c'est risquer ce qui marche pour retrouver ce qui existe. |
| Supprimer les domaines secondaires | Neuf domaines, tous testés, tous isolés du cœur. Aucun ne le fragilise. |
| Corriger `stock_quantity` | Sa technique est juste ; sa granularité est fausse. Il sera **remplacé** au lot 2, pas réparé. |
| Mettre à jour la documentation vers « Kitchen » avant le code | Une documentation fausse coûte plus cher qu'un vocabulaire daté. |
| Raccourcir les commentaires du backend | Ils portent le *pourquoi* — l'incident évité, l'alternative écartée. C'est la seule partie qu'un lecteur ne peut pas reconstituer depuis le code. |

---

## 4. Discipline par lot

Reprise du brief, avec une précision que le double dépôt impose.

À chaque lot : modifier → tester → `ruff check` → `ruff format --check` →
`mypy --strict` → migrations → vérifier les régressions → documenter.

**Deux ajouts, non négociables :**

1. **Chaque entité nouvelle arrive avec sa permission, son cloisonnement par
   cuisine et ses tests de refus.** Les garanties structurelles du document 04
   (`test_aucune_route_n_est_sans_permission`) se videraient de leur sens si le
   code grossissait plus vite que les règles qui le tiennent.

2. **Chaque migration arrive dans les deux dépôts**, tant que la fusion n'est
   pas faite. Un tableau de bord vert dans l'un ne dit rien de l'autre — le
   mécanisme a déjà produit un incident réel.

---

## 5. Résumé exécutif

| Lot | Contenu | Valeur produite |
|---|---|---|
| **Immédiat** | Base payante, sauvegardes planifiées et **testées**, Sentry | Les données cessent d'être en risque |
| **0** | Entrée Cuisine, doublon d'écrans, vestige hors ligne | Le KDS devient utilisable en service |
| **1** ✅ | `AvailabilityService` — et la cuisine fermée qui encaissait | Une seule réponse à « peut-on commander ? », appliquée à la commande |
| **2** | **Ingrédients, recettes, inventaire, postes, tâches, KDS branché** | **El Corazón devient une dark kitchen** |
| **3** | Entité `Menu`, périmètre de flotte | Le réseau multi-cuisines devient exploitable |
| **4** | Design system unifié, puis `Kitchen` | Une seule identité, un seul vocabulaire |

**Le lot 2 est le projet.** Les lots Immédiat et 0 le préparent en quelques
jours, le lot 1 pose le juge dont le lot 2 aura besoin, et les lots 3 et 4
récoltent ce qu'il aura rendu possible.

Tout ce qui passe devant le lot 2 sans le servir retarde la seule chose qui
manque réellement à ce produit : **savoir fabriquer ce qu'il vend.**
