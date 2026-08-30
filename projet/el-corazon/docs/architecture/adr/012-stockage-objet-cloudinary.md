# ADR-012 — Stockage objet : Cloudinary

**Statut** : accepté · **Date** : 2026-08-21 · **Remplace** : [ADR-011](011-stockage-objet.md)

## Contexte

ADR-011 a posé une architecture juste et l'a servie avec MinIO. Ce qu'elle a bien tenu — la
séparation public/privé, la porte unique — n'est pas en cause. Ce qui a cédé est l'hébergement.

Trois faits, constatés à l'usage :

- **MinIO ne s'héberge pas sur le déploiement réel.** Le service tourne sur Render en offre
  gratuite : pas de volume persistant, pas de second conteneur. Les variables `S3_*` n'ont jamais
  été renseignées, et le catalogue s'est affiché sans photos pendant toute la durée de la
  démonstration.
- **`S3_PUBLIC_URL` est ingouvernable en développement.** L'adresse publique doit être joignable
  depuis un téléphone, donc être l'IP du poste sur le réseau local — qui change de réseau en
  réseau. Le 21 août 2026, le poste était passé de `10.102.28.68` à `10.37.80.68` et toutes les
  images étaient cassées, sans que rien ne le signale.
- **Cloudflare R2, l'issue compatible S3, ne l'est pas tout à fait.** R2 expose un domaine *par
  compartiment*, alors que `ObjectStorage.url()` construisait `{base}/{compartiment}/{clé}`. Le
  correctif était court, mais il fallait le faire.

S'ajoute un besoin que S3 ne couvre pas : une carte de restaurant sur un réseau mobile togolais a
besoin de vignettes et de WebP, pas de JPEG de 1200 pixels. Avec S3, c'est du Pillow côté serveur.

## Décision

Le stockage objet passe à **Cloudinary**, en développement comme en production.

### Ce qui ne change pas — et c'est l'essentiel

Les décisions de fond d'ADR-011 sont **reconduites telles quelles** :

- deux visibilités, et la frontière au même endroit — `products`, `banners`, `users` publics,
  `documents` privé ;
- `STORAGES["default"]` pointe toujours sur le privé : l'oubli ferme, il n'ouvre pas ;
- une seule porte, `common/storage.py`, vérifiée par un test qui inspecte l'AST de chaque module ;
- les champs reçoivent une fonction, pas une instance, et passent par le registre `STORAGES` ;
- deux fichiers de même nom ne s'écrasent pas.

C'est cette discipline qui a rendu la bascule possible **sans toucher un seul modèle, sérialiseur,
point d'API ni migration**. Un fichier réécrit, `makemigrations --check` sans changement détecté.

### Le compartiment devient un dossier

Cloudinary n'a pas de compartiments : un dossier n'est qu'un préfixe dans l'identifiant d'une
ressource, créé au premier dépôt. `STORAGE_BUCKETS` garde son nom et son rôle, les variables
deviennent `CLOUDINARY_FOLDER_*`.

### La visibilité est portée par l'objet, plus par le contenant

Chez S3, elle tenait à une politique posée sur le compartiment — qu'il fallait penser à poser.
Chez Cloudinary, chaque objet porte son **type de livraison**, fixé à l'envoi par la classe de
stockage : `upload` pour les dossiers publics, `private` pour `documents`. Cloudinary ne sert aucun
objet `private` en accès anonyme.

C'est un risque de moins : il n'y a plus d'étape de provisionnement à oublier.
`ensure_storage_buckets` ne crée donc plus rien — elle vérifie que le compte est configuré, ce qui
reste utile au démarrage.

### Les URL signées passent par le point de téléchargement

`private_download_url()`, et non une URL de livraison signée. Cette dernière porte bien une
signature mais **n'expire pas** : un lien transmis une fois resterait valable indéfiniment, ce
qu'on refuse à une pièce d'identité. `CLOUDINARY_SIGNED_URL_EXPIRE` remplace `S3_SIGNED_URL_EXPIRE`.

### Le SDK, sans `django-cloudinary-storage`

Le paquet d'intégration lève `ImproperlyConfigured` **à l'import de son module** quand les
identifiants manquent. Or `common/storage.py` est importé par quatre modèles et quatre migrations :
sans compte Cloudinary, ni `migrate`, ni la suite de tests — qui utilise un stockage en mémoire
précisément pour ne dépendre d'aucun fournisseur — ni `collectstatic` ne démarreraient.

## Conséquences

- **Le protocole n'est plus portable.** ADR-011 tenait à parler S3 pour pouvoir changer de
  fournisseur en changeant une variable. Ce n'est plus vrai : l'API de Cloudinary est propriétaire.
  Ce qui reste, et qui est l'essentiel, c'est qu'un changement de fournisseur demeure la réécriture
  d'**un fichier** — la porte unique est ce qui protège, pas le protocole.
- **⚠ Les pièces d'identité des livreurs partent chez un tiers.** ADR-011 avait écarté AWS S3 pour
  cette raison exacte : « les pièces d'identité de livreurs togolais partiraient chez un tiers, sans
  nécessité ». Cette décision-ci l'accepte. Elles restent en `type=private` et sous URL expirante,
  mais elles sont hébergées hors de l'infrastructure du projet, chez un prestataire américain. Si
  cette exposition devient inacceptable — exigence contractuelle, cadre réglementaire —, le retour
  arrière est limité au dossier `documents` : la frontière `PUBLIC_BUCKETS` / `PRIVATE_BUCKETS`
  existe dans le code et permet un attelage à deux fournisseurs.
- **Les images deviennent transformables** : vignettes, WebP et qualité adaptative à la volée, sans
  Pillow ni traitement au dépôt. Non exploité aujourd'hui ; c'est un paramètre d'URL le jour venu.
- **Le développement n'a plus de stockage local.** Un conteneur de moins, plus d'`S3_PUBLIC_URL` à
  suivre au fil des réseaux, et surtout le même chemin de code qu'en production — un écart de
  fournisseur ne se découvre plus au déploiement.
- **Les fichiers déjà déposés ne migrent pas seuls.** `python manage.py migrate_media_to_cloudinary`
  les recopie sous le même chemin relatif. La colonne ne contenant qu'un chemin et jamais une URL,
  les lignes existantes restent valides sans être réécrites.
- **La durabilité devient l'affaire du prestataire.** La sauvegarde du volume MinIO
  (`deploy/backup.sh`) n'a plus d'objet une fois la migration faite.

## Alternatives écartées

| Alternative | Raison du rejet |
|---|---|
| **Cloudflare R2** | Recommandée en analyse, et écartée par décision du porteur du projet. Elle gardait le protocole S3 (donc aucune réécriture), n'a aucun frais de sortie et sert par un CDN bien présent en Afrique de l'Ouest. Son seul obstacle était la forme d'URL — une dizaine de lignes dans `url()`. Elle reste l'issue de repli si l'hébergement des pièces d'identité chez un tiers devient un problème. |
| Rester sur MinIO, hébergé ailleurs | Demande un serveur, un volume et une sauvegarde à tenir — pour un projet dont le déploiement actuel est une démonstration en offre gratuite. |
| MinIO en local, Cloudinary en production | Fait travailler le développement sur un autre chemin de code que la production : les écarts du fournisseur ne se rencontrent qu'au déploiement. C'est la configuration qui laisse passer les bugs. |
| `django-cloudinary-storage` | Échoue à l'import sans identifiants, ce qui casserait `migrate`, les tests et `collectstatic`. Version 0.3.0 face à Django 5.2. |
| Cloudinary pour les images, S3 pour les documents | Envisagé — la frontière du code s'y prête. Écarté pour ne pas tenir deux fournisseurs, deux jeux d'identifiants et deux modes de panne sur un projet de cette taille. Reste ouvert, voir la conséquence ⚠ ci-dessus. |
