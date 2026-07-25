# ADR-008 — Temps réel : Channels ou notification push

**Statut** : accepté · **Date** : 2026-07-25

## Contexte

Quatre flux exigent une propagation quasi immédiate (Phase 1 §8) : position du livreur, changement de
statut de commande, mise à disposition d'une course, chat.

WebSocket et notification push résolvent des problèmes différents, et les confondre produit soit une
application qui rate des événements en arrière-plan, soit une consommation de batterie inacceptable.
L'existant s'appuyait sur les abonnements Realtime de Supabase, c'est-à-dire sur un abonnement
**direct aux tables** depuis le client — donc sans filtrage métier possible.

## Décision

Le critère est simple : **l'application est-elle au premier plan ?**

| | WebSocket (Channels) | Push (FCM) |
|---|---|---|
| Condition | App ouverte, écran concerné affiché | App fermée ou en arrière-plan |
| Coût | Connexion maintenue | Aucun |
| Garantie | Aucune si déconnecté | Remise différée par l'OS |
| Charge utile | Complète | Minimale, l'app recharge |

### Répartition par flux

| Flux | Transport | Justification |
|---|---|---|
| Position du livreur | **WebSocket seul** | N'a de valeur que sur une carte affichée. En arrière-plan, aucun intérêt à réveiller le téléphone toutes les 10 s. |
| Statut de commande | **Les deux** | WebSocket si l'écran de suivi est ouvert ; push sinon. « Votre commande arrive » doit passer app fermée. |
| Nouvelle course disponible | **Push prioritaire** + WebSocket | Le livreur n'a pas l'app au premier plan en roulant. C'est le seul flux où rater un événement a un coût métier direct. |
| Chat | **WebSocket** + push si absent | Standard du domaine. |

### Ce qui n'est pas résolu par ce choix

Un WebSocket ne garantit rien : une reconnexion après coupure réseau doit pouvoir rattraper les
événements manqués. Chaque groupe porte donc un **numéro de séquence**, et le client demande à la
reconnexion ce qu'il a raté (`?since=<seq>`). Sans cela, un tunnel routier produit une carte figée
qui ne se répare jamais.

### Autorisation à la connexion

C'est le point où l'existant échouait. Un abonnement Supabase donnait accès à des lignes, pas à un
périmètre métier — d'où la falsification de suivi (**L3**).

En v2, `connect()` vérifie, **avant** d'accepter le socket :

- le JWT est valide et non révoqué ;
- l'utilisateur a un droit sur la ressource — le client est bien celui de la commande, le livreur est
  bien celui à qui la course est assignée, le membre du personnel a bien `orders.read` ;
- la commande est dans un état où un suivi a du sens.

Un socket refusé est fermé avec un code explicite, jamais laissé ouvert en lecture seule.

### Groupes

```
order.{order_id}.tracking     un client, un livreur, le personnel
order.{order_id}.chat         un client, un livreur
courier.{courier_id}          les courses proposées à ce livreur
restaurant.{restaurant_id}    le tableau de bord du personnel
```

Le nommage est hiérarchique et contient toujours l'identifiant de la ressource : aucun groupe ne
peut être rejoint sans que la vérification ci-dessus ait porté sur cet identifiant.

## Conséquences

- Un seul déploiement ASGI sert HTTP et WebSocket (ADR-001).
- Le *channel layer* Redis est indispensable dès deux répliques — sans lui, un événement émis par
  une réplique n'atteint pas les clients connectés à l'autre.
- Le push FCM part **toujours** par Celery, jamais dans le cycle de requête : un appel OAuth suivi
  d'un POST par appareil ajouterait des centaines de millisecondes à chaque changement de statut.
- Les jetons FCM morts doivent être purgés. L'implémentation précédente retentait trois fois un
  appareil désinstallé à chaque notification, indéfiniment : la réponse du service doit distinguer
  l'échec transitoire de l'appareil définitivement injoignable, et supprimer dans le second cas.

## Alternatives écartées

| Alternative | Raison du rejet |
|---|---|
| Polling HTTP | À 10 s et 200 livreurs, c'est 1,7 M de requêtes par jour pour rien, et une latence de suivi égale au pas de scrutation. |
| Push seul | La position du livreur en push serait un désastre de batterie et de quota FCM. |
| WebSocket seul | Rate tout événement app fermée — dont l'arrivée du livreur, qui est le moment où la notification compte le plus. |
| Supabase Realtime | Abonnement aux tables, pas au métier : impossible d'exprimer « ce livreur ne peut publier que sur la course qui lui est assignée ». C'est la cause racine de L3. |
| Server-Sent Events | Unidirectionnel : ne convient ni au chat ni à la remontée de position. |
