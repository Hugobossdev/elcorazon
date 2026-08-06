# Firebase Cloud Messaging — mise en service

> ## État au 5 août 2026 — validé côté serveur
>
> Le projet **`elcorazon-9595`** existe, les deux applications Android y sont
> déclarées (`com.elcorazon.fast`, `com.elcorazon.dely`), le compte de service
> est en place et le backend est basculé sur `FirebaseCloudMessagingBackend`.
> Ce qui a été **exercé contre le service réel** est décrit au §5 ; ce qui reste
> à faire — une livraison sur un téléphone, et tout iOS — au §7.
>
> La validation a trouvé un défaut qui aurait rendu le push **totalement muet en
> production** : voir §5.0. C'était exactement sa raison d'être.

Tout le câblage push est écrit : le connecteur backend (`apps/notifications/fcm.py`),
la tâche d'envoi, l'enregistrement des appareils (`POST /api/v1/auth/devices/`) et
la réception dans les deux applications Flutter.

Ce document est la marche à suivre, dans l'ordre. Elle se termine par la seule
chose qui compte vraiment : **vérifier que les codes d'erreur renvoyés par Google
sont bien ceux que le connecteur sait interpréter**. L'envoi, lui, est un POST.

Tant que `PUSH_BACKEND` vaut `ConsolePushBackend`, les notifications sont
enregistrées et visibles dans l'historique (`/api/v1/notifications/`), mais aucun
téléphone ne sonne. Ce n'est pas une panne, c'est le réglage par défaut.

---

## 0. Une décision à prendre avant de cliquer

Les deux applications portent encore l'identifiant de paquet du gabarit Flutter :

| Application | `applicationId` actuel |
|---|---|
| `El Corazon fastfood` | `com.example.elcora_fast` |
| `El corazon dely` | `com.example.elcora_dely` |

**Une application Firebase est créée pour un nom de paquet donné et ce nom ne se
change pas après coup** : il faut supprimer l'application dans la console et la
recréer, régénérer `google-services.json`, et tous les jetons déjà distribués
deviennent inutilisables. Google Play refuse par ailleurs `com.example.*`.

Renommez donc **avant** — par exemple `com.elcorazon.fast` et `com.elcorazon.dely`
— dans `android/app/build.gradle.kts` (`namespace` et `applicationId`),
l'arborescence Kotlin sous `android/app/src/main/kotlin/`, et le *bundle
identifier* iOS dans Xcode. Ou assumez explicitement de garder `com.example.*`
pour la validation et de tout refaire avant publication.

---

## 1. Le projet Firebase

Console → <https://console.firebase.google.com> → **Ajouter un projet**.

**Un seul projet pour les deux applications.** Un jeton d'appareil appartient au
projet qui l'a émis : envoyé depuis un autre, il renvoie `SENDER_ID_MISMATCH`.
Le backend n'a qu'un `FCM_PROJECT_ID`, donc deux projets Firebase voudraient dire
deux backends.

Dans ce projet, créez quatre applications — deux Android, deux iOS — avec les
identifiants de paquet arrêtés à l'étape 0. Google Analytics est facultatif et
sans rapport avec le push.

Notez l'**ID du projet** (pas son nom d'affichage) : c'est la valeur de
`FCM_PROJECT_ID`, et on la retrouve dans le champ `project_id` du fichier de
compte de service généré à l'étape 4.

---

## 2. Côté Flutter — les deux applications

Une fois par application, depuis son répertoire :

```bash
dart pub global activate flutterfire_cli   # une seule fois sur la machine
flutterfire configure --project=<ID-DU-PROJET>
```

La commande écrit `lib/firebase_options.dart`,
`android/app/google-services.json` et `ios/Runner/GoogleService-Info.plist`.

**`lib/firebase_options.dart` doit être intégralement remplacé.** Celui qui est
dans le dépôt pour `fastfood` ne contient que des valeurs de remplissage — il a
la forme exacte de ce que produit la CLI pour que le câblage push soit écrit et
compilé dès maintenant, rien de plus. Ne modifiez pas ses valeurs à la main :
relancez la commande.

Vérifiez ensuite que le greffon Gradle de Google est bien appliqué (les versions
récentes de la CLI le font seules ; ajoutez-le sinon) :

```kotlin
// android/settings.gradle.kts — bloc plugins
id("com.google.gms.google-services") version "4.4.2" apply false
```

```kotlin
// android/app/build.gradle.kts — bloc plugins, AVANT le greffon Flutter,
// qui doit rester le dernier
id("com.google.gms.google-services")
```

Puis `flutter clean && flutter run` sur un appareil Android **physique** : un
émulateur sans services Google ne recevra jamais rien, et l'échec ressemble
alors à un défaut de configuration.

### iOS, en plus

Le push iOS ne passe pas par Firebase seul, mais par APNs :

1. Apple Developer → **Keys** → créer une clé d'authentification APNs (`.p8`),
   noter le *Key ID* et le *Team ID* ;
2. Firebase → Paramètres du projet → **Cloud Messaging** → téléverser cette clé ;
3. Xcode, pour chaque application : capacités **Push Notifications** et
   **Background Modes → Remote notifications**.

Sans la clé APNs, l'API v1 accepte l'envoi et l'iPhone ne reçoit rien.

---

## 3. Le compte de service

Firebase → Paramètres du projet → **Comptes de service** → *Générer une nouvelle
clé privée*. Un JSON est téléchargé.

```bash
mkdir -p backend/secrets
mv ~/Téléchargements/<fichier>.json backend/secrets/fcm.json
chmod 600 backend/secrets/fcm.json
git check-ignore -v backend/secrets/fcm.json   # doit répondre : secrets/
```

Ce fichier signe les envois de **tous** vos utilisateurs. Il est monté en volume
(`./secrets:/run/secrets:ro`, déjà déclaré dans les deux `docker-compose`) et
jamais passé en variable d'environnement : c'est un JSON multiligne, et c'est la
forme qu'attendent aussi les `Secret` Kubernetes.

---

## 4. Le backend

Dans `backend/.env` (ou `.env.prod`) :

```dotenv
PUSH_BACKEND=apps.notifications.fcm.FirebaseCloudMessagingBackend
FCM_CREDENTIALS_PATH=/run/secrets/fcm.json
FCM_PROJECT_ID=<ID-DU-PROJET>
FCM_TIMEOUT_SECONDS=10
```

`PUSH_BACKEND` est l'interrupteur : tant qu'il vaut `ConsolePushBackend`, les
trois autres variables ne servent à rien. Redémarrez `api` **et** `worker` — le
second est celui qui envoie réellement.

```bash
docker compose up -d --force-recreate api worker
```

---

## 5. La validation

### 5.0 Ce que la validation a trouvé — le push ne partait pas du tout

Premier constat, dès la première tentative d'authentification :

```
ImportError: The requests library is not installed
  apps/notifications/fcm.py:101 → google.auth.transport.requests
```

Le connecteur importait `google.auth.transport.requests` pour rafraîchir son
jeton OAuth. Ce module exige le paquet `requests`, qui n'est **pas** une
dépendance du projet — et ne l'est pas par choix : `pyproject.toml` retient
`httpx` pour son transport simulable.

La conséquence était totale et silencieuse. L'`ImportError` se produit avant
tout envoi ; `send()` l'attrape, journalise `fcm.authentification` et rend
**tous** les appareils en échec passager. Aucune notification ne serait jamais
partie, aucun appelant n'aurait vu d'erreur, et l'historique des notifications
se serait rempli normalement. Le seul symptôme aurait été : « les téléphones ne
sonnent pas ».

Le défaut a échappé aux tests pour une raison précise : ils court-circuitaient
`_authorization` — la seule ligne qui échouait.

**Correction** : `_TransportOAuth`, un transport `google-auth` bâti sur httpx
(point d'extension documenté par la bibliothèque). Le projet garde un seul
client HTTP. Quatre tests couvrent désormais ce chemin, dont un qui vérifie que
le rafraîchissement aboutit et reçoit bien ce transport.

### 5.1 Ce qui a été exercé contre Google — 5 août 2026

Projet `elcorazon-9595`, compte de service
`firebase-adminsdk-fbsvc@elcorazon-9595.iam.gserviceaccount.com`.

| Vérification | Résultat |
|---|---|
| Authentification du compte de service (OAuth, portée `firebase.messaging`) | **OK** — jeton d'accès obtenu |
| `FCM_PROJECT_ID` et URL d'envoi acceptés | **OK** — l'API répond sur `/v1/projects/elcorazon-9595/messages:send` |
| `PUSH_BACKEND` résolu vers le connecteur FCM | **OK** |
| `send_test_push` de bout en bout | **OK** — passe par `backend()`, donc le chemin de production |

**Codes de refus réellement renvoyés**, confrontés à `ERREURS_DEFINITIVES` :

| Cas envoyé | HTTP | `errorCode` | Dans la liste | Classement |
|---|---|---|---|---|
| Jeton tronqué | 400 | `INVALID_ARGUMENT` | oui | `unregistered` (définitif) |
| Jeton de forme plausible, inexistant | 404 | `UNREGISTERED` | oui | `unregistered` (définitif) |
| Jeton vide | 400 | `INVALID_ARGUMENT` | oui | `unregistered` (définitif) |

**La classification est bonne** : aucun code inconnu, aucun appareil sain classé
définitif. `SENDER_ID_MISMATCH` n'a pas pu être provoqué — il demande un jeton
émis par un autre projet Firebase — mais il reste dans la liste : un tel jeton
ne fonctionnera jamais depuis ce projet, le retenter indéfiniment n'a pas de sens.

Un incident réseau passager survenu pendant les essais a été journalisé
`fcm.reseau` et classé **échec passager**, sans purge d'appareil. C'est le
comportement voulu, observé par hasard sur un vrai incident.

### Obtenir un jeton d'appareil

Connectez-vous dans l'application : `AppService` enregistre le jeton auprès de
`/api/v1/auth/devices/` juste après. Relisez-le en base plutôt que dans les
journaux du téléphone :

```bash
docker compose exec api python manage.py shell -c \
  "from apps.accounts.models import Device; print(*Device.objects.values_list('platform','token'), sep='\n')"
```

L'admin Django le montre aussi, sur la fiche de l'utilisateur (`/admin/`).
Aucun appareil listé signifie que l'enregistrement a échoué : le câblage push est
best-effort, il n'interrompt jamais une connexion. Regardez les journaux de
l'application (`⚠️ Échec de l'enregistrement du jeton FCM`).

### Envoyer

```bash
docker compose exec api python manage.py send_test_push <jeton>
```

La commande passe par `PUSH_BACKEND` — donc par le chemin exact de la production,
et non par un appel direct au connecteur, qui laisserait passer une erreur de
câblage. Trois issues :

| Sortie | Ce que ça veut dire |
|---|---|
| `Livré.` | Le téléphone doit sonner. S'il ne sonne pas, le problème est côté application (permission refusée, canal Android, clé APNs), pas côté serveur. |
| `Appareil signalé définitivement injoignable` | Le jeton sera **supprimé** en production. À vérifier avant de faire confiance à la purge automatique. |
| `Échec` | Panne passagère ou erreur de configuration. |

### Comparer les codes — c'est l'étape qui compte

Chaque refus de Google est journalisé sous **`fcm.rejet`**, avec le statut HTTP,
le code d'erreur reçu et la décision qui en a été tirée :

```json
{"level":"WARNING","logger":"apps.notifications.fcm","message":"fcm.rejet",
 "status":404,"code":"UNREGISTERED","definitif":true,"device":"…"}
```

Provoquez au moins un refus — le plus simple est d'envoyer sur un jeton
volontairement tronqué, puis sur le jeton d'un appareil dont l'application a été
désinstallée — et confrontez le `code` observé à `ERREURS_DEFINITIVES`
(`apps/notifications/fcm.py`) :

- **le code est dans la liste et `definitif` vaut `true`** : la classification est
  bonne, rien à changer ;
- **un jeton mort revient avec un code absent de la liste** : ajoutez-le à
  `ERREURS_DEFINITIVES`. Sans cela, un appareil désinstallé sera retenté à chaque
  notification, indéfiniment — c'est exactement le défaut que ce connecteur a été
  écrit pour corriger ;
- **un appareil sain est classé `definitif`** : retirez le code de la liste, et
  vite. En production il ferait supprimer des appareils qui fonctionnent, et leurs
  propriétaires cesseraient de recevoir sans que rien ne l'explique.

Les autres journaux utiles : `fcm.authentification` (compte de service illisible
ou refusé — aucun appareil n'est purgé dans ce cas, la panne est de notre côté) et
`fcm.reseau` (rien n'est parti).

### De bout en bout

Le test unitaire ci-dessus ne prouve rien du chemin métier. Faites passer une vraie
commande d'un statut à l'autre (back-office ou API) avec l'application **fermée** :
`notify()` écrit la notification, programme l'envoi après le commit, et le worker
Celery l'envoie. Si l'historique se remplit mais que le téléphone reste muet, le
worker ne tourne pas ou n'a pas la même configuration que l'API.

---

## 6. Une fois validé

Reportez le résultat dans `docs/architecture/04-migration-flutter.md` §3.0 —
c'est le dernier prérequis backend encore ouvert — et retirez la réserve
correspondante de `docs/deploiement.md`. En précisant ce qui a réellement été
exercé : un appareil Android, un iPhone, ou les deux.

---

## 7. Ce qui reste à faire

Deux choses, qu'aucune vérification depuis un poste ne peut remplacer.

### 7.1 Une livraison sur un téléphone réel

Tout ce qui précède prouve que le serveur parle correctement à Google. Cela ne
prouve **pas** qu'un téléphone sonne : il y faut un jeton émis par une
installation réelle de l'application.

```bash
# 1. se connecter dans l'application sur un Android physique
#    (un émulateur sans services Google ne recevra jamais rien)
# 2. relire le jeton enregistré
docker compose exec api python manage.py shell -c \
  "from apps.accounts.models import Device; print(*Device.objects.values_list('platform','token'), sep='\n')"
# 3. envoyer
docker compose exec api python manage.py send_test_push <jeton>
```

Attendu : `Livré.` et une notification à l'écran. Si le serveur dit `Livré.` et
que rien n'arrive, le problème est côté application — permission de
notification refusée, canal Android manquant — et non côté serveur.

Puis le parcours métier, **application fermée** : faire avancer une commande
d'un statut à l'autre et vérifier que le worker Celery envoie. Si l'historique
se remplit et que le téléphone reste muet, le worker ne tourne pas ou n'a pas la
même configuration que l'API.

### 7.2 iOS — rien n'est configuré

Aucune des deux applications ne porte de `ios/Runner/GoogleService-Info.plist` :
le `flutterfire configure` n'a couvert qu'Android. Les entrées iOS de
`firebase_options.dart` existent, mais sans le fichier de configuration et sans
clé APNs, **l'API v1 acceptera l'envoi et l'iPhone ne recevra rien** — c'est le
mode d'échec le plus trompeur de FCM, parce qu'il ressemble à un succès côté
serveur.

Il faut donc, avant toute publication iOS : la clé APNs `.p8` (Apple Developer →
Keys), téléversée dans Firebase → Cloud Messaging ; les capacités Xcode **Push
Notifications** et **Background Modes → Remote notifications** ; et le
`GoogleService-Info.plist` produit par `flutterfire configure` incluant la
plateforme iOS. Voir §2.

**Tant que ce n'est pas fait, seul Android est en état de recevoir.**
