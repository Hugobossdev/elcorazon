# Audit du parcours livreur — `apps/dely`

**Date** : 1er septembre 2026 · **Branche** : `redesign-client-ui` · **Backend** : Django v2, local (`http://localhost:8000`, pile docker complète)

Audit complet du parcours livreur, de la connexion à l'historique, contre le
**backend réel**. Les 48 vérifications de bout en bout ont été passées sur des
comptes livreurs, des commandes et des courses réels ; aucune donnée n'a été
simulée pour produire ce rapport.

---

## Statut

**READY WITH WARNINGS.**

Le parcours complet fonctionne de bout en bout. Trois choses l'empêchaient de
fonctionner au début de l'audit, et aucune n'était visible depuis le code
seul :

1. l'application ne demandait **aucune permission Android** — le suivi GPS ne
   pouvait pas démarrer en release ;
2. `NotificationService.initialize()` n'était **appelé nulle part** — aucun
   appareil n'était enregistré, donc aucune notification de course ne partait ;
3. l'écran de suivi **géocodait une chaîne d'adresse** au lieu de lire les
   coordonnées de la course, avec un repli sur Abidjan.

Les réserves restantes sont listées en fin de document. Aucune n'interrompt le
parcours ; deux demandent une décision d'exploitation avant mise en production.

---

## Ce que l'audit a trouvé

La couche réseau est saine, et nettement plus avancée que ne le laissait
supposer l'état apparent des écrans. La migration vers le backend Django v2 est
réellement terminée : plus une ligne de Supabase, pas de base de données
parallèle, pas de commande simulée.

- toutes les routes passent par `packages/elcorazon_core`, un dépôt par
  domaine, chacun reflétant un sérialiseur Django nommé en commentaire ;
- **le livreur n'écrit jamais le statut d'une commande** : il fait avancer sa
  *course*, et la commande suit par projection déclarée côté serveur
  (`ORDER_STATUS_PROJECTION`) ;
- **la rémunération est arrêtée par le serveur** à l'acceptation
  (`courier_fee`), jamais recalculée comme un pourcentage du panier ;
- **l'émission de position passe par HTTP**, pas par le WebSocket :
  `ws/couriers/me/` est une file de propositions en lecture seule ;
- l'acceptation est exclusive côté serveur, et le perdant reçoit un refus
  métier plutôt qu'une incohérence.

Les défauts trouvés sont donc **ponctuels et identifiables**, mais quatre
d'entre eux cassaient le parcours.

---

## Les défauts qui cassaient le parcours

### 1. Aucune permission au manifeste Android — le GPS ne pouvait pas démarrer

`android/app/src/main/AndroidManifest.xml` ne déclarait **aucune**
`uses-permission`. Et contrairement à ce qu'on suppose souvent, le greffon ne
les apporte pas : le manifeste de `geolocator_android` ne contient qu'un
service, pas une seule permission. En release, `Geolocator.requestPermission()`
refusait donc d'office.

Ajouté : `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `INTERNET`,
`ACCESS_NETWORK_STATE`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`,
`POST_NOTIFICATIONS`, plus un bloc `<queries>` sans lequel `canLaunchUrl` rend
faux sur Android 11+ — ce qui faisait échouer *tous* les boutons de navigation
et d'appel.

`ACCESS_BACKGROUND_LOCATION` n'y figure **pas**, délibérément : un service de
premier plan visible suffit au besoin, et suivre un livreur sans qu'il le voie
n'est pas ce qu'on veut faire.

Côté iOS, `NSLocationAlwaysAndWhenInUseUsageDescription` manquait — clé exigée
depuis iOS 11, sans laquelle la demande d'autorisation permanente est ignorée —
ainsi que `UIBackgroundModes`.

**Vérification** : la lecture du manifeste fusionné après `flutter build apk`
confirme les sept permissions.

### 2. Les notifications de course ne partaient jamais

`NotificationService.initialize()` n'avait **aucun appelant** dans tout `lib/`.
Conséquence en chaîne : aucune permission demandée → aucun jeton FCM →
`fcmToken` toujours nul → `_registerPushDeviceBestEffort()` sortait
immédiatement → l'appareil n'était **jamais** enregistré auprès de
`/auth/devices/`.

Le backend faisait pourtant tout son travail : `on_assignment_offered`
(`apps/notifications/receivers.py`) émet bien sur chaque proposition. Il
poussait vers une liste d'appareils vide.

Une course proposée n'atteignait donc le livreur que si l'application était au
premier plan **et** que le sondage de trente secondes de l'écran d'accueil
tombait bien. C'est le seul flux où rater un événement a un coût métier direct
(ADR-008).

Deux défauts aggravants découverts au passage :

- `NotificationService` n'était **pas** un singleton, contrairement à
  `ChatService` et `RealtimeTrackingService`. `main()` et `AppService` en
  construisaient chacun une instance : même initialisée, celle de `main()`
  n'aurait pas donné son jeton à `AppService` ;
- l'enregistrement n'était tenté qu'après `loginDriver`. Un livreur qui rouvre
  l'application sans se reconnecter — le cas courant — ne réenregistrait rien,
  et un jeton ayant tourné pendant que l'application était fermée n'était
  jamais rattrapé.

Corrigé : `initialize()` appelé au démarrage après Firebase, singleton,
enregistrement à **chaque** ouverture de session (`/auth/devices/` est un upsert
prévu pour cela), gestion de l'ouverture depuis l'arrière-plan **et** du
démarrage à froid, canal Android déclaré, et prise en charge des messages
poussés en données seules.

Supprimées au passage : **trois notifications fabriquées** au démarrage
— « 20 % de réduction sur votre première commande », « votre commande #1234 est
en préparation », « votre livreur arrivera dans 10 minutes » — copiées de
l'application cliente, adressées à un client, dans l'application du livreur.

### 3. Les coordonnées étaient fabriquées

`real_time_tracking_screen.dart` **géocodait la chaîne** d'adresse de livraison,
et retombait, quand le géocodage échouait, sur `LatLng(5.3599, -4.0083)` — soit
**Abidjan**, sous un commentaire annonçant Lomé. Le restaurant, lui, était un
point écrit en dur, le même pour tous les établissements.

L'affectation porte pourtant les deux points en clair depuis toujours :
`pickup_location` et `delivery_location`, tous deux obligatoires côté serveur.
Vérifié en bout à bout : `retrait={lat: 6.1319, lon: 1.2255}`,
`dépôt={lat: 6.1319, lon: 1.2228}`.

Corrigé, et avec deux conséquences que le géocodage masquait :

- la destination **dépend de l'étape** : le restaurant tant que le repas n'est
  pas récupéré, le client ensuite. L'écran visait le client dès l'ouverture, si
  bien qu'un livreur venant d'accepter voyait un itinéraire vers une adresse où
  il n'avait rien à faire ;
- l'itinéraire externe s'ouvre désormais **par coordonnées** (`maps/dir/?api=1`,
  Waze, puis `geo:`) et non par une recherche textuelle, qui pouvait tomber sur
  une homonymie à l'autre bout de la ville.

### 4. `allowed_transitions` n'était lu par personne

Le serveur déclare sur chaque course les étapes atteignables
(`DELIVERY_MACHINE.targets_from`). Les trois écrans rejouaient la machine à
états à la main, chacun avec un `switch` séparé, et chacun avec un trou
différent :

- **écran des livraisons** : aucun cas pour `accepted`. Sur une course
  fraîchement acceptée — l'étape la plus courante de cet écran — le bouton
  « Suivant » tombait dans le `default` et ne faisait **rien**, sans message ;
- **écran de suivi** : « Livré » affiché dès l'acceptation, sur une transition
  que la machine refuse. L'appui produisait une erreur d'API pour un geste que
  rien n'avait signalé comme impossible ;
- **écran d'accueil** : la seule des trois dont la table était complète.

Corrigé par `Course.prochaineEtape`, qui lit `allowed_transitions` et rien
d'autre, et par `peutAccepter` / `peutRefuser`. Quinze tests pinnent ce
comportement (`test/course_transitions_test.dart`).

---

## Les fonctionnalités manquantes ou factices

### Refuser une course était impossible

`AppService.declineDelivery()` existait, `/delivery/assignments/{id}/decline/`
existait, et **aucun écran ne les appelait**. Un livreur à qui on proposait une
course qu'il ne pouvait pas prendre — trop loin, fin de service, panne — n'avait
d'autre choix que de la laisser expirer, en la retenant tout ce temps loin d'un
collègue disponible.

Ajouté : bouton « Refuser » avec saisie de la raison, affiché seulement quand le
serveur déclare le refus permis. Vérifié en bout en bout : le refus n'incrémente
pas `deliveries_cancelled`, et la raison est conservée.

### Le « Support » écrivait au client

`ChatScreen(chatType: 'support')` ouvrait **exactement le même canal** que
`'customer'` — `ws/orders/{id}/chat/`, qui relie le livreur au client de la
commande — et n'en changeait que trois libellés. Un livreur qui signalait un
problème au « Support » écrivait donc **au client qu'il était en train de
livrer**, sous un en-tête lui faisant croire l'inverse.

Il n'existe aucun canal de support pour un livreur au contrat :
`/support/tickets/`, `/support/complaints/` et `/support/returns/` sont tous
`IsCustomer`. Le paramètre `chatType` et les trois points d'entrée « Support »
ont donc été retirés — pas remplacés par un canal fabriqué.

### L'onglet « Rapports » ne rapportait rien

Trois boutons de génération et trois rapports « récents » à télécharger : les
cinq n'appelaient rien et affichaient un message d'attente qui ne se résolvait
jamais. Il ne pouvait pas en être autrement — toutes les routes
`/analytics/reports/*` exigent la permission `analytics.read`, qu'un compte
livreur n'a pas (vérifié : HTTP 403). L'onglet est retiré.

### Sept réglages écrits, aucun lu

L'écran des paramètres écrivait sept bascules dans `SharedPreferences` par un
bouton « Sauvegarder les paramètres », et **aucune n'était relue nulle part** :
couper « Suivi GPS » n'arrêtait pas le suivi, « Accepter automatiquement »
n'acceptait rien, la langue ne changeait pas la langue, et « Sombre » ne donnait
pas de thème sombre — l'application n'en déclare pas.

Un interrupteur qui ne fait rien est pire qu'un interrupteur absent : le livreur
qui coupe « Suivi GPS » croit avoir cessé d'être suivi. L'écran montre désormais
l'**état réel** de la position et des notifications, et le chemin pour le
corriger. Le contact support — un numéro ivoirien inventé
(`+225 01 02 03 04 05`) et une adresse en `.ci`, dans une application dont toute
la géographie est togolaise, aucun des deux n'ouvrant quoi que ce soit — est
remplacé par une adresse lue dans `.env`, masquée tant qu'elle n'est pas
renseignée.

---

## Les défauts d'exactitude

### Le « solde disponible » n'était pas un solde

L'écran des gains affichait le total de la **période sélectionnée** sous le
libellé « Solde disponible » — il changeait donc en touchant « Aujourd'hui » /
« Cette semaine » / « Ce mois » — et **c'est ce montant-là qu'il envoyait au
retrait**. Selon l'onglet ouvert, la demande était soit très inférieure à ce que
le livreur avait gagné, soit supérieure à son solde et refusée par le serveur
sans explication lisible.

Le solde qui fait foi est `total_earnings` du dossier, débité sous verrou par
`WithdrawalService.request`. Corrigé, avec saisie du montant, plafonnée au solde
réel, et ajout de l'historique des demandes — un retrait naît « en attente », et
le livreur n'avait aucun moyen de savoir ce qu'il devenait.

### Les gains du jour étaient ceux de la veille

Gains, statistiques et historique groupaient sur `passeeLe`, qui vaut — pour une
course livrée dont le détail de commande n'est plus relu — `offered_at`, le
moment où la course a été **proposée**. Une course proposée à 23 h 50 et livrée à
00 h 10 comptait donc dans les gains de la veille. Corrigé par `livreeLe`
(`delivered_at`, horodaté par le serveur).

### Les exceptions brutes s'affichaient à l'écran

Dix-sept endroits interpolaient l'exception dans le message. En essayant de
passer en ligne avec un dossier non validé, le livreur lisait littéralement :

```
Erreur lors de la mise à jour du statut: ApiException(409,
business_rule_violation, Votre dossier n'est pas validé ; vous ne pouvez pas
encore recevoir de courses.)
```

Le serveur avait écrit exactement la phrase qu'il fallait lui dire — le format
RFC 9457 porte un `detail` rédigé pour l'affichage — et l'application
l'enterrait sous le nom de sa classe. Sur `loginDriver`, l'emballage était
double. Corrigé par `lib/presentation/messages_erreur.dart`, avec treize tests.

### Autres

- `verification_status == 'suspended'` s'affichait « En attente » : un livreur
  suspendu lisait que son dossier était en cours d'instruction. Les quatre états
  sont désormais distingués, avec ce qu'ils impliquent, et les motifs de refus
  (`verification_notes`) sont affichés — ils voyageaient sans que rien ne les
  montre ;
- `can_accept_orders` (invariant L1) était calculé et **jamais affiché** : un
  livreur en ligne mais inéligible attendait des courses qui ne pouvaient pas
  lui être proposées ;
- division par zéro dans les statistiques : « NaN FCFA » s'affichait à tout
  livreur ouvrant l'écran avant sa première course ;
- la référence de commande était un fragment d'UUID (`#A1B2C3D4`), illisible à
  voix haute et introuvable au back-office, alors que `order_reference`
  (`EC000019`) voyage dans chaque affectation sans que personne ne la lise ;
- `driver@fasteat.ci` s'affichait en repli d'adresse e-mail — une adresse
  inventée, sous une marque qui n'est pas la nôtre.

---

## Performance et robustesse

### Le suivi ne survivait pas à l'arrière-plan

L'émission de position reposait sur une `Timer.periodic` appelant
`getCurrentPosition` toutes les dix secondes. Deux défauts, dont un
rédhibitoire : **une minuterie Dart ne survit pas au gel du processus** par
Android — le suivi s'arrêtait peu après que le livreur range son téléphone,
c'est-à-dire précisément quand il sert. Et un point GPS neuf toutes les dix
secondes coûte cher en batterie pour des relevés que le serveur écarte de toute
façon à moins de 100 m ou 30 s du précédent.

Remplacé par un flux de position adossé au service de premier plan de
`geolocator_android` — il continue en arrière-plan, sous une notification que le
livreur voit — avec filtre de 25 m, plancher d'émission de 10 s, et un battement
de 30 s pour qu'un livreur immobile ne disparaisse pas de la carte du client.

### La file des courses ne se rouvrait pas

`RealtimeChannel` ne tente **qu'une seule** reconnexion, puis ferme le flux.
C'est une politique délibérée du socle, partagée avec l'application cliente, où
un flux perdu se rattrape au prochain rechargement d'écran. Elle ne convient pas
à un livreur qui roule et traverse des zones sans réseau : après deux coupures —
quelques minutes de tournée — la file restait fermée pour le reste de la
session.

Une reprise à report exponentiel plafonné (5 s → 60 s) vit désormais dans
`RealtimeTrackingService`, où l'on sait qu'une session de livreur est ouverte,
et non dans le socle. Effet de bord souhaitable : un dossier validé pendant que
l'application tourne rouvre la file de lui-même.

### Silence en perte de réseau

L'écran d'accueil gardait sa liste en cache **sans rien dire** quand le
rechargement échouait — un rafraîchissement silencieux ne montrait même pas de
message. Le livreur lisait des courses périmées en croyant les voir à jour. Un
bandeau distingue maintenant les deux cas : file temps réel fermée, ou dernier
rechargement en échec.

### Code mort supprimé

`GeocodingService` (259 lignes) et ses quatre délégations sur
`RealtimeTrackingService` n'avaient plus aucun appelant — le calcul
d'itinéraire passe par `DirectionsRepository` du socle. Supprimé.

---

## Vérification de bout en bout

Backend Django v2 local, pile docker complète (api, worker, beat, redis,
postgres, minio, nginx). Deux livreurs, un dossier en attente, un compte
personnel, deux commandes réelles.

Chaque appel émis est une route que le code Flutter émet réellement.
**48 vérifications, 48 succès.**

| Phase | Vérifié |
|---|---|
| 3 — Authentification | jeton, refus sans jeton, jeton invalide, mot de passe faux, `user_type == courier` |
| 4 — Disponibilité | bascule réelle ; **un dossier non validé est refusé par un 409** portant sa raison ; le livreur ne peut pas s'auto-valider |
| 5 — Réception | pas de vivier : le livreur ne voit que ce qui lui est adressé |
| 6 — Acceptation | proposition par le personnel ; **le livreur B ne voit ni n'accepte la course de A** (404) ; rémunération figée à l'acceptation ; double acceptation → 409 |
| 6 — Refus | refus avec raison ; n'incrémente pas `deliveries_cancelled` ; accepter après refus → 409 |
| 7 / 11 | `accepted → picked_up → on_the_way → delivered` ; **sauter à `delivered` → 409** ; `delivered_at` horodaté par le serveur ; plus aucune transition ensuite |
| 8 / 9 — GPS | relevé accepté (201) ; relevé quasi immobile **écarté par l'échantillonnage (202)** ; relevé après 100 m enregistré ; un autre livreur ne peut pas émettre (404) |
| 12 — Revenus | compteurs et gains crédités **par le serveur** ; retrait au-delà du solde refusé ; retrait exact accepté, né « en attente » ; solde débité ; historique lisible |
| 13 — Historique | date, montant, destination, statut présents sur chaque ligne |
| 14 — Notifications | enregistrement d'appareil, ré-enregistrement en upsert, notification serveur produite à chaque proposition avec `assignment` + `order` en charge utile, retrait de l'appareil |
| 17 — Sécurité | course d'un collègue **introuvable** ; commande non confiée refusée ; `/delivery/couriers/`, `/analytics/reports/*`, `/notifications/campaigns/` → **403** ; s'auto-proposer une course → **403** |

### Une assertion corrigée, pas un défaut

Rejouer `delivered` sur une course déjà livrée rend **200**, non 409. Vérifié :
c'est une idempotence délibérée et documentée (`DELIVERY_MACHINE.is_noop`) —
« un livreur qui tapote deux fois dans une zone à réseau instable ne doit pas
recevoir d'erreur ». Trois rejeux consécutifs laissent `delivered_at`,
`deliveries_completed` et `total_earnings` **inchangés** : l'invariant C3 tient.
C'est mon attente initiale qui était fausse.

---

## Vérification statique

| | Avant | Après |
|---|---|---|
| `flutter analyze` | 0 problème | **0 problème** |
| `flutter test` | 26 tests | **53 tests** |
| `flutter build apk --debug` | succès | **succès** |
| Couverture (dénominateur honnête) | ~1,3 % | **3,28 %** (plancher 2,5 %) |

27 tests ajoutés : `course_transitions_test.dart` (15) pinne la lecture des
transitions serveur, `messages_erreur_test.dart` (13) pinne les messages
affichés sur les erreurs réellement observées pendant l'audit.

---

## Réserves restantes

### Demandent une décision d'exploitation

1. **`SUPPORT_EMAIL` n'est pas renseigné.** Aucune coordonnée de support réelle
   n'existe dans ce dépôt ; celle qui s'y trouvait était inventée. L'entrée
   « Contacter El Corazón » reste masquée tant que la variable est vide. Il faut
   décider par où un livreur signale un problème.

2. **`API_BASE_URL` pointe sur Render**, dont le déploiement rendait 500 sur
   toute route publique (cache Redis absent). L'audit a été mené contre le
   backend local. Le fichier `.env` n'a pas été modifié.

### Écarts de contrat, sans effet sur le parcours

3. **Aucune preuve de livraison n'est possible.** `Assignment.proof_of_delivery`
   existe en base, mais **aucun sérialiseur, aucune vue, aucun service** ne
   l'expose. Il n'y a ni code, ni photo, ni signature au contrat. La
   confirmation de livraison est donc un dialogue de confirmation — en
   fabriquer une côté application donnerait une garantie que rien ne vérifie.
   Ouvrir l'endpoint est un travail backend.

4. **Un livreur ne peut pas déposer ses pièces depuis l'application.**
   `POST /delivery/me/` accepte des documents en multipart (`DocumentsSerializer`),
   mais `DeliveryRepository` ne l'expose pas. Un livreur dont le dossier est
   rejeté n'a aucun moyen de le corriger lui-même. L'écran affiche désormais le
   motif du refus, ce qui est le minimum.

5. **La langue et le thème ne sont pas réglables.** Les deux sélecteurs
   n'agissaient sur rien et ont été retirés plutôt que laissés en trompe-l'œil.
   L'application suit la locale du système et n'a qu'un thème clair.

### Non couvert par cet audit

6. **Le parcours n'a pas été piloté depuis l'interface Flutter sur un
   téléphone.** Les 48 vérifications portent sur les échanges serveur — chaque
   route que l'application émet — et le rendu est couvert par 53 tests, mais un
   passage manuel sur appareil réel reste à faire, en particulier pour la
   notification de service de premier plan et l'arrivée d'une notification
   application fermée.

7. **Les appels Agora** (`agora_call_service.dart`, `call_screen.dart`) n'ont
   pas été audités : hors du parcours décrit, et l'écran porte un `TODO` sur
   l'affichage vidéo qui lui préexiste.
