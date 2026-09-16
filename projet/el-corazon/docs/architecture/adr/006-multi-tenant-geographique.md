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

### Ce qui a été ajouté depuis (septembre 2026)

La hiérarchie n'a pas bougé ; ce qui manquait, c'est ce qui la rendait
exploitable. Quatre ajouts, tous sans reprise de schéma sur l'existant.

- **Périmètre de marché et de ville** (`AreaMembership`). Le cloisonnement
  n'avait que deux étages : le siège, qui voit tout, et le rattachement à un
  établissement, qui ne voit que lui. Un directeur pays devait donc être
  rattaché à chacun de ses établissements un par un — et cessait
  **silencieusement** de voir le suivant qu'on ouvrait. Le palier s'ajoute au
  point de passage unique (`staff_restaurant_ids`), si bien que les huit écrans
  qui le consultent — commandes, catalogue, flotte, promotions, fidélité,
  paiements, rapports, personnel — en héritent d'un coup, et qu'un neuvième
  écrit demain en héritera sans qu'on y pense.
- **Cloisonnement des rapports.** Les agrégats d'`analytics` ignoraient le
  périmètre : un gérant rattaché au seul établissement de Lomé, muni de
  `analytics.read`, lisait le chiffre d'affaires d'Abidjan. Le défaut était
  silencieux — la réponse rendait des chiffres justes, simplement pas les
  siens. Le filtre du compte et le filtre demandé (`?country=`, `?city=`,
  `?restaurant=`) se composent par **intersection** : le second restreint,
  jamais il n'élargit.
- **Duplication d'un établissement.** Par registre d'abonnement, comme la
  vérification de complétude : `catalog` s'abonne depuis son `ready()`, et
  `restaurants` ne le connaît pas. Commandes, clients, livreurs et historiques
  n'ont **aucune section** — il n'existe pas de chemin de code pour les copier,
  ce qui est plus fort qu'une case décochée par défaut. La duplication d'une
  carte est refusée entre deux devises : recopier 2 500 XOF vers un marché en
  NGN produirait un prix plausible et faux d'un facteur cinq.
- **Devises et fuseaux servis par l'API** (`GET /geography/reference/`). Le
  formulaire d'ouverture de marché portait dix fuseaux écrits en dur ; ouvrir un
  onzième marché demandait de republier l'application, ce qui contredisait la
  promesse même de cet ADR. Les deux listes viennent maintenant de la source qui
  les fait respecter — `CURRENCY_EXPONENTS` et `available_timezones()`.

### Géographie assistée, et règle de résolution unique (septembre 2026)

Quatre ajouts, tous additifs.

- **Une seule règle décide de la zone.** Elle était écrite **deux fois, et
  différemment** : l'écran qui annonce un tarif retenait la zone de plus petite
  surface, la commande qui le facture retenait celle de plus petit
  `max_distance_km`. Les deux coïncidaient tant qu'une ville n'avait qu'une
  zone, et divergeaient dès qu'une zone en contenait une autre — l'écran
  annonçait un prix, la facture en appliquait un autre, et rien ne le signalait
  puisque les deux réponses étaient individuellement cohérentes. Elles appellent
  désormais `apps.geography.resolution.resolve_zone`, et la règle est *la plus
  spécifique gagne*.
- **Un référentiel unique de livrabilité** (`POST /restaurants/delivery-check/`).
  `zones/resolve/` rendait la zone seule ; le devis complet n'existait qu'à
  l'intérieur du passage de commande. Chaque écran recomposait donc le reste à
  sa façon. La route rend établissement, zone, distance, délai, frais — et, en
  cas de refus, **lequel** des quatre.
- **Trois modes de saisie de zone** — cercle, polygone, contour administratif —
  avec le disque discrétisé **par le serveur**, géodésiquement. L'approximation
  par conversion en degrés s'écarte de 0,5 % à Lomé et de 35 % à Paris : elle
  était acceptable pour un produit mono-marché, elle ne l'est pas ici. Une zone
  peut désormais être rattachée à un établissement, ce qui permet à deux
  cuisines d'une même ville de facturer différemment.
- **Un journal d'audit** sur les trois écritures silencieuses et coûteuses :
  déplacement d'un établissement, contour d'une zone, barème. Il n'y en avait
  aucun.

Le géocodage inverse passe par le serveur (`POST /geography/geocode/reverse/`) :
la clé y reste restreinte par adresse IP, les réponses s'y mettent en cache, et
les composants d'adresse sont extraits **une fois** — l'implémentation Flutter
cherchait le nom de la ville *dans le texte* de l'adresse, et trouvait « Lomé »
dans « Rue de Lomé, Cotonou ».

### Le réseau de cuisines de bout en bout (septembre 2026, lot 4)

La hiérarchie n'a toujours pas bougé — `Country → City → DeliveryZone →
Restaurant` est la hiérarchie pays → ville → lieu → cuisine que demande le
produit, sous d'autres noms. Ce qui manquait tenait à ses bords : la commande,
la flotte, et quelques incohérences que le schéma laissait passer.

- **La commande fige sa géographie** (`Order.country`, `city`, `delivery_zone`,
  `delivery_zone_name`). Pays et ville se déduisaient de la cuisine : la
  rattacher ailleurs faisait migrer toute son histoire, et les rapports par
  ville réécrivaient le passé. La zone — celle de l'adresse, qui tarife la
  course — n'était retenue nulle part. Reprise des commandes existantes par la
  même règle que `resolve_zone`, zones retirées comprises.
- **Une zone municipale ne tarife que sa ville.** `resolve_zone` prend la ville
  de la cuisine désignée : sans elle, un panier ouvert à Lomé se faisait livrer
  une adresse de la ville voisine au barème de celle-ci, alors que le choix
  automatique la refusait.
- **Une cuisine ne se pose pas sur la zone propre d'une autre**, ni ne se publie
  sur un marché fermé (`configuration_gaps`).
- **Fermetures exceptionnelles datées** (`KitchenClosure`), jugées avant les
  horaires (`kitchen_temporarily_closed`), et **réouverture annoncée** —
  instant et phrase composés dans le fuseau du pays par le juge
  (`next_opening`, seul lecteur autorisé de l'ouverture).
- **Périmètre de zone des livreurs** (`CourierProfile.service_zones`, vide =
  toutes les zones de la cuisine), relu par la liste des disponibles et par
  `AssignmentService.offer`.
- **Affectation automatique** (`apps.delivery.dispatch`, réglable par cuisine) :
  commande prête → livreur compatible ; refus, expiration
  (`DELIVERY_OFFER_TTL_SECONDS`, horloge `expire-stale-offers`) et mise en
  ligne relancent. Aucune garde contournée : elle passe par `offer`.
- **Rapport réseau** par pays, ville, zone ou cuisine, et **audit** de
  cohérence en lecture seule (`manage.py audit_reseau`).

Le livreur reste rattaché à **une** cuisine. L'élargir à plusieurs toucherait le
cloisonnement du personnel, les gains et la file temps réel ; la zone suffit
aux cas rencontrés, et une zone municipale couvre déjà toute une ville.

### Ce qui est reporté, sans obstacle futur

| Reporté | Débloqué par |
|---|---|
| ~~Sélection de restaurant par le client~~ | **Fait** — sélecteur ville puis cuisine, tri par proximité facultatif |
| ~~Catalogues réellement divergents~~ | **Fait** — isolés par restaurant, et duplication explicite quand on veut les rapprocher |
| ~~Périmètre du personnel par restaurant~~ | **Fait** — et étendu aux paliers ville et marché |
| Multi-devises effectif (conversion, affichage) | La devise est déjà portée par `Country` et figée sur chaque commande (ADR-007). Aucune conversion n'est faite nulle part, et c'est délibéré : un taux du jour n'a pas à décider d'une politique tarifaire. |
| Fiscalité et entités juridiques par pays | Nouvelle app, aucune reprise du modèle existant |
| Barème par paliers de distance (0–3 km, 3–6 km…) | Le barème reste affine (base + prix au kilomètre, plafonné par `max_distance_km`). Des paliers se posent aujourd'hui en **empilant des zones circulaires concentriques** de barèmes différents — la plus petite gagne, ce qui donne exactement le comportement voulu. Un second mode de calcul sur le même champ n'est donc plus nécessaire. |

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
