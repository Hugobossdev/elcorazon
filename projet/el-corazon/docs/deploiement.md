# Déploiement

Ce document décrit la mise en service du backend. Il porte sur des fichiers qui
existent et ont été vérifiés syntaxiquement (`docker compose config`, `bash -n`),
mais **aucun déploiement réel n'a encore été exécuté** : il demande un domaine et
un serveur. Ce qui suit est donc une procédure écrite, pas une procédure éprouvée.

---

## Ce que la production fait tourner

`backend/docker-compose.prod.yml` déclare huit services :

| Service   | Rôle                                                                 |
|-----------|----------------------------------------------------------------------|
| `db`      | PostgreSQL + PostGIS. Volume `pgdata`, sauvegardé par `backup.sh`.    |
| `redis`   | Cache, files Celery, *channel layer* des WebSocket. Volume `redisdata`. |
| `api`     | ASGI (Uvicorn). Sert l'API REST **et** les WebSocket — même processus, même autorisation. |
| `worker`  | Celery. Envois push, expiration de points, tâches différées.          |
| `beat`    | Celery beat. Ordonnanceur. Volume `beatdata` pour ne pas rejouer un cycle au redémarrage. |
| `minio`   | Stockage objet S3. Pièces livreurs, photos d'avis. Volume `miniodata`. |
| `nginx`   | Terminaison TLS, limitation de premier niveau, service des fichiers statiques. |
| `certbot` | Renouvellement Let's Encrypt.                                         |

Chaque service porte un `healthcheck` et une politique `restart: unless-stopped`.
Les journaux sont bornés (rotation) : un disque plein par accumulation de logs
arrête tout le reste.

---

## Prérequis

- un serveur Linux avec Docker et le greffon Compose ;
- un **nom de domaine** pointant vers ce serveur (A/AAAA) — Let's Encrypt vérifie
  la propriété, une adresse IP nue ne suffit pas ;
- les ports 80 et 443 ouverts ;
- une paire de clés RSA pour signer les jetons (ADR-004).

### Générer les clés de jetons

```bash
mkdir -p backend/secrets
openssl genrsa -out backend/secrets/jwt-private.pem 4096
openssl rsa -in backend/secrets/jwt-private.pem -pubout -out backend/secrets/jwt-public.pem
chmod 600 backend/secrets/jwt-private.pem
```

`backend/secrets/` est ignoré par Git. Vérifiez-le avant tout commit :

```bash
git check-ignore -v backend/secrets/jwt-private.pem
```

---

## Configuration

Partez de `backend/.env.prod.example`, qui liste **toutes** les variables et dit
à quoi chacune sert :

```bash
cp backend/.env.prod.example backend/.env.prod
```

Cinq variables n'ont aucune valeur par défaut acceptable. `config/settings/prod.py`
refuse de démarrer si l'une manque — un oubli devient un échec de démarrage
immédiat plutôt qu'un incident de sécurité découvert plus tard :

- `DJANGO_SECRET_KEY`
- `JWT_SIGNING_KEY` (ou `JWT_PRIVATE_KEY_PATH`)
- `JWT_VERIFYING_KEY` (ou `JWT_PUBLIC_KEY_PATH`)
- `POSTGRES_PASSWORD`
- les identifiants MinIO (`S3_ACCESS_KEY`, `S3_SECRET_KEY`)

Les clés du prestataire de paiement (`PAYDUNYA_*`) et le certificat Agora
(`AGORA_APP_CERTIFICATE`) vivent ici et **nulle part ailleurs** : ni dans un
dépôt, ni dans un `.env` d'application Flutter. Voir
[docs/security/paydunya_rotation.md](security/paydunya_rotation.md).

---

## Premier déploiement

```bash
cd backend
./deploy/deploy.sh --cert-init
```

`--cert-init` obtient le premier certificat TLS avant de démarrer Nginx en mode
HTTPS — sans lui, Nginx refuserait de démarrer faute de certificat, et Certbot ne
pourrait pas répondre au défi faute de Nginx.

Le script est **idempotent** et s'arrête à la première erreur. Il :

1. sauvegarde la base avant toute migration ;
2. construit et récupère les images ;
3. applique les migrations ;
4. collecte les fichiers statiques ;
5. redémarre les services par vagues, en attendant les `healthcheck`.

Un déploiement interrompu à mi-course vaut mieux qu'un service qui tourne à
moitié migré.

## Déploiements suivants

```bash
./deploy/deploy.sh
```

---

## Sauvegarde et restauration

```bash
./deploy/backup.sh                 # base + stockage objet, horodaté
./deploy/backup.sh --base-seule    # PostgreSQL uniquement
```

`deploy.sh` appelle `backup.sh --silencieux` avant chaque migration. Une
sauvegarde qui n'est jamais restaurée n'est pas une sauvegarde : testez la
restauration sur un environnement jetable.

```bash
./deploy/restore.sh --lister       # inventaire, sans rien faire
./deploy/restore.sh                # dernière sauvegarde
./deploy/restore.sh deploy/backups/db-2026-08-03T02-00-00.dump
```

**`restore.sh` est destructeur** : il remplace la base en service. Le script
arrête d'abord `api`, `worker` et `beat` — restaurer sous une application qui
écrit produirait un état incohérent que rien ne signalerait.

Programmez la sauvegarde hors de Docker, par `cron` sur l'hôte :

```cron
0 2 * * * cd /srv/elcorazon/backend && ./deploy/backup.sh --silencieux
```

---

## Vérifications après mise en service

```bash
curl -sf https://VOTRE-DOMAINE/health/                  # 200
curl -si https://VOTRE-DOMAINE/api/v1/orders/ | head -1 # 401 : refus par défaut
docker compose -f docker-compose.prod.yml ps            # tous « healthy »
```

Le second contrôle est le plus parlant : une route métier qui répond autre chose
que 401 sans jeton signale une régression d'autorisation (ADR-005).

---

## Ce qui n'est pas couvert

- **aucun déploiement réel n'a été exécuté** — la procédure est écrite, pas
  éprouvée ;
- **le push FCM n'a pas été validé** contre un vrai projet Firebase. Le code
  d'envoi est testé, l'aller-retour avec Google ne l'est pas ;
- **pas de sauvegarde hors site.** `backup.sh` écrit sur le même serveur : une
  perte de machine emporte la base et ses sauvegardes. Recopiez `deploy/backups/`
  vers un stockage distant ;
- **pas de supervision.** Ni métriques, ni alertes, ni agrégation de journaux.
  Les `healthcheck` redémarrent un conteneur mort, ils ne préviennent personne.
