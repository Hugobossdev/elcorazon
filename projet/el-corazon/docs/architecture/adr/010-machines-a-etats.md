# ADR-010 — Machines à états déclaratives

**Statut** : accepté · **Date** : 2026-07-25

## Contexte

Quatre entités ont un cycle de vie contraint : commande (8 états), livraison (5), paiement (5),
dossier livreur (3). Ce sont les objets sur lesquels l'implémentation précédente a produit **quatre
des douze failles prouvées** :

- **C3** — rejouer `delivered` réincrémentait `completed_deliveries` et `total_deliveries` : le
  livreur gagnait des livraisons en rappelant un point d'entrée ;
- **C4** — l'étape `accepted` écrivait sur la commande un statut absent de l'énumération, ce qui
  aurait violé la contrainte `CHECK` en production ;
- **C5** — une commande annulée pouvait encore être prise en charge ou payée ;
- **P1** — un webhook rejoué rétrogradait un paiement `completed`.

Le point commun n'est pas l'inattention : c'est que les transitions étaient écrites en `if` dispersés
dans les contrôleurs. Chaque nouveau point d'entrée devait re-vérifier l'ensemble des règles, et il
suffisait d'en oublier une.

## Décision

Les transitions sont **déclarées une fois, en donnée**, et la déclaration est le seul chemin d'écriture.

```python
class OrderStatus(models.TextChoices):
    PENDING = "pending"; CONFIRMED = "confirmed"; PREPARING = "preparing"
    READY = "ready"; PICKED_UP = "picked_up"; ON_THE_WAY = "on_the_way"
    DELIVERED = "delivered"; CANCELLED = "cancelled"

ORDER_TRANSITIONS = {
    OrderStatus.PENDING:    {OrderStatus.CONFIRMED, OrderStatus.CANCELLED},
    OrderStatus.CONFIRMED:  {OrderStatus.PREPARING, OrderStatus.CANCELLED},
    OrderStatus.PREPARING:  {OrderStatus.READY, OrderStatus.CANCELLED},
    OrderStatus.READY:      {OrderStatus.PICKED_UP, OrderStatus.CANCELLED},
    OrderStatus.PICKED_UP:  {OrderStatus.ON_THE_WAY},
    OrderStatus.ON_THE_WAY: {OrderStatus.DELIVERED},
    OrderStatus.DELIVERED:  frozenset(),   # terminal
    OrderStatus.CANCELLED:  frozenset(),   # terminal
}
```

### Quatre propriétés garanties par construction

**Monotonie.** Le graphe est acyclique et deux états sont terminaux. Aucun retour arrière n'est
exprimable — **C3** devient impossible, et non plus « à ne pas oublier ». Les compteurs de livraison
peuvent donc être incrémentés lors de la transition sans garde supplémentaire.

**Exhaustivité.** Toute valeur écrite provient de l'énumération, elle-même reflétée en base par une
contrainte `CHECK` générée depuis la même source. **C4** ne peut pas se produire : le code et le
schéma ne peuvent pas diverger puisqu'ils ont une origine unique.

**Passage obligé.** L'écriture du statut est privée ; seule `transition_to(target, by, reason)`
l'expose. Elle vérifie l'autorisation de transition, écrit le statut, journalise dans l'historique et
émet l'événement de domaine — dans **une seule transaction**. Impossible de changer un statut sans
trace, ce qui rend **C5** structurel : la garde est dans la déclaration, pas dans l'appelant.

**Idempotence.** Une transition vers l'état courant est un `no-op` explicite qui retourne sans
réécrire ni réémettre. C'est la réponse directe à **P1** : rejouer un webhook `completed` ne fait
rien.

### Verrouillage

Toute transition ouvre par un `SELECT ... FOR UPDATE` sur la ligne. Deux livreurs acceptant la même
course simultanément sont sérialisés : le premier passe, le second se voit refuser une transition
depuis un état qui n'est plus valide. C'est ce qui ferme **L2** sans code de verrouillage explicite
dans chaque appelant.

### Projection entre machines

La livraison et la commande ont des cycles distincts mais couplés : `picked_up` côté livraison doit
projeter `picked_up` côté commande. La table de correspondance est déclarée à côté des transitions,
et la projection s'exécute dans la même transaction. C'est là que **C4** était né — d'une projection
écrite à la main vers un état inexistant.

### Tests

Une propriété générique, appliquée aux quatre machines : pour tout couple d'états (A, B) non déclaré,
`transition_to` doit refuser. Cela couvre 64 combinaisons pour la commande, dont l'immense majorité
n'aurait jamais été testée à la main — et c'est dans cette majorité que vivaient C3 et C4.

## Conséquences

- Ajouter un état est une modification locale : l'énumération, la table de transitions, la
  correspondance. Les tests de propriété couvrent immédiatement les nouvelles combinaisons.
- L'historique de statut est un sous-produit gratuit, plus une écriture séparée qu'on peut oublier.
- Contrainte de discipline : personne n'écrit `order.status = ...` directement. Vérifié par un test
  d'architecture qui inspecte les affectations dans l'AST.
- Une transition légitime mais non déclarée devient une panne visible plutôt qu'une corruption
  silencieuse. C'est le bon sens de l'échec.

## Alternatives écartées

| Alternative | Raison du rejet |
|---|---|
| `if` dans les services | Exactement l'existant. Chaque point d'entrée redéclare les règles, donc en oublie. |
| `django-fsm` | Fait le travail, mais n'est plus maintenu activement et attache les transitions aux méthodes du modèle, ce qui y ramène de la logique métier. Le besoin tient en une centaine de lignes dans `common/`. |
| Contraintes SQL seules (triggers) | Défendent la donnée mais ne peuvent ni émettre d'événement ni journaliser proprement, et le message d'erreur est illisible côté API. Conservées **en complément**, comme dernière ligne. |
| *Event sourcing* | Résoudrait l'historique et la reprise, au prix d'une complexité sans rapport avec la taille du produit. |
