# 03 — Incohérences métier

Ce document ne liste que des faits vérifiés dans le code, avec leur emplacement.
Chaque entrée précise **ce que le système promet**, **ce qu'il fait**, et **à
partir de quand l'écart devient visible**.

Les incohérences sont classées par le moment où elles blessent, pas par leur
élégance à corriger.

---

## I1 — Deux temps de préparation, un seul compte

**Gravité : élevée.** Visible dès le premier gâteau commandé.

`MenuItem.preparation_minutes` existe (`catalog/models.py:83`, défaut 15). Il est
filtrable (`catalog/filters.py:35`), sérialisé vers Flutter deux fois
(`catalog/serializers.py:97` et `:225`), triable (`catalog/views.py:78`),
recopié à la duplication de carte (`duplication.py:116`), et peuplé par les deux
commandes de seed avec des valeurs par plat.

**Il n'entre dans aucun calcul d'engagement.** L'heure promise au client est :

```python
# apps/orders/services.py:227-230
estimated_delivery_at = timezone.now() + dt.timedelta(
    minutes=restaurant.default_preparation_minutes + quote.estimated_minutes
)
```

`restaurant.default_preparation_minutes` est une constante d'établissement —
20 minutes par défaut (`restaurants/models.py:109`). Le temps du plat n'est
jamais consulté.

Conséquence : un jus pressé et un gâteau d'anniversaire sur mesure annoncent la
même heure de livraison. Le client voit « 45 min » sur la fiche du gâteau, puis
« livré vers 20h10 » au paiement, et les deux chiffres n'ont aucun rapport. La
cuisine, elle, est jugée en retard sur un seuil qui ignore ce qu'elle prépare.

**Ce n'est pas un bug d'arrondi, c'est une règle absente** : nulle part le
système ne dit comment un panier de plusieurs plats compose un temps. Le
maximum ? La somme ? Le maximum par poste ? La question n'a de réponse qu'avec
les postes de travail — donc avec la production (document 10, lot 2).

---

## I2 — La disponibilité n'a pas de juge

**Gravité : élevée.** Déjà survenue une fois, sur un autre axe.

Sept questions composent « ce client peut-il commander cet article
maintenant ? ». Sept lieux y répondent :

| Question | Lieu |
|---|---|
| cuisine ouverte ? | `Restaurant.is_open_at()` |
| publiée ? | `Restaurant.is_active` |
| accepte les commandes ? | `Restaurant.accepts_orders` |
| article actif ? | `MenuItem.is_available` + `Category.is_active` |
| stock ? | `carts/services.py:135` |
| zone desservie ? | `geography/resolution.py` |
| **capacité ?** | **aucun** |

Chacune est juste. Aucune ne compose. L'appelant recompose — et deux appelants
recomposent différemment.

**Ce scénario n'est pas hypothétique : il s'est produit.** L'en-tête de
`geography/resolution.py` le raconte. La zone applicable à un point était
résolue à deux endroits par deux règles différentes : le devis affiché retenait
la plus petite surface, la facturation le plus petit `max_distance_km`. Les deux
coïncidaient tant qu'une ville n'avait qu'une zone. Le jour où une zone
« Centre-ville » a été posée dans « Grand Lomé », l'écran annonçait un tarif et
la commande en appliquait un autre — sans qu'aucun journal ne s'en plaigne,
puisque chaque réponse était individuellement cohérente.

Le commit `50d0cea` a fermé **cet** axe en créant `resolve_zone()`, lieu unique.
Les six autres restent ouverts, par le même mécanisme.

### Traitée au lot 1 — et ce que l'audit n'avait pas vu

**Correction de cet audit.** « Chacune est juste. Aucune ne compose » était
inexact sur un point grave : deux des sept règles **n'étaient pas appliquées du
tout** au moment de commander.

La création de commande ne vérifiait que la publication (`is_active`, par le
`queryset` du sérialiseur). `accepts_orders` et `is_open_at()` n'étaient lus
que par `RestaurantSerializer.get_can_order_now` — un champ d'**affichage**.
Une cuisine fermée, ou qui venait de suspendre ses commandes pour un coup de
feu, encaissait donc toute commande envoyée à l'API ou depuis un panier resté
ouvert. L'écran disait « Fermé » ; le serveur répondait 201.

Prouvé avant correction : une commande passée par l'API sur un établissement
sans aucune plage d'ouverture a rendu **201 et une commande en base**. La suite
de tests exerçait d'ailleurs ce défaut sans le voir : sa fixture d'établissement
n'avait aucun horaire, et des centaines de tests y commandaient.

Statut réel avant le lot 1 : `BROKEN`, pas `INCONSISTENT`.

**Ce qui est en place.** `apps.availability.AvailabilityService` compose les
trois niveaux, chacun resté où vivent ses données :

| Niveau | Règles | Lieu |
|---|---|---|
| Cuisine | publiée, marché ouvert, dans ses horaires, prenant les commandes | `restaurants/availability.py` |
| Article | au menu, actif, catégorie active, stock de plats finis, options servies | `catalog/availability.py` |
| Matière | de quoi le préparer, réservations déduites, cumul du panier | `production/services.py` — `MaterialService.shortages` |

La commande rejuge la cuisine **au moment d'écrire** ; la carte, le panier, le
devis et la fiche d'établissement lisent le même juge. Un test d'architecture
vérifie qu'aucun autre module ne lit `accepts_orders`.

Deux défauts voisins, fermés par le même geste :

* **la catégorie éteinte** ne rendait pas ses articles incommandables depuis un
  panier déjà composé — le panier ne la regardait pas ;
* **la rupture d'ingrédient** refusait la commande au paiement, mais la carte
  continuait de proposer le plat.

**Ce qui reste hors du juge, délibérément.** La capacité de production : sans
postes ni file, aucune donnée ne permet de dire qu'une cuisine est saturée, et
une question qui répondrait toujours « oui » ferait croire qu'elle est posée.
La zone de livraison : elle dépend de l'adresse, et a déjà son lieu unique
(`check_delivery`).

---

## I3 — Le catalogue se duplique, il ne se publie pas

**Gravité : élevée à l'échelle réseau.** Invisible à une cuisine, bloquante à dix.

`Category` et `MenuItem` portent une clé étrangère **non nulle** vers
`Restaurant` (`catalog/models.py:38` et `:68`). Un plat appartient à une cuisine
et à une seule. Ouvrir une deuxième cuisine passe donc par
`catalog/duplication.py` : recopie des catégories, puis des articles, puis des
groupes d'options, puis des options.

Ce module est bien écrit et ses exclusions sont justes — ni avis, ni achats
vérifiés, ni stocks, ni popularité recopiés ; les images partagées par
référence. Le problème n'est pas son exécution, c'est **l'axe qu'il impose**.

Après duplication, un réseau de dix cuisines détient dix `MenuItem` « Burger
Corazón » sans lien entre eux. Changer le prix de l'enseigne, corriger une
allergie, retirer un plat du catalogue national : dix écritures, dix occasions
d'en oublier une, aucune requête pour savoir si elles concordent.

C'est précisément ce que l'entité `Menu` — absente, phase 4 du brief — résout :
une carte se **publie** vers plusieurs cuisines, avec une surcharge locale de
prix et de disponibilité. La duplication reste utile pour amorcer une cuisine
neuve ; elle ne peut pas rester le seul mode d'existence du catalogue.

Le brief décrit `Kitchen → Menu → Category → Product`. Le code fait
`Restaurant → Category → MenuItem`. L'étage manquant n'est pas décoratif : c'est
l'unité de publication.

---

## I4 — Un livreur appartient à une cuisine

**Gravité : moyenne aujourd'hui, élevée dès la deuxième cuisine d'une ville.**

```python
# apps/delivery/services.py:373
CourierProfile.objects.filter(restaurant=order.restaurant, ...)
```

`CourierProfile.restaurant` est une clé étrangère non nulle
(`delivery/models.py:55`). Un livreur est éligible aux courses de sa cuisine, et
d'aucune autre.

Tant qu'une ville n'a qu'une cuisine, c'est sans effet. Dès la deuxième, un
livreur disponible à 400 mètres de la cuisine B est invisible pour elle parce
qu'il est rattaché à la cuisine A — pendant que la commande de B attend.

Le reste du service d'affectation est pourtant fait pour le réseau : tri PostGIS
par distance réelle depuis la cuisine, exclusion des livreurs engagés, position
inconnue tolérée en fin de liste. La seule ligne qui bloque est le filtre de
rattachement.

Le bon périmètre pour une flotte est la **ville** ou la **zone**, pas la
cuisine. `AreaMembership` donne déjà ce vocabulaire pour le personnel ; la
flotte ne l'a pas.

**Cette incohérence est neuve** : elle a été créée par `50d0cea`, qui a rendu
l'ouverture d'une cuisine dans une nouvelle ville accessible sans développeur.
La capacité d'ouvrir un réseau existe désormais ; la flotte n'a pas suivi.

---

## I5 — « Préparer » ne prépare rien

**Gravité : structurelle.** C'est le sujet central de ce projet.

`CONFIRMED → PREPARING → READY` sont trois écritures de colonne, validées par
une machine à états rigoureuse — qui vérifie l'**enchaînement** et jamais le
**contenu**.

Passer une commande en `PREPARING` ne consomme aucune matière, ne charge aucun
poste, ne réserve rien. Passer en `READY` n'atteste d'aucune étape franchie.
Une cuisine peut déclarer prêtes quarante commandes en quarante clics, sans
qu'aucune règle ne s'y oppose et sans qu'aucun ingrédient ne bouge.

Le corollaire financier est direct : **le coût des marchandises vendues est
inconnu**. Les rapports d'`analytics` donnent un chiffre d'affaires réel et
agrégé en SQL, mais aucune marge — il n'existe aucune donnée pour la calculer.
Pour une dark kitchen, dont le modèle repose sur la maîtrise du coût matière,
c'est l'indicateur manquant, pas un indicateur secondaire.

---

## I6 — Le stock compte des plats, pas des ingrédients

**Gravité : élevée.** Corollaire de I5, mais avec un effet propre.

`MenuItem.tracks_stock` / `stock_quantity` (`catalog/models.py:110-126`).
La décrémentation est techniquement irréprochable — `UPDATE … WHERE
stock_quantity >= n` évalué par la base, sans lecture préalable, donc à l'abri
de deux commandes simultanées (`catalog/services.py:73-74`).

Mais l'unité est fausse. Les plats d'une cuisine partagent leurs ingrédients :
le même pain sert trois burgers, la même sauce six plats. Décompter « 12 burgers
restants » suppose que ces douze existent déjà, faits et emballés — ce qui
décrit un magasin, pas une cuisine.

Effets de bord observables :

- La rupture d'un ingrédient ne retire aucun plat de la carte. Le personnel doit
  basculer `is_available` à la main sur chaque plat concerné — ce que le poste
  de cuisine (`42f24b0`) permet justement de faire, faute de mieux.
- `duplication.py` refuse à juste titre de recopier les stocks. Mais la raison
  invoquée — « `stock_quantity` décrit ce qu'il y a dans une chambre froide » —
  décrit un **ingrédient**, pas un plat fini. Le commentaire dit la bonne chose
  à propos du mauvais champ.

---

## I7 — `QUEUED` manquant, et le vocabulaire de paiement

**Gravité : faible.** À traiter avec la production, pas avant.

Le brief demande `PENDING_PAYMENT → PAID → CONFIRMED → QUEUED`. Le code a
`pending → confirmed`.

- `PENDING_PAYMENT` ≈ `pending` : même sens, autre nom.
- `PAID` n'a pas d'état propre, mais il a un **fait** : la `Transaction` réglée,
  et `PaymentService._confirm_order` (`payments/services.py:349`) qui pose
  `confirmed`. L'information n'est pas perdue, elle est ailleurs — ce qui est
  défendable, la vérité du paiement appartenant à `payments`.
- `QUEUED` n'existe ni comme état ni comme fait. C'est le seul vrai manque, et
  il ne signifie rien tant qu'aucune file de production ne l'attend.

**Ne pas renommer ces états avant le lot production.** Renommer d'abord
imposerait une migration de données, une reprise des trois applications Flutter
et des 1 695 cas de test, pour un gain nul — puis une seconde passe quand `QUEUED`
aura enfin un contenu.

---

## I8 — Le mode hors ligne décrit une capacité qu'il n'a pas

**Gravité : faible.** Aucun effet en production ; à nettoyer.

`offline_sync_service.dart` crée la table `offline_orders`, lui pose deux index,
la lit au démarrage, la purge — et ne l'écrit **jamais**. Aucun `INSERT`, aucune
routine de synchronisation.

Le risque que redoute la phase 25 du brief — une commande réputée créée parce
qu'elle est enregistrée localement — **ne peut pas se produire**, faute
d'écriture. `_pendingOrders` n'est exposée à aucun écran.

Reste que quatre-vingts lignes de schéma et de chargement annoncent une
fonctionnalité absente. Un développeur qui les lit conclut que la commande hors
ligne existe. Voir document 09.

---

## Ce qui n'est PAS incohérent, contrairement à ce qu'on pourrait craindre

Ces points ont été vérifiés parce qu'ils sont les fautes habituelles du domaine.
Aucun n'est présent ici, et il serait coûteux de les « corriger ».

| Soupçon | Réalité |
|---|---|
| Le client fixe les prix | Le panier **ne stocke aucun prix**. Recalcul à chaque lecture depuis le catalogue. |
| Le catalogue réécrit l'historique | `OrderLine` fige nom, image, prix unitaire, options et leurs prix. |
| Double encaissement sur rejeu de webhook | `WebhookEvent` + `provider_reference` unique + `select_for_update`. |
| Deux livreurs sur une course | Verrou sur la **commande** avant lecture de l'affectation. |
| Devise ou pays en dur | Portés par `Country`, hérités par propriété. Traité en `9cb4596`. |
| `is_active` confondu avec `accepts_orders` | Séparés, avec la raison écrite dans le modèle. |
| Statuts libres en base | `CHECK` PostgreSQL **généré depuis** la machine à états. |
| Statistiques simulées | 17 agrégations SQL réelles, zéro constante inventée. |
| Zone ambiguë entre deux barèmes | `resolve_zone()`, lieu unique, depuis `50d0cea`. |
| Rapports non cloisonnés | Cloisonnés par périmètre depuis `50d0cea`. |

---

## Ordre de traitement

| # | Incohérence | Traitée par |
|---|---|---|
| I2 | Disponibilité sans juge | `AvailabilityService` — lot 1 ✅ |
| I6 | Stock en plats finis | Ingrédients + recettes — lot 2 |
| I5 | Production sans contenu | `ProductionTask` + `Station` — lot 2 |
| I1 | Deux temps de préparation | Calcul par poste — lot 2, avec I5 |
| I3 | Catalogue dupliqué | Entité `Menu` publiable — lot 3 |
| I4 | Livreur lié à une cuisine | Périmètre flotte = ville/zone — lot 3 |
| I7 | `QUEUED` absent | Avec la file de production — lot 2 |
| I8 | Hors ligne vestigial | Suppression — lot 0 |

I2 vient en premier parce qu'elle est la seule dont le mécanisme a **déjà**
produit un défaut en production, et parce que la production (lot 2) ajoutera une
huitième question — la capacité — à un ensemble qui n'a pas encore de juge.
