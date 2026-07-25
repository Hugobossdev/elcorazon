# ADR-007 — Identifiants et montants

**Statut** : accepté · **Date** : 2026-07-25

## Contexte

Deux primitives traversent tous les domaines. Les fixer mal coûte une migration sur l'intégralité du
schéma ; les fixer bien ne coûte rien.

L'existant utilisait déjà des UUID (bon réflexe), mais des montants en `DECIMAL` **sans devise**, ce
qui rend le multi-pays impossible et l'historique comptable ambigu.

## Décision

### Identifiants : UUIDv7 comme clé primaire

```python
class UUIDModel(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid7, editable=False)
```

**UUIDv7 plutôt que UUIDv4.** Les deux sont opaques et non devinables (T5), mais l'UUIDv7 préfixe
48 bits d'horodatage : les valeurs générées successivement sont **ordonnées**.

L'enjeu est physique. Avec un UUIDv4, chaque insertion tombe à un endroit aléatoire de l'index B-tree,
ce qui fragmente les pages et fait chuter le taux de succès du cache à mesure que la table grossit.
Sur `orders`, `delivery_locations` ou `analytics_events` — les tables à forte cardinalité — la
différence est mesurable. L'UUIDv7 insère en fin d'index, comme une séquence, sans en révéler le
volume.

Bénéfice secondaire : un tri par clé primaire est un tri chronologique, ce qui évite un index
supplémentaire sur `created_at` pour la pagination.

`uuid.uuid7()` est disponible en standard depuis Python 3.14 ; une implémentation locale dans
`common/` couvre 3.13, avec bascule sur la primitive standard dès que les images y passent.

### Montants : entier mineur + devise

```python
class Money:
    amount_minor: int   # 1 250 = 12,50 € ; 1250 = 1250 F CFA
    currency: str       # ISO-4217
```

Deux propriétés, pour deux raisons distinctes.

**Entier en unité mineure, jamais de flottant** (T4). Le flottant binaire ne représente pas
exactement les décimaux : `0.1 + 0.2 != 0.3`. Sur un total de commande, l'écart est invisible ; sur
un cumul de commissions livreur en fin de mois, il devient un litige. Un piège concret rencontré sur
l'implémentation précédente : en PHP 8.5, `json_encode(10.0)` sérialise `10` — le montant perdait sa
décimale dans la réponse. Un entier n'a pas ce comportement.

**Devise portée par le montant, et figée sur la transaction.** Un montant sans devise n'a pas de
sens dès qu'il existe plus d'un pays. Surtout, la devise et le taux applicable sont **copiés sur la
commande au moment de sa création** : une commande passée en XOF reste lisible en XOF pour toujours,
même si le restaurant change de pays ou si le taux évolue. Un historique comptable ne se recalcule
jamais.

En base : `amount_minor BIGINT` + `currency CHAR(3)`, avec un `CHECK` d'exponent cohérent (XOF a zéro
décimale, EUR en a deux — un montant XOF ne doit pas porter de centimes).

## Conséquences

- Un type `Money` en `common/money.py`, avec sérialiseur DRF dédié. L'API expose
  `{"amount": "1250", "currency": "XOF"}` — une chaîne, pas un nombre, pour qu'aucun client JavaScript
  ne la fasse transiter par un flottant.
- Toute arithmétique sur des montants de devises différentes lève une exception. Il n'existe pas de
  conversion implicite.
- L'ORM ne connaît pas nativement un type composite : deux colonnes et une propriété Python. Léger
  surcoût d'écriture, entièrement contenu dans `common/`.
- Les agrégats SQL (`SUM`) portent sur `amount_minor` et **doivent** être groupés par `currency`. Un
  test d'architecture interdit une somme de montants non groupée par devise.

## Alternatives écartées

| Alternative | Raison du rejet |
|---|---|
| `BIGSERIAL` en clé primaire | Divulgue le volume d'activité (`/orders/1042` révèle le nombre de commandes) et l'énumération devient triviale. |
| UUIDv4 | Correct fonctionnellement, mais dégrade les index en écriture sur les tables à forte cardinalité — sans contrepartie. |
| `DECIMAL(10,2)` | Exact en base, mais toute la chaîne applicative (Python, JSON, Dart) le reconvertit en flottant au passage. C'est là que la précision se perd, pas dans PostgreSQL. Et le format à deux décimales est faux pour le XOF. |
| Bibliothèque `py-moneyed` | Fait le travail, mais impose son modèle de persistance et sa gestion des taux. Le besoin ici tient en une centaine de lignes maîtrisées. |
