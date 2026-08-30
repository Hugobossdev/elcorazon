# Audit — troisième lot Stitch (adresses et commandes)

> Source : `stitch_el_coraz_n_client_ui_redesign (2).zip` — **6 maquettes**.
> Cible : `apps/fastfood` (paquet `elcora_fast`), branche `redesign-client-ui`.
> Établi le 2026-08-30, **avant toute modification de code**.

Ce lot achève la couverture : avec les deux précédents (15 + 14 maquettes),
l'application cliente est intégralement redessinée.

Point de restauration : l'arbre de travail était **propre** avant de commencer
(`git status` vide, HEAD sur `de6fe7d`). Aucun `git reset` n'a été employé, ni
ne le sera.

---

## 0. Le système de design, une troisième fois

```
diff stitch/DESIGN.md  stitch3/DESIGN.md  →  aucune différence
```

`DESIGN.md` est **identique octet pour octet** aux deux archives précédentes.
Il n'y a donc, une fois de plus, **aucun système de design à créer** : la
palette, l'échelle typographique, les espacements et les seize composants de
`lib/widgets/design/` s'appliquent tels quels.

C'est exactement le cas que §4 du cahier des charges anticipe — « NE CRÉE PAS
un nouveau design system complet si le projet possède déjà un système
équivalent ». Ce lot est un travail d'écrans, rien d'autre.

---

## 1. Architecture existante (rappel, inchangée)

```
main.dart
 ├── ProviderContainer (Riverpod)  → session, ApiClient, TokenStorage
 ├── MultiProvider (provider)      → services ChangeNotifier
 └── MaterialApp → onGenerateRoute → AppRouter (33 routes nommées)
```

| Couche | Emplacement |
|---|---|
| Écrans | `lib/screens/` |
| Composants du design system | `lib/widgets/design/` (16 briques) |
| Vocabulaire d'affichage | `lib/presentation/` |
| Services (`ChangeNotifier`) | `lib/services/` |
| Adaptateurs | `lib/repositories/` |
| Socle partagé | `packages/elcorazon_core` |

**Gestion d'état** : `provider` pour les écrans, `flutter_riverpod` pour la
session et l'`ApiClient`. **Aucune migration ne sera faite** — l'interdiction
du cahier des charges rejoint l'état des lieux.

**Navigation** : `Navigator` + routes nommées. Un seul système. Les routes
concernées par ce lot existent déjà et **ne changeront pas** :
`AppRouter.addressManagement`, `AppRouter.addressSelector`,
`AppRouter.enhancedOrders`, `AppRouter.orders`.

**Stockage local** : `shared_preferences` (cache du carnet d'adresses,
panier, drapeau d'onboarding), `sqflite` (notifications). Inchangé.

---

## 2. Matrice écran par écran

| Maquette Stitch | Écran Flutter actuel | Lignes | Logique actuelle | Action |
|---|---|---|---|---|
| `address_management` | `client/address_management_screen.dart` | 726 | `AddressService`, `LocationService` | refonte UI |
| `address_details` | `client/address_detail_bottom_sheet.dart` | 915 | `AddressService`, `PlacesService`, `GeocodingService`, `DeliveryFeeService`, `DjangoAddressRepository` | refonte UI |
| `select_address` | `client/address_selector_screen.dart` | 298 | `AddressService` | refonte UI |
| `set_location_on_map` | `client/address_map_picker_screen.dart` | 770 | Google Maps, `LocationService`, `GeocodingService`, `PlacesService`, `DeliveryFeeService` | refonte UI **prudente** |
| `my_orders` | `client/orders_screen.dart` | 186 | `AppService` | **déjà à la nouvelle charte** (lot 1) — écarts seulement |
| `order_history` | `client/enhanced_orders_screen.dart` | 762 | `OrderHistoryService`, `CartService`, `DjangoOrderRepository` | refonte UI |

### Détail par écran

#### `address_management` → `address_management_screen.dart`

```
UI      → recherche, tri, filtres, statistiques, liste, actions par adresse
Données → AddressService (carnet en mémoire + cache SharedPreferences)
Modèle  → eccore.Address · TypeAdresse (presentation/adresse.dart)
API     → GET/POST/PATCH/DELETE /accounts/addresses/
Route   → AppRouter.addressManagement
```

**À conserver** : récupération, sélection, modification, suppression, adresse
par défaut, favoris, tri, recherche, actualisation, état déconnecté.
**32 couleurs hors palette** à reprendre.

#### `address_details` → `address_detail_bottom_sheet.dart`

```
UI      → feuille de saisie : libellé, type, destinataire, rue, repère,
          consignes, position, aperçu des frais
Données → AddressService.addAddress / updateAddress (BrouillonAdresse)
Modèle  → eccore.Address · BrouillonAdresse
API     → POST/PATCH /accounts/addresses/ · POST /orders/preview/ (frais)
Route   → aucune (feuille modale ouverte depuis la gestion)
```

**À conserver** : création, modification, validation, sauvegarde, adresse par
défaut, autocomplétion Places, géocodage inverse, aperçu des frais.
**23 couleurs hors palette.**

#### `select_address` → `address_selector_screen.dart`

```
UI      → liste des adresses, sélection, retour de l'adresse choisie
Données → AddressService
Modèle  → eccore.Address
API     → GET /accounts/addresses/
Route   → AppRouter.addressSelector (rappel `onAddressSelected`)
```

**À conserver** : sélection, adresse courante, récupération, navigation vers
la carte, retour, comportement sans adresse.

La maquette ajoute deux blocs — « Use current location » et « Recent
Places » — traités au §4.

#### `set_location_on_map` → `address_map_picker_screen.dart`

**Écran sensible.** La maquette montre une carte **fictive** (un `div` avec une
image de fond). Elle ne remplacera pas `GoogleMap`.

```
UI      → carte plein écran, recherche, bouton « ma position », carte basse
          d'adresse résolue, confirmation
Données → GoogleMap · Geolocator · GeocodingService · PlacesService ·
          DeliveryFeeService
Modèle  → LatLng · eccore.Address · devis de livraison
API     → Google Maps/Places/Geocoding · POST /geography/zones/resolve/ ·
          POST /orders/preview/
Route   → aucune (poussée depuis la feuille de détail)
```

**Intouchable** : Google Maps, Geolocator, permissions, position courante,
sélection d'un point, géocodage inverse, adresse retenue, sauvegarde, retour.
La refonte se limitera au **chrome** : barre flottante, carte basse, bouton de
confirmation.

#### `my_orders` → `orders_screen.dart`

**Déjà à la nouvelle charte** (refait au lot 1). La maquette confirme le
parti pris — deux onglets « Active / Past », cartes de commande, barre
inférieure — et ajoute **« Reorder »** sur les commandes passées, traité au §4.

#### `order_history` → `enhanced_orders_screen.dart`

```
UI      → onglets En cours / Historique, filtres, cartes détaillées, recommande
Données → OrderHistoryService · CartService · DjangoOrderRepository
Modèle  → Order · OrderItem
API     → GET /orders/ · POST /carts/{slug}/lines/ (recommande)
Route   → AppRouter.enhancedOrders
```

**À conserver** : historique, statuts, filtres, tri, recommande
(`_reorderItems`, ligne 518), navigation, chargement, erreurs, listes vides.
**32 couleurs hors palette.**

La maquette ajoute une **mini-chronologie** sur la commande en cours (Prep · On
the way · Delivered) et une **note par commande** — voir §4.

---

## 3. Composants réutilisables déjà disponibles

Aucun à créer *a priori*. Les seize briques de `lib/widgets/design/` couvrent
l'essentiel :

```
GlassAppBar · GlassBottomBar · GlassIconButton · SegmentedTabs
SectionCard · SectionHeader · StatusChip · SummaryRow · SummaryDivider
ActionButton · SearchField · FoodImage · RatingBadge · RatingStars
AppreciationChips · QuantityStepper · Skeleton · FoodCardSkeletonList
```

Plus les états partagés : `PageLoadingWidget`, `ErrorWidget`,
`EmptyStateWidget` (`lib/widgets/loading_widget.dart`).

Et la chronologie de commande, déjà factorisée au lot 2 :
`presentation/suivi_commande.dart` — `etapesDeSuivi()`, quatre jalons. C'est
exactement la mini-chronologie que `order_history` dessine.

**Un seul composant manque** : la carte d'adresse. `lib/widgets/address_card.dart`
existe (591 lignes) mais est à l'ancienne charte ; il sera repris plutôt que
doublé.

---

## 4. Divergences maquette ↔ produit

| # | Maquette | Élément | Constat | Décision |
|---|---|---|---|---|
| A | `select_address` | « Recent Places » | Aucun historique de lieux n'est conservé : `AddressService` tient le carnet, pas les recherches | **Non dessiné.** Besoin backend ou stockage local à décider — consigné |
| B | `select_address`, `set_location_on_map` | « Use current location » / « Enable GPS » | `LocationService` et Geolocator existent déjà | **Repris**, branché sur l'existant |
| C | `my_orders`, `order_history` | « Reorder » | `_reorderItems` existe dans `enhanced_orders_screen` (ligne 518) | **Repris** ; à étendre à `orders_screen` si la logique se factorise sans risque |
| D | `order_history` | Note par commande (« ★ 4.8 ») | `Order` ne porte pas de note ; les avis sont **par article** (`Review.menuItemId`) | **Non dessiné.** Une note de commande n'existe pas — l'afficher demanderait de l'inventer |
| E | `address_management` | Téléphone sur la carte d'adresse | `Address.recipientPhone` **existe** | **Repris** |
| F | `address_management` | « Drop at reception » | `Address.deliveryInstructions` **existe** | **Repris** |
| G | toutes | Copie « Abidjan, Côte d'Ivoire » | L'établissement est à **Lomé** (`AppConstants.defaultCityName`) | Villes réelles, jamais la copie de la maquette |
| H | `my_orders`, `order_history` | Barre inférieure **Rewards** en 3ᵉ place | L'application a **Commandes** ; décision déjà prise au lot 2 | Inchangée |
| I | `address_details` | Titre « Address Details » sur fond blanc plein écran | L'écran est une **feuille modale** dans l'application, pas une page | Feuille conservée : elle garde le contexte de la liste dessous |

---

## 5. Défauts déjà visibles à l'audit

Relevés en lisant le code, avant modification :

| # | Défaut | Fichier |
|---|---|---|
| 1 | `TypeAdresse` porte `Colors.green`, `Colors.blue`, `Colors.orange` — trois couleurs hors palette, au cœur du **vocabulaire d'affichage** partagé par les quatre écrans d'adresse | `presentation/adresse.dart` |
| 2 | 99 couleurs brutes cumulées sur les cinq écrans à reprendre | — |
| 3 | `_showSnack(String, Color)` impose une couleur à l'appelant plutôt que de nommer une intention | `address_management_screen.dart` |

---

## 6. Ordre d'exécution retenu

```
1. presentation/adresse.dart   (les trois couleurs, en amont des quatre écrans)
2. widgets/address_card.dart   (la brique que trois écrans partagent)
3. address_management          4. address_details
5. select_address              6. set_location_on_map  ← prudence maximale
7. order_history               8. my_orders (écarts)
9. flutter analyze + flutter test après chaque écran
```

Ce qui n'est **pas** touché : backend, base, contrat d'API, modèles métier,
services, gestion d'état, navigation, dépendances, Firebase, Google Maps,
Geolocator, PayDunya, et le nom **El Corazón**.
