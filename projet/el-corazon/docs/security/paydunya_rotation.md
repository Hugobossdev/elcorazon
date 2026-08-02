# Rotation des clés PayDunya

**Statut** : à exécuter · **Origine** : constat S-1 de l'audit du 2 août 2026

---

## 1. Pourquoi ces clés sont compromises

Jusqu'au 2 août 2026, les trois applications Flutter détenaient les clés
marchandes PayDunya :

| Application | Clés | Emplacement |
| --- | --- | --- |
| `fastfood` (client) | `MASTER_KEY`, `PRIVATE_KEY`, `TOKEN` | `.env`, compilé dans le binaire |
| `dely` (livreur) | idem — valeurs de gabarit, jamais renseignées | `lib/config/api_config.dart`, **en dur dans les sources** |
| `admin` (back-office) | `MASTER_KEY`, `PUBLIC_KEY`, `PRIVATE_KEY`, `TOKEN` | saisies à l'écran, rangées dans `SharedPreferences` |

Une clé dans un binaire distribué n'est pas un secret. Elle s'extrait d'un APK,
d'un IPA ou du bundle web en quelques minutes, sans outil particulier. Quiconque
a installé l'une de ces applications a pu en disposer.

Ce que ces clés permettent : créer une facture, encaisser, et **rembourser** —
au nom de l'enseigne, sans passer par le serveur, donc sans permission, sans
rattachement à un établissement, sans trace et sans plafond.

> **Retirer les clés du code ne les révoque pas.** Le commit qui les a
> supprimées empêche de nouvelles fuites ; il ne fait rien contre les copies
> déjà extraites, ni contre l'historique Git.

---

## 2. Procédure de rotation

À exécuter dans l'ordre. Les étapes 1 à 3 se font dans la console PayDunya,
la 4 sur le serveur, la 5 après vérification.

### Étape 1 — Générer un nouveau jeu de clés

Console PayDunya → **Développeurs** → *Applications* → l'application El Corazón.

Générer un nouveau couple `MASTER_KEY` / `PRIVATE_KEY` et un nouveau `TOKEN`.
Ne pas révoquer les anciennes tout de suite : le service tournerait à vide entre
la génération et le déploiement.

### Étape 2 — Noter l'empreinte des anciennes clés

Avant révocation, relever les quatre derniers caractères de chaque ancienne clé
et la date de leur création. Ils serviront à identifier, dans les journaux
PayDunya, une transaction faite avec une clé fuitée après la bascule.

### Étape 3 — Renseigner les nouvelles clés côté serveur

Dans `backend/.env` (ou le gestionnaire de secrets de la plateforme) :

```env
PAYDUNYA_MASTER_KEY=
PAYDUNYA_PRIVATE_KEY=
PAYDUNYA_TOKEN=
PAYDUNYA_MODE=live          # ou `test` selon l'environnement

# Secret de signature des webhooks — indépendant des clés marchandes, à
# régénérer également : il vivait dans le même fichier.
PAYMENT_WEBHOOK_SECRET=
```

Ces variables sont lues par `apps.payments.paydunya` et
`apps.payments.gateway`. Aucune application Flutter ne les voit.

### Étape 4 — Redémarrer et vérifier

```bash
cd backend
docker compose up -d --force-recreate api worker
docker compose exec api python manage.py check --deploy
```

Puis un encaissement de bout en bout en environnement de test :

1. créer une commande depuis l'application client ;
2. `POST /api/v1/payments/{commande}/initiate/` — vérifier que l'adresse de
   règlement est bien renvoyée ;
3. régler chez le prestataire ;
4. vérifier que le webhook arrive **et qu'il est authentifié** — un webhook
   refusé ressort en 403 dans les journaux, et la transaction reste en attente ;
5. vérifier que la transaction passe à `succeeded` côté serveur.

### Étape 5 — Révoquer les anciennes clés

Une fois l'encaissement de test validé, révoquer dans la console PayDunya les
clés relevées à l'étape 2.

**C'est cette étape qui ferme la fuite.** Les quatre précédentes ne font que
préparer le terrain.

---

## 3. Procédure de révocation d'urgence

Si une utilisation frauduleuse est constatée, sans attendre la rotation
complète :

1. **Console PayDunya → révoquer immédiatement** le jeu de clés en cours.
   L'encaissement s'arrête pour tout le monde — c'est voulu.
2. Vider `PAYDUNYA_*` dans `backend/.env` et redémarrer : le serveur rendra une
   erreur claire à l'initiation plutôt que de tenter des appels qui échouent.
3. Relever dans les journaux PayDunya les transactions de la période suspecte,
   et les rapprocher de `apps.payments.models.Transaction` — toute transaction
   présente chez le prestataire et absente en base a été faite hors du serveur.
4. Reprendre la procédure de rotation à l'étape 1.

---

## 4. Nettoyage de l'historique Git

Les clés de `fastfood` étaient dans un `.env` **ignoré par Git** : elles ne sont
pas dans l'historique. Vérification :

```bash
git log --all --full-history -- "*/.env"          # doit ne rien rendre
git grep -I "PAYDUNYA_MASTER_KEY=." $(git rev-list --all) -- '*.env' | head
```

Celles de `dely` étaient en dur dans `lib/config/api_config.dart`, donc
**dans l'historique** — mais c'étaient des gabarits
(`YOUR_PAYDUNYA_MASTER_KEY`), sans valeur. Aucune réécriture d'historique n'est
nécessaire.

Si une vraie clé venait à être commitée un jour, la réécriture
(`git filter-repo`) ne suffirait pas : il faudrait **de toute façon** révoquer,
puisque les clones existants gardent l'objet.

---

## 5. Ce qui empêche la situation de se reproduire

- Aucun `.env` d'application ne contient plus de variable `PAYDUNYA_*`
  (`docs/env/*.env.example` font foi).
- Aucun code Flutter n'appelle `app.paydunya.com` — vérifiable en une
  commande :

  ```bash
  grep -rn "paydunya" */lib --include=*.dart     # ne doit rendre que des commentaires
  ```

- Le seul chemin d'encaissement est `POST /payments/{commande}/initiate/`, et
  le seul chemin de remboursement `POST /payments/{commande}/refund/`, sous
  permission `orders.refund` et plafonné par l'invariant P3.
- Le webhook signé est la seule écriture d'état de paiement : le retour du
  client sur l'application ne décide de rien.
