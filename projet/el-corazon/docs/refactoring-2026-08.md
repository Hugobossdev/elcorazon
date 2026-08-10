# Plan de refactoring — El Corazón

**Révision 2, 6 août 2026.** La révision 1 a été établie puis exécutée jusqu'au
lot 1 inclus le même jour ; elle est consultable dans l'historique git
(`8e1995a`). Cette révision-ci **repart de l'état mesuré après ce travail**, et
corrige deux erreurs de cadrage de la première.

Ce document ne remplace pas [`04-migration-flutter.md`](architecture/04-migration-flutter.md),
qui reste la référence sur *ce qui doit être branché* côté fonctionnel. Il traite
de la dette laissée derrière cette migration.

---

## 1. Où on en est

Mesuré aujourd'hui, pas déduit.

Mise à jour au 7 août 2026, après les lots 2 et 5.

| Composant | Fichiers | Code | Tests | `flutter analyze` | Couverture |
|---|---:|---:|---:|---:|---:|
| `backend/` | 314 | 29 676 l. | **1276 passés** | ruff + mypy strict, verts | — |
| `packages/elcorazon_core` | 81 | 8 428 l. | **185 passés** | **0** | 58,87 % |
| `apps/admin` | 76 | 35 362 l. | **50 passés** | **0** | 0,99 % |
| `apps/fastfood` | 135 | 46 660 l. | **69 passés** | **0** | 3,51 % |
| `apps/dely` | 48 | 16 973 l. | **16 passés** | **0** | 1,31 % |

Zéro diagnostic partout, et plus seulement zéro erreur : le lot 5 a aligné les
règles des quatre paquets et retiré `--no-fatal-infos` de la CI. `flutter build
web` aboutit sur les trois applications. Trois garde-fous bloquent la CI :
`tools/code_mort.py` (fichier injoignable), `flutter analyze` (le moindre écart),
`tools/couverture.py` (baisse de couverture).

### Ce que les lots 0 et 1 ont donné

Les applications sont passées de **135 050 à 99 573 lignes** (−35 477, −26 %) et
de 385 à 259 fichiers, sans qu'un seul test change de couleur.

| Lot | Commit | Effet |
|---|---|---|
| 0 — correctifs + mesure | `fd4ffb4` | `beat` observable, flux de discussion fermés, garde-fou écrit |
| 1.1 — fichiers injoignables | `39a057e` | −109 fichiers, −29 890 l. |
| 1.2 — services zombies | `847958c` | −16 services construits pour personne |
| 1.3 — résidus + CI | `945a25d` | −12 SQL Supabase, −16 dépendances, garde-fou bloquant |
| 2.1 — affichage des montants | `f803e4f` | Une règle d'affichage dans le socle, 17 tests |
| 2.2 — applications branchées | — | 3 formateurs → 3 délégations, 22 tests, 2 régressions évitées |
| 2.3 — itinéraires + présentation | — | `DirectionsRepository` au socle (20 tests), `dely` aligné sur `admin` |
| 5 — outillage durci | — | 1 368 diagnostics → 0, 663 traces muettes en production, plancher de couverture |

---

## 2. Les deux erreurs de cadrage de la révision 1

Il faut les dire, parce qu'elles changent le plan.

### 2.1 Le lot 2 était surdimensionné

La révision 1 annonçait « la duplication entre applications » comme un chantier
de 3 à 4 jours, sur la foi d'un inventaire des fichiers homonymes. Elle comptait
des widgets triplés (`order_card`, `cart_item_card`, `category_chip`,
`promotion_banner`, `el_corazon_logo`) **qui étaient morts dans les trois
applications**. Le lot 1 les a supprimés ; il ne restait rien à unifier.

Mesure de similarité réelle sur ce qui subsiste (`difflib`, texte intégral) :

| Similarité | ~lignes | Fichier | Paire |
|---:|---:|---|---|
| 100 % | 18 | `price_formatter.dart` | fast/dely |
| 98 % | 360 | `promo_code_service.dart` | fast/dely |
| 96 % | 250 | `loading_widget.dart` | admin/dely |
| 96 % | 275 | `promo_code.dart` | fast/dely |
| 93 % | 222 | `custom_text_field.dart` | admin/dely |
| 86 % | 373 | `directions_service.dart` | fast/dely |
| 81 % | 127 | `user.dart` | fast/dely |

**Sept paires, ~1 625 lignes.** C'est un lot de 2 jours, pas de 4. Tout le reste
des homonymes est descendu sous 70 % de similarité : `order.dart` (59 %),
`menu_item.dart` (56 %), `gamification_service.dart` (642 lignes d'écart sur
750). Ceux-là ont réellement divergé — les fusionner n'est pas une
déduplication, c'est une réconciliation de sémantiques.

### 2.2 Les modèles n'appartiennent pas au lot 2

La révision 1 plaçait « supprimer les modèles locaux dont le socle porte déjà
l'entité, en commençant par `order.dart` » dans le lot 2, présenté comme sans
risque fonctionnel. C'est faux : 55 écrans sur 88 dépendent de ces modèles.
Retirer `order.dart` **est** la migration domaine par domaine du lot 3, pas un
préalable à celle-ci. La ligne est déplacée.

---

## 3. Diagnostic actualisé

### 3.1 Le constat central n'a pas bougé : deux piles clientes coexistent

C'est ce qui reste à faire, et c'est l'essentiel du travail.

| | Pile cible | Pile héritée |
|---|---|---|
| Modèles | entités du socle, typées | **27** modèles locaux de forme Supabase |
| Accès données | repositories du socle (161 tests) | **72** services `*_service.dart` |
| État | Riverpod | `ChangeNotifier` + **44** singletons |
| Écrans | **17** | **55** |

Les deux piles sont raccordées par **12 adaptateurs** (`django_*_repository.dart`,
`django_order_mapper.dart`) dont le seul travail est de traduire, et par
`AppService` — singleton `ChangeNotifier` importé par 25 fichiers dans
`fastfood`, 14 dans `dely`, 5 dans `admin`.

`admin` est le plus avancé : 19 services hérités, 6 modèles, 1 adaptateur.
`fastfood` porte le gros du reliquat : 40 services, 15 modèles, 10 adaptateurs.

### 3.2 Les écrans démesurés

Inchangé — le lot 1 ne les touchait pas. **32 fichiers dépassent 700 lignes**,
dont 5 dépassaient 1 500 :

| Fichier | Lignes | Après lot 4 |
|---|---:|---:|
| `admin/…/advanced_order_management_screen.dart` | 3 070 | **1 224** |
| `fastfood/…/cake_order_screen.dart` | 2 886 | 2 442 * |
| `admin/…/order_management_screen.dart` | 2 531 | **1 324** |
| `admin/…/gamification_management_screen.dart` | 1 744 | **163** |
| `fastfood/…/delivery_tracking_screen.dart` | 1 589 | 1 561 * |

\* écrans encore longs, mais dont la logique est sortie — voir §4.4 et §4.5.

400 `setState` au total. Aucun écran n'appelle le réseau directement — la
frontière écran ↔ données tient, c'est ce qui rend la découpe faisable.

### 3.3 Le déséquilibre des tests reste le sujet

Le lot 5 l'a **chiffré** au lieu de l'estimer, et le constat est plus dur que ne
le laissait croire le compte de tests :

```
backend             29 676 l.  ←→  1276 tests
elcorazon_core       8 428 l.  ←→   185 tests   58,87 % couvert
les 3 applications  99 000 l.  ←→   135 tests    1,89 % couvert
```

837 lignes couvertes sur 38 250 dans les trois applications. `admin` est à
**0,99 %** — 143 lignes sur 14 487. C'est le filet qui manque pour les lots 3
et 4, et c'est désormais mesuré à chaque exécution de la CI plutôt que deviné.

### 3.4 L'outillage était inégal — traité au lot 5

`dely` n'activait **aucune** règle de lint, `admin` 7, `fastfood` 53, et le socle
déclarait `flutter_lints` sans jamais l'inclure. Les quatre partagent maintenant
le même jeu (`analysis_options.yaml` à la racine) et sont à zéro diagnostic, la
CI n'en tolérant plus aucun.

Les 663 `debugPrint` restants sont passés par `Journal.trace`, qui ne fait rien
hors du mode debug. Le point n'était pas cosmétique : contrairement à `print`,
`debugPrint` **s'exécute en production**, et l'audit y a trouvé des adresses de
livraison complètes et des coordonnées GPS de clients.

---

## 4. Les lots restants

### Lot 2 — Finir la déduplication (2 jours) — *entamé*

**2.1 fait** (`f803e4f`) : la règle d'affichage des montants vit dans
`Money.format()` / `formatPrice()`, testée. Les trois applications rendaient des
prix différents pour la même commande — « 12.500 CFA » côté client, « 12 500 CFA »
côté back-office — et la version client n'avait aucune garde (`format(-500)`
rendait « -.500 CFA »).

**2.2 fait** : les trois `price_formatter.dart` sont des délégations d'une
ligne, ce qui a laissé les 131 points d'appel intacts (138 annoncés, 131
mesurés). Ils disparaîtront d'eux-mêmes au lot 3, quand les écrans manipuleront
des `Money`. ⚠️ **Changement visible** : le client et le livreur sont passés de
« 12.500 CFA » à « 12 500 CFA ». C'est la correction, mais elle se voit, et
**elle reste à annoncer**.

Deux points d'appel ont dû suivre, faute de quoi le lot aurait régressé : le
nettoyage de l'export CSV du back-office ne voyait pas l'espace insécable
(`replaceAll(' ')` → `RegExp(r'\s')`), et la ligne « Remise » du panier client
préfixait un second signe sur un montant déjà négatif — « --.500 CFA » avant,
« -500 CFA » après.

**2.3 fait, avec une correction de cadrage.** `directions_service` (86 %) est
passé au socle avec ses tests, sous la forme d'un `DirectionsRepository` : les
deux copies divergeaient sur le transport, et celle de `dely` construisait ses
URL par concaténation **sans encoder ses points de passage**. Le socle n'a pas
pris `google_maps_flutter` pour autant — un `GeoPoint` de deux nombres suffit,
les écrans convertissent à la frontière.

`loading_widget` et `custom_text_field` (96 % et 93 %, admin/dely) sont de la
présentation : le socle **ne doit pas** les prendre — `04-migration-flutter.md`
§2.2 réserve la présentation aux applications. `dely` a été aligné sur `admin`
par copie, et on s'est arrêté là. C'était sans risque : `LoadingOverlay` et
`SearchTextField`, les seules classes dont le comportement différait, ne sont
pas utilisées dans `dely`, et son `ThemeData` ne câble que `lightTheme` — où
`primaryColor` **est** `colorScheme.primary`.

`promo_code_service` + `promo_code` (98 % et 96 %, fast/dely) **ne vont pas au
socle** : la ligne était fausse, pour la même raison qu'en §2.2. Le socle porte
déjà l'entité (`Promotion`, miroir de `ManagedPromotionSerializer`, en `Money`,
plus `PromotionRepository`) ; et ce que porte le local n'est pas un modèle de
domaine mais un magasin `SharedPreferences` de codes promo, sous un singleton
`ChangeNotifier` qui calcule la remise côté client et laisse le client *créer*
des codes — c'est-à-dire exactement la pile héritée décrite en §3.1. L'y verser
l'installerait dans le socle. Il n'y a d'ailleurs **aucune route publique de
promotion** : la remise arrive par le devis de la commande. Ces deux fichiers
relèvent donc du lot 3, comme tout modèle local que le socle double (§2.2), et
leur fin n'est pas un déplacement mais une suppression.

*Ne pas faire* : unifier `custom_button` (160/320/221 l.) ni
`gamification_service` (642 lignes d'écart). Ils ont divergé pour des raisons
qu'il faudrait comprendre avant d'effacer.

### Lot 3 — Démonter la pile héritée (3 à 4 semaines) — *le gros œuvre*

Domaine par domaine, jamais d'un bloc. Pour un domaine (commandes, catalogue,
panier, adresses…) :

1. **Écrire le test d'abord**, sur le comportement qu'on s'apprête à déplacer.
   Le filet n'existe pas (113 tests pour 99 573 lignes) : le construire après la
   migration ne protège de rien.
2. Les écrans passent du modèle local à l'entité du socle.
3. L'adaptateur correspondant disparaît — il n'existait que pour traduire.
4. Le service hérité du domaine disparaît.
5. L'état passe en Riverpod.

Ordre : **`dely` d'abord** (15 écrans, 13 services, 1 adaptateur — le plus petit
périmètre, et celui dont l'app est la plus simple), puis `admin` (33 écrans mais
déjà 19 services seulement), puis `fastfood` (40 écrans, 40 services, 10
adaptateurs — le plus gros, mais aussi le plus déjà migré : 13 écrans sur le
socle).

`AppService` se vide au fil des domaines et **se supprime en dernier**. C'est lui
qui tient l'application debout tant qu'un domaine hérité subsiste.

*Critère de fin d'un domaine* : plus aucun `import '…/models/<domaine>.dart'`,
plus d'adaptateur, et un test qui passe sur la logique déplacée.

#### 3.6 — `admin`, domaine « commandes » : **fait**

Le dernier domaine hérité d'`admin`, et le plus gros : 26 fichiers, environ
330 références. Il ne se découpait pas — la charnière était le type de retour
d'`OrderManagementService`, et le jour où il rend `eccore.Order`, tout le reste
suit d'un coup. C'est ce qui a été fait.

`models/order.dart` (851 l.) et `django_order_mapper.dart` (104 l.) sont
supprimés. À leur place, quatre fichiers de présentation qui ne traduisent
rien mais nomment : `StatutCommande` (8 statuts), `MoyenPaiement` (4 moyens),
et deux extensions — `CommandeAffichee`, `LigneAffichee` — qui portent les
valeurs dérivées que l'adaptateur figeait dans une copie.

**Ce que la traduction perdait en route, et qui arrive maintenant à l'écran :**

- les **options choisies** par le client sur chaque article. Le back-office
  affichait un bloc « Personnalisations » alimenté par un champ que rien ne
  remplissait : il ne s'affichait jamais. Un client qui commande « sans
  oignon » l'écrivait dans le vide, et la cuisine préparait autre chose ;
- l'**historique réel** des transitions. Deux écrans fabriquaient chacun le
  leur — `order_management_screen.dart` avec +5/+10/+25/+30/+45 minutes,
  `order_timeline_widget.dart` avec +5/+15/+20/+25/+30. Les deux lisent
  désormais `statusEvents`. Une étape dont on ignore l'heure n'en affiche
  pas ;
- `reference`, `deliveredAt`, `cancelledAt`, `cancellationReason`,
  `allowedTransitions`.

**Trois corrections de comportement**, toutes documentées par des tests :

1. une commande **annulée** ne coche plus les étapes du service. Le rang se
   lisait sur `status.index`, et `cancelled` était déclaré après `delivered` ;
2. la chronologie n'invente plus d'heures ;
3. le bloc des personnalisations s'affiche enfin.

**Ce qui a été retiré après vérification qu'il ne servait à rien :**

| Retiré | Pourquoi |
|---|---|
| `refunded`, `failed` | statuts que le serveur ne connaît pas ; le mapper les renvoyait tous deux en `cancelled` |
| `debitCard` | moyen de paiement sans contrepartie serveur |
| `markOrderFailed()` | visait `failed` ; aucun appelant |
| `getTopCustomers()` | groupait sur `userId`, que le contrat de supervision ne rend pas : tous les clients tombaient dans la même clé vide ; aucun appelant |
| `promoCode`, `paymentTransactionId`, `specialInstructions`, `statusUpdates` | 0 usage, ou jamais renseignés |
| le garde-fou `total.isNaN \|\| total.isInfinite` | `Money` ne peut être ni l'un ni l'autre |

**Le manque qui reste, et qui appartient au serveur.** `deliveryPersonId`
n'était jamais renseigné. Il devient `CommandeAffichee.livreurAffecte`, qui
rend `null` — **écrit une fois, documenté une fois**, plutôt que dispersé en
quatre `null` silencieux. Les conséquences restent entières :

- `driver_detailed_stats_screen.dart` est toujours vide ;
- `driver_map_screen.dart` ne pose jamais de marqueur de livraison ;
- le bouton d'assignation ne propose jamais de réassigner.

Le sérialiseur de supervision n'expose pas le livreur, et `AssignmentViewSet`
est réservée au livreur lui-même. Le jour où le serveur l'expose, il y a **un**
endroit à changer.

**Deux écarts relevés, non corrigés :** le serveur rend une `reference` lisible
(`CMD-0001`) désormais disponible, pendant que 32 endroits fabriquent encore un
identifiant en découpant l'UUID ; et les libellés de paiement restent en
anglais dans un back-office français.

*Critère de fin atteint* : plus aucun `import '…/models/order.dart'`, plus
d'adaptateur, et 51 cas sur la logique déplacée.

#### 3.8 — `fastfood`, domaine « catalogue » : **fait**

`models/menu_item.dart` et `models/menu_category.dart` sont retirés, et
`DjangoMenuRepository` ne traduit plus rien — `eccore.CatalogRepository` rend
déjà ce que les écrans lisent. 21 fichiers touchés.

L'aller-retour JSON manquait au socle : `fromJson` existait seul, alors que le
cache hors-ligne range les entités en base locale. `MenuItem.toJson`,
`Category.toJson`, plus celles d'`OptionGroup` et `Option`, comblent le manque
— 7 cas les épinglent, dont le prix au centime près.

Cinq défauts sont tombés avec la traduction :

- **Le regroupement par catégorie n'aurait plus rien trouvé.** `menu_screen`
  indexait les catégories par `id` et cherchait avec le `categorySlug` de
  l'article. L'ancien adaptateur rangeait le slug dans le champ `id` du modèle
  local, ce qui masquait l'écart ; `eccore.Category.id` est l'UUID. Corrigé en
  indexant par `slug` — l'identifiant que l'article partage réellement ;
- **Un article sans catégorie connue tombait dans la première venue.**
  `app_service` rattachait l'objet catégorie article par article, avec
  `orElse: () => _menuCategories.first`. La boucle entière disparaît : le
  contrat rend `category` et `category_name` sur l'article ;
- **La « recommande » fabriquait des articles que le serveur refuse.** Un
  article retiré de la carte était recréé avec un identifiant `temp-` et une
  catégorie `temp-category` ; le panier l'acceptait, `/carts/` non, et la ligne
  disparaissait à la synchronisation suivante sans que personne ne le dise.
  L'écran nomme désormais les articles qui ne sont plus à la carte ;
- **Les cartes du menu affichaient un article qui n'était pas le leur.**
  `createEnhancedMenuItemCard` recevait une dizaine de scalaires et
  reconstruisait un `MenuItem` avec `categoryId: 'burgers'` écrit en dur, sans
  note ni disponibilité ni exclusivité VIP. Elle reçoit l'article entier ;
- **Le prix « personnalisé » du panier n'a jamais servi.**
  `enhanced_item_customization_screen` recopiait un total calculé localement
  sur une copie de l'article. Le serveur ne l'a jamais lu : il chiffre les
  options depuis leurs identifiants (ADR-007).

Un sixième a été corrigé au passage : **`OfflineSyncService` écartait les
catégories sans emoji**, au même titre qu'une catégorie sans nom. Une catégorie
disparaissait donc du mode hors ligne pour un champ décoratif. Le rejet est
retiré, et l'écran affiche un repli (`CategorieAffichee.pastille`).

#### 3.7 — `fastfood`, ce qui reste : mesuré, pas exécuté

Après la fermeture du catalogue (§3.8), deux modèles subsistent —
`address` (14 consommateurs) et `cart_item` (9) — plus `order` (18) et trois
modèles de paiement.

**`address`, mesuré.** `eccore.Address` couvre le modèle local sauf trois
champs, et chacun raconte quelque chose :

- `isFavorite` n'existe pas côté serveur, et c'est **assumé** : `AddressService`
  tient sa propre table d'ids favoris, persistée en `SharedPreferences`. Le
  champ doit rester, porté par l'application. J'ai d'abord cru à une case à
  cocher sans effet ; vérification faite, elle en a un ;
- `postalCode` est écrit dans **`line2`** par l'adaptateur, et relu de là. Le
  serveur n'a pas de code postal ; `line2` est la seconde ligne d'une adresse —
  appartement, bâtiment. Les deux notions se marchent dessus : saisir un code
  postal écrase la seconde ligne, et réciproquement ;
- `userId` est passé à l'adaptateur pour être recopié dans le modèle local. Le
  serveur cloisonne sur le jeton ; le champ n'apprend rien.

La bascule croise `address_detail_bottom_sheet.dart`, en cours d'édition côté
humain au moment de cette mesure.

La correspondance avec le socle est directe — `price` en `Money`, `categoryId`
en `categorySlug`, `imageUrl` en `image`, `preparationTime` en
`preparationMinutes`, `rating`/`reviewCount` en `ratingAverage`/`ratingCount`,
`isVegetarian`/`isVegan` dérivés de `dietaryTags`. Un seul champ local n'a pas
de contrepartie, `availableQuantity`, et il a **zéro usage**.

Trois constats de la mesure, tous vérifiés :

- **Une catégorie sans emoji disparaît du mode hors-ligne.**
  `OfflineSyncService` écarte toute catégorie dont `emoji` est vide, au même
  titre qu'un nom vide. Or `emoji` vaut `''` dès que le serveur n'en a pas
  configuré — et **toujours** quand la catégorie est reconstruite depuis un
  article, l'adaptateur écrivant `emoji: ''` en dur à cet endroit. Deux objets
  `MenuCategory` coexistent donc pour la même catégorie, l'un avec son emoji,
  l'autre sans ;
- `displayName` vaut toujours `name`. Le champ n'existe que parce que le modèle
  local le déclare ; le serveur ne rend pas de `display_name`, et `fromMap`
  déroule trois replis pour une clé qui n'arrive jamais ;
- `id` porte le **slug**, pas l'UUID, sur toute la chaîne locale. Cohérent,
  mais l'identifiant réel est perdu à la traduction.

`address` croise `address_detail_bottom_sheet.dart` et `cart_item` croise
`cart_service.dart` — deux fichiers en cours d'édition côté humain au moment de
cette mesure. Ces deux domaines attendent.

### Lot 4 — Découper les écrans (2 semaines, parallélisable au lot 3)

Les 5 écrans de plus de 1 500 lignes, dans l'ordre du tableau §3.2. Pour
chacun : extraire les sous-vues en widgets nommés, sortir la logique dans un
provider, écrire le test sur cette logique.

Le critère n'est pas un nombre de lignes : **le comportement métier de l'écran
est-il atteignable par un test sans monter l'arbre de widgets ?** Tant que la
réponse est non, la découpe n'est pas finie.

**4.1 — `advanced_order_management_screen.dart` : fait.** 3 067 → 1 224 lignes.
Trois règles sont devenues atteignables et sont couvertes par 31 cas : la
recherche et le tri de la liste, l'âge affiché d'une commande, le comptage par
jour du graphe. Les cinq onglets de statut, cinq copies de 47 lignes, n'en font
plus qu'une. Trois dialogues et l'onglet des statistiques sont devenus des vues
nommées sous `lib/presentation/`.

Ce que la découpe a mis au jour — et qui n'aurait pas été trouvé autrement :

- La légende du graphe annonçait « Total: N commandes sur 7 jours » avec N le
  nombre de commandes **toutes dates confondues**. Sortir le comptage l'a rendu
  visible ; il compte désormais la fenêtre qu'il nomme.
- Deux dialogues d'assignation de livreur coexistent et **ne font pas la même
  chose** : celui de la gestion avancée marque la commande « récupérée » après
  assignation, celui d'`active_deliveries_screen.dart` non. Fusionner
  trancherait une question de métier — laissé tel quel, à arbitrer.
- **Trois** correspondances statut → couleur coexistent dans le back-office :
  jetons du thème ici, palette statique `ModernTheme` dans le tableau de bord,
  `Colors.orange`/`Colors.blue` écrits en dur — donc aveugles au thème sombre —
  dans `order_management_screen.dart`. Les unifier changerait ce que voient les
  utilisateurs sur deux écrans. Le présent document n'en dit rien : à décider
  avant de le faire.

**4.2 — `order_management_screen.dart` : fait.** 2 528 → 1 324 lignes, 23 cas
ajoutés. Les trois filtres (recherche, zone, fenêtre de temps), l'historique
d'une commande et l'âge affiché sont sortis dans `lib/presentation/` ; les
trois panneaux d'une commande dépliée, la fiche et la barre de filtres sont
devenus des widgets nommés. `ancienneteCommande`, écrite deux fois à
l'identique dans les deux écrans, n'existe plus qu'une fois.

Ce que la découpe a mis au jour ici est plus lourd qu'au 4.1 — **trois points
attendent un arbitrage, aucun n'est corrigé** :

- **Le filtre par zone cherche des quartiers de Dakar.** Yoff, Pikine,
  Guédiawaye, Almadies, Mermoz, Rufisque, Parcelles Assainies, Médina… Le
  restaurant est à Lomé. Aucune adresse togolaise ne contient ces mots : « Zone
  2 - Nord » et « Zone 3 - Sud » ne rendent jamais rien, et « Zone 1 - Centre »
  rend tout, par mot générique ou par repli. Deux des trois choix du filtre
  sont morts, le troisième ne filtre pas. Le back-office possède pourtant un
  `DeliveryZoneService` qui tient les vraies zones du serveur. Rebrancher le
  filtre dessus est une décision de produit.
- **L'« Historique de la commande » affiche des heures inventées.** Chaque
  étape montre l'heure de commande augmentée d'un délai fixe — +5 min
  « confirmée », +10 « en préparation », +25 « prête », +30 « en livraison »,
  +45 « livrée ». Rien de mesuré n'y entre : une commande encore en attente
  affiche la même heure de « livrée » qu'une commande livrée.

  **Rectification, apportée au lot 3.** J'ai d'abord écrit ici que le serveur
  ne renvoyait pas d'horodatage par étape. C'était faux, et l'erreur venait de
  n'avoir regardé que l'entité du socle. Le serveur tient `OrderStatusEvent` —
  un journal des transitions écrit par la machine à états dans la même
  transaction que le changement de statut — et le rend sur la forme détail
  (`OrderDetailSerializer`). C'est le **socle** qui ne le lisait pas, alors que
  son propre commentaire de classe l'annonçait. Il le lit désormais. La sortie
  ne demande donc pas de toucher au back-end : elle demande que l'écran aille
  chercher la forme détail au dépliage d'une commande.
- **Une commande annulée paraît avoir été mise en livraison.** L'étape franchie
  se décide par `status.index >= n`, et `cancelled` est déclaré après
  `delivered` dans l'énumération. Le rang de déclaration n'est pas le cycle de
  vie.

Les trois sont épinglés par des tests qui décrivent l'état actuel, pour que la
correction se voie le jour où elle est décidée.

Un quatrième point a été corrigé, parce qu'il ne demandait pas d'arbitrage : la
ligne « Client: » d'une commande dépliée affichait `order.id`, la référence de
la commande sous une étiquette qui annonce une personne. Elle affiche le
destinataire, et retombe sur la référence quand le nom manque.

**4.3 — `gamification_management_screen.dart` : fait.** 1 744 → 163 lignes.
Le cas est différent des deux précédents : les quatre onglets et les quatre
formulaires étaient **déjà** des classes nommées. C'était le fichier qui était
trop long, pas les widgets. Il est coupé en quatre — succès, défis, badges,
récompenses — chacun avec son onglet et son formulaire, sous
`lib/screens/admin/gamification/`.

La découpe a fait tomber une règle qui tirait deux fois sur l'horloge : un défi
**sans date de fin** prenait `DateTime.now()` comme date de fin, puis la
comparait à un second `DateTime.now()` pris quelques microsecondes plus tard.
Le premier étant antérieur au second, le défi s'affichait expiré — par course,
pas par décision. Il n'expire plus, et sa carte n'affiche plus « Fin: » suivi
de la date du jour. Six cas couvrent `defiExpire` et `dateDeFinDefi`.

Reste que le vrai passif de cet écran n'est pas le lot 4 mais le lot 3 : le
domaine gamification n'a **aucun modèle**. Tout y circule en
`Map<String, dynamic>` — `challenge['end_date']`, `achievement['id']` — et il
n'y a donc presque rien à tester au-delà de la validation des formulaires.

**4.4 — `delivery_tracking_screen.dart` : le calcul est sorti, le fichier
reste long.** 1 589 → 1 561 lignes seulement, et c'est volontaire : ce qui
comptait ici n'était pas le nombre de lignes mais le fait que le seul vrai
calcul de l'écran — distance parcourue et vitesse moyenne du livreur — était
enfermé dans une méthode qui écrivait directement dans l'état du widget.
`statistiquesDuTrajet` le porte maintenant, avec 12 cas.

Trois règles étaient dedans, aucune n'était dite :

- l'historique des positions va **du plus récent au plus ancien**
  (`insert(0, …)`), et c'est ce qui rend positif l'écart de temps entre deux
  relevés. J'ai d'abord cru à un bug ; vérification faite, le calcul est juste,
  il était seulement invérifiable ;
- deux sources de vitesse coexistent — celle déduite du trajet et celle que le
  GPS rapporte — et les deux comptent ;
- les vitesses hors de `]0, 100[` km/h sont rejetées comme aberrantes.

Aucun changement de comportement : `vitesseMoyenne == null` recouvre exactement
l'ancien `speeds.isEmpty`, et l'écran garde comme avant la dernière vitesse
connue plutôt que d'afficher un zéro qu'il n'a pas mesuré. Le seul écart
théorique tient à moins de deux relevés, où la distance vaut désormais zéro au
lieu de rester inchangée — cas hors d'atteinte, l'historique ne faisant que
croître.

Deux chiffres écrits au milieu du code en sont sortis aussi : le seuil
d'alerte de proximité (500 m) et l'estimation de repli (2 min/km, soit
30 km/h, quand le service d'itinéraire ne répond pas).

**4.5 — `cake_order_screen.dart` : entamé, pas fini.** 2 886 → 2 442 lignes.
La seule règle métier que l'écran portait en propre est sortie et couverte par
11 cas : la pré-sélection d'options quand un client part d'un gâteau du
catalogue pour composer le sien. Le reste du métier — prix des options,
contraintes de catégorie — vit déjà dans `CustomizationService` et y est testé.
Le récapitulatif (407 lignes) est devenu `RecapitulatifGateau`.

Ce que la règle sortie a rendu visible : la correspondance est une **inclusion
littérale**, donc « Fraisier » ne suggère pas « Fraise » — le nom de pâtisserie
le plus courant en français passe à côté de son propre parfum. Corriger
demanderait une racinisation, donc une décision ; le cas est épinglé par un
test qui dit ce qui se passe aujourd'hui.

Restent deux blocs de présentation à nommer, `_buildCategorySection` (285 l.,
qui entraîne avec lui les sélecteurs de couleur et de texture et les deux
gestionnaires de sélection) et `_buildDeliverySelectors` (274 l.). Ils ne
portent pas de règle testable ; c'est de la lisibilité, pas de la dette
fonctionnelle.

### Lot 5 — Durcir l'outillage — **fait**, mais pas en un jour

Le lot était estimé à une journée sur l'hypothèse qu'il restait 56 diagnostics.
C'est la troisième erreur de cadrage du même genre que celles reconnues au §2 :
le chiffre mesurait l'outillage en place, pas ce que son alignement révèle.

**5.1 — un jeu de règles pour les quatre paquets.** Les trois
`analysis_options.yaml` triplaient 53 règles ; elles vivent désormais dans
`analysis_options.yaml` à la racine, que les quatre incluent. Le socle en reçoit
un aussi : il déclarait `flutter_lints` **sans jamais l'inclure**, faute
d'`analysis_options.yaml` — son « zéro diagnostic » mesurait surtout ce qu'on ne
lui demandait pas.

L'alignement a révélé **1 368 diagnostics** (socle 161, admin 796, dely 402,
fastfood 9), pas 56. 894 traités par `dart fix`, **474 à la main**. Tous à zéro.

Ce que le traitement manuel a mis au jour, au-delà du style :

- **`dart fix` produit du code invalide.** Quatre `const AxisTitles(\n ,)` dans
  le tableau de bord admin, après retrait d'arguments redondants. D'où la règle :
  **bâtir** après chaque passe automatique, pas seulement analyser.
- **30 `BuildContext` traversant un `await`**, dont plusieurs déjà mal gardés
  *avant* ce lot. La règle que l'analyseur applique : `State.context` se garde
  avec `mounted`, tout autre `BuildContext` avec `context.mounted`. Le code
  d'origine faisait l'inverse par endroits.
- **4 `close_sinks`** vérifiés un par un : tous faux positifs (fermeture au
  travers d'un champ ou d'une map), documentés par un `// ignore:` justifié.
- **`RadioListTile.groupValue`/`onChanged` dépréciés** : migration réelle vers
  `RadioGroup` dans les deux dialogues de réglages de `dely`.
- **177 appels dynamiques typés**, dont 100 dans les deux `geocoding_service`
  (36 % de similarité : divergence, pas duplication — on ne les fusionne pas).

**5.2 — `--no-fatal-infos` retiré** de `flutter-ci.yml`. Le jeu de règles partagé
a été ajouté aux filtres de chemin du workflow : sans cela, le modifier
n'aurait plus déclenché la CI.

**5.3 — journaliseur.** `Journal.trace` vit dans le socle et **ne fait rien hors
du mode debug**. Les 663 `debugPrint` des trois applications y sont passés.

L'audit demandé a trouvé, non pas des jetons — le seul jeton tracé l'était déjà
sous la forme « obtenu »/« indisponible » — mais **des adresses de livraison
complètes et des coordonnées GPS de clients**, dans les trois applications :
`GeocodingService: Adresse géocodée - $address -> $latLng`, son symétrique
inverse, `✅ Coordonnées client obtenues: $_customerLocation` chez le livreur, et
trois vidages de la réponse Google brute chez le client. `debugPrint` écrit dans
le journal système de l'appareil ; sur Android, une application outillée le lit.
Le passage au journal ferme la fuite par construction.

**5.4 — plancher de couverture**, tenu par `tools/couverture.py`.

Le ratio brut de `flutter test --coverage` ne veut rien dire : il n'instrumente
que les fichiers qu'un test finit par charger. Mesuré sur `dely` — **3 fichiers
sur 48**, et 29,96 % annoncés pour **1,31 %** réels. Pire pour un cliquet :
ajouter un fichier sans test ne fait pas baisser un chiffre où le fichier
n'apparaît pas. L'outil rétablit le dénominateur (un fichier de test généré
importe tout `lib/`), refuse toute baisse, et refuse aussi un fichier généré
périmé.

| | couvertes / instrumentables | réel | plancher |
|---|---:|---:|---:|
| `elcorazon_core` | 1 480 / 2 514 | 58,87 % | 55,0 % |
| `fastfood` | 611 / 17 413 | 3,51 % | 3,0 % |
| `dely` | 83 / 6 350 | 1,31 % | 1,0 % |
| `admin` | 143 / 14 487 | 0,99 % | 0,9 % |

Les planchers **constatent l'existant**, ils ne fixent pas de cible : ils se
relèvent à chaque domaine migré au lot 3. C'est le §3.3 chiffré autrement, et
c'est le filet qui manque au lot 3.

*Reste ouvert* : rien n'interdit à `debugPrint` de revenir — `avoid_print` ne
couvre que `print`. Un contrôle de CI le fermerait ; il n'a pas été ajouté, le
document ne le demandait pas.

### Lot 6 — Documentation (2 jours, en dernier)

1. Trancher sur `CAHIER_DES_CHARGES.md` (928 l.) et `ETAT_FONCTIONNALITES.md`
   (755 l.), rédigés pour l'architecture Supabase et qui s'ouvrent tous deux sur
   un avertissement disant qu'ils sont faux. **Archiver** est cohérent avec ce
   qui a été fait du backend Laravel.
2. `SCHEMA_BDD_COMPLET.md:1251` renvoie vers `lib/database/`, supprimé au lot 1.
3. Sortir de `lib/services/` les sept `README_*.md` survivants.
4. Renommer `apps/dely` → `El Corazon dely`, et retirer les espaces des
   trois répertoires. À faire en une opération isolée : cela touche les deux
   workflows CI. C'est l'espace non échappé qui avait produit l'arborescence
   parasite `El/ Corazon/ dely/build/` supprimée au lot 1.

#### 6.1 — Deux points 2 et 3 faits, le point 1 repose sur une prémisse périmée

**Le point 1 n'a pas été exécuté, et il ne devrait pas l'être tel quel.** Il a
été écrit avant le commit `99c09e3`, « Réaligne la documentation sur
l'architecture Django », qui a changé la donne :

- `CAHIER_DES_CHARGES.md` ne contient **plus aucune** mention de Supabase et
  n'ouvre sur aucun avertissement. L'archiver détruirait un travail de
  réalignement postérieur au plan ;
- `ETAT_FONCTIONNALITES.md` porte bien un avertissement, mais ses sept mentions
  de Supabase sont toutes des constats de son **retrait**, datés du 1er août
  2026. C'est un inventaire tenu, pas un document faux.

Le document qui correspond réellement à la description du point 1 est
`SCHEMA_BDD_COMPLET.md` : il décrit le schéma Supabase abandonné et le dit dès
sa troisième ligne. Il se déclare lui-même « conservé comme référence
historique » — décision explicite qu'il n'appartenait pas à ce lot de renverser.
Seuls ses renvois morts ont été corrigés : ils pointaient vers la documentation
Supabase, vers `lib/database/` (supprimé au lot 1) et vers `lib/models/`
(retiré domaine par domaine au lot 3).

**Le point 3 portait sur huit fichiers, pas sept**, et un neuvième que le plan
ne citait pas : `apps/admin/lib/core/architecture/README.md`, seul
occupant de son répertoire. Les huit de `fastfood` sont sous
`apps/fastfood/docs/`, avec un index qui distingue les trois qui décrivent
encore du code existant des cinq qui décrivent du code disparu — dont
`connectivity_service.dart` et `PaginatedMenuScreen`, qui n'existent plus.

Le neuvième a été **corrigé en le déplaçant**, parce qu'il n'était pas daté mais
trompeur : il prescrivait `AdminInteractiveWidget`, `AdminSafeCard` et
`AdminRouter`, trois classes jamais écrites, et dessinait sept sous-répertoires
d'écrans dont un seul existe. Il vit désormais en
`apps/admin/docs/architecture.md`, vérifié contre le code.

Plus aucun `.md` ne subsiste dans les `lib/` des quatre paquets.

#### 6.2 — La prose des racines d'applications, que le plan ne couvrait pas

Le lot ne visait que `lib/services/`. Le reste de la documentation des
applications était dans le même état, et deux points relevaient de la sécurité,
pas du rangement :

- **`apps/fastfood/SETUP.md` demandait de placer les quatre clés marchandes
  PayDunya dans le `.env` de l'application**, et de créer un compte Supabase.
  C'est exactement la fuite que le commit `99c09e3` avait fermée dans le README
  racine — ce fichier-là avait été manqué ;
- **`apps/fastfood/.env.example`**, le gabarit que les développeurs copient,
  les redemandait. Vérification faite, `PAYDUNYA_MASTER_KEY`,
  `PAYDUNYA_PRIVATE_KEY`, `PAYDUNYA_TOKEN`, `SUPABASE_URL` et
  `SUPABASE_ANON_KEY` ne sont lus **par aucune ligne de code**. Le gabarit ne
  liste plus que ce que le code lit ;
- **`apps/fastfood/README.md` conseillait** : « Toutes les clés sensibles
  doivent être dans `.env` ». L'inverse est vrai. Le `.env` ignoré par Git
  protège le dépôt, pas le produit : une clé qui y figure part dans le binaire.

Trois documents décrivaient une application qui n'existe plus :

- **`apps/admin/README.md`** — 480 lignes sur `supabase_flutter`,
  `SupabaseRealtimeService` et `lib/supabase/supabase_config.dart`, tous
  disparus. Archivé en `docs/README-supabase.md`, remplacé par un README
  vérifié. Il était par ailleurs **illisible** : 19 octets d'UTF-16 collés en
  fin de fichier UTF-8 le faisaient passer pour un binaire aux yeux de `grep` ;
- **`apps/admin/ADMIN_ROLE_FIX.md`** — 217 lignes sur un bug d'une classe
  `AdminRole` qui n'existe plus. Déplacé en `docs/` ;
- **`apps/dely/README.md`** — le gabarit Flutter d'origine, jamais rempli.
  Remplacé.

`NOTIFICATIONS_PUSH_REALTIME.md` et `APPELS_AGORA.md` rejoignent
`apps/fastfood/docs/` : aucun document ne les référençait, et ils décrivent des
mécaniques bâties sur Supabase. `ARCHITECTURE.md` reste à la racine — trois
documents y renvoient — et a été corrigé en place.

Hors archives assumées, plus une seule mention de Supabase ne subsiste dans la
documentation des applications, sauf le `CHANGELOG.md` de `fastfood`, où elle
est à sa place : un changelog consigne ce qui a eu lieu.

#### 6.2 — Les trois répertoires sont sous `apps/`

Point 4 fait. Le plan demandait de retirer les espaces sans dire vers quoi ;
la forme retenue regroupe les trois applications, à côté de `backend/`,
`docs/`, `packages/` et `tools/` :

| Avant | Après |
|---|---|
| `El Corazon admin` | `apps/admin` |
| `El Corazon fastfood` | `apps/fastfood` |
| `El corazon dely` | `apps/dely` |

Descendre d'un niveau déplace tous les chemins relatifs. Ont suivi : les trois
`pubspec.yaml` (`path: ../../packages/elcorazon_core`), les trois
`analysis_options.yaml` (`include: ../../analysis_options.yaml`),
`tools/code_mort.py`, `tools/couverture.py`, le workflow CI — dont l'appel
`python ../tools/couverture.py` devenu `../../` — et 33 mentions dans la
documentation.

Deux choses à savoir pour la suite :

- `git mv` a échoué : sous Windows, le serveur de langage Dart de l'éditeur
  tient un descripteur sur les répertoires ouverts. Le contenu a été déplacé
  fichier par fichier ; git détecte les renommages au contenu, l'historique est
  préservé. Les trois répertoires d'origine restent en place, **vides**, jusqu'à
  ce que l'éditeur les relâche — git ne les suit pas ;
- il existe une seconde copie du workflow en `elcorazon/.github/workflows/`,
  hors du suivi git. Elle n'a pas été touchée.

---

## 5. Ce que je ne recommande pas

- **Toucher au backend.** 1276 tests, mypy strict, tests d'architecture. Rien à
  y refactorer, et le temps qu'on y passerait manque ailleurs.
- **Remonter la présentation dans le socle.** Écrans client, livreur et
  back-office n'ont pas les mêmes contraintes ; `04-migration-flutter.md` §2.2
  réserve délibérément cette couche aux applications.
- **Fusionner ce qui a divergé sous 80 %.** Une différence de 642 lignes entre
  deux `gamification_service` n'est pas de la duplication, c'est de la
  divergence — il faut la comprendre avant de l'effacer.
- **Réécrire les applications.** Elles fonctionnent, elles sont vertes, et ce qui
  reste après le lot 1 est du code vivant.

---

## 6. Risques

| Risque | Lot | Parade |
|---|---|---|
| Régression invisible faute de tests | 3, 4 | 113 tests pour 99 573 lignes : le filet **n'existe pas**. Test avant migration, jamais après |
| `flutter analyze` valide à tort | tous | Vérifié empiriquement au lot 1 : `admin` a compilé faux sur un `web_plugin_registrant.dart` généré que `pub get` ne régénère pas. **`flutter clean` puis `flutter build`** |
| Suppression en cascade | 2, 3 | Retirer `cart_service.dart` a rendu `models/cart_item.dart` injoignable. Boucler `tools/code_mort.py` jusqu'au point fixe |
| Le lot 3 s'étale, les deux piles coexistent un an | 3 | Un domaine se termine avant que le suivant commence. Un domaine à moitié migré est pire que pas migré |
| Le changement d'affichage des prix surprend | 2.2 | Visible pour l'utilisateur. À annoncer, pas à glisser |

---

## 7. Séquence

```
Lot 2   ▓▓                                      fait    déduplication finie
Lot 5   ▓▓                                      fait    outillage durci
Lot 3     ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓        3-4 sem  pile héritée démontée
Lot 4          ▓▓▓▓▓▓▓▓▓▓▓▓▓▓                   2 sem   écrans découpés (parallèle)
Lot 6                                    ▓▓     2 j     documentation
```

**Les lots 2 et 5 sont faits.** Le lot 5 a coûté davantage qu'une journée —
l'alignement des règles a révélé 1 368 diagnostics là où 56 étaient annoncés —
mais il a rendu mesurable tout ce qui suit : quatre paquets à zéro diagnostic,
une CI qui refuse le moindre écart, aucune trace en production, et un plancher
de couverture qui ne peut que monter.

Reste **environ 5 semaines**, dominées par le lot 3. C'est le seul qui demande
un arbitrage de calendrier.
