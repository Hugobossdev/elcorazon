# Audit — second lot Stitch (parcours de compte et de livraison)

> Source : `stitch_el_coraz_n_client_ui_redesign (1).zip` — **14 maquettes** +
> `el_coraz_n_mobile/DESIGN.md`.
> Cible : `apps/fastfood` (paquet `elcora_fast`), branche `redesign-client-ui`.
> Établi le 2026-08-30, avant toute modification de code.

Ce lot **complète** le premier (`UI_REDESIGN_AUDIT.md`, 15 maquettes du
parcours de commande). Les deux ensemble couvrent l'application cliente
entière : 29 maquettes.

---

## 0. Le fait le plus important de cet audit

**`DESIGN.md` des deux archives est identique, octet pour octet.**

```
diff stitch/el_coraz_n_mobile/DESIGN.md stitch2/el_coraz_n_mobile/DESIGN.md
→ aucune différence
```

Conséquence directe : **il n'y a pas de système de design à refaire**. La
palette Material 3 (`#b51822`), les huit rôles typographiques Inter, les
espacements 4/8/16/24/32, les rayons 8/12/16/24, les trois élévations et le
verre dépoli sont déjà dans `lib/theme.dart` et
`lib/utils/design_constants.dart`, et les douze composants de
`lib/widgets/design/` les appliquent déjà.

Ce lot est donc **exclusivement un travail d'écrans**. §7 et §8 du cahier des
charges (design system, composants) sont satisfaits par l'existant ; ce qui
manque, ce sont les composants propres à ces quatorze écrans — chronologie de
statut, carte de livreur, bulle de conversation, étoiles de notation.

---

## 1. Architecture actuelle

Inchangée depuis le premier lot. Rappel condensé :

```
main.dart
 ├── ProviderContainer (Riverpod)  → session, ApiClient, TokenStorage
 ├── MultiProvider (provider)      → 24 services ChangeNotifier
 └── MaterialApp
      ├── theme / darkTheme        → lib/theme.dart
      └── onGenerateRoute          → AppRouter (32 routes nommées)
```

| Couche | Emplacement | Rôle |
|---|---|---|
| Écrans | `lib/screens/` | présentation |
| Composants | `lib/widgets/`, `lib/widgets/design/` | briques réutilisables |
| Vocabulaire d'affichage | `lib/presentation/` | extensions sur les modèles du socle |
| Services | `lib/services/` | état, cache, temps réel |
| Dépôts | `lib/repositories/` | adaptation vers le socle |
| Socle partagé | `packages/elcorazon_core` | modèles, `ApiClient`, dépôts REST |

**Gestion d'état** : `provider` (`ChangeNotifier`) pour les services d'écran,
`flutter_riverpod` pour la session et l'`ApiClient` uniquement. Les deux
coexistent volontairement ; ce n'est pas une dette à résorber dans une phase
d'interface.

**Navigation** : un seul système — `Navigator` + routes nommées via
`AppRouter.generateRoute`, avec des raccourcis typés dans
`lib/widgets/navigation_helper.dart`. Aucun routeur concurrent (§21 satisfait).

**Services externes réellement en place** : Firebase Core + Messaging (FCM),
Google Maps + Geolocator, Agora RTC (appels), WebSockets Django Channels
(chat, suivi, panier de groupe, appels), PayDunya via
`POST /payments/{id}/initiate/`, `sqflite` + `shared_preferences` (cache et
hors ligne).

---

## 2. Écrans existants concernés par ce lot

| Fichier | Lignes | Charte | Services lus |
|---|---|---|---|
| `screens/auth_screen.dart` | 657 | ancienne | `AppService` |
| `screens/client/rewards_screen.dart` | 656 | ancienne | `AppService`, `GamificationService` |
| `screens/client/order_details_screen.dart` | 729 | ancienne | **aucun** |
| `screens/client/delivery_tracking_screen.dart` | 1 590 | ancienne | `RealtimeTrackingService`, `DirectionsService`, `GeocodingService`, `DriverRatingService`, `DjangoOrderRepository` |
| `screens/client/chat_screen.dart` | 313 | ancienne | `ChatService`, `AppService` |
| `screens/client/call_screen.dart` | 404 | ancienne | `CallService`, `AgoraService`, `AppService` |
| `screens/client/order_rating_screen.dart` | 357 | ancienne | `ReviewRatingService`, `DriverRatingService` |
| `screens/client/driver_rating_screen.dart` | 149 | ancienne | `DriverRatingService` |
| `screens/client/support_screen.dart` | 364 | ancienne | `SupportService` |
| `screens/client/profile_screen.dart` | 752 | **nouvelle** | `AppService`, `GamificationService`, `ThemeService` |
| `screens/client/notifications_screen.dart` | 389 | **nouvelle** | `NotificationDatabaseService` |

**Aucun écran d'onboarding n'existe.** Vérifié : aucune occurrence de
`onboarding`, `firstLaunch`, `hasSeenIntro` dans `lib/`. Le premier lancement
mène directement à `SplashScreen` → `AuthScreen` ou `MainNavigationScreen`.
Les quatre maquettes d'onboarding sont donc un **ajout**, pas une refonte.

---

## 3. Écrans du ZIP

```
onboarding_welcome                    onboarding_tracking_highlight
onboarding_authentication_options     onboarding_create_account
profile                               rewards
notifications                         order_details
delivery_tracking                     chat_with_driver
voice_call                            rate_your_meal
rate_delivery                         help_center
```

---

## 4. Mapping

| Écran Stitch | Écran Flutter actuel | Action |
|---|---|---|
| `onboarding_welcome` | *(aucun)* | **Création** |
| `onboarding_tracking_highlight` | *(aucun)* | **Création** |
| `onboarding_authentication_options` | *(aucun)* | **Création** — amputé (voir §6) |
| `onboarding_create_account` | `auth_screen.dart` (onglet Inscription) | Refonte |
| `profile` | `profile_screen.dart` | Écart seulement (voir §6) |
| `rewards` | `rewards_screen.dart` | Refonte |
| `notifications` | `notifications_screen.dart` | Écart seulement (voir §6) |
| `order_details` | `order_details_screen.dart` | Refonte |
| `delivery_tracking` | `delivery_tracking_screen.dart` | Refonte |
| `chat_with_driver` | `chat_screen.dart` | Refonte |
| `voice_call` | `call_screen.dart` | Refonte |
| `rate_your_meal` | `order_rating_screen.dart` | Refonte |
| `rate_delivery` | `driver_rating_screen.dart` | Refonte |
| `help_center` | `support_screen.dart` | Refonte |

---

## 5. Analyse écran par écran

Format : `UI → widgets → données → modèle → service → API → route`.
Les noms sont ceux **réellement présents** dans le projet.

### 5.1 `onboarding_welcome` — création

```
Logo, photo pleine hauteur, « Gourmet at Heart. Fast by Nature. »,
« Get Started » + « Sign In »
 ↓ OnboardingScreen (nouveau), page 1
 ↓ aucune donnée serveur — écran marketing
 ↓ —
 ↓ SharedPreferences (drapeau « déjà vu »)
 ↓ —
 ↓ AppRouter.onboarding (nouvelle route)
```

### 5.2 `onboarding_tracking_highlight` — création

```
« Skip », illustration, pastille « Arriving in 12 min »,
« Track Every Bite », « Next »
 ↓ OnboardingScreen, page 2
 ↓ aucune donnée serveur
 ↓ — · — · —
 ↓ même route
```

La pastille « 12 min » est un **élément d'illustration**, pas une estimation :
elle ne doit être branchée sur rien (§24).

### 5.3 `onboarding_authentication_options` — création partielle

```
Logo, « Sign Up with Email », « Continue with Google »,
« Continue with Apple », « Log in », CGU + confidentialité
 ↓ OnboardingScreen, page 3 → AuthScreen
 ↓ AppService.login / register
 ↓ Session · User
 ↓ POST /auth/login/ · POST /auth/register/
 ↓ AppRouter.auth
```

**Google et Apple sont écartés.** `auth_screen.dart:493` le dit déjà :

> « La connexion/inscription téléphone+OTP, Google et "mot de passe oublié"
> n'ont pas d'équivalent côté backend Django (Phase 6). »

§9 du cahier des charges est explicite : « Ne crée pas de méthode
d'authentification qui n'existe pas dans le backend. » Ces deux boutons ne
seront donc **pas** dessinés — un bouton « Continuer avec Google » qui ouvre
un formulaire e-mail est pire qu'un bouton absent. Consigné en
`STITCH_BACKEND_REQUIREMENTS.md`.

Les liens CGU et confidentialité renvoient à ISSUE-007 du premier lot :
aucun document n'est publié.

### 5.4 `onboarding_create_account` — refonte

```
Nom, e-mail, téléphone, mot de passe (œil), « Create Account »
 ↓ auth_screen.dart, onglet Inscription
 ↓ AppService.register(name, email, phone, password)
 ↓ sessionProvider.register → AuthRepository
 ↓ POST /auth/register/
 ↓ User · Session
 ↓ AppRouter.auth
```

Les quatre champs de la maquette correspondent **exactement** à la signature
existante. Aucun champ à inventer.

### 5.5 `profile` — écart seulement

```
Avatar, « Gourmet Lover », puce « Gold Member », liste :
Edit Profile · My Addresses · Payment Methods · Order History ·
Settings · Log Out
 ↓ profile_screen.dart  (déjà à la nouvelle charte)
 ↓ AppService · GamificationService · ThemeService
 ↓ User · PointsAccount
 ↓ GET /accounts/me/ · GET /loyalty/account/
 ↓ MainNavigationScreen, onglet 4
```

Écarts relevés :

| Maquette | État |
|---|---|
| Puce de palier (« Gold Member ») | **déjà fait** — `palierDeFidelite` |
| Edit Profile · My Addresses · Order History · Settings | **déjà fait** |
| **Payment Methods** | **absent** — voir §6 |
| Icône « menu » (tiroir) en tête | Écarté : l'application n'a pas de tiroir, et en ajouter un doublerait la barre inférieure |

### 5.6 `rewards` — refonte

```
Carte de palier + points + progression vers le palier suivant,
« Active Rewards » (Redeem / Locked), « Point History »
 ↓ rewards_screen.dart
 ↓ GamificationService
 ↓ PointsAccount · Reward · PointsEntry · RewardRedemption
 ↓ GET /loyalty/account/ · GET /loyalty/rewards/ ·
   GET /loyalty/entries/ · POST /loyalty/rewards/{id}/redeem/
 ↓ AppRouter.rewards
```

**Le backend couvre entièrement cette maquette.** `PointsAccount` porte
`balance`, `lifetimeEarned`, `lifetimeSpent` ; `Reward` porte `name`,
`description`, `pointsCost`, `discount`, `validityDays` ; `PointsEntry` porte
`delta`, `balanceAfter`, `description`, `orderId`, `createdAt` — c'est
exactement l'historique « +120 pts / Order #ELC-492 » de la maquette.

Le verrou « Unlocks at 2500 pts » se déduit de `pointsCost > balance`.

Les paliers (« Gold », « Platinum (3000 pts) ») viennent en revanche de
`palierDeFidelite()`, **écrit côté client** — voir §6.

### 5.7 `notifications` — écart seulement

```
« Mute Notifications », onglets All / Orders / Promotions / System,
groupement Today / Yesterday
 ↓ notifications_screen.dart  (déjà à la nouvelle charte)
 ↓ NotificationDatabaseService
 ↓ AppNotification · GenreNotification
 ↓ GET /notifications/ · POST /notifications/{id}/read/ ·
   POST /notifications/read-all/
 ↓ AppRouter.notifications
```

| Maquette | État |
|---|---|
| Filtres par genre | **déjà fait** (5 genres au lieu de 3 — le serveur en distingue cinq) |
| Marquer tout comme lu | **déjà fait** |
| **Groupement par jour** (Today / Yesterday) | à ajouter — pur affichage, aucune API |
| **« Mute Notifications »** | à écarter — voir §6 |

### 5.8 `order_details` — refonte

```
Chronologie 4 étapes, adresse, livreur, articles, récapitulatif,
moyen de paiement
 ↓ order_details_screen.dart
 ↓ (aucun aujourd'hui) → DjangoOrderRepository
 ↓ Order · OrderLine · Transaction
 ↓ GET /orders/{id}/ · GET /payments/transactions/?order={id}
 ↓ AppRouter.orderDetails
```

**Défaut de fond relevé** : l'écran reçoit un `Order` **en argument de route**
et ne le relit jamais. Le statut affiché est celui du moment où la liste a été
chargée. Or la maquette place une chronologie de statut au premier plan —
c'est l'information la plus périssable de l'écran. `GET /orders/{id}/` existe.

### 5.9 `delivery_tracking` — refonte

```
Carte, ETA « 15-20 min », chronologie Prep → Picked Up → Nearby →
Delivered, carte livreur (note, moto, plaque), boutons chat + appel
 ↓ delivery_tracking_screen.dart
 ↓ RealtimeTrackingService · DirectionsService · GeocodingService ·
   DriverRatingService
 ↓ OrderTracking · LocationPing · Order
 ↓ GET /tracking/orders/{id}/  +  WebSocket ws/orders/{id}/tracking/
 ↓ AppRouter.deliveryTracking
```

**Le temps réel existe réellement.** `OrderTracking` porte `assignmentStatus`,
`courier` (dont `rating_average`, `rating_count`), `lastPosition`
(`LocationPing` : latitude, longitude, cap, vitesse, horodatage) et
`estimatedDeliveryAt`. Aucun déplacement de livreur n'aura à être simulé
(§14).

La plaque et le modèle du deux-roues (« Yamaha NMAX • ABJ-742ers ») dépendent
de ce que `courier` contient réellement — à vérifier à l'exécution, et à
omettre si absent.

### 5.10 `chat_with_driver` — refonte

```
En-tête livreur + « Online », bulles, horodatage, double coche,
champ de saisie
 ↓ chat_screen.dart
 ↓ ChatService (WebSocket)
 ↓ ChatMessage
 ↓ ws/orders/{id}/chat/
 ↓ (poussé depuis le suivi)
```

**Contrainte structurante** : `ChatService` le documente —
« **Le backend ne persiste pas la conversation** (ADR-008) : le consommateur
relaie, il n'écrit nulle part. » Il n'y a donc **pas d'historique** à
recharger ; le fil part vide à chaque ouverture.

La maquette montre un fil garni dès l'arrivée. Ce sera un fil vide avec un
état explicite, pas un faux historique (§15 : « Ne simule pas un chat réel
avec un stockage local uniquement »). Consigné.

La double coche « lu » n'existe pas au contrat non plus.

### 5.11 `voice_call` — refonte

```
Avatar plein écran, « Calling... », minuteur, Mute / End / Speaker
 ↓ call_screen.dart
 ↓ CallService · AgoraService
 ↓ Call
 ↓ POST /calls/… + Agora RTC
 ↓ (poussé depuis le suivi ou la conversation)
```

**Agora est réellement intégré.** `CallService` expose `initiateCall`,
`acceptCall`, `rejectCall`, `endCall` et deux flux d'état. Le minuteur devra
compter depuis l'instant de connexion **réel**, pas depuis l'ouverture de
l'écran — la maquette démarre le sien à 45 s par simple `setInterval`.

### 5.12 `rate_your_meal` — refonte

```
Note par article, puces « What stood out? », commentaire, envoi
 ↓ order_rating_screen.dart
 ↓ ReviewRatingService
 ↓ Review
 ↓ POST /catalog/reviews/  { menu_item, rating, title, comment }
 ↓ AppRouter.orderRating
```

**La notation par article est réellement supportée** — c'est exactement la
signature de `submitReview`. Un avis par article et par personne ; le serveur
refuse le second (S5).

Les puces « What stood out? » n'ont pas de champ dédié : elles alimenteront
`title`, qui existe et est aujourd'hui laissé vide.

### 5.13 `rate_delivery` — refonte

```
« How did Koffi A. do today? », étoiles, puces, **pourboire**
(No Tip / 500 F / 1000 F / 2000 F)
 ↓ driver_rating_screen.dart
 ↓ DriverRatingService
 ↓ —
 ↓ POST /delivery/orders/{id}/rating/  { score, comment }
 ↓ AppRouter.driverRating
```

**Le pourboire n'existe pas au contrat.** Ni `/delivery/orders/{id}/rating/`
ni `/payments/` n'acceptent de montant de gratification. Le bloc ne sera pas
dessiné — un sélecteur de pourboire qui ne débite rien est le pire cas de
figure sur un écran d'argent. Consigné.

Le nom du livreur : voir ISSUE-006 du premier lot — `Order` ne le porte pas,
mais `OrderTracking.courier` **oui**. C'est la voie de correction.

### 5.14 `help_center` — refonte

```
Recherche, « Help Topics » (4 tuiles), « Contact Us » (chat / e-mail),
FAQ en accordéon
 ↓ support_screen.dart
 ↓ SupportService
 ↓ SupportTicket · SupportMessage
 ↓ GET/POST /support/tickets/ · GET/POST /support/tickets/{id}/messages/
 ↓ AppRouter.support
```

Le support est réel : tickets, fil de messages, réclamations, retours. « Chat
with Support » ouvre un ticket ; ce n'est pas une fausse messagerie.

La FAQ est du **contenu statique configuré** — explicitement autorisé par §24.
Les quatre catégories de la maquette correspondent aux catégories de ticket.

---

## 6. Divergences maquette ↔ produit

Ce que Stitch dessine et qui ne sera pas repris tel quel, avec le motif.

| # | Maquette | Élément | Motif |
|---|---|---|---|
| A | `onboarding_authentication_options` | « Continue with Google », « Continue with Apple » | Aucun équivalent backend. §9 l'interdit explicitement |
| B | `rate_delivery` | Pourboire 500 / 1 000 / 2 000 F | Aucune route n'encaisse un pourboire. Un sélecteur qui ne débite pas est un mensonge sur un écran d'argent |
| C | `notifications` | « Mute Notifications » | Aucun réglage serveur (vérifié : `NotificationRepository` n'expose que lecture et marquage). Un interrupteur local n'arrêterait pas les pushs FCM — il ferait croire au silence |
| D | `chat_with_driver` | Fil garni à l'ouverture, double coche « lu » | Le serveur **ne persiste pas** la conversation (ADR-008). Aucun historique, aucun accusé de lecture |
| E | `profile` | « Payment Methods » | Aucun moyen de paiement enregistré : PayDunya ouvre une session par commande. Rien à lister |
| F | `profile`, `rewards` | Icône « menu » (tiroir) | L'application n'a pas de tiroir ; en ajouter un doublerait la barre inférieure |
| G | `profile`, `rewards` | Barre inférieure **Home / Menu / Rewards / Profile** | L'application a **Home / Menu / Commandes / Profil**. La maquette `help_center` du même lot montre pourtant *Home / Orders / Support / Profile* — Stitch n'est pas cohérent avec lui-même. Les commandes restent : c'est le cœur d'une application de livraison, et les récompenses restent atteignables depuis le profil et l'accueil |
| H | `rewards` | Paliers « Gold », « Platinum (3000 pts) » | `palierDeFidelite()` est **écrit côté client** (seuils 200 / 500). Le serveur ne publie pas de paliers. Les noms de la maquette ne correspondent pas aux seuils du code |
| I | `delivery_tracking` | « Yamaha NMAX • ABJ-742 » | Dépend de ce que `OrderTracking.courier` porte réellement. À omettre si absent |
| J | `rate_your_meal` | Puces « What stood out? » | Pas de champ dédié ; elles alimenteront `title`, aujourd'hui inutilisé |

A, B, C, D, E, H seront détaillés dans `docs/STITCH_BACKEND_REQUIREMENTS.md`
au format demandé par §25.

---

## 7. Défauts déjà visibles à l'audit

Trouvés en lisant le code, avant toute modification.

| # | Défaut | Fichier |
|---|---|---|
| 1 | `OrderDetailsScreen` ne relit jamais la commande : le statut affiché est celui du chargement de la liste. La maquette met une chronologie de statut au premier plan | `order_details_screen.dart` |
| 2 | ISSUE-015 du premier lot est **inexacte** : `Review` porte bien `helpfulCount` et `isVerifiedPurchase`. Ce qui manque, c'est la route pour **voter** — pas le champ | `packages/elcorazon_core/.../review.dart` |
| 3 | Le nom du livreur, laissé à `null` par ISSUE-006, est en réalité disponible dans `OrderTracking.courier` | `delivery_status_card.dart` |

---

## 8. Ordre d'exécution retenu

Celui du §34, réduit à ce qui reste à faire :

```
1. ONBOARDING (4 écrans, création)          6. DELIVERY TRACKING
2. AUTH (refonte)                           7. DRIVER CHAT
3. PROFILE (écart : rien de bloquant)       8. VOICE CALL
4. REWARDS                                  9. MEAL RATING + DELIVERY RATING
5. ORDER DETAILS                           10. HELP CENTER
                                           11. NOTIFICATIONS (groupement par jour)
                                           12. NAVIGATION · TESTS · NETTOYAGE
```

Ce qui n'est **pas** touché : backend, base, contrat d'API, authentification,
PayDunya, Firebase, Google Maps, Agora, identifiants de paquet, et le nom
**El Corazón**.
