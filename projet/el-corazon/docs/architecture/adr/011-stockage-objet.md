# ADR-011 — Stockage objet : S3 servi par MinIO

**Statut** : **remplacé** par [ADR-012](012-stockage-objet-cloudinary.md) (2026-08-21) · **Date** : 2026-08-05

> Le stockage est passé à Cloudinary. Les décisions d'architecture posées ici — les deux
> visibilités, la porte unique, le stockage par défaut privé, les fabriques par le registre
> — sont **reconduites** par ADR-012 ; seul l'hébergement change. Ce document reste la trace
> du raisonnement qui les a établies.

## Contexte

Le produit stocke deux familles de fichiers que tout oppose :

- des **médias destinés à être vus** — images d'articles, de catégories, bannières de campagne,
  avatars, photos de couverture d'établissement. Ils sont demandés des milliers de fois par jour,
  par des inconnus, et gagnent à être mis en cache le plus longtemps possible ;
- des **documents qui ne doivent jamais l'être** — pièces d'identité des livreurs, permis, cartes
  grises, preuves de livraison. Ils sont lus quelques fois dans leur vie, par une poignée de
  personnes habilitées, et chaque lecture est un événement qu'on devrait pouvoir justifier.

L'implémentation précédente les rangeait dans **le même compartiment**, avec la même politique :
`AWS_QUERYSTRING_AUTH = True`, donc tout signé, tout expirant en quinze minutes. La partie
« documents » était juste. Le reste était un contresens : une URL d'image de burger périmée au bout
d'un quart d'heure ne peut être mise en cache par personne — ni par le navigateur, ni par un CDN —
et une carte mise en favori affiche des cadres vides le lendemain. Chaque affichage de menu
regénérait autant de signatures que de vignettes.

Plus tôt encore, dans la version Supabase, les documents des livreurs vivaient dans un
**compartiment public** : une pièce d'identité y était lisible indéfiniment par qui connaissait
l'adresse.

Le chapitre « Stockage » du plan de migration est resté ouvert entre les deux, avec MinIO validé
techniquement (2026-07-27) mais aucune décision écrite sur ce qui va où.

## Décision

### Le protocole est S3 ; MinIO en est une implémentation

Le code ne connaît pas MinIO. Il parle **S3**, via `boto3` et `django-storages`. MinIO est ce qui
répond en développement et en production aujourd'hui ; AWS S3, un service géré ou un autre serveur
compatible répondront demain sans qu'une ligne de Python change — seulement `S3_ENDPOINT_URL`, la
région et les identifiants.

C'est la raison du choix : un serveur compatible qu'on héberge donne le contrôle des données
personnelles (les pièces d'identité ne quittent pas l'infrastructure) sans enfermer le projet dans
une API propriétaire.

### Un compartiment par domaine, et la visibilité portée par le compartiment

| Alias | Variable | Visibilité | Contenu |
|---|---|---|---|
| `products` | `S3_BUCKET_PRODUCTS` | **public** | Images d'articles et de catégories |
| `banners` | `S3_BUCKET_BANNERS` | **public** | Bannières, visuels de campagne, couvertures d'établissement |
| `users` | `S3_BUCKET_USERS` | **public** | Avatars |
| `documents` | `S3_BUCKET_DOCUMENTS` | **privé** | Pièces d'identité, permis, cartes grises, preuves de livraison |

Le découpage n'est pas du rangement. Une politique de lecture se pose **sur un compartiment**, pas
sur un préfixe : c'est donc le compartiment qui peut porter la frontière, et un compartiment unique
la rendait inexprimable.

- Les compartiments publics reçoivent une politique de **lecture seule anonyme** : `s3:GetObject`,
  et rien d'autre. Ni `ListBucket` — qui reviendrait à publier l'inventaire des fichiers — ni
  `PutObject`.
- Le compartiment privé n'en reçoit **aucune**. Sans politique, S3 refuse tout ce qui n'est pas
  signé : c'est exactement le comportement voulu, et il est obtenu par absence plutôt que par une
  règle qu'on pourrait mal écrire.

### Le stockage par défaut est le privé

`STORAGES["default"]` pointe sur le compartiment `documents`. Un champ fichier ajouté demain sans
stockage explicite atterrit donc dans le compartiment signé, jamais en libre accès. C'est le sens de
la sécurité par défaut : l'oubli doit fermer, pas ouvrir.

### Une seule porte : `common/storage.py`

Aucun autre module du projet n'importe `boto3`, `botocore` ni `storages`. Tout passe par
`StorageService` (dépôt, suppression, URL publique, URL signée, provisionnement) ou par les
fabriques rattachées aux champs des modèles (`product_images`, `banners`, `user_media`,
`courier_documents`).

La règle est vérifiée par un test qui inspecte l'AST de chaque module — elle ne dépend donc pas de
l'attention d'un relecteur. Son intérêt est concret : chiffrement au repos, politique de rétention,
antivirus à l'entrée, second fournisseur — tout cela se règle dans un fichier.

### Les fabriques passent par le registre `STORAGES`

Les champs reçoivent une **fonction** (`storage=product_images`), pas une instance. Django sérialise
alors un chemin d'import dans la migration, et non l'état d'un objet configuré : les identifiants et
le point d'accès du jour ne se figent pas dans un fichier versionné. La fonction lit
`storages["products"]`, ce qui permet aussi à la suite de tests de substituer un stockage en mémoire
sans que les modèles ni les migrations aient à connaître les tests.

### Deux fichiers de même nom ne s'écrasent pas

`file_overwrite = False`, contrairement au défaut de `django-storages`. Avec l'écrasement, deux
clients envoyant chacun un `photo.jpg` comme avatar auraient partagé le même objet : le second aurait
remplacé le premier, qui aurait vu apparaître la photo d'un inconnu sur son profil.

### Les compartiments se créent tout seuls

`python manage.py ensure_storage_buckets` crée ce qui manque et applique les politiques. Idempotente,
elle est appelée **au démarrage** de l'API en développement comme en production, avant Gunicorn. Elle
n'est donc pas une étape de procédure — les étapes de procédure se sautent — et un stockage
injoignable fait échouer le démarrage plutôt que le premier envoi de fichier d'un utilisateur.

## Conséquences

- Les images de catalogue redeviennent cachables : URL stables, pas de signature, `S3_PUBLIC_URL`
  permet de les servir par le domaine public ou un CDN sans toucher au code.
- Les documents des livreurs sont dans un compartiment que rien ne rend lisible sans signature du
  serveur, et la durée de validité (`S3_SIGNED_URL_EXPIRE`) est un réglage, pas une constante.
- Passer sur AWS S3 est une modification de `.env`. `S3_ADDRESSING_STYLE` existe pour cela : MinIO
  n'accepte que `path`, AWS accepte les deux.
- **Attention aux fichiers déjà stockés.** Les objets écrits avant cette décision vivent dans le
  compartiment unique historique et ne sont pas déplacés automatiquement. Sur une base réellement
  exploitée, il faudrait une migration de données ; le projet n'ayant pas encore tourné sur une
  infrastructure de production, la question ne se pose pas aujourd'hui — mais elle se poserait à la
  première reprise d'un environnement existant.
- Sur AWS, une politique de lecture anonyme suppose que le blocage d'accès public du compartiment
  soit levé pour les trois compartiments publics. Sur MinIO, rien à faire.

## Alternatives écartées

| Alternative | Raison du rejet |
|---|---|
| Un compartiment unique avec des préfixes | Une politique de lecture se pose sur un compartiment, pas sur un préfixe : la frontière public/privé deviendrait un contrôle applicatif, donc oubliable. C'est l'état dont on sort. |
| Tout signer, y compris les images | L'état précédent. Correct pour les documents, absurde pour un catalogue : aucun cache possible, une signature par vignette, des favoris qui expirent. |
| Tout servir publiquement | Ce que faisait la version Supabase pour les pièces d'identité. |
| Stockage sur le disque du serveur (`FileSystemStorage`) | Ne survit pas à un conteneur remplacé, interdit d'ajouter une seconde instance d'API, et rend les sauvegardes solidaires du serveur applicatif. |
| AWS S3 directement | Les pièces d'identité de livreurs togolais partiraient chez un tiers, sans nécessité. Le code y est prêt : c'est une variable d'environnement, pas une réécriture. |
| Client `minio` (SDK officiel) plutôt que `boto3` | Lie le projet à MinIO au lieu du protocole. `boto3` marche avec les deux, et `django-storages` s'appuie dessus. |
