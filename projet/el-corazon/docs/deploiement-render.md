# Déploiement du backend sur Render

Le dépôt porte un blueprint Render à sa racine (`render.yaml`). Il décrit quatre
ressources : la base PostgreSQL, l'instance Key Value (Redis), l'API et les deux
processus Celery. Render lit ce fichier et crée l'ensemble d'un coup.

## Ce que le blueprint met en place

| Ressource | Type | Rôle |
|---|---|---|
| `elcorazon-db` | PostgreSQL 17 | Base applicative, PostGIS activé par migration |
| `elcorazon-redis` | Key Value | Cache, couche Channels, file Celery |
| `elcorazon-api` | Web (Docker) | Uvicorn/ASGI, sonde sur `/health/` |
| `elcorazon-worker` | Worker (Docker) | Consomme la file Celery |
| `elcorazon-beat` | Worker (Docker) | Émet les six tâches périodiques |

Les trois services partagent une seule image — le `Dockerfile` du backend — et ne
diffèrent que par leur commande de démarrage. C'est la ligne d'ADR-001.

## Préparer les secrets

Deux choses sont à produire avant de commencer.

**Les clés JWT.** `SIMPLE_JWT` tourne en RS256 : il faut une paire RSA, pas
Ed25519. Si vous n'en avez pas déjà une en production :

```bash
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out jwt.pem
openssl rsa -in jwt.pem -pubout -out jwt.pub
```

Régénérer ces clés invalide tous les jetons en circulation : les utilisateurs
connectés sont déconnectés. Si une paire sert déjà, reprenez-la telle quelle.

**Un stockage objet compatible S3.** Render n'en fournit pas. Cloudflare R2 ou
Backblaze B2 conviennent ; il faut deux compartiments, un public (`S3_BUCKET_MEDIA`)
et un privé (`S3_BUCKET_PRIVATE`, pour les pièces d'identité des livreurs).

## Déployer

1. **Pousser la branche.** Render déploie depuis GitHub, pas depuis le disque.
   Le blueprint pointe sur `feat/v2-django-architecture`, seule branche présente
   sur le remote. Après une fusion vers `main`, changer les quatre champs
   `branch:` du `render.yaml`.

2. **Créer le blueprint.** Dans Render : *New* → *Blueprint*, choisir le dépôt.
   Render lit `render.yaml` et affiche le plan des ressources.

3. **Renseigner les secrets.** Render réclame toutes les variables marquées
   `sync: false` avant de lancer quoi que ce soit :

   | Variable | Valeur |
   |---|---|
   | `JWT_SIGNING_KEY` | contenu de `jwt.pem` |
   | `JWT_VERIFYING_KEY` | contenu de `jwt.pub` |
   | `CORS_ALLOWED_ORIGINS` | origines des applications Flutter, séparées par des virgules |
   | `CSRF_TRUSTED_ORIGINS` | `https://elcorazon-api.onrender.com` |
   | `EMAIL_HOST`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD`, `DEFAULT_FROM_EMAIL` | fournisseur SMTP |
   | `S3_*` | les cinq réglages du stockage objet |

   `DJANGO_SECRET_KEY` est engendré par Render. `DATABASE_URL`, `REDIS_URL` et
   `POSTGRES_PASSWORD` sont câblés automatiquement sur les ressources créées.

4. **Lancer.** Le premier déploiement construit l'image trois fois — une par
   service. Comptez une dizaine de minutes.

5. **Créer les compartiments et le premier administrateur.** Une fois l'API en
   ligne, dans *Shell* sur `elcorazon-api` :

   ```bash
   python manage.py ensure_storage_buckets
   python manage.py createsuperuser
   ```

   `ensure_storage_buckets` reste hors de la commande de démarrage à dessein :
   elle échoue si les réglages S3 sont absents, et un échec au démarrage
   mettrait le service en boucle de redémarrage au lieu de signaler le problème.

## Vérifier

```bash
curl https://elcorazon-api.onrender.com/health/
```

La réponse doit être `200`. Puis dans les journaux de `elcorazon-beat`, la
mention `beat: Starting...` et la première tâche émise dans les cinq minutes
(`expire-group-carts` est la plus fréquente).

## Ce qu'il faudra reprendre

- **Une seule instance d'API.** `migrate` vit dans la commande de démarrage :
  deux conteneurs migreraient la même base en même temps. Pour passer à
  l'échelle, déplacer `migrate` vers `preDeployCommand` — mais pas
  `collectstatic`, qui écrit dans un conteneur que le service ne verra jamais.

- **L'échéancier de `beat` est en `/tmp`.** Il repart de zéro à chaque
  redémarrage. Les six tâches planifiées étant des purges idempotentes, une
  passe anticipée ne trouve rien à faire. Si des tâches non idempotentes
  arrivent, il faudra un disque — en réglant d'abord le fait qu'un disque Render
  est monté à root alors que l'image tourne en uid 10001.

- **Le hachage des noms de fichiers statiques.** WhiteNoise est en
  `CompressedStaticFilesStorage`. La variante `Manifest` ajoute le cache long
  mais fait échouer `collectstatic` — donc le déploiement — sur une seule URL
  cassée dans le CSS d'une dépendance. À basculer quand la chaîne est stable.
