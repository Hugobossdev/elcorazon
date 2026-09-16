# 07 — Audit de la base de données

PostgreSQL 17 + PostGIS 3.5. 51 migrations réparties sur 20 apps.

**Verdict : le schéma est le socle le plus solide du projet.** Les invariants
sont portés par la base, pas par la discipline. Ce document relève trois points
à surveiller et fixe les règles pour les tables du lot 2.

---

## 1. Inventaire

| Élément | Compte |
|---|---|
| `CheckConstraint` | **38** |
| `UniqueConstraint` | **32** |
| `models.Index` | 52 |
| `gis.Index` (GiST) | 4 |
| `select_for_update()` | 26 |
| `select_related` | 122 |
| `prefetch_related` | 14 |
| Migrations | 51 |

Politique de suppression :

| `on_delete` | Compte | Usage |
|---|---|---|
| `CASCADE` | 76 | données dépendantes sans valeur propre (lignes, options, rattachements) |
| `PROTECT` | **29** | ce qu'une écriture comptable référence |
| `SET_NULL` | 8 | rattachements facultatifs |

29 `PROTECT` est le bon signe : `Order.restaurant`, `Order.customer`,
`OrderLine.menu_item`, `Refund.order`, `Refund.transaction`,
`CourierProfile.restaurant` — rien de ce qu'une commande référence ne peut
disparaître sous elle.

---

## 2. Ce qui distingue ce schéma

### Les statuts sont contraints par la base, depuis le code

```python
state_check_constraint(ORDER_MACHINE, "status", "order_status_in_enum")
```

La contrainte `CHECK` est **générée depuis la table de transitions**. Le schéma
ne peut pas accepter un statut que le code ignore, ni l'inverse — et l'en-tête
d'`orders/states.py` nomme le défaut que ce mécanisme a fermé (« C4 »).

Une écriture hors application — `django-admin`, `shell`, script de reprise — ne
peut pas poser un état invalide. C'est le dernier rempart, et il est réel.

### Les montants sont entiers

`MoneyField` stocke en unités mineures (`*_minor`). Aucun flottant dans un
chemin d'argent, et `test_aucune_app_ne_contourne_common_pour_les_montants`
empêche qu'une app se fabrique son propre champ.

Contraintes associées sur `Order` :

```
order_amounts_not_negative      subtotal, delivery_fee, discount, total ≥ 0
order_discount_within_bounds    discount ≤ subtotal + delivery_fee
```

La seconde empêche une commande de rapporter de l'argent au client.

### Les invariants complexes sont exprimés, pas commentés

Trois exemples qui auraient pu rester des conventions :

```python
# AreaMembership — un rattachement vise un pays OU une ville, jamais les deux
CheckConstraint(
    condition=Q(country__isnull=False, city__isnull=True)
            | Q(country__isnull=True, city__isnull=False),
    name="area_membership_exactly_one_target",
)

# DeliveryZone — un disque porte son centre et son rayon, un polygone non
CheckConstraint(
    condition=Q(shape="circle", center__isnull=False, radius_meters__isnull=False)
            | (~Q(shape="circle") & Q(center__isnull=True, radius_meters__isnull=True)),
    name="zone_circle_carries_center_and_radius",
)

# OpeningHours — une plage vide n'est pas une plage
CheckConstraint(condition=~Q(opens_at=F("closes_at")), name="opening_hours_not_empty")
```

Chacune tient aussi pour `django-admin`, pour une commande de peuplement et pour
une correction en `shell` — ce qu'une validation de sérialiseur ne fait pas.

### Les index suivent les requêtes réelles

```python
Index(fields=["restaurant", "status", "-placed_at"])   # tableau de bord du personnel
Index(fields=["customer", "-placed_at"])               # historique client
gis.Index(fields=["boundary"])                         # résolution de zone
gis.Index(fields=["location"])                         # tri des livreurs par distance
Index(fields=["restaurant", "is_active"], name="zone_restaurant_active_idx")
```

Les index composés sont ordonnés dans le sens des clauses, pas posés colonne par
colonne. Le GiST sur `boundary` est indispensable : sans lui, déterminer la zone
d'un point balaie la table à chaque commande.

### Les instantanés protègent l'histoire

| Table | Ce qui est figé |
|---|---|
| `OrderLine` | `item_name`, `item_image`, prix unitaire, options **et leurs prix** |
| `Order` | adresse, point de livraison, nom et téléphone du destinataire, `promo_code` |

L'adresse est **copiée**, pas référencée. Une suppression RGPD du carnet
d'adresses n'ébrèche pas la comptabilité. `MenuItem` est en `SoftDeleteModel`
pour la même raison, dite explicitement dans le modèle : « une écriture
comptable pointe dessus ».

### La concurrence est traitée, et testée

26 `select_for_update()`, sur tous les chemins d'argent et d'affectation. Les
quatre scénarios de la phase 32 du brief ont chacun leur test :

| Scénario | Test |
|---|---|
| Dernière unité, deux commandes | `test_deux_commandes_concurrentes_n_emportent_pas_la_meme_unite` |
| Même clé d'idempotence | `test_un_rejeu_ne_cree_pas_une_seconde_commande` |
| Même webhook deux fois | `test_le_meme_evenement_ne_passe_pas_deux_fois` |
| Deux livreurs, une course | `test_deux_livreurs_ne_prennent_pas_la_meme_course` |

Deux techniques distinctes, chacune à sa place :

```python
# Décrément de stock — évalué par la base, sans lecture préalable
MenuItem.objects.filter(pk=item_id, tracks_stock=True, stock_quantity__gte=quantity) \
    .update(stock_quantity=F("stock_quantity") - quantity)

# Affectation — verrou sur la COMMANDE, pas sur la course
locked = Order.objects.select_for_update().get(pk=assignment.order_id)
```

Le second point est subtil et juste : ce qu'on protège est l'unicité de la
course active, qui est une propriété de la **commande**. Verrouiller la course
qu'on s'apprête à créer ne protégerait rien.

---

## 3. Les trois points à surveiller

### P1 — `prefetch_related` sous-employé (14 contre 122 `select_related`)

`select_related` couvre les clés étrangères ; les relations inverses et
plusieurs-à-plusieurs demandent `prefetch_related`. Un rapport de 1 à 9 mérite
d'être vérifié sur les endpoints de liste à relations profondes — typiquement
le catalogue (`MenuItem → OptionGroup → Option`) et le KDS
(`Order → OrderLine → options`).

**Ce n'est pas un constat de N+1, c'est une zone à mesurer.** Voir document 34
pour la méthode : mesurer avant d'optimiser. Un `assertNumQueries` sur les trois
listes les plus chargées répondrait définitivement.

### P2 — Aucune contrainte n'interdit le chevauchement de plages horaires

`OpeningHours` a `opening_hours_unique_slot` (établissement, jour, heure
d'ouverture) et `opening_hours_not_empty`. Rien n'empêche `08:00–14:00` et
`12:00–18:00` de coexister le même jour.

L'effet est bénin — `is_open_at()` rend `True` dans les deux cas, et les plages
se contentent de se recouvrir — mais l'affichage des horaires au client montrera
deux créneaux qui se chevauchent, ce qui se lit mal.

PostgreSQL a `ExclusionConstraint` avec `btree_gist` pour exactement ce cas. À
poser si l'on veut fermer la saisie ; à documenter comme accepté sinon.

### P3 — `delivery_fee_gross` est nullable, et le restera

Le champ a été ajouté après coup ; les commandes antérieures retombent sur
`delivery_fee`. C'est la bonne décision — rétro-remplir aurait inventé une
donnée — mais elle impose à chaque lecteur de gérer le `None`.

À documenter comme dette permanente plutôt qu'à corriger : le jour où plus
aucune commande antérieure n'est consultée, le champ pourra passer non nul.

---

## 4. Règles pour les tables du lot 2

L'inventaire et la production introduiront les premières tables **à valeur
comptable** en dehors de `payments`. Ce qu'elles devront porter :

### `StockMovement` est un journal, pas un état

- **Jamais de `UPDATE`, jamais de `DELETE`.** Une erreur se **contre-passe** par
  un mouvement inverse. C'est ce qui rend l'inventaire auditable.
- Index par curseur (`-created_at`, `id`) : la table ne cesse de grandir.
- `PROTECT` sur `ingredient` et sur `kitchen`.
- Type de mouvement en `TextChoices`, contraint par `CHECK` — même mécanisme que
  les statuts.

### Le stock courant est dérivé, pas saisi

Deux options, à trancher au lot 2 :

| Option | Avantage | Coût |
|---|---|---|
| Somme des mouvements à la lecture | une seule vérité, pas de désynchronisation | coûteux dès 10⁵ mouvements |
| Colonne `on_hand` maintenue par `F()` | lecture instantanée | peut diverger du journal |

**Recommandation : la colonne, avec un test de réconciliation.** C'est le choix
déjà fait pour `MenuItem.stock_quantity`, décrémenté par `F()` sans lecture
préalable — la technique est acquise, elle se transpose. Le test de
réconciliation (somme des mouvements = `on_hand`) est ce qui rend l'option
défendable, et il doit être écrit en même temps que la colonne.

### Le stock négatif est interdit, sauf règle explicite

Le brief le demande. La forme est déjà connue dans ce dépôt :

```python
CheckConstraint(condition=Q(on_hand__gte=0), name="inventory_no_negative_stock")
```

Si une cuisine doit pouvoir passer en négatif (consommation saisie après coup),
ce doit être un **type de mouvement** qui l'autorise explicitement, pas une
contrainte retirée.

### Réservation et libération sont des mouvements, pas des drapeaux

`RESERVATION` et `RELEASE` figurent dans les types demandés par le brief. Les
traiter comme des mouvements — et non comme un booléen sur la ligne de commande
— fait que le stock disponible est toujours `on_hand − réservé`, calculable, et
qu'une réservation orpheline se voit dans le journal.

---

## 5. Migrations

51 migrations, aucune anomalie relevée. La règle de la phase 31 du brief — ne
jamais modifier une migration déjà appliquée en production — est à tenir
d'autant plus que **le backend vit dans deux dépôts** : `elcorazon` et
`elcorazon-backend`, ce dernier étant celui que Render déploie. L'en-tête de
`backend/.github/workflows/backend-ci.yml` raconte l'incident que cette
séparation a déjà produit — un correctif testé et vert, dans un commit non
poussé, pendant que la production envoyait ses notifications dans le vide.

**Conséquence pour le lot 2** : les migrations d'inventaire et de production
devront arriver dans les deux dépôts, et le tableau de bord vert de l'un ne dit
rien de l'autre. Voir document 08.

---

## Synthèse

| Volet | État |
|---|---|
| Clés étrangères et politiques de suppression | **abouti** — 29 `PROTECT` bien placés |
| Contraintes `CHECK` | **abouti** — 38, dont les statuts générés |
| Contraintes d'unicité | **abouti** — 32 |
| Index | **abouti** — composés dans le sens des requêtes, 4 GiST |
| Transactions et verrous | **abouti** — 26 `select_for_update`, 4 scénarios testés |
| Instantanés historiques | **abouti** |
| Suppression douce | **présente** là où c'est nécessaire |
| `prefetch_related` | **à mesurer** (P1) |
| Chevauchement d'horaires | **non contraint** (P2) — bénin |
| Tables d'inventaire | **à créer** — règles fixées au §4 |
