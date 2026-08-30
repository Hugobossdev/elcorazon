# Rapport final — intégration du design Stitch dans le client El Corazón

> Cible : `apps/fastfood` (paquet `elcora_fast`).
> Branche : `redesign-client-ui`.
> Source : `stitch_el_coraz_n_client_ui_redesign.zip` — 15 maquettes +
> `el_coraz_n_mobile/DESIGN.md`.
> Achevé le 2026-08-30.

Documents liés : [`UI_REDESIGN_AUDIT.md`](UI_REDESIGN_AUDIT.md) (mapping écran
par écran) · [`UI_REDESIGN_ISSUES.md`](UI_REDESIGN_ISSUES.md) (16 problèmes
recensés).

---

## Résultat des vérifications

```
flutter analyze              aucun problème
flutter test                 226 tests, tous verts  (196 au départ, +30)
flutter build web --release  succès (exit 0)
```

La compilation est vérifiée en plus de l'analyse : `flutter analyze` ne visite
pas le code qu'aucun chemin n'atteint, et un écran peut analyser proprement
sans se construire. Les seuls avertissements du build sont les
incompatibilités WebAssembly de `flutter_secure_storage_web` — antérieures à
cette phase et sans rapport avec elle.

---

## 1. Écrans intégrés

Les 15 maquettes livrées, dans leur ordre de dépendance.

| # | Maquette Stitch | Écran Flutter | État |
|---|---|---|---|
| 1 | `splash_screen` | `screens/splash_screen.dart` | ✓ |
| 2 | `welcome_screen` | `screens/guest_welcome_screen.dart` | ✓ |
| 3 | `home_screen` | `screens/client/client_home_screen.dart` | ✓ |
| 4 | `product_detail` | `screens/client/enhanced_item_customization_screen.dart` | ✓ (repris) |
| 5 | `product_reviews` | `screens/client/product_reviews_screen.dart` | ✓ |
| 6 | `enhanced_customization` | même écran que 4 | ✓ |
| 7 | `item_customization` | même écran que 4 | ✓ |
| 8 | `cake_order` | `screens/client/cake_order_screen.dart` | ✓ (refait) |
| 9 | `promo_codes` | `screens/client/promo_codes_screen.dart` | ✓ |
| 10 | `my_cart` | `screens/client/cart_screen.dart` | ✓ |
| 11 | `checkout` | `screens/client/checkout_screen.dart` | ✓ |
| 12 | `payment` | `screens/client/payment_screen.dart` | ✓ |
| 13 | `group_order` | `screens/client/group_order_screen.dart` | ✓ |
| 14 | `split_bill` | `screens/client/shared_payment_screen.dart` | ✓ |
| 15 | `payment_status` | `screens/client/group_payment_status_screen.dart` | ✓ |

**Trois maquettes, un écran.** `product_detail`, `item_customization` et
`enhanced_customization` décrivent toutes une page unique qui défile, avec la
même colonne d'options. Elles sont servies par le même écran, et non par trois :
le découpage en onglets qui existait auparavant cachait un groupe
**obligatoire** derrière un onglet fermé, et l'on butait sur un bouton sans
voir ce qui manquait.

### Écrans hors maquette, repris pour la cohérence de navigation (§20)

| Écran | Pourquoi |
|---|---|
| `orders_screen` | onglet 3 de la barre inférieure redessinée |
| `profile_screen` | onglet 4 |
| `notifications_screen` | atteint par la cloche de l'accueil |
| `delivery_status_card` | la carte que l'onglet « Commandes » répète |
| `recapitulatif_gateau` | le bloc de tête de la commande sur mesure |

Les dix-huit écrans encore à l'ancienne charte — carnet d'adresses, suivi de
livraison, récompenses, support… — sont listés dans ISSUE-016 avec leur ordre
de priorité. Ils sont fonctionnels ; ils ne sont pas redessinés.

---

## 2. Système de design

Aucune valeur du design system n'est écrite dans un écran.

| Fichier | Contenu |
|---|---|
| `lib/theme.dart` | `AppColors` (palette Material 3 complète, graine `#b91c24`), `LightModeColors`, `DarkModeColors`, `FontSizes`, `AppTypography` (8 rôles Inter) |
| `lib/utils/design_constants.dart` | espacements 4/8/16/24/32, `edgeMargin` 16, `gutter` 12, rayons 8/12/16/24, élévations 2/4/8 dp, ombres chaudes `#1A1A1A`, durées et courbes, points de rupture |

Le fichier unique plutôt que les sept fichiers suggérés par le cahier des
charges (`app_colors.dart`, `app_spacing.dart`…) : les jetons y étaient déjà,
documentés et lus par toute l'application. Les éclater en sept aurait produit
un très grand diff sans changer une seule valeur, et cassé tous les imports
existants.

### Palette sombre

`DESIGN.md` n'en livre pas. Elle est dérivée selon les correspondances
Material 3 (`primary` sombre = `inversePrimary` clair, etc.), avec la surface
`#1A1A1A` que la prose du design system nomme explicitement — un neutre M3,
plus froid, aurait verdi les photos de plats.

---

## 3. Composants réutilisables

`lib/widgets/design/`, exportés par `design.dart` :

```
action_button.dart      ActionButton (primary | gradient | outlined | text)
food_card.dart          FoodCard
food_image.dart         FoodImage · ImageScrim · RatingBadge
glass_surface.dart      GlassAppBar · GlassBottomBar · GlassIconButton
option_tile.dart        OptionGroupCard · OptionRow · OptionChoiceChip
promo_banner.dart       PromoBanner · StatusChip
quantity_stepper.dart   QuantityStepper
search_field.dart       SearchField
section_card.dart       SectionCard · SectionHeader
segmented_tabs.dart     SegmentedTabs                      ← ajouté
skeleton.dart           Skeleton · FoodCardSkeleton · FoodCardSkeletonList
summary_row.dart        SummaryRow · SummaryDivider · StickySummaryBar
```

Les composants déjà en place et toujours justes — `MenuItemCard`,
`CartItemCard`, `LoadingWidget`, `ErrorWidget`, `EmptyStateWidget` — ont été
ré-habillés sur place plutôt que doublés : un second `EmptyStateWidget` aurait
divergé du premier au premier correctif.

**`SegmentedTabs`** est né dans l'écran gâteau puis extrait : trois écrans le
partagent désormais.

---

## 4. Fonctionnalités conservées

Rien n'a été retiré du domaine. Vérifié écran par écran :

**Authentification** — connexion, inscription, session restaurée au démarrage,
mode invité, déconnexion, jeton FCM enregistré et révoqué.

**Catalogue** — catégories, articles, recherche, recherche avancée, favoris,
recommandations, cache hors ligne.

**Personnalisation** — groupes d'options du catalogue avec leurs bornes
(`min_select` / `max_select`), instructions spéciales, validation locale
alignée sur `validate_selection`.

**Panier** — ajout, retrait, quantité, variantes, personnalisations,
synchronisation serveur, panier invité et panier de compte.

**Promotions** — code soumis au serveur (`POST /orders/preview/`), remise
appliquée au panier et au total.

**Règlement** — adresse, résolution de zone, options de livraison, notes,
récapitulatif, frais issus du devis serveur.

**Paiement** — **PayDunya intact**. Le client ouvre une demande
(`POST /payments/{id}/initiate/`) et lit son statut ; il ne le fait jamais
avancer — seul le webhook signé du prestataire le peut. Les quatre états
`SUCCESS` / `PENDING` / `FAILED` / `CANCELLED` viennent de
`Transaction.status`.

**Commande groupée et partage d'addition** — création, code, invitation,
convives, verrouillage, répartition calculée par le serveur, état réel de
chaque part.

**Livraison** — suivi temps réel, WebSocket, Google Maps, itinéraire,
évaluation du livreur.

**Notifications** — Firebase Messaging, historique serveur, marquage lu,
navigation depuis une notification.

**Divers** — Agora (appels), gamification, adresses, support, mode hors ligne
et synchronisation différée.

### Ce qui n'a pas été touché

Backend · base de données · contrat d'API · Firebase · Google Maps · PayDunya ·
Agora · nom du paquet (`elcora_fast`) · identifiant Android
(`com.elcorazon.fast`) · titre de l'application (`El corazon`) · assets de
marque.

**Aucun rebranding. Aucune occurrence de « Miadounou » (vérifié sur `lib/`,
`android/`, `ios/`, `web/`, `pubspec.yaml`, `docs/`).**

---

## 5. Fonctionnalités améliorées

| Amélioration | Écran |
|---|---|
| Étapes numérotées, tirées des groupes que le catalogue publie | Commande de gâteau |
| Bandeau ancré « total estimé + action », lisible pendant la composition | Commande de gâteau |
| Tirage vers le bas pour recharger, y compris sur liste vide | Commandes, catalogue de gâteaux, notifications |
| Note cliquable qui mène aux avis, là où elle était une pastille inerte sur la photo | Fiche produit |
| Puce « Populaire » — `isPopular` n'était affiché nulle part | Fiche produit |
| Indisponibilité annoncée **avant** la composition, et ajout grisé | Fiche produit |
| Partage d'une fiche texte (presse-papiers — voir ISSUE-005) | Fiche produit |
| Statut de commande en puce colorée par la palette, contour supprimé | Commandes |
| Modification du profil réellement enregistrée | Profil |
| Un filtre en double retiré | Notifications |
| Deux entrées de menu qui ouvraient le même écran, fusionnées | Profil |
| Feuille « Comment ça marche » : catalogue, sur mesure, délai de 24 h | Commande de gâteau |

---

## 6. Problèmes corrigés

Détail dans `UI_REDESIGN_ISSUES.md`.

| # | Problème | Portée |
|---|---|---|
| 001 | `Expanded` dans un `Wrap` : l'étape « créneau » levait à l'ouverture | Commande de gâteau |
| 002 | `OptionRow` réduisait l'intitulé à une colonne d'une lettre par ligne (961 px de haut, débordement de 34 px) | Fiche produit, gâteau |
| 003 | `StickySummaryBar` écrasait son action (débordement de 27 à 69 px) | **Panier, règlement**, gâteau |
| 004 | Fiche produit : `isAvailable` n'était pas lu | Fiche produit |
| 008 | « Profil mis à jour avec succès ! » sans le moindre appel | Profil |
| 009 | `substring(0, 8)` faisait tomber toute la liste des commandes | Commandes |
| 010 | Commandes remboursées et échouées classées « en cours » | Commandes |
| — | Photo d'une banque d'images extérieure pour le gâteau sur mesure | Commande de gâteau |
| — | Numéro de téléphone français en exemple, dans une application abidjanaise | Commande de gâteau |
| — | 38 couleurs hors palette (`Colors.green`, `grey.shade300`…) | Gâteau, commandes, notifications, profil |
| — | `require_trailing_commas` restant | `presentation/commande.dart` |

Les trois premiers ont été trouvés par les tests de mise en page ajoutés à
cette occasion, pas à l'œil : ils ne se produisent qu'aux extrémités — petit
téléphone, police système grossie. **002 et 003 touchaient des écrans que
cette phase ne devait pas rouvrir** — le panier et le règlement partagent ces
composants.

---

## 7. Problèmes backend

Ce que les maquettes dessinent et que l'API ne sait pas encore servir. **Rien
n'est simulé.**

| # | Manque | Route ou champ attendu |
|---|---|---|
| 011 | Protéines, glucides, lipides | `proteins_g`, `carbs_g`, `fats_g` sur `MenuItem` détail |
| 012 | Prix de référence barré | `compare_at_price`, ou promotions exposées par article |
| 013 | Catalogue d'offres promotionnelles côté client | `GET /promotions/available/` |
| 014 | Téléversement d'une image de référence pour un gâteau | route de dépôt média authentifiée, bornée en taille et en type |
| 015 | Photos et votes d'utilité sur les avis | pièces jointes sur `Review`, table de votes |
| 006 | Nom du livreur pour l'évaluation | nom sur `OrderSerializer`, ou lecture de la course |
| 007 | Politique de confidentialité, CGU, évaluation en boutique | documents à une URL stable ; `in_app_review` |

Aucun de ces manques n'empêche l'application de fonctionner. Chacun retire un
élément **décoratif ou secondaire** d'une maquette, et aucun n'a été remplacé
par une valeur inventée.

---

## 8. Responsive

`test/debordement_test.dart` monte les composants **avec les contraintes
réelles des écrans de production**, sur cinq largeurs et deux échelles de
texte :

```
320 × 640    petit téléphone
360 × 740    téléphone courant
412 × 915    grand téléphone
768 × 1024   tablette
1280 × 800   navigateur de bureau
        × texte 1,0 et 1,3
```

Rien n'y est asserté : un débordement lève de lui-même et fait échouer le cas.
L'assertion, c'est le rendu. Le groupe « Commande de gâteau » ajoute 30 cas —
étape numérotée, couple date/heure, bandeau ancré.

Les mesures sensibles se font au `TextPainter` avec le `textScaler` de la vue,
jamais à un seuil en pixels codé en dur : un seuil deviné ne survit pas au
réglage « très grand » d'Android, comme ISSUE-002 l'a montré.

---

## 9. Ce qui reste

1. **ISSUE-016** — dix-huit écrans hors maquette encore à l'ancienne charte.
   `rewards` et `delivery_tracking` d'abord : ce sont les plus visités.
2. **Les sept manques backend** du §7, à arbitrer par priorité produit.
3. **Deux vocabulaires de statut de commande** coexistent —
   `presentation/commande.dart` (8 valeurs, celles du serveur) et
   `models/order.dart` (10). La consolidation dépasse le périmètre d'une phase
   d'interface, mais elle est due.
4. **Validation visuelle sur appareil.** L'analyse, les 226 tests et la
   compilation web passent ; les captures écran par écran, maquette contre
   rendu, demandent un émulateur ou un téléphone — elles n'ont pas été prises
   ici.

---

## 10. Journal des commits

```
e199033  feat(ui): redesign cake order
ce93786  feat(ui): redesign product details, and hold the layouts that broke
def3938  feat(ui): harmonize the tabs the redesigned navigation reaches
```

Le système de design, les composants et onze des quinze maquettes venaient du
commit antérieur `15ebe32`. Cette phase a livré l'audit, la dernière maquette
manquante, les reprises de la fiche produit, la cohérence de navigation, les
correctifs de mise en page et la documentation.

Bilan sur le code (`lib/` et `test/`, hors documentation) :
**+2 841 / −3 621 lignes**, soit **780 lignes de moins** pour davantage de
fonctions et 30 tests de plus. L'essentiel du gain vient de la commande de
gâteau — 2 465 lignes ramenées à 1 687, en confiant aux composants partagés ce
qu'elle décorait à la main.
