# ADR-006 — Multi-tenant géographique

**Statut** : accepté · **Date** : 2026-07-25

## Contexte

La mission exige une plateforme « prête pour plusieurs pays », « multi-restaurants, multi-villes,
multi-pays ».

L'existant est strictement mono-restaurant : aucune table `restaurants`, `cities` ou `countries`. Le
catalogue est global, les frais de livraison sont une constante — et une constante contradictoire,
`5.00` sur `orders.delivery_fee` contre `500.0` sur `user_carts.delivery_fee`, ce qui trahit
l'absence de toute règle de tarification. Il n'y a rien à migrer : il faut concevoir.

Le risque symétrique est le sur-dimensionnement. El Corazón opère aujourd'hui **un** restaurant. Une
plateforme multi-pays complète — devises, fiscalité, langues, fuseaux, entités juridiques — serait
plusieurs mois de travail au service d'un besoin hypothétique, et ralentirait chaque fonctionnalité
du chemin critique.

## Décision

**Poser la hiérarchie complète dans le modèle de données, n'implémenter que ce qui sert
aujourd'hui.** La structure est le coût irrécupérable — la rajouter après coup imposerait de migrer
commandes, paiements et historiques. Les fonctionnalités, elles, s'ajoutent sans rien casser.

### Hiérarchie

```
Country (ISO-3166, devise, fuseau, langue par défaut)
   └── City
         └── DeliveryZone  (polygone PostGIS, barème de frais, horaires)
               └── Restaurant  (établissement, horaires, rayon de service)
                     └── Catalogue, personnel, flotte
```

### Ce qui est implémenté maintenant

- Les quatre modèles, avec leurs clés étrangères et leurs index.
- `Restaurant` comme point de rattachement : `orders`, `menu_items`, `couriers` portent tous une
  clé de restaurant **non nulle**. C'est cette colonne, présente dès le premier jour, qui rend
  l'ouverture d'un second établissement indolore.
- Un `DeliveryZone` polygonal avec calcul de frais par distance réelle — cela remplace la constante
  incohérente et sert immédiatement, même avec un seul restaurant.
- Un jeu de données initial : un pays (Togo), une ville, une zone, un restaurant.

### Ce qui est reporté, sans obstacle futur

| Reporté | Débloqué par |
|---|---|
| Sélection de restaurant par le client | Un écran, la donnée est déjà là |
| Catalogues réellement divergents | Le catalogue est déjà rattaché au restaurant |
| Multi-devises effectif (conversion, affichage) | La devise est déjà portée par `Country` et figée sur chaque commande (ADR-007) |
| Fiscalité et entités juridiques par pays | Nouvelle app, aucune reprise du modèle existant |
| Périmètre du personnel par restaurant | Le champ existe, le filtrage sera activé quand il y aura plus d'un site |

### Filtrage

Le rattachement au restaurant est appliqué dans les `get_queryset`, jamais laissé au client. Avec un
seul restaurant le filtre est un passe-plat — mais il est **écrit et testé dès maintenant**. Un
filtre de périmètre qu'on ajoute après coup est précisément le genre de chose qu'on oublie sur trois
points d'entrée sur vingt.

## Conséquences

- Toute commande, tout article, tout livreur porte un restaurant. Non négociable, y compris pour les
  jeux de test — ce qui garantit que le chemin multi-site est exercé en permanence.
- Une jointure de plus sur les requêtes catalogue. Négligeable, et indexée.
- L'ouverture d'un second restaurant devient une opération de données, pas un chantier de migration.
- Risque assumé : si El Corazón reste mono-site indéfiniment, on aura porté une hiérarchie à quatre
  niveaux pour rien. Le coût est de l'ordre de quelques dizaines de lignes et d'une jointure — sans
  commune mesure avec celui d'une migration rétroactive sur des données comptables.

## Alternatives écartées

| Alternative | Raison du rejet |
|---|---|
| Mono-restaurant, on verra plus tard | Reporte le coût au moment où il est maximal : sur des commandes et des paiements historiques. |
| Multi-tenant par schéma PostgreSQL | Isole fortement, mais fait exploser le coût des migrations et interdit toute requête analytique transverse. Justifié si les clients étaient des entreprises distinctes ; ici les restaurants appartiennent au même opérateur. |
| Multi-tenant par base de données | Même objection, en pire. |
| Implémenter tout le multi-pays maintenant | Plusieurs mois pour un besoin non avéré, au détriment du chemin critique. |
