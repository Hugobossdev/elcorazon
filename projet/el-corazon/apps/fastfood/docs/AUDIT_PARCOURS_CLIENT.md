# Audit du parcours client — `apps/fastfood`

**Date** : 31 août 2026 · **Branche** : `redesign-client-ui` · **Backend** : Django v2, local (`http://localhost:8000`)

Audit complet du parcours client, de l'ouverture de l'application à la notation
de la commande, contre le **backend réel** — aucune donnée n'a été simulée pour
produire ce rapport.

---

## Statut

**READY WITH WARNINGS.**

Le parcours complet fonctionne de bout en bout. Il ne fonctionnait pas au début
de l'audit : une adresse de base incomplète dans `.env` mettait **toutes** les
routes de l'API en 404. Les réserves restantes sont listées en fin de document ;
aucune n'interrompt le parcours, deux demandent une décision d'exploitation
avant mise en production.

---

## Ce que l'audit a trouvé

L'application est nettement plus avancée que ne le laissait supposer son état
apparent. L'architecture est saine et cohérente :

- toute la couche réseau passe par `packages/elcorazon_core`, un dépôt par
  domaine, chacun reflétant un sérialiseur Django nommé en commentaire ;
- les montants sensibles sont établis par le serveur (`POST /orders/preview/`),
  jamais recalculés côté client ;
- la commande naît du **panier serveur** (`ensureSynced` précède
  `POST /orders/`), avec clé d'idempotence ;
- le paiement n'avance que par webhook signé : l'écran sonde
  `/payments/transactions/` et ne déclare jamais un succès de lui-même ;
- le temps réel (suivi, chat, appels, panier de groupe) dérive son adresse
  d'une seule fonction, `adresseWebSocket`.

Les défauts trouvés sont donc **ponctuels et identifiables**, pas structurels.

---

## Corrections apportées

### 1. Bloquant — l'API répondait 404 sur tout

`.env` portait `API_BASE_URL=localhost:8000`. Le schéma manquant était déjà
rattrapé au démarrage ; le préfixe `/api/v1` ne l'était pas. Le client demandait
`/catalog/items/` à un serveur qui ne monte l'API que sous
`/api/v1/catalog/items/`.

Vérifié au `curl` : `/api/v1/catalog/items/` → **200** (50 articles),
`/catalog/items/` → **404**.

Le symptôme — catalogue vide, connexion impossible, panier muet — ressemble
trait pour trait à une base non peuplée. La base était pleine.

**Corrigé à deux niveaux** :

- `.env` porte désormais `http://localhost:8000/api/v1` ;
- `adresseDeLApi` ([`lib/main.dart`](../lib/main.dart)) rattrape le préfixe
  absent comme elle rattrapait déjà le schéma absent, **en le traçant** — un
  réglage corrigé en silence reste faux dans le fichier. Un chemin déjà déclaré
  (`/api/v2`, préfixe de proxy) est respecté : c'est un choix, pas un oubli.

7 tests ajoutés dans [`test/adresse_api_test.dart`](../test/adresse_api_test.dart).

### 2. Le bouton « Commander » restait muet en cas de refus

`AppService.placeOrderFromCartService` rattrapait **toute** exception pour
rendre une chaîne vide. Son unique appelant n'agit que si l'identifiant rendu
n'est pas vide, et son propre `catch` ne voyait donc jamais rien.

Conséquence : sur un article devenu indisponible, un minimum de commande non
atteint, un 429 ou une coupure réseau, le client appuyait sur « Commander », le
voyant tournait, s'arrêtait — et rien ne se passait, sans un mot. À l'étape
exacte où l'on abandonne.

Le serveur disait pourtant précisément pourquoi : `problem+json` porte un
`detail` lisible. Il était jeté.

**Corrigé** : l'exception est tracée **et** relancée ; le règlement affiche le
motif du serveur, en distinguant la panne réseau (« réessayez ») du refus
métier (« corrigez »).

### 3. Les notifications push n'ouvraient aucun écran

Trois défauts cumulés dans [`push_notification_service.dart`](../lib/services/push_notification_service.dart) :

| Défaut | Effet |
|---|---|
| Aucun abonné à `notificationStream` | Toucher une notification posait l'app sur l'accueil |
| Pas de `getInitialMessage()` | Démarrage à froid depuis une notification : destination perdue |
| Charge utile mal relue au premier plan | `data` vidé, donc plus d'identifiant de commande |
| Genre lu sur `type` | Le serveur écrit `kind` — tout message retombait sur `general` |

**Corrigé** : les quatre. Un nouveau guet,
[`PushNotificationRouter`](../lib/widgets/push_notification_router.dart), placé
sous le `Navigator` — même emplacement et même raison qu'`IncomingCallHandler`
— ouvre l'écran visé, en suivant **la règle déjà écrite** pour la liste des
notifications, pour que les deux chemins ne divergent pas.

### 4. Écran de contact des visiteurs — Abidjan, et trois boutons morts

[`guest_contact_screen.dart`](../lib/screens/guest_contact_screen.dart),
visible par tout visiteur non connecté, affichait : une adresse à Abidjan, un
numéro ivoirien `+225 07 00 00 00 00` composable, un WhatsApp sur ce numéro,
un courriel en `.ci`, et trois boutons de réseaux sociaux dont le rappel était
`() {}`.

Le reste de l'application avait déjà été rassemblé sur `AppConstants` ; cet
écran était resté en arrière avec ses valeurs en dur.

**Corrigé** : tout passe par `AppConstants`. Téléphone et WhatsApp
n'apparaissent que si un numéro est réellement configuré — `supportPhone` est
vide par convention tant que le vrai n'est pas connu. Nouveau `supportEmail`,
vide de même. Les trois boutons morts sont retirés. Le support écrit mène à la
connexion, et le dit : les tickets exigent un compte, et cet écran ne s'affiche
qu'aux visiteurs déconnectés.

### 5. Suggestions d'accueil — un moteur qui inventait ses données

`AIRecommendationService` fabriquait, pour **tout** compte, les mêmes goûts
inventés et deux commandes qui n'avaient jamais eu lieu — un « El Corazón
Burger » à 12,99 et une « Margherita Pizza » à 15,99, livrées au « 123 Main
St ». Le classement était ensuite bousculé par `Random().nextBool()` (météo) et
`Random().nextDouble()` (score).

Trois défauts que l'audit a mesurés :

- les catégories cherchées étaient anglaises (`drink`, `soup`, `coffee`) contre
  un catalogue français : « Boissons » ne contient pas `drink` ;
- les seuils de prix étaient en dollars (10 / 20) sur des articles à 1 500 –
  6 000 F CFA : ce terme du score valait **zéro pour tout le monde** ;
- l'accueil filtrait ensuite sur `isPopular && ratingAverage > 4.0`, alors que
  le serveur ouvre tout article à `0.00` sans aucun avis en base : la section
  « Nos suggestions » était **structurellement vide**, et l'a toujours été.

**Corrigé** : service réécrit sur trois signaux qui existent pour de bon —
l'historique réel du compte (`/orders/`, rapproché du catalogue par identifiant
d'article pour retrouver la catégorie), `is_popular` posé par l'exploitation, et
la note moyenne quand il y a des avis. Aucun tirage aléatoire : deux ouvertures
de l'accueil proposent la même chose. Le filtre impossible est retiré.

### 6. Suivi de livraison — le filet doublait la source

L'écran de suivi relisait `GET /orders/{id}/` **toutes les dix secondes**, en
permanence, pendant que le WebSocket livrait déjà les mêmes changements. Six
requêtes par minute et par client, sur l'écran qu'on laisse ouvert le plus
longtemps de l'application.

**Corrigé** : la cadence suit l'état du canal — une minute quand il est ouvert
(le filet ne rattrape qu'un message perdu), dix secondes quand il est tombé
(il est alors la seule source).

---

## Vérification de bout en bout

Parcours complet rejoué contre le backend local, compte créé pour l'occasion :

| Étape | Route | Résultat |
|---|---|---|
| Inscription | `POST /auth/register/` | 201, couple de jetons |
| Session | `GET /auth/me/` | 200, `user_type: customer` |
| Catalogue | `GET /catalog/items/` | 200, **50 articles**, 8 catégories |
| Zone | `GET /geography/zones/resolve/` | `is_covered: true` |
| Adresse | `POST /profiles/addresses/` | 201 (`city` = UUID, résolu par le dépôt) |
| Panier | `POST /carts/{slug}/lines/` | 200, ligne à 2 × 1 500 |
| Devis | `POST /orders/preview/` | 3 000 + 659 = **3 659 XOF**, `is_orderable` |
| Commande | `POST /orders/` | 201, `EC000018`, `pending` |
| Paiement | `POST /payments/{id}/initiate/` | 200, transaction `processing` |
| Transactions | `GET /payments/transactions/` | 200, l'encaissement en cours |
| Historique | `GET /orders/` | 200, la commande y figure |
| Fidélité | `GET /loyalty/account/` | 200, solde à 0 (crédité à la livraison) |

Aucun écart entre ce que le client envoie et ce que le serveur attend.

---

## Contrôles

| Contrôle | Avant | Après |
|---|---|---|
| `flutter analyze` | 0 problème | **0 problème** |
| `flutter test` | 303 tests | **310 tests**, tous verts |
| `flutter build web` | — | **succès** |

Le build a été fait, et pas seulement l'analyse : `flutter analyze` ne voit ni
les assets ni le code injoignable. L'asset `.env` du bundle a été relu pour
vérifier qu'il porte bien l'adresse corrigée.

---

## Réserves restantes

### À décider avant mise en production

1. **`AppConstants.supportPhone` et `supportEmail` sont vides.** C'est
   volontaire — mieux vaut un moyen de contact en moins qu'un numéro qui sonne
   chez un inconnu — mais il faut les renseigner. Tant qu'ils le sont, l'appel
   et le courriel n'apparaissent nulle part.
2. **PayDunya répond en bac à sable.** L'initiation rend une référence `SBX-…`
   et une adresse `sandbox.elcorazon.app`. Réglage backend, hors de cette
   application.

### Connu et assumé

3. **Les 30 SVG du pack emojis n'existent pas encore.** Les quatre dossiers de
   `packages/elcorazon_core/assets/emojis/` sont vides ; `AppEmoji` se replie
   sur les icônes du design system, ce qui reste un écran juste. Le build passe.
4. **Aucune route de recommandation côté serveur.** Le classement local
   ci-dessus est ce qu'on peut établir honnêtement ; une vraie recommandation
   est un travail de modèle.
5. **`VoiceService` reste simulé.** Il n'est branché à aucun écran — seulement
   déclaré dans `main.dart` et `ServiceInitializer`. Hors parcours de
   production.
6. **`DjangoOrderRepository.watchUserOrders`** (sondage à 30 s) n'a aucun
   appelant : il n'existe que pour satisfaire l'interface.
7. **`lib/screens/dev/emoji_gallery_screen.dart`** n'est référencé nulle part —
   écran d'outillage, non joignable depuis l'application.
8. **`ARCHITECTURE.md` est périmé** : il décrit encore un backend Node, du
   `socket.io` et des clés PayDunya côté client. Le code ne fait plus rien de
   tout cela.

---

## Fichiers modifiés

| Fichier | Objet |
|---|---|
| `.env` | Adresse de l'API complétée |
| `lib/main.dart` | Rattrapage du préfixe `/api/v1` ; branchement du guet de notifications |
| `test/adresse_api_test.dart` | 7 tests sur le rattrapage |
| `lib/services/app_service.dart` | Les refus de commande remontent |
| `lib/screens/client/checkout_screen.dart` | Affiche le motif du serveur |
| `lib/services/push_notification_service.dart` | Démarrage à froid, charge utile, genre |
| `lib/widgets/push_notification_router.dart` | **Nouveau** — ouvre l'écran visé |
| `lib/services/ai_recommendation_service.dart` | Réécrit sur des signaux réels |
| `lib/screens/client/client_home_screen.dart` | Filtre impossible retiré |
| `lib/screens/guest_contact_screen.dart` | Lomé, plus de numéros inventés ni de boutons morts |
| `lib/config/app_constants.dart` | `supportEmail` |
| `lib/screens/client/delivery_tracking_screen.dart` | Cadence de relecture adaptative |

Aucune API modifiée : le contrat serveur était juste, c'est le client qui s'en
écartait.
