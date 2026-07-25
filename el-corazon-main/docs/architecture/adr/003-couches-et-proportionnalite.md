# ADR-003 — Couches proportionnées à l'enjeu

**Statut** : accepté · **Date** : 2026-07-25

## Contexte

La mission demande *Services Layer*, *Repository Pattern*, *Domain Layer* et *DTO*. Appliqués
uniformément aux 18 domaines, ces patrons produiraient environ 400 fichiers dont une large majorité
ne ferait que transporter un appel `.save()` d'une couche à la suivante.

Ce n'est pas une crainte théorique. L'implémentation précédente a fini avec 40 classes de validation
et 6 politiques d'autorisation, et son propre journal d'architecture note, pour le module catalogue :

> « Pas de Service ni de Policy créés : CRUD trivial déjà protégé par `role:admin` — couches
> inutiles écartées. »

Le constat est juste et mérite d'être érigé en règle plutôt que redécouvert domaine par domaine.

## Décision

Les couches sont **conditionnelles**, selon des critères explicites.

### Un service de domaine existe si l'opération remplit au moins un critère

1. elle écrit dans plus d'une table sous transaction ;
2. elle porte une décision métier (calcul de prix, validité d'une transition, éligibilité) ;
3. elle doit résister à la concurrence (verrou, débit conditionnel) ;
4. elle émet un événement de domaine ;
5. elle appelle un service externe.

### Un repository existe si la requête remplit au moins un critère

1. elle est réutilisée par au moins deux appelants ;
2. elle dépasse trois jointures ou nécessite un `select_related`/`prefetch_related` non trivial ;
3. elle est géospatiale ;
4. elle doit être remplaçable en test sans base de données.

### Sinon

`ViewSet` → `Serializer` → ORM. Directement. C'est du Django idiomatique, lisible par n'importe quel
développeur Django, et cela ne coûte rien à faire évoluer le jour où un critère devient vrai.

### Application aux domaines

| Service | Repository | Domaines |
|---|---|---|
| oui | oui | `orders`, `payments`, `delivery` |
| oui | non | `carts`, `loyalty`, `promotions`, `accounts` (auth) |
| non | oui | `tracking` (requêtes géospatiales), `analytics` |
| non | non | `catalog`, `geography`, `restaurants`, `profiles`, `notifications` (lecture) |

### DTO

Des `dataclass` **gelées** aux seules frontières où un dictionnaire nu serait ambigu : entrée des
services de commande, de paiement et de livraison. Pas de DTO de sortie — les sérialiseurs DRF
remplissent déjà ce rôle, en dupliquer un second jeu créerait deux contrats à maintenir en phase.

## Conséquences

- L'arborescence est irrégulière : certaines apps ont `services/`, d'autres non. **C'est voulu**, et
  documenté ici pour qu'on ne « corrige » pas cette asymétrie par réflexe de symétrie.
- Une revue de code peut trancher objectivement l'ajout d'une couche : on cite le critère rempli.
- Le risque inverse — laisser grossir une vue jusqu'à ce qu'elle porte du métier — est traité par
  une règle de revue : toute vue dépassant 40 lignes de logique déclenche l'extraction d'un service.

## Alternatives écartées

| Alternative | Raison du rejet |
|---|---|
| Couches systématiques partout | Coût de maintenance sans contrepartie ; la traversée d'un CRUD demanderait d'ouvrir cinq fichiers. |
| Aucune couche, tout en ViewSet | Reproduit exactement la faiblesse de l'existant : la règle métier vit là où on l'appelle, donc en plusieurs exemplaires ou en aucun. |
| Architecture hexagonale stricte (ports/adaptateurs sur tout) | Justifiée si l'on prévoyait de remplacer l'ORM ou le framework. Ce n'est pas le cas, et le prix serait payé immédiatement pour un bénéfice hypothétique. |
