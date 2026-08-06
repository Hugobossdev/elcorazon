# Plan de refactoring — El Corazón, août 2026

**Établi le 6 août 2026**, sur la base d'une analyse complète du dépôt : backend Django,
socle partagé `elcorazon_core`, trois applications Flutter, outillage, CI, déploiement,
documentation.

Ce document ne remplace pas [`docs/architecture/04-migration-flutter.md`](architecture/04-migration-flutter.md),
qui décrit la migration fonctionnelle vers le backend v2 et reste la référence sur *ce qui
doit être branché*. Il traite d'autre chose : **la dette laissée derrière cette migration**
— ce qui n'a pas été supprimé, ce qui a été dupliqué, et ce que l'outillage ne voit pas.

> ### État d'avancement — 6 août 2026
>
> **Lots 0 et 1 faits.** Le diagnostic ci-dessous décrit l'état du dépôt **avant**
> ces deux lots ; il est conservé tel quel, c'est lui qui justifie la suite.
>
> | Lot | État | Commit |
> |---|---|---|
> | 0 — correctifs + garde-fou | ✅ | `fd4ffb4` |
> | 1.1 — fichiers injoignables | ✅ | `39a057e` |
> | 1.2 — services zombies | ✅ | `847958c` |
> | 1.3 — résidus + CI | ✅ | `945a25d` |
> | 2 — socle unifié | à faire | |
> | 3 — pile héritée | à faire | |
> | 4 — écrans géants | à faire | |
> | 5 — outillage | à faire | |
> | 6 — documentation | à faire | |
>
> **Résultat mesuré** : les applications passent de 135 050 à **99 573 lignes**
> (−35 477, soit −26 %) et de 385 à **259 fichiers**. `flutter analyze` rend le
> même nombre de diagnostics qu'avant (0, 1, 9, 46), `flutter test` reste vert
> (265 tests), `flutter build web` aboutit sur les trois applications.
>
> Deux constats du diagnostic sont désormais **périmés et corrigés** : le §2.7
> (`beat` en panne permanente, `Sink` non fermés) et le §2.2 (code mort), ce
> dernier étant maintenant tenu par un job CI bloquant. Le §2.3 reste vrai et
> reste la raison d'être de ce job.
>
> Deux enseignements pour les lots suivants :
>
> - **`flutter analyze` ne suffit pas à valider une suppression.** `admin` a
>   compilé faux après le retrait de dépendances, sur un
>   `web_plugin_registrant.dart` généré que `flutter pub get` ne régénère pas.
>   Il faut `flutter clean` puis `flutter build`.
> - **Supprimer fait tomber d'autres fichiers.** Retirer `cart_service.dart` de
>   `dely` a rendu `models/cart_item.dart` injoignable à son tour. Le garde-fou
>   l'a signalé ; boucler jusqu'à point fixe.

---

## 1. Ligne de base vérifiée

Tout ce qui suit a été exécuté le 6 août 2026, pas déduit.

| Composant | Volume | Tests | Analyse statique |
|---|---|---|---|
| `backend/` | 29 676 l. | **1276 passés** (8 min 50) | ruff + mypy strict, plancher couverture 92 % |
| `packages/elcorazon_core` | 7 940 l. | **152 passés** | `flutter analyze` : **0 problème** |
| `El Corazon admin` | 49 048 l. | 42 passés | 1 info |
| `El Corazon fastfood` | 60 539 l. | 62 passés | 11 infos |
| `El corazon dely` | 25 463 l. | 9 passés | 49 infos |

**Zéro erreur, zéro avertissement, tout est vert.** C'est un vrai acquis, et il faut le dire
avant de critiquer quoi que ce soit : le backend et le socle partagé sont d'un niveau de
rigueur inhabituel (tests d'architecture, liste auditable des routes publiques, ADR tenus à
jour, commentaires qui expliquent les décisions plutôt que le code).

Le problème n'est pas la qualité de ce qui a été écrit. C'est le volume de ce qui n'a pas
été enlevé.

### Le déséquilibre en une ligne

```
backend            29 676 l. de code  ←→  19 576 l. de test   (0,66)
elcorazon_core      7 940 l. de code  ←→   4 161 l. de test   (0,52)
les 3 apps        135 050 l. de code  ←→   1 922 l. de test   (0,014)
```

Les applications pèsent **78 % du code du projet et 7 % de ses tests.**

---

## 2. Diagnostic

### 2.1 Deux piles clientes coexistent — c'est le constat central

La migration a construit une pile propre sans démonter l'ancienne. Les deux tournent
aujourd'hui côte à côte dans les trois applications :

| | Pile cible | Pile héritée |
|---|---|---|
| Modèles | `eccore.User`, `Order`… typés, contrat serveur | `models/user.dart` de forme Supabase |
| Accès données | `OrderRepository` (socle, testé) | `*_service.dart` singletons |
| État | Riverpod | `ChangeNotifier` + singletons globaux |
| Tests | 152 | ~0 |

Elles sont raccordées par une couche d'adaptation : **19 points de traduction**
(`_fromDjangoUser`, `django_order_mapper.dart`, les 8 `django_*_repository.dart` de
`fastfood`…). Le pivot est `AppService`, un singleton `ChangeNotifier` importé par
**27 fichiers** dans `fastfood`, qui agrège 13 autres services, écoute le conteneur Riverpod
et retraduit les modèles du socle vers les modèles hérités.

Le code le dit lui-même :

```dart
// Alias explicite : `eccore.User` (backend Django) et le `User` local
// (Supabase, ci-dessous) portent le même nom mais pas la même forme
```

Conséquence mesurable : sur 96 écrans, **62 dépendent encore des modèles locaux** et 17
seulement du socle.

| App | Écrans | Sur le socle | Sur les modèles locaux |
|---|---|---|---|
| admin | 39 | 3 | 23 |
| fastfood | 42 | 13 | 27 |
| dely | 15 | 1 | 12 |

### 2.2 Un quart du code Flutter ne s'exécute jamais

Deux catégories, mesurées par parcours du graphe d'imports depuis `main()`.

**(a) Injoignable — 29 645 lignes**, soit 22 % du code des applications.

| App | Fichiers morts | Lignes mortes | Part |
|---|---|---|---|
| admin | 53 / 129 | 13 586 | 27,7 % |
| fastfood | 42 / 183 | 12 412 | 20,5 % |
| dely | 13 / 73 | 3 647 | 14,3 % |

**(b) Enregistré mais consommé par personne — ~4 900 lignes.** `main.dart` de `dely`
instancie 23 `ChangeNotifierProvider` au démarrage. Onze de ces services ne sont importés
que par `main.dart` — aucun écran ne les lit :

```
advanced_gamification_service   694 l.      ai_recommendation_service   463 l.
offline_sync_service            577 l.      voice_command_service       397 l.
group_delivery_service          546 l.      wallet_service              390 l.
social_features_service         488 l.      ar_service                  288 l.
ai_service                      283 l.      cart_service                218 l.
voice_service                   186 l.                          total 4 530 l.
```

Une application de livreur qui construit au démarrage un service de réalité augmentée, un
panier et un portefeuille. `fastfood` a le même travers en plus petit (`form_manager_service`,
`complaints_returns_service` : 400 l.).

**Total : ~34 500 lignes, soit 25 % du code des applications.**

### 2.3 Le vert de l'analyseur ne couvre pas le code mort

`lib/dialogs/menu_item_dialog.dart` de `dely` (361 l.) importe :

```dart
import '../../models/menu_item.dart';       // → <racine app>/models/  n'existe pas
import '../../services/cart_service.dart';  // → <racine app>/services/ n'existe pas
import '../../widgets/custom_button.dart';  // → <racine app>/widgets/  n'existe pas
```

Les trois cibles vivent sous `lib/`, pas deux niveaux au-dessus. **Ces imports ne peuvent
pas se résoudre — et ni `flutter analyze` ni `dart analyze` ne signalent quoi que ce soit**
sur ce fichier (vérifié, y compris `--format=machine` sur le fichier seul : zéro
diagnostic).

Le fait à en retenir : aucun des fichiers injoignables n'apparaît dans les 61 diagnostics
des trois applications. La ligne de base « 0 erreur, 0 avertissement » du §1 vaut pour le
code vivant. Les 29 600 lignes injoignables ne sont vérifiées par rien, et elles pourrissent
— cet import cassé le prouve.

C'est ce qui rend le lot de suppression prioritaire plutôt que cosmétique : on ne peut pas
faire confiance à ce qu'on ne mesure pas.

### 2.4 Duplication entre applications

Le socle partagé existe et fonctionne, mais la couche présentation a été copiée-collée avant
lui, et les copies sont restées.

**Widgets triplés** (variantes dérivées, toutes mortes ou presque) :

| Fichier | admin | fastfood | dely |
|---|---|---|---|
| `order_card.dart` | 301 | 231 | 272 |
| `cart_item_card.dart` | 389 | 341 | 359 |
| `category_chip.dart` | 227 | 189 | 199 |
| `el_corazon_logo.dart` | 233 | 268 | 381 |
| `promotion_banner.dart` | 402 | — | 374 |
| `real_time_order_tracker.dart` | — | 393 | 400 |
| `menu_item_dialog.dart` | — | 361 | 361 |

**Modèles triplés** alors que le socle porte déjà l'entité : `order.dart` (856 + 433 + 411 =
1 700 l.), `user.dart`, `cart_item.dart` en trois exemplaires ; `driver.dart`,
`driver_rating.dart`, `driver_badge.dart`, `address.dart`, `menu_item.dart`,
`promo_code.dart`, `notification_model.dart` en deux.

Deux fichiers sont encore **strictement identiques** au bit près : `voice_service.dart`
(admin/dely) et `price_formatter.dart` (fastfood/dely).

### 2.5 Écrans démesurés

| Fichier | Lignes |
|---|---|
| `admin/…/advanced_order_management_screen.dart` | 3 070 |
| `fastfood/…/cake_order_screen.dart` | 2 886 |
| `admin/…/order_management_screen.dart` | 2 531 |
| `admin/…/gamification_management_screen.dart` | 1 744 |
| `fastfood/…/delivery_tracking_screen.dart` | 1 589 |

Le premier tient en **une classe d'état** de 3 000 lignes : 25 méthodes `_build*`, 11
`setState`. Rien n'y est testable isolément. À l'échelle des trois apps : 476 `setState`,
108 `StatefulWidget`, 83 fichiers à singleton.

Point à porter au crédit du code : **aucun écran n'appelle le réseau directement** (0 usage
de `http.`/`Dio(`/`apiClient.` sous `screens/`). La frontière écran ↔ données est tenue.
C'est ce qui rend la découpe faisable.

### 2.6 Documentation qui décrit du code supprimé

13 fichiers `README_*.md` (~4 200 l.) vivent **dans** `fastfood/lib/services/`. Plusieurs
documentent du code mort : `README_RIVERPOD.md` décrit `cart_providers.dart` et
`menu_providers.dart` (morts), `README_DATA_VALIDATION.md` décrit `data_validator_service.dart`
(mort), `README_VISUAL_FEEDBACK.md` décrit `visual_feedback_service.dart` (mort),
`README_REPOSITORY_PATTERN.md` décrit `menu_service.dart` (mort).

À la racine, `CAHIER_DES_CHARGES.md` (928 l.) et `ETAT_FONCTIONNALITES.md` (755 l.) portent
déjà leur propre avertissement : *« Le corps de ce document a été écrit en décembre 2024,
quand les trois applications parlaient directement à Supabase. »* Un document qui s'ouvre en
prévenant qu'il est faux a cessé d'être une documentation.

### 2.7 Deux vrais défauts, petits et réels

**(a) `beat` sera perpétuellement *unhealthy* en production.** Le `Dockerfile` grave un
`HEALTHCHECK` HTTP dans l'image partagée :

```dockerfile
HEALTHCHECK … CMD curl -fsS http://localhost:8000/health/ || exit 1
```

`worker` le remplace bien dans `docker-compose.prod.yml` (`celery inspect ping`). **`beat`,
non** — il hérite du contrôle HTTP alors qu'il ne sert aucun HTTP. Constaté en local :
`elcorazon-worker-1` et `elcorazon-beat-1` sont `unhealthy` avec une série de **908 échecs**,
pendant que les tâches passent normalement dans les journaux. Avec `restart: unless-stopped`
et un orchestrateur qui agit sur la santé, c'est une boucle de redémarrage sur un service
qui va très bien.

**(b) Deux `Sink` non fermés** dans `fastfood/lib/services/chat_service.dart:52` et `:55`
(`close_sinks`) — fuite de `StreamController`.

### 2.8 Résidus de l'arborescence

- **`El/ Corazon/ dely/build/…`** — arborescence créée par une commande shell où
  `El Corazon dely` n'était pas entre guillemets. Contient des artefacts de compilation.
  Non suivie par git, mais elle pollue le répertoire de travail.
- **Nommage incohérent** : `El Corazon admin`, `El Corazon fastfood`, `El corazon dely`
  (minuscule). C'est ce genre d'écart, avec les espaces, qui produit le point précédent.
- **12 fichiers SQL Supabase** pour un backend abandonné : `supabase/migrations/` (2),
  `El corazon dely/supabase/migrations/` (4), `El Corazon admin/lib/database/*.sql` (6 —
  du SQL *dans* `lib/` d'une app Flutter).
- **Dépendances jamais importées** : `pdf`, `file_picker` (admin) ; `badges`, `jwt_decoder`,
  `package_info_plus`, `freezed_annotation`, `json_annotation` (fastfood) ; `image_picker`
  (dely). Les deux dernières de `fastfood` signalent une génération de code commencée puis
  abandonnée — sans `build_runner`, elles ne servent à rien.
- **1 009 `debugPrint`**. Contrairement à `print`, `debugPrint` **s'exécute en production** :
  à vérifier au cas par cas pour ce qui touche aux jetons, adresses et identifiants.

---

## 3. Principe directeur

**Supprimer avant de restructurer.** Chaque lot suivant coûte proportionnellement au volume
de code encore présent. Retirer 34 500 lignes d'abord rend tout le reste moins cher, et c'est
l'opération la moins risquée du plan : ce qui n'est atteint par aucun chemin d'exécution ne
peut rien casser en partant.

**Ne pas réécrire ce qui marche.** Le backend et `elcorazon_core` ne sont pas concernés par
ce plan, hors le correctif §2.7. Le chantier est la présentation Flutter.

**Une seule pile à l'arrivée.** L'objectif n'est pas d'améliorer la pile héritée : c'est de
la supprimer, domaine par domaine, en la remplaçant par le socle qui existe déjà.

---

## 4. Les lots

Ordre imposé par les dépendances : les lots 1 et 2 réduisent la surface des lots 3 et 4.

### Lot 0 — Correctifs et filet (½ journée)

Petit, immédiat, sans dépendance.

1. `docker-compose.prod.yml` : donner à `beat` son propre `healthcheck`
   (`celery -A config inspect ping` ne convient pas à un ordonnanceur — viser la fraîcheur du
   fichier d'échéancier, ou `CMD-SHELL true` avec un commentaire assumant l'absence de
   sonde). Idem dans `docker-compose.yml` pour ne pas laisser `worker`/`beat` en
   `unhealthy` permanent en développement.
2. Fermer les deux `Sink` de `chat_service.dart`.
3. Ajouter à la CI un garde-fou de code mort : le script de parcours du graphe d'imports
   utilisé pour ce rapport, en échec si un fichier de `lib/` devient injoignable depuis
   `main()`. **C'est la marche à ne pas rater** — sans elle, la dette supprimée au lot 1
   revient en trois mois.

*Sortie* : `beat` sain, CI qui refuse tout nouveau fichier orphelin.

### Lot 1 — Suppression (2 à 3 jours)

Le plus gros gain pour le plus faible risque.

1. Les **29 645 lignes injoignables** (les listes complètes sont reproductibles par le script
   du lot 0).
2. Les **11 services zombies de `dely`** + les 2 de `fastfood` (~4 900 l.), et les
   `ChangeNotifierProvider` correspondants dans `main.dart` — ce qui allège aussi le
   démarrage.
3. Les **12 fichiers SQL Supabase** et `El Corazon admin/lib/database/`.
4. L'arborescence parasite `El/`.
5. Les **8 dépendances jamais importées**.
6. Les `README_*.md` qui documentent du code supprimé, retirés avec lui.

*Vérification à chaque étape* : `flutter analyze` **puis `flutter build`** (l'analyse seule
ne suffit pas — §2.3), puis `flutter test`. Un commit par catégorie, pour que la révocation
reste chirurgicale.

*Sortie* : ~34 500 lignes en moins, apps à ~100 000 lignes, aucun test rouge.

### Lot 2 — Unifier le socle (3 à 4 jours)

Maintenant que les copies mortes sont parties, traiter les vivantes.

1. Remonter dans `elcorazon_core` les widgets réellement partagés qui survivent au lot 1
   (`order_card`, `cart_item_card`, `category_chip`, `el_corazon_logo`…), en une
   implémentation paramétrée — pas trois.
2. Supprimer les modèles locaux dont le socle porte déjà l'entité, en commençant par
   `order.dart` (1 700 l. en trois exemplaires).
3. `price_formatter.dart` et `voice_service.dart`, identiques au bit près, deviennent un seul
   fichier.

*Attention* : ne remonter dans le socle que ce qui est **utilisé par au moins deux apps**.
Un widget partagé par une seule app est une abstraction spéculative — exactement le travers
que ce plan combat.

*Sortie* : la duplication inter-apps est terminée ; `elcorazon_core` reste à 0 problème
d'analyse et gagne les tests des widgets remontés.

### Lot 3 — Démonter la pile héritée (le gros œuvre — 3 à 4 semaines)

C'est le lot qui change l'architecture. Il se fait **domaine par domaine**, jamais d'un bloc,
et chaque domaine se termine avant que le suivant ne commence.

Pour un domaine (commandes, catalogue, panier, adresses…) :

1. Les écrans passent du modèle local au modèle du socle.
2. L'adaptateur correspondant (`django_*_repository.dart`, entrée de `django_order_mapper`)
   disparaît — il n'existait que pour traduire.
3. Le service hérité du domaine disparaît.
4. L'état passe en Riverpod, cohérent avec le socle.
5. **Un test par domaine migré**, au minimum sur la logique déplacée.

Ordre suggéré, du plus contraint au moins risqué : `dely` (15 écrans, 1 seul sur le socle,
le plus petit périmètre) → `admin` → `fastfood` (le plus gros, mais le plus déjà migré :
13 écrans sur le socle).

`AppService` se vide au fil des domaines. **Il se supprime en dernier, jamais en premier** :
c'est lui qui tient l'application debout tant qu'un seul domaine hérité subsiste.

*Sortie* : plus aucun `models/` local redondant, plus aucun `django_*_repository`, plus de
`AppService`, une seule pile.

### Lot 4 — Découper les écrans (2 semaines, parallélisable avec le lot 3)

Cibler les 5 écrans de plus de 1 500 lignes, dans l'ordre du tableau §2.5. Pour chacun :
extraire les sous-vues en widgets nommés, sortir la logique dans un provider Riverpod,
écrire le test sur cette logique.

Le critère n'est pas un nombre de lignes mais celui-ci : **le comportement métier de l'écran
est-il atteignable par un test sans monter l'arbre de widgets ?** Tant que la réponse est
non, la découpe n'est pas finie.

### Lot 5 — Durcir l'outillage (1 jour, après le lot 1)

1. Aligner les trois `analysis_options.yaml` : `dely` n'active **aucune** règle propre
   aujourd'hui (`linter: rules:` vide, d'où ses 49 infos contre 1 pour `admin`). Reprendre le
   jeu de `fastfood`, le plus complet.
2. Retirer `--no-fatal-infos` de la CI Flutter. Le commentaire du workflow le justifie par
   une dette de style « sur des écrans que la migration n'a pas encore touchés » ; après les
   lots 1 et 5.1, il ne reste qu'une poignée d'infos. **Cette justification est déjà
   périmée** : 61 infos au total, dont 49 concentrées sur `dely`.
3. Traiter les 1 009 `debugPrint` : un journaliseur qui se tait en production, et vérifier au
   passage qu'aucun ne rend un jeton ou une adresse.
4. Poser un plancher de couverture sur les apps, à la manière du backend — bas au départ
   (le code testable n'existe qu'après le lot 3), relevé à chaque domaine migré.

### Lot 6 — Documentation (2 jours, en dernier)

À faire **après** le lot 3, pas avant : documenter une architecture en cours de démontage,
c'est écrire le prochain document périmé.

1. Trancher sur `CAHIER_DES_CHARGES.md` et `ETAT_FONCTIONNALITES.md` — l'arbitrage est déjà
   posé, non tranché, dans `04-migration-flutter.md` §3.5 : archiver comme référence
   historique (l'historique git les conserve) ou réécrire pour la v2. **Archiver** est le
   choix cohérent avec ce qui a été fait du backend Laravel.
2. Sortir de `lib/services/` les `README_*.md` survivants : la documentation d'une
   architecture ne vit pas dans un répertoire de code source.
3. Renommer `El corazon dely` → `El Corazon dely`, et envisager de retirer les espaces des
   trois répertoires (cause directe du §2.8). À faire en une opération isolée : cela touche
   les trois workflows CI.

---

## 5. Ce que je ne recommande pas

- **Toucher au backend.** 1276 tests, mypy strict, tests d'architecture, ADR tenus. Hors le
  correctif `beat`, il n'y a rien à y refactorer — et le temps qu'on y passerait manque
  ailleurs.
- **Réécrire les applications de zéro.** Elles fonctionnent, elles sont vertes, et 75 % du
  code restant après le lot 1 est du code vivant qui rend un service.
- **Remonter davantage dans `elcorazon_core` que le strictement partagé.** La couche
  présentation *doit* rester propre à chaque app — écrans client, livreur et back-office
  n'ont rien en commun. `04-migration-flutter.md` §2.2 le pose déjà ainsi.
- **Introduire une nouvelle bibliothèque d'état.** Riverpod est là, il est dans le socle, il
  est testé. Le problème n'est pas le choix de l'outil, c'est qu'il coexiste avec deux autres.

---

## 6. Risques

| Risque | Portée | Parade |
|---|---|---|
| Supprimer du code atteint par réflexion / chaîne de caractères | Lot 1 | Le graphe d'imports ne voit pas la réflexion. `flutter build` en plus de `analyze` (§2.3), un commit par catégorie |
| Régression fonctionnelle invisible, faute de tests | Lot 3 | 113 tests pour 135 000 lignes : le filet **n'existe pas**. Écrire le test *avant* de migrer le domaine, pas après |
| Le lot 3 s'étale et les deux piles coexistent un an de plus | Lot 3 | Un domaine se termine avant que le suivant commence. Un domaine à moitié migré est pire que pas migré |
| La dette revient | Tous | Le garde-fou du lot 0. Sans lui, ce document sera à réécrire en 2027 |

---

## 7. Ordre d'exécution

```
Lot 0  ▓                                        ½ j   correctifs + garde-fou CI
Lot 1  ▓▓▓                                      3 j   suppression       −34 500 l.
Lot 2  ▓▓▓▓                                     4 j   socle unifié
Lot 5  ▓                                        1 j   outillage
Lot 3  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓          3-4 sem  pile héritée démontée
Lot 4          ▓▓▓▓▓▓▓▓▓▓▓▓▓▓                   2 sem  écrans découpés (en parallèle)
Lot 6                                    ▓▓     2 j   documentation
```

**Environ 7 semaines**, dont la première rend déjà 25 % du code des applications. Les lots 0
à 2 et 5 sont sans risque fonctionnel et peuvent être engagés immédiatement ; le lot 3 est le
seul qui demande un arbitrage de calendrier.
