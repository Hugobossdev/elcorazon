# ADR-005 — Modèle d'autorisation unifié

**Statut** : accepté · **Date** : 2026-07-25

## Contexte

L'existant fait cohabiter **deux mécanismes d'autorisation qui s'ignorent** :

1. `users.role` — une colonne texte contrainte à `client | admin | delivery`, utilisée par le
   backend pour garder les routes ;
2. `admin_roles` + `user_admin_roles` — des rôles nommés portant des permissions dans un champ
   JSONB, utilisés par le back-office Flutter pour afficher ou masquer des écrans.

Le second n'a jamais été appliqué côté serveur. Un « Opérateur » privé du module marketing dans
l'interface pouvait appeler l'API marketing sans obstacle : la garde ne testait que `role = admin`.
C'est une autorisation d'apparence, la pire des catégories — elle donne l'illusion du contrôle.

Par ailleurs l'analyse a retenu **T3 : refus par défaut**.

## Décision

Un modèle unique, à deux étages, appliqué **exclusivement côté serveur**.

### Étage 1 — Le type de compte (`UserType`)

Un utilisateur est d'un seul type, structurel et rarement changeant :

```
CUSTOMER · COURIER · STAFF
```

Il détermine l'app qu'on peut utiliser et la nature des ressources accessibles. Il est porté par le
JWT et filtre au plus tôt.

### Étage 2 — Les permissions (pour `STAFF` uniquement)

Le personnel reçoit des permissions nommées `domaine.action`, portées par des rôles cumulables :

```
catalog.read      orders.assign_courier    couriers.approve
catalog.write     orders.refund            promotions.write
orders.read       analytics.read           roles.write
```

Les rôles fournis à l'installation (`Super Admin`, `Manager`, `Opérateur`) ne sont que des
**groupements de permissions**, modifiables. Le code n'a jamais connaissance d'un nom de rôle : il ne
teste que des permissions. C'est ce qui permet de créer un rôle sur mesure sans redéployer.

### Étage 3 — L'appartenance de la ressource

Le type et la permission disent *ce qu'on peut faire*, pas *sur quoi*. Un client ne peut lire que ses
commandes ; un livreur, que les courses qui lui sont assignées ; un membre du personnel, que les
restaurants de son périmètre (cf. ADR-006).

Ce filtrage vit dans le `get_queryset` et dans les permissions d'objet — **jamais** dans le
sérialiseur ni dans le client.

### Refus par défaut

La permission globale du projet est `IsAuthenticated` + refus. Toute route publique est déclarée
explicitement (`AllowAny`), ce qui rend la liste des points d'entrée ouverts auditable en une
recherche. L'inverse — tout ouvert, on restreint au cas par cas — garantit statistiquement l'oubli.

## Conséquences

- Une seule vérité d'autorisation, appliquée là où elle ne peut pas être contournée.
- Le back-office Flutter continue de masquer des écrans, mais uniquement pour le confort : le serveur
  refuserait de toute façon. L'interface ne peut plus être la seule barrière.
- Migration : les rôles existants deviennent des jeux de permissions. Simple, car ils n'étaient
  appliqués nulle part.
- Coût : `couriers.approve` et consorts doivent être définis exhaustivement. Une permission oubliée
  bloque une fonctionnalité — panne visible et corrigible, préférable à une autorisation trop large,
  silencieuse et exploitable.

## Alternatives écartées

| Alternative | Raison du rejet |
|---|---|
| Garder `role` seul | Ne permet aucune granularité. Tout membre du personnel serait tout-puissant. |
| Permissions natives Django (`auth.Permission`) | Liées aux modèles et aux opérations CRUD. `orders.refund` n'est pas un CRUD sur un modèle, et le vocabulaire métier compte pour l'auditabilité. |
| Bibliothèque externe (django-guardian, django-rules) | Guardian pose des permissions par objet en base, coûteux pour un besoin surtout dimensionnel. Le besoin réel tient en une centaine de lignes. |
| ABAC complet (règles sur attributs) | Puissant, mais on ne sait pas encore quelles règles on aura besoin d'exprimer. Adopter ce niveau d'abstraction maintenant serait un pari. |
