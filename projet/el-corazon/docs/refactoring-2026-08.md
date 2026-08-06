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

| Composant | Fichiers | Code | Tests | `flutter analyze` |
|---|---:|---:|---:|---:|
| `backend/` | 314 | 29 676 l. | **1276 passés** | ruff + mypy strict, verts |
| `packages/elcorazon_core` | 77 | 8 008 l. | **161 passés** | **0** |
| `El Corazon admin` | 76 | 35 462 l. | 42 passés | 1 info |
| `El Corazon fastfood` | 135 | 46 916 l. | 62 passés | 9 infos |
| `El corazon dely` | 48 | 17 195 l. | 9 passés | 46 infos |

Zéro erreur, zéro avertissement partout. `flutter build web` aboutit sur les
trois applications. `tools/code_mort.py` sort à 0 et bloque la CI.

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
dont 5 dépassent 1 500 :

| Fichier | Lignes |
|---|---:|
| `admin/…/advanced_order_management_screen.dart` | 3 070 |
| `fastfood/…/cake_order_screen.dart` | 2 886 |
| `admin/…/order_management_screen.dart` | 2 531 |
| `admin/…/gamification_management_screen.dart` | 1 744 |
| `fastfood/…/delivery_tracking_screen.dart` | 1 589 |

400 `setState` au total. Aucun écran n'appelle le réseau directement — la
frontière écran ↔ données tient, c'est ce qui rend la découpe faisable.

### 3.3 Le déséquilibre des tests, aggravé en proportion

```
backend            29 676 l.  ←→  1276 tests
elcorazon_core      8 008 l.  ←→   161 tests
les 3 applications 99 573 l.  ←→   113 tests
```

`dely` a **9 tests pour 17 195 lignes**. C'est le filet qui manque pour le lot 4.

### 3.4 L'outillage est inégal

`dely` n'active **aucune** règle de lint (`linter: rules:` vide), `admin` en
active 7, `fastfood` 53. D'où la répartition des 56 diagnostics : 46 sur `dely`,
9 sur `fastfood`, 1 sur `admin`. Ce n'est pas que `dely` soit moins soigné,
c'est qu'on ne lui demande rien.

681 `debugPrint` subsistent (contre 1 009 avant le lot 1). Contrairement à
`print`, `debugPrint` **s'exécute en production**.

---

## 4. Les lots restants

### Lot 2 — Finir la déduplication (2 jours) — *entamé*

**2.1 fait** (`f803e4f`) : la règle d'affichage des montants vit dans
`Money.format()` / `formatPrice()`, testée. Les trois applications rendaient des
prix différents pour la même commande — « 12.500 CFA » côté client, « 12 500 CFA »
côté back-office — et la version client n'avait aucune garde (`format(-500)`
rendait « -.500 CFA »).

**2.2 — brancher les applications dessus.** Les trois `price_formatter.dart`
deviennent des délégations d'une ligne, ce qui laisse les 138 points d'appel
intacts. Ils disparaîtront d'eux-mêmes au lot 3, quand les écrans manipuleront
des `Money`. ⚠️ **Changement visible** : le client et le livreur passeront de
« 12.500 CFA » à « 12 500 CFA ». C'est la correction, mais elle se voit.

**2.3 — les six autres paires.** `promo_code_service` + `promo_code` (98 % et
96 %, fast/dely) et `directions_service` (86 %) sont du domaine : ils vont dans
le socle, avec leurs tests. `loading_widget` et `custom_text_field` (96 % et
93 %, admin/dely) sont de la présentation : le socle **ne doit pas** les
prendre — `04-migration-flutter.md` §2.2 réserve la présentation aux
applications. Les laisser divergents est le bon choix ; ce qu'on peut faire,
c'est aligner `dely` sur `admin` par copie et s'arrêter là.

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

### Lot 4 — Découper les écrans (2 semaines, parallélisable au lot 3)

Les 5 écrans de plus de 1 500 lignes, dans l'ordre du tableau §3.2. Pour
chacun : extraire les sous-vues en widgets nommés, sortir la logique dans un
provider, écrire le test sur cette logique.

Le critère n'est pas un nombre de lignes : **le comportement métier de l'écran
est-il atteignable par un test sans monter l'arbre de widgets ?** Tant que la
réponse est non, la découpe n'est pas finie.

### Lot 5 — Durcir l'outillage (1 jour) — *à faire maintenant, pas à la fin*

Remonté avant le lot 3 dans cette révision : il coûte une journée et rend
mesurable tout ce qui suit.

1. Donner à `dely` le jeu de règles de `fastfood`, et à `admin` aussi. Traiter
   les diagnostics que ça révèle.
2. Retirer `--no-fatal-infos` de la CI Flutter. La justification écrite dans le
   workflow — « les trois applications traînent des info de style sur des écrans
   que la migration n'a pas encore touchés » — **est périmée** : il en reste 56,
   dont 46 dus au seul fait que `dely` n'active aucune règle.
3. Les 681 `debugPrint` : un journaliseur qui se tait en production, et vérifier
   au passage qu'aucun ne rend un jeton ou une adresse.
4. Un plancher de couverture sur les applications, bas au départ, relevé à
   chaque domaine migré au lot 3.

### Lot 6 — Documentation (2 jours, en dernier)

1. Trancher sur `CAHIER_DES_CHARGES.md` (928 l.) et `ETAT_FONCTIONNALITES.md`
   (755 l.), rédigés pour l'architecture Supabase et qui s'ouvrent tous deux sur
   un avertissement disant qu'ils sont faux. **Archiver** est cohérent avec ce
   qui a été fait du backend Laravel.
2. `SCHEMA_BDD_COMPLET.md:1251` renvoie vers `lib/database/`, supprimé au lot 1.
3. Sortir de `lib/services/` les sept `README_*.md` survivants.
4. Renommer `El corazon dely` → `El Corazon dely`, et retirer les espaces des
   trois répertoires. À faire en une opération isolée : cela touche les deux
   workflows CI. C'est l'espace non échappé qui avait produit l'arborescence
   parasite `El/ Corazon/ dely/build/` supprimée au lot 1.

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
Lot 2   ▓▓                                      2 j    déduplication finie      (2.1 fait)
Lot 5   ▓                                       1 j    outillage durci
Lot 3     ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓        3-4 sem  pile héritée démontée
Lot 4          ▓▓▓▓▓▓▓▓▓▓▓▓▓▓                   2 sem   écrans découpés (parallèle)
Lot 6                                    ▓▓     2 j     documentation
```

**Environ 5 semaines**, contre 7 à la révision 1 — le lot 1 a coûté moins cher
que prévu et rendu le lot 2 presque sans objet.

Les lots 2 et 5 sont sans risque fonctionnel et peuvent partir immédiatement. Le
lot 3 est le seul qui demande un arbitrage de calendrier.
