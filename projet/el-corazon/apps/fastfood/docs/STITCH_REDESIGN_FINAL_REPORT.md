# Rapport final — second lot Stitch (parcours de compte et de livraison)

> Source : `stitch_el_coraz_n_client_ui_redesign (1).zip` — 14 maquettes.
> Cible : `apps/fastfood` (paquet `elcora_fast`), branche `redesign-client-ui`.
> Achevé le 2026-08-30.

Documents liés : [`STITCH_REDESIGN_AUDIT.md`](STITCH_REDESIGN_AUDIT.md) ·
[`STITCH_BACKEND_REQUIREMENTS.md`](STITCH_BACKEND_REQUIREMENTS.md) ·
et, pour le premier lot, [`UI_REDESIGN_AUDIT.md`](UI_REDESIGN_AUDIT.md) ·
[`UI_REDESIGN_ISSUES.md`](UI_REDESIGN_ISSUES.md) ·
[`UI_REDESIGN_FINAL_REPORT.md`](UI_REDESIGN_FINAL_REPORT.md).

**Avec le premier lot, les 29 maquettes livrées sont intégrées.**

---

## État final

```
UI                     29 maquettes sur 29
Fonctionnalités        aucune retirée ; 4 écrans créés (onboarding)
API                    aucune route inventée ; 13 besoins backend consignés
Tests                  flutter analyze : aucun problème
                       flutter test    : 283 tests verts (196 au départ)
                       flutter build web --release : succès (exit 0)
Responsive             5 largeurs × 2 échelles de texte, au banc
Performance            aucun appel réseau ajouté ; 3 champs cessent d'être jetés
Prêt pour production   non — 2 besoins backend en P1 (voir §7)
```

---

## 1. Écrans intégrés

| # | Maquette | Écran Flutter | Nature |
|---|---|---|---|
| 1 | `onboarding_welcome` | `screens/onboarding_screen.dart` (page 1) | **création** |
| 2 | `onboarding_tracking_highlight` | idem (page 2) | **création** |
| 3 | `onboarding_authentication_options` | idem (page 3) | **création**, amputée |
| 4 | `onboarding_create_account` | `screens/auth_screen.dart` | refonte |
| 5 | `profile` | `screens/client/profile_screen.dart` | déjà repris (lot 1) |
| 6 | `rewards` | `screens/client/rewards_screen.dart` | refonte |
| 7 | `notifications` | `screens/client/notifications_screen.dart` | complétée |
| 8 | `order_details` | `screens/client/order_details_screen.dart` | refonte |
| 9 | `delivery_tracking` | `screens/client/delivery_tracking_screen.dart` | refonte de la présentation |
| 10 | `chat_with_driver` | `screens/client/chat_screen.dart` | refonte |
| 11 | `voice_call` | `screens/client/call_screen.dart` | refonte |
| 12 | `rate_your_meal` | `screens/client/order_rating_screen.dart` | refonte |
| 13 | `rate_delivery` | `screens/client/driver_rating_screen.dart` | refonte |
| 14 | `help_center` | `screens/client/support_screen.dart` | refonte |

### Aucun écran non intégré

Les 14 maquettes sont portées. Six comportent un élément **non repris**, chacun
pour une raison de contrat, détaillée au §6.

---

## 2. Fonctionnalités nouvelles

| Fonctionnalité | Écran |
|---|---|
| Présentation d'ouverture en trois pages, au premier lancement seulement | onboarding |
| Reprise de l'onboarding après réinstallation, drapeau local à l'appareil | `OnboardingService` |
| Œil d'affichage du mot de passe | authentification |
| Catalogue de récompenses avec échange réel et relevé de points | récompenses |
| Progression vers le palier suivant, mesurée **entre deux seuils** | récompenses, profil |
| Chronologie de commande à quatre jalons, horodatée par le serveur | détail de commande, suivi |
| Relecture de la commande à l'ouverture et au tirage vers le bas | détail de commande |
| Options retenues affichées sur chaque ligne (« sans oignons ») | détail de commande |
| Référence lisible de commande (« EC-4921 ») | détail de commande |
| Véhicule et plaque du livreur, quand le suivi les porte | suivi |
| Puces d'appréciation, transmises dans un champ réel | notations |
| Notation par plat **et** de la livraison sur un même écran | notation de commande |
| Sujets d'aide qui pré-classent la demande de support | centre d'aide |
| FAQ en accordéon | centre d'aide |
| Groupement des notifications par journée civile | notifications |

---

## 3. Fonctionnalités conservées

Aucune n'a été retirée. Vérifié écran par écran : authentification (connexion,
inscription, session restaurée, mode invité, jeton FCM), catalogue,
personnalisation, panier, promotions, règlement, **PayDunya**, commande
groupée, partage d'addition, suivi temps réel (WebSocket + Google Maps),
**Agora** (appels), conversation livreur, notifications Firebase, fidélité,
support (tickets, réclamations, retours), adresses, mode hors ligne.

Intacts : backend, base de données, contrat d'API, Firebase, Google Maps,
Agora, nom du paquet (`elcora_fast`), identifiant Android
(`com.elcorazon.fast`), titre (`El corazon`), assets de marque.

**Aucun rebranding. Aucune occurrence de « Miadounou »** — vérifié sur `lib/`,
`android/`, `ios/`, `web/`, `pubspec.yaml`, `docs/`.

---

## 4. API réellement utilisées

Toutes existaient. Aucune n'a été inventée.

```
POST /auth/login/ · /auth/register/ · /auth/logout/
PATCH /auth/me/                          ← profil, enfin appelé (ISSUE-008)
GET  /accounts/me/
GET  /orders/ · GET /orders/{id}/        ← relecture du détail
GET  /tracking/orders/{id}/              + ws/orders/{id}/tracking/
     ws/orders/{id}/chat/
GET  /loyalty/account/ · /loyalty/rewards/ · /loyalty/entries/
POST /loyalty/rewards/{id}/redeem/
POST /catalog/reviews/                   ← avec `title`, enfin rempli
POST /delivery/orders/{id}/rating/
GET/POST /support/tickets/
GET  /notifications/ · POST /notifications/read-all/
```

---

## 5. Bugs rencontrés et corrigés

### Données que le code jetait

| Défaut | Portée |
|---|---|
| `statusEvents` (chronologie horodatée) jeté par l'adaptateur de commande | détail, suivi |
| `options` de chaque ligne (« bien cuit ») jetées par le même adaptateur | détail, notation |
| `reference` jetée : l'écran affichait 8 caractères d'UUID | détail |
| `title` d'avis envoyé vide à chaque dépôt | avis produits |

### Écrans qui mentaient

| Défaut | Portée |
|---|---|
| Le détail de commande ne relisait jamais son statut : figé au chargement de la liste | détail |
| La modification du profil annonçait un succès **sans rien envoyer** | profil |
| Deux numéros de support **inventés**, ivoiriens, écrits en dur | suivi, contact invité |
| Le pays par défaut des téléphones : Togo à l'inscription, Côte d'Ivoire au profil | inscription, profil |
| « Le cœur de la cuisine d'Abidjan » pour une cuisine de **Lomé** | accueil invité |
| Statut de ticket affiché brut : « IN_PROGRESS » | support |
| « Il y a 0 jours » le jour même | support |
| Le fil de conversation disait « Aucun message » sans dire qu'il n'est pas conservé | conversation |
| Le champ de message se vidait **avant** l'accusé du canal : texte perdu si l'envoi échouait | conversation |
| Boutons message et appel actifs sans livreur, répondant « aucun livreur assigné » | suivi |
| « Bientôt disponible » sur le bouton image — note de développement en production | conversation |

### Mises en page qui cassaient

| Défaut | Portée |
|---|---|
| `RatingStars` mettait la **cinquième étoile hors de l'écran** à l'échelle ×1,3 sur 320 px — on ne pouvait pas mettre 5/5 | notations |
| Une puce d'appréciation trop longue sortait de l'écran (`Wrap` ne borne pas ses enfants) | notations |
| Vitesse moyenne affichée « 0,0 km/h » pour un livreur à l'arrêt | suivi |
| Tracé d'historique en bleu Material, invisible sur une carte routière bleue | suivi |
| Une note de livreur absente affichée « 0,0 ★ » plutôt que « Nouveau » | suivi |

### Sécurité et cohérence

* `refunded` et `failed` classés « en cours » : une commande échouée restait en
  tête de liste indéfiniment (lot 1, rappelé ici car le repliement des statuts
  est maintenant partagé) ;
* le repliement des dix statuts serveur sur quatre jalons est vérifié par deux
  invariants sur **tous** les statuts : exactement un jalon courant, et aucun
  jalon franchi après un jalon qui ne l'est pas. Un statut ajouté sans être
  classé fera échouer la compilation ou les tests.

---

## 6. Ce qui n'a pas été repris des maquettes

| Maquette | Élément | Motif | Réf. |
|---|---|---|---|
| `onboarding_authentication_options` | « Continue with Google », « Continue with Apple » | Aucune route OAuth. Un bouton qui ouvre un formulaire e-mail ment sur ce qui va se passer | BR-001 |
| `rate_delivery` | Pourboire 500 / 1 000 / 2 000 F | Aucune route n'encaisse de gratification. Le client croirait avoir donné, le livreur ne recevrait rien | BR-002 |
| `notifications` | « Mute Notifications » | Aucun réglage serveur. Un interrupteur local n'arrête pas les pushs FCM — il ferait croire au silence | BR-003 |
| `chat_with_driver` | Fil garni à l'ouverture, double coche « lu » | Le serveur ne persiste pas la conversation (ADR-008) | BR-004 |
| `profile` | « Payment Methods » | PayDunya ouvre une session par commande ; aucun instrument enregistré, rien à lister | BR-005 |
| `rewards` | Paliers « Gold », « Platinum (3000 pts) » | Ne correspondent à aucun seuil en place. Les afficher promettrait ce que le serveur ne connaît pas | BR-006 |
| `profile`, `rewards` | Icône de tiroir | L'application n'a pas de tiroir ; en ajouter un doublerait la barre inférieure | — |
| `profile`, `rewards` | Barre inférieure **Rewards** en 3ᵉ position | L'application a **Commandes**. La maquette `help_center` du même lot montre pourtant *Orders* — Stitch n'est pas cohérent avec lui-même ; les commandes sont le cœur d'une application de livraison | — |
| `delivery_tracking` | « Yamaha NMAX • ABJ-742 » | Affiché **si** le suivi le porte, omis sinon | — |
| toutes | Copie « Abidjan » | L'établissement est à **Lomé** (`AppConstants`) | — |

---

## 7. Besoins backend

Treize, détaillés dans `STITCH_BACKEND_REQUIREMENTS.md` au format demandé
(endpoint, méthode, payload, réponse, authentification, temps réel, priorité).

**Les deux P1 bloquent la mise en production :**

* **BR-004 — persistance de la conversation livreur.** Sans elle, le chat ne
  fonctionne que si les deux parties regardent leur écran en même temps. Un
  client qui écrit « laissez au portail » pendant que le livreur roule ne sera
  jamais lu.
* **BR-013 — documents légaux publiés.** Politique de confidentialité et CGU
  sont exigées par Google Play et l'App Store, et les écrans d'onboarding les
  référencent.

P2 : BR-001 (Google/Apple), BR-002 (pourboire), BR-003 (réglages de
notification), BR-006 (paliers serveur), BR-010 (offres promotionnelles),
BR-011 (dépôt de fichier).
P3 : BR-005, BR-007, BR-008, BR-009, BR-012.

---

## 8. Ce qui reste

1. **Neuf écrans hors maquette** gardent l'ancienne charte : carnet d'adresses
   (4 écrans), recherche avancée, historique enrichi, fil et groupes sociaux,
   contact invité. Le carnet d'adresses d'abord — c'est le seul du lot qui se
   trouve sur le chemin d'une commande.

2. **`tools/code_mort.py` échoue sur `presentation/commande.dart`** (138
   lignes, atteint par aucun `main.dart`). Vérifié sur une extraction du
   commit `15ebe32` : **la situation est antérieure à cette phase**, à
   l'identique. Le fichier porte le vocabulaire *juste* — les huit statuts que
   le serveur émet — pendant que les écrans lisent `models/order.dart`, qui en
   déclare dix dont deux inexistants. Résoudre demande de consolider les deux
   vocabulaires : un travail de modèle, pas d'interface. Consigné plutôt que
   réglé à la hâte, et surtout plutôt que masqué par un import de complaisance
   qui priverait l'outil de son objet.

3. **`AppConstants.supportPhone` est vide** et doit être renseigné avant mise
   en production. Tant qu'il l'est, les écrans proposent le support écrit —
   réel — au lieu d'un numéro.

4. **Validation visuelle sur appareil.** L'analyse, les 283 tests et la
   compilation web passent ; les captures maquette contre rendu demandent un
   émulateur ou un téléphone, et n'ont pas été prises.

---

## 9. Journal des commits

```
3295111  docs(ui): audit the second Stitch batch before touching code
1141d2c  feat(onboarding): add the welcome sequence, minus what the server cannot back
5704af5  feat(auth): redesign sign-in and sign-up on the light surface
30e6f1b  feat(rewards): rebuild the loyalty screen on the data the server already serves
b85e913  feat(orders): redesign order details, and stop discarding what the server sends
0f2e7f3  fix(config): one country for the whole app — Lomé, not Abidjan
a99b02b  feat(tracking): redesign delivery tracking on the real-time data already flowing
7f96b55  feat(chat,call): redesign the two ways of reaching the courier
44ca0f0  feat(reviews): redesign both rating screens, and send what they collect
b8ab628  feat(support,notifications): a help centre that classifies, and days that read
0753d1d  style(test): drop a redundant argument the linter flags
9c5756e  test(ui): hold the second batch layouts, and fix what they caught
```

---

## 10. Une note de méthode

Le fait le plus utile de cette phase est apparu à l'audit :
**`DESIGN.md` des deux archives est identique octet pour octet.** Il n'y avait
donc pas de système de design à refaire — la palette, la typographie, les
espacements et les composants du premier lot s'appliquaient tels quels. Ce lot
a été exclusivement un travail d'écrans, et les quatorze ont pu réutiliser
quinze briques existantes plutôt que d'en inventer.

Le second fait utile est que **le serveur en savait plus que les écrans n'en
montraient**. Fidélité, chronologie de commande, options retenues, position du
livreur, note du livreur, tickets de support : tout était servi, et souvent
jeté par un adaptateur ou ignoré par un écran. Une bonne part de ce rapport ne
décrit pas des fonctions ajoutées mais des données **cessant d'être perdues**.
