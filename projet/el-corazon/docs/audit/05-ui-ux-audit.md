# 05 — Audit UI / UX

Périmètre : `apps/fastfood` (client, 49 802 l.), `apps/dely` (livreur,
19 424 l.), `apps/admin` (back-office, 41 711 l.), `packages/elcorazon_core`
(socle, 14 960 l.).

**Le constat n'est pas « les écrans sont mauvais ».** Ils sont majoritairement
complets, avec leurs états de chargement, de vide et d'erreur. Le défaut est
ailleurs : **les trois applications ne partagent pas d'identité visuelle**, et
la fonctionnalité la plus importante du produit est la plus difficile à
atteindre.

---

## 1. Le poste de cuisine n'est pas dans la navigation

**C'est le défaut d'ergonomie le plus coûteux du produit.**

Le KDS a été construit (`42f24b0`) précisément parce que le personnel de cuisine
faisait avancer les commandes depuis `advanced_order_management_screen.dart` —
1 779 lignes d'écran d'administration, ses filtres, ses exports, ses
statistiques. Le commit le dit : « On y pilote une flotte ; on n'y tient pas un
coup de feu. »

L'écran a été livré. La porte n'a pas suivi.

La navigation du back-office
(`apps/admin/lib/screens/admin/admin_navigation_screen.dart:102-248`) compte
sept sections :

```
VUE D'ENSEMBLE · OPÉRATIONS · CATALOGUE · UTILISATEURS
MARKETING · RÉSEAU · SYSTÈME
```

**Aucune n'est « Cuisine ».** Le seul accès à `KitchenScreen` est un bouton
`FilledButton.tonalIcon` posé dans la barre d'outils de
`advanced_order_management_screen.dart:1769` — c'est-à-dire **à l'intérieur de
l'écran même qu'il était censé remplacer**.

Le cuisinier doit donc ouvrir l'écran de supervision de flotte, y trouver un
bouton, et pousser un troisième écran pour atteindre son poste de travail. Sur
une tablette de cuisine, en plein service.

**Correctif : une entrée de premier niveau.** C'est une trentaine de lignes dans
la navigation, et le gain est disproportionné par rapport au coût. À faire au
lot 0.

---

## 2. La marque n'a pas la même couleur selon l'application

Fait vérifié, pas une impression :

| Application | Couleur primaire | Fichier |
|---|---|---|
| Client | `#B51822` | `apps/fastfood/lib/theme.dart:29` |
| Livreur | `#E53E3E` | `apps/dely/lib/theme.dart:7` |
| Back-office | `#E53E3E` | `apps/admin/lib/theme/modern_theme.dart:11` |

Deux rouges différents pour une même enseigne. Le client — celui que voit le
public — est le seul à porter le `#B51822`.

L'intersection des couleurs déclarées entre l'application client et le
back-office est de **une seule couleur** sur 62 et 29 déclarations distinctes.

Ce n'est pas qu'un défaut esthétique : un livreur qui bascule entre son
application et un écran de suivi client voit deux produits, et une capture
d'écran de support ne permet pas de dire de quelle application elle vient.

### Le socle partagé ne partage pas le design

`packages/elcorazon_core/lib/src/design/` ne contient **que** `emojis` — le
travail de `be95377` et `40c4427`, qui est réel et abouti. Tout le reste des
jetons visuels est réécrit par application :

| Fichier | Lignes |
|---|---|
| `apps/fastfood/lib/theme.dart` | 814 |
| `apps/fastfood/lib/services/design_enhancement_service.dart` | 526 |
| `apps/fastfood/lib/utils/design_constants.dart` | 270 |
| `apps/dely/lib/theme.dart` | 294 |
| `apps/admin/lib/ui/admin_color_tokens.dart` | 31 |
| `apps/fastfood/lib/widgets/design/design.dart` | 40 |
| **Total** | **1 975** |

---

## 3. Trois applications, trois degrés de discipline

Mesure du recours au thème plutôt qu'à une couleur écrite en dur :

| Application | `Theme.of(context)` | `Colors.*` brut | Rapport |
|---|---|---|---|
| **Back-office** | 396 | 220 | **1,8 : 1** en faveur du thème |
| Client | 232 | 494 | 1 : 2,1 en faveur du brut |
| Livreur | 122 | 307 | 1 : 2,5 en faveur du brut |

**Le back-office est le mieux construit des trois**, et il montre la cible :
`AdminColorTokens` expose des couleurs **sémantiques** (`success`, `warning`,
badges de statut) **dérivées du `ColorScheme`** de `ModernTheme`, au lieu de
constantes. C'est la bonne architecture, elle existe déjà dans ce dépôt, et 25
fichiers l'utilisent.

L'application client fait l'inverse, avec deux fois plus de couleurs écrites en
dur que d'accès au thème. Conséquence directe et vérifiable : `darkTheme` /
`ThemeMode` y apparaît 22 fois, mais 494 couleurs brutes ne suivront jamais le
mode sombre. **Le mode sombre du client est structurellement incomplet**, quelle
que soit la qualité du `ThemeData`.

Le livreur est dans le même cas, en pire ratio, avec une seule occurrence de
`ThemeMode` — il n'a pratiquement pas de mode sombre, alors que c'est
l'application utilisée de nuit, au guidon.

---

## 4. Deux écrans de commandes sous un même libellé

| Écran | Lignes | Accès |
|---|---|---|
| `OrdersScreen` | 260 | onglet de la barre du bas |
| `EnhancedOrdersScreen` | 660 | bouton « Filtrer et rechercher » de l'onglet **et**, jusqu'au lot 0, deux entrées du profil |

Les deux sont atteignables, et ce n'est donc **pas** un doublon au sens du code
mort : l'onglet est la vue rapide, l'écran filtré est l'historique complet avec
son tri. Le bouton `Icons.tune_rounded` de `orders_screen.dart:106` va de l'un à
l'autre délibérément.

**Le défaut réel est ailleurs, et il était visible du client** : le profil
portait deux entrées — une tuile « Commandes » et une ligne « Mes commandes » —
qui ouvraient l'écran **filtré**, tandis que l'onglet du même nom ouvrait
`OrdersScreen`. Même mot, deux écrans, deux mises en page. Le client ne pouvait
pas savoir lequel il allait obtenir.

S'y ajoute un défaut d'architecture qui demeure : `EnhancedOrdersScreen`
construit son propre `OrderHistoryService` sur une instance neuve de
`DjangoOrderRepository`, au lieu de lire `AppService.orders`. Les deux vues
peuvent donc afficher des données différentes au même instant.

**Traité au lot 0** : les deux entrées du profil pointent désormais vers
`AppRouter.orders`, c'est-à-dire l'onglet. Les filtres ne sont pas perdus — ils
restent à un tap, par le bouton de l'onglet, qui est leur place : on filtre une
liste qu'on regarde déjà.

**Reste à faire** : brancher `EnhancedOrdersScreen` sur `AppService` pour
supprimer la seconde source de données. Non fait au lot 0 — c'est une
modification de chemin de données, pas un réglage de navigation.

---

## 5. États d'écran — le point fort

Mesure sur les 34 écrans client :

| État | Couverture |
|---|---|
| Chargement | 29 / 34 |
| Vide | 34 / 34 |
| Erreur | 24 / 34 |

C'est bon, et c'est le fruit d'un travail visible dans l'historique : `ea28091`
a remplacé « Erreur: DioException » par un message lisible, `6dddb74` a
distingué un refus de permission d'une panne réseau, `d8fee1a` a corrigé trois
écrans qui mentaient.

Les dix écrans sans état d'erreur explicite sont à traiter, mais c'est de
l'affinage, pas une reprise.

---

## 6. Accessibilité — le point faible

| Application | `Semantics(` | `semanticLabel` |
|---|---|---|
| Client | 14 | **0** |
| Livreur | 1 | **0** |
| Back-office | **0** | **0** |

**Zéro `semanticLabel` sur 124 450 lignes de Dart.** Aucune image, aucune icône
d'action n'est annoncée à un lecteur d'écran. Les 14 `Semantics(` du client sont
l'essentiel de l'effort d'accessibilité du produit.

La checklist de la phase 38 coche « accessibility ». En l'état, c'est la case la
moins fondée de la liste.

Ce n'est pas un chantier de refonte : c'est un passage sur les composants
partagés une fois qu'ils existent (§8). Un bouton d'action correctement étiqueté
dans le socle l'est partout.

---

## 7. Responsive — insuffisant là où ça compte

| Application | `LayoutBuilder` | Contexte d'usage |
|---|---|---|
| Client | 7 | mobile — acceptable |
| **Back-office** | **5** | **desktop + tablette de cuisine** |
| Livreur | 0 | mobile — acceptable |

Le back-office est l'application qui a le plus besoin d'adaptation — elle est
utilisée sur écran large *et*, depuis `42f24b0`, sur tablette de cuisine — et
c'est celle qui en a le moins. 18 fichiers touchent à `MediaQuery.size` ou
équivalent, ce qui est peu pour 41 711 lignes.

**Le poste de cuisine est le cas critique** : il est conçu pour une tablette
posée en cuisine, en mode paysage, lue à un mètre de distance, par quelqu'un qui
a les mains occupées. Quatre colonnes sur 180 lignes ne suffiront pas à tenir
cette contrainte sur tous les formats. À vérifier sur matériel réel avant
d'annoncer le KDS opérationnel.

---

## 8. Écrans surdimensionnés

| Fichier | Lignes |
|---|---|
| `fastfood/…/delivery_tracking_screen.dart` | 1 957 |
| `admin/…/advanced_order_management_screen.dart` | 1 779 |
| `fastfood/…/cake_order_screen.dart` | 1 589 |
| `fastfood/…/group_order_screen.dart` | 1 462 |
| `dely/…/delivery_home_screen.dart` | 1 366 |
| `dely/…/delivery_orders_screen.dart` | 1 263 |
| `admin/…/admin_navigation_screen.dart` | 1 253 |
| `admin/…/admin_dashboard_screen.dart` | 1 243 |

Huit fichiers au-dessus de 1 200 lignes. Un écran de cette taille ne se teste
pas, ne se relit pas, et absorbe silencieusement la logique métier qui devrait
vivre ailleurs.

**Le remède existe déjà dans le dépôt** : `apps/fastfood/lib/presentation/`
extrait dix-huit modules de logique de présentation testables hors widget
(`tarification.dart`, `frais_de_livraison.dart`, `etape_de_course.dart`…), et
`apps/admin/lib/presentation/` fait de même. Le motif est bon ; il n'a
simplement pas été appliqué aux plus gros écrans.

C'est un chantier d'entretien continu, pas un préalable. À traiter écran par
écran, quand on y touche pour une autre raison.

---

## 9. Ce que le parcours client ne dit pas encore

Le brief (phase 24) demande que le client comprenne toujours **quelle cuisine
prépare sa commande, où elle est, quand elle sera prête, quand elle sera
livrée**.

Les trois premiers points sont couverts : `selecteur_etablissement_sheet.dart`
choisit la cuisine, le suivi affiche la position, l'heure estimée est renvoyée
par le serveur.

Le quatrième est **faux par construction**, et la cause est en I1 du document
03 : l'heure annoncée se calcule sur `default_preparation_minutes` de
l'établissement, jamais sur ce qui a été commandé. Un gâteau sur mesure et un
jus pressé annoncent la même heure.

Aucun travail d'interface ne corrigera cela. C'est le lot 2 — la production —
qui donnera au client une heure qui veut dire quelque chose.

---

## Plan de traitement

| Priorité | Action | Coût | Lot |
|---|---|---|---|
| 1 | Entrée « Cuisine » de premier niveau dans la nav admin | ~30 l. | 0 |
| 2 | Trancher `OrdersScreen` / `EnhancedOrdersScreen` | décision + suppression | 0 |
| 3 | Monter les jetons de couleur dans `elcorazon_core/design`, sur le modèle sémantique du back-office | moyen | 1 |
| 4 | Unifier la couleur primaire des trois applications | faible, après 3 | 1 |
| 5 | Basculer client et livreur du brut vers le thème | élevé, progressif | 1-2 |
| 6 | `semanticLabel` sur les composants partagés | faible, après 3 | 2 |
| 7 | Vérifier le KDS sur tablette réelle | mesure | 2 |
| 8 | Dix écrans client sans état d'erreur | faible | continu |
| 9 | Découper les huit écrans > 1 200 lignes | élevé | continu |

Les deux premiers se font en une séance et suppriment un défaut d'usage
quotidien. Le troisième conditionne les trois suivants : tant que les jetons
vivent dans chaque application, unifier la couleur signifie la corriger trois
fois, et poser un label d'accessibilité signifie le poser trois fois.
