# ADR-002 — Découpage en applications et dépendances acycliques

**Statut** : accepté · **Date** : 2026-07-25

## Contexte

L'existant est un monolithe implicite : 45 tables sans frontière, dont la cohésion n'était portée
que par des conventions de nommage. N'importe quelle app Flutter pouvait lire n'importe quelle table.
Résultat : aucune règle ne pouvait être garantie, puisqu'aucun code n'était le passage obligé.

Un découpage en applications Django ne résout rien à lui seul — Python n'empêche pas
`from apps.orders.models import Order` dans `apps.catalog`. Sans discipline sur les dépendances, on
obtient les mêmes enchevêtrements dans une arborescence plus jolie.

## Décision

**Découpage par domaine métier** (18 apps, cf. architecture générale §4), avec deux règles de
dépendance opposables :

### Règle 1 — Le graphe de dépendances directes est acyclique

Une app peut importer les modèles et services d'une autre uniquement si l'arête existe dans le graphe
déclaré. `orders` → `catalog` est autorisé ; `catalog` → `orders` ne l'est pas.

Le graphe est déclaré dans `config/architecture.py` et **vérifié par un test** qui analyse les
imports réels via l'AST. Une violation casse la CI. Sans ce test, la règle serait un vœu pieux —
c'est exactement ce qui a échoué dans l'existant.

### Règle 2 — Ce qui remonte le graphe passe par un événement

`orders` ne connaît ni `loyalty`, ni `gamification`, ni `analytics`. Il émet `OrderDelivered` ; ces
apps s'y abonnent. Ajouter un nouveau consommateur ne modifie aucune ligne de `orders`.

Les événements sont dispatchés **après commit** (`transaction.on_commit`) : un abonné ne doit jamais
réagir à une commande dont la transaction sera annulée.

### Couche `common/`

Socle transverse, **sans aucune dépendance vers `apps/`** : modèles de base, montants, machine à
états, permissions réutilisables, pagination, exceptions, helpers géospatiaux. C'est la seule app que
tout le monde peut importer.

## Conséquences

- Le graphe rend les frontières mesurables plutôt que déclaratives.
- `tracking` et `analytics` sont des feuilles : extractibles en services autonomes sans réécriture
  si la charge l'exige un jour.
- Coût réel : un événement est moins direct à suivre qu'un appel de fonction. Atténué en gardant un
  registre unique des événements de domaine et de leurs abonnés, dans `docs/architecture/`.
- Les migrations Django restent globales : le découpage est logique, pas physique. Une extraction en
  service demanderait un vrai travail de scission de schéma — mais elle resterait possible, ce qui
  n'est pas le cas aujourd'hui.

## Alternatives écartées

| Alternative | Raison du rejet |
|---|---|
| Microservices dès le départ | Le volume (1 000 utilisateurs simultanés visés) ne le justifie pas. On paierait la latence réseau, la cohérence distribuée et l'exploitation multipliée pour un problème qu'on n'a pas encore. |
| Une seule app `core` | Reproduit le monolithe indifférencié de l'existant. |
| Découpage technique (`models/`, `views/`, `services/` à la racine) | Regroupe ce qui change pour des raisons différentes. Une évolution du paiement toucherait quatre dossiers. |
| Frontières par convention, sans test | C'est ce qu'a fait l'existant. Les conventions non vérifiées ne survivent pas à la pression du délai. |
