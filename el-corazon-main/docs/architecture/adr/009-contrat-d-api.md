# ADR-009 — Contrat d'API

**Statut** : accepté · **Date** : 2026-07-25

## Contexte

Les clients Dart actuels imposent trois contraintes de forme, relevées en Phase 1 §7 et vérifiées sur
l'implémentation précédente :

1. la pagination est lue **à la racine** (`current_page`, `last_page`, `total`), pas sous `meta` —
   l'enveloppe standard de DRF casse toutes les listes ;
2. les booléens transitent en chaîne (`?popular_only=true`) ;
3. `User.fromMap` et `Address.fromJson` appellent `DateTime.parse` **sans garde nulle** — omettre
   `created_at` d'une réponse d'authentification ne dégrade pas l'affichage, **ça fait planter la
   connexion**.

Il faut choisir : plier le contrat serveur à ces clients, ou concevoir un contrat propre et adapter
les clients.

## Décision

**Contrat propre, rupture assumée avec les clients Dart actuels.**

La Phase 6 réécrit de toute façon la couche `data/` des applications Flutter en Clean Architecture.
Contraindre le serveur pour préserver un code qui sera remplacé reviendrait à figer trois défauts —
dont un plantage au démarrage sur champ absent — dans un contrat destiné à durer des années.

La compatibilité n'est donc pas rompue *par négligence* : elle est rompue *dans le même chantier* qui
réécrit l'autre bout. C'est une migration coordonnée, pas une régression.

### Le contrat

**Versionnement par URL** : `/api/v1/`. Explicite, visible dans les journaux, trivial à router côté
Nginx. Une v2 pourra coexister sans négociation de contenu.

**Enveloppe de liste** — conforme à DRF, avec le total à la racine :

```json
{ "count": 142, "next": "...?page=3", "previous": "...?page=1", "results": [ ... ] }
```

Pagination par curseur (`cursor`) sur les flux à forte cardinalité — positions, notifications,
événements — où `OFFSET` dégénère en fin de liste.

**Erreurs** — RFC 9457 (`application/problem+json`), avec un code métier stable :

```json
{
  "type": "https://api.elcorazon.app/errors/insufficient-stock",
  "title": "Stock insuffisant",
  "status": 409,
  "code": "insufficient_stock",
  "detail": "Il reste 2 unités de « Burger Corazón ».",
  "errors": { "items.0.quantity": ["Quantité supérieure au stock disponible."] }
}
```

Le client s'appuie sur `code`, jamais sur `detail` : les messages sont traduisibles et peuvent
changer, les codes non.

**Dates** — ISO 8601 en UTC, toujours présentes quand le modèle les porte. Le contrat OpenAPI marque
explicitement ce qui peut être nul, et un test de contrat vérifie qu'un champ déclaré non nul ne
sort jamais absent. C'est la réponse structurelle au piège nº 3 : le serveur garantit la présence,
plutôt que d'espérer que le client se protège.

**Booléens** — `true`/`false` en JSON. En chaîne de requête, `true`, `1`, `yes` sont acceptés : ce
n'est pas une concession aux clients actuels mais une robustesse normale des paramètres d'URL, qui
n'ont pas de typage.

**Montants** — objet `{"amount": "1250", "currency": "XOF"}`, la valeur en chaîne (ADR-007).

**Idempotence** — en-tête `Idempotency-Key` obligatoire sur la création de commande et l'initiation
de paiement. Un client mobile qui perd le réseau après l'envoi retente ; sans clé d'idempotence, il
crée une seconde commande. Ce n'est pas un cas rare, c'est le quotidien du réseau mobile.

**Documentation** — OpenAPI 3.1 généré par `drf-spectacular` depuis les sérialiseurs, servi sur
`/api/v1/schema/`. Généré, donc jamais désynchronisé du code.

## Conséquences

- Les trois apps Flutter doivent migrer leur couche data. Prévu en Phase 6 ; le catalogue et
  l'authentification passent d'abord, le reste suit.
- Pendant la transition, les apps peuvent continuer d'attaquer Supabase pour les domaines non encore
  migrés. La bascule se fait domaine par domaine, jamais en une fois.
- L'idempotence exige une table de clés consommées avec purge périodique. Coût réel, bénéfice
  supérieur : c'est ce qui empêche les commandes en double.
- Le schéma OpenAPI devient un artefact de CI : sa modification apparaît en revue, ce qui rend toute
  rupture de contrat visible avant livraison.

## Alternatives écartées

| Alternative | Raison du rejet |
|---|---|
| Épouser le contrat des clients actuels | Fige un plantage sur champ absent et une pagination non standard dans un contrat durable, pour préserver du code déjà condamné. |
| JSON:API | Très normalisé, mais verbeux et sans usage dans l'écosystème Flutter du projet. Coût d'apprentissage sans bénéfice ici. |
| GraphQL | Répondrait bien à trois clients aux besoins divergents, mais complique la limitation de débit, le cache et l'autorisation par champ. Prématuré. |
| Versionnement par en-tête | Invisible dans les journaux et les traces, plus difficile à router. |
| Pas de versionnement | On y revient toujours, mais en urgence. |
