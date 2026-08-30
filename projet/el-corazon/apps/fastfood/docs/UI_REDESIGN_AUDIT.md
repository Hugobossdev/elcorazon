# Audit d'intégration du design Stitch — application client El Corazón

> Source du design : `stitch_el_coraz_n_client_ui_redesign.zip`
> (15 maquettes + `el_coraz_n_mobile/DESIGN.md`).
> Cible : `apps/fastfood` (paquet `elcora_fast`), branche `redesign-client-ui`.
> Établi le 2026-08-30.

Ce document précède toute modification d'écran. Il répond à une seule
question : **pour chaque maquette Stitch, quel code existe déjà, et que
faut-il y toucher ?** Il ne propose rien — il constate.

---

## 0. Ce que l'audit a trouvé en arrivant

L'intégration n'est pas à faire de zéro. Le commit `15ebe32` porte déjà :

* le **système de design** — `lib/theme.dart` reprend la palette Material 3
  complète de `DESIGN.md` (graine `#b91c24`, rouge `#b51822`), l'échelle
  typographique à huit rôles (`AppTypography`), et
  `lib/utils/design_constants.dart` porte les espacements 4/8/16/24/32, les
  rayons 8/12/16/24, les trois élévations et les ombres chaudes (`#1A1A1A`)
  que le design system réclame ;
* la **bibliothèque de composants** `lib/widgets/design/` — 12 briques
  exportées par `design.dart` ;
* **13 des 15 maquettes** déjà portées.

L'audit porte donc surtout sur ce qui **manque** ou **diverge**.

### État de la base au moment de l'audit

```
flutter analyze : 1 info (require_trailing_commas, presentation/commande.dart:70)
flutter test    : 196 tests, tous verts
```

---

## 1. Correspondance des jetons de design

`DESIGN.md` → code. Aucune divergence relevée.

| Jeton Stitch | Valeur | Porté par |
|---|---|---|
| `primary` | `#b51822` | `AppColors.primary`, `LightModeColors.lightPrimary` |
| `primary-container` | `#d93537` | `AppColors.primaryLight` |
| `secondary` | `#715d00` | `AppColors.secondaryDeep` |
| `secondary-fixed-dim` | `#e4c44d` | `AppColors.secondary` |
| `tertiary` | `#9c4007` | `AppColors.tertiary` |
| `surface` … `surface-container-highest` | 6 niveaux | `AppColors.surface*` |
| `on-surface` / `on-surface-variant` | `#1c1b1b` / `#5b403e` | `AppColors.textPrimary` / `textSecondary` |
| `outline` / `outline-variant` | `#8f6f6d` / `#e4beba` | `AppColors.outline` / `outlineVariant` |
| `display-lg` … `price-display` | 8 styles Inter | `AppTypography.displayLg` … `priceDisplay` |
| `rounded` sm/DEFAULT/md/lg/xl | 4/8/12/16/24 | `DesignConstants.radius*` |
| `spacing` xs…xl, `edge-margin` 16, `gutter` 12 | 4/8/16/24/32 | `DesignConstants.spacing*`, `edgeMargin`, `gutter` |
| Élévation 2/4/8 dp, ombre `rgba(26,26,26,.08)` | — | `DesignConstants.shadowLow/Medium/High` |
| Glassmorphisme, flou 15–20 px, opacité 90 % | — | `AppColors.glass*`, `glassBlur = 18` |

**Palette sombre** : `DESIGN.md` n'en livre pas. `DarkModeColors` la dérive
selon les correspondances Material 3, avec la surface `#1A1A1A` que la prose
du design system nomme explicitement.

---

## 2. Mapping écran par écran

Format demandé :
`Stitch → Écran Flutter → Provider/Service → Repository → API → Modèle → Route`

### 2.1 `splash_screen`

```
splash_screen
 ↓ lib/screens/splash_screen.dart
 ↓ AppService · ErrorHandlerService · PerformanceService
 ↓ sessionReadyFuture (main.dart) → sessionProvider.restoreSession()
 ↓ rafraîchissement de jeton (TokenStorage), puis GET /accounts/me/
 ↓ Session · User
 ↓ AppRouter.splash = '/'
```

État : **porté**. Logo animé, halo dégradé, sous-titre « Fire-Grilled
Kitchen ». La séquence métier est intacte : session restaurée → `Home` si
connecté, `Welcome` sinon.

### 2.2 `welcome_screen`

```
welcome_screen
 ↓ lib/screens/guest_welcome_screen.dart
 ↓ AppService
 ↓ —
 ↓ —
 ↓ —
 ↓ rendu par MainNavigationScreen quand !isLoggedIn
```

État : **porté**. « Sign In » → `AppRouter.auth`, « Browse as Guest » →
onglet Menu.

### 2.3 `home_screen`

```
home_screen
 ↓ lib/screens/client/client_home_screen.dart
 ↓ AppService · AddressService · AIRecommendationService ·
   FavoritesService · NotificationDatabaseService
 ↓ DjangoMenuRepository · DjangoAddressRepository
 ↓ GET /catalog/categories/ · GET /catalog/items/ ·
   GET /accounts/addresses/ · GET /notifications/unread-count/
 ↓ Category · MenuItem · Address
 ↓ AppRouter.clientHome = '/client/home' (onglet 0)
```

État : **porté**. En-tête « Livrer à » + cloche, `SearchField`, bannière
promotionnelle dégradée, rail de catégories, sections « Populaires » /
« Suggestions » / « Favoris », barre inférieure translucide à badge panier.
Aucun plat en dur : tout vient de `AppService.menuItems`.

### 2.4 `product_detail` · 2.5 `item_customization` · 2.6 `enhanced_customization`

```
product_detail + item_customization + enhanced_customization
 ↓ lib/screens/client/enhanced_item_customization_screen.dart  (un seul écran)
 ↓ CustomizationService · CartService · FavoritesService
 ↓ DjangoMenuRepository · CartRepository
 ↓ GET /catalog/items/{id}/  ·  POST /carts/{slug}/lines/
 ↓ MenuItem · OptionGroup · MenuItemOption · CartItem
 ↓ AppRouter.itemCustomization = '/client/item-customization'
```

**Les trois maquettes sont fusionnées en une page qui défile.** Décision
antérieure, documentée dans l'en-tête du fichier, et fondée : les trois
maquettes montrent toutes une page unique, et le découpage en onglets cachait
un groupe **obligatoire** derrière un onglet fermé.

Les groupes d'options ne sont **pas** écrits en dur : ce sont les
`OptionGroup` de l'article, avec leurs bornes (`min_selections` /
`max_selections`), ce qui aligne la validation locale sur
`validate_selection` côté Django.

Divergences relevées avec `product_detail` — voir §4.

### 2.7 `cake_order`

```
cake_order
 ↓ lib/screens/client/cake_order_screen.dart
 ↓ CustomizationService · CartService · OfflineSyncService
 ↓ DjangoMenuRepository
 ↓ GET /catalog/items/?category=desserts · GET /catalog/items/{id}/ ·
   POST /carts/{slug}/lines/
 ↓ MenuItem · OptionGroup · CustomizationOption
 ↓ AppRouter.cakeOrder = '/client/cake-order'
```

État : **NON porté**. Seul écran de la liste resté à l'ancienne charte.
2 465 lignes, deux onglets `TabBar`, 38 couleurs hors palette
(`Colors.green`, `Colors.grey.shade300`…), commentaires morts hérités de
Supabase. C'est le chantier principal.

### 2.8 `product_reviews`

```
product_reviews
 ↓ lib/screens/client/product_reviews_screen.dart
 ↓ ReviewRatingService
 ↓ DjangoReviewRepository
 ↓ GET /catalog/reviews/?menu_item={id}
 ↓ Review · ProductRating
 ↓ AppRouter.productReviews = '/client/product-reviews'
```

État : **porté**. Synthèse (moyenne serveur `rating_average`, total
`rating_count`, répartition comptée localement sur les avis chargés),
histogramme 5→1, filtres, cartes d'avis.

### 2.9 `promo_codes`

```
promo_codes
 ↓ lib/screens/client/promo_codes_screen.dart
 ↓ CartService.appliquerCodePromo()
 ↓ DeliveryFeeService.quoteOrder
 ↓ POST /orders/preview/  { promo_code, address }
 ↓ OrderQuote (hasPromotion, promotionCode, discount)
 ↓ AppRouter.promoCodes = '/client/promo-codes'
```

État : **porté**. Le code est **validé par le serveur** : la remise affichée
est celle que `POST /orders/preview/` renvoie, jamais un calcul local.

### 2.10 `my_cart`

```
my_cart
 ↓ lib/screens/client/cart_screen.dart
 ↓ CartService · AppService
 ↓ CartRepository
 ↓ GET/POST/PATCH/DELETE /carts/{slug}/lines/ · POST /orders/preview/
 ↓ CartItem · Cart · OrderQuote
 ↓ AppRouter.cart = '/client/cart'
```

État : **porté**. Lignes avec personnalisations, `QuantityStepper`, encart
promo, `SummaryRow` (sous-total / livraison / remise / total), barre
translucide « Commander ».

### 2.11 `checkout`

```
checkout
 ↓ lib/screens/client/checkout_screen.dart
 ↓ CartService · AddressService · DeliveryFeeService · AppService
 ↓ DjangoAddressRepository · DjangoOrderRepository
 ↓ GET /accounts/addresses/ · POST /geography/zones/resolve/ ·
   POST /orders/preview/ · POST /orders/
 ↓ Address · DeliveryZone · OrderQuote · Order
 ↓ AppRouter.checkout = '/client/checkout'
```

État : **porté**. Adresse, options de livraison, moyen de paiement, notes,
promo, récapitulatif. Les frais viennent de `POST /orders/preview/` — aucune
localisation ni tarif codé en dur.

### 2.12 `payment`

```
payment
 ↓ lib/screens/client/payment_screen.dart
 ↓ DjangoOrderRepository (+ PaymentRepository du socle)
 ↓ PaymentRepository
 ↓ POST /payments/{orderId}/initiate/ · GET /payments/transactions/?order={id}
 ↓ CheckoutInstruction · Transaction (provider : paydunya | cash | wallet)
 ↓ AppRouter.payment = '/client/payment'
```

État : **porté**. **PayDunya conservé** : le client ouvre une demande et
**lit** son statut ; il ne le fait jamais avancer — seul le webhook signé du
prestataire le peut (`PaymentRepository`). Les quatre états
`SUCCESS/PENDING/FAILED/CANCELLED` sont rendus depuis `Transaction.status`.

### 2.13 `group_order`

```
group_order
 ↓ lib/screens/client/group_order_screen.dart
 ↓ GroupCartService · AppService · AddressService
 ↓ GroupCartRepository
 ↓ POST /group-carts/ · POST /group-carts/join/ ·
   POST/PATCH/DELETE /group-carts/{id}/lines/ ·
   POST /group-carts/{id}/lock/ · /confirm/ · /cancel/
   + WebSocket ws/group-carts/{id}/
 ↓ GroupCart · GroupCartLine · GroupCartParticipant
 ↓ AppRouter.groupOrder = '/client/group-order'
```

État : **porté**. Code de groupe copiable, partage, convives, verrouillage.

### 2.14 `split_bill`

```
split_bill
 ↓ lib/screens/client/shared_payment_screen.dart
 ↓ PaymentRepository (socle, lu directement)
 ↓ PaymentRepository
 ↓ POST /payments/{orderId}/split/ · GET /payments/shares/{token}/
 ↓ SplitPayment · SplitShare
 ↓ AppRouter.sharedPayment = '/client/shared-payment'
```

État : **porté**. Le partage est **calculé par le serveur** ; l'écran ne
répartit rien lui-même.

### 2.15 `payment_status` (« Group Payment Status »)

```
payment_status
 ↓ lib/screens/client/group_payment_status_screen.dart
 ↓ PaymentRepository (socle)
 ↓ PaymentRepository
 ↓ POST /payments/{orderId}/split/  (état des parts)
 ↓ SplitPayment · SplitShare
 ↓ AppRouter.groupPaymentStatus = '/client/group-payment-status'
```

État : **porté**. Compteur « n/m payé », total, reste dû, liste des convives
avec leur état réel. **Aucun état n'est deviné** : chaque part affiche ce que
le serveur dit d'elle.

---

## 3. Écrans hors périmètre Stitch, mais dans la navigation

Le design Stitch ne fournit pas de maquette pour ces écrans, alors que trois
d'entre eux sont des **onglets de la barre inférieure** redessinée. Ils
restent à l'ancienne charte et détonnent au premier coup d'œil.

| Écran | Atteint depuis | Charte |
|---|---|---|
| `orders_screen.dart` | onglet 3 de la barre | ancienne |
| `profile_screen.dart` | onglet 4 de la barre | ancienne |
| `notifications_screen.dart` | cloche de l'accueil | ancienne |
| `rewards_screen.dart` | accueil, profil | ancienne |
| `menu_screen.dart` | onglet 2 | **nouvelle** |
| `address_*`, `support`, `advanced_search`, `delivery_tracking`, `order_details`, `social_*`, `chat`, `call`, `*_rating` | divers | ancienne |

Les trois premiers sont traités dans cette phase (cohérence de navigation,
§20 du cahier de charges). Les autres sont recensés dans
`UI_REDESIGN_ISSUES.md`.

---

## 4. Divergences maquette ↔ contrat serveur

Ce que Stitch dessine et que l'API ne sait pas encore servir. **Rien n'est
simulé** : ces éléments sont soit omis, soit alimentés par ce qui existe.

| Maquette | Élément dessiné | Contrat actuel | Décision |
|---|---|---|---|
| `product_detail` | « Nutritional Info » : protéines, glucides, lipides | `MenuItem` ne porte que `calories` | Bloc omis ; besoin backend consigné |
| `product_detail` | Prix barré `10,000 ₣` → `8,500 ₣` | Aucun `compare_at_price` | Prix simple ; besoin backend consigné |
| `product_detail` | Bouton « share » | — | Implémentable côté client |
| `product_detail` | Puce « Popular » | `MenuItem.isPopular` **existe** | À afficher |
| `product_reviews` | « With Photos », `thumb_up 12` | `Review` n'a ni photo ni vote | Filtres restreints à ce qui existe |
| `home_screen` | Recherche vocale (`mic`) | `VoiceService` local | Hors périmètre de cette phase |
| `promo_codes` | Catalogue d'offres disponibles | `GET /promotions/` existe mais n'est pas exposé au client | Saisie de code seule ; besoin backend consigné |
| `split_bill` | Curseur « nombre de personnes » | `POST /payments/{id}/split/` accepte les parts | Compatible |
| `cake_order` | Image de référence (téléversement) | Aucun point d'entrée média client | Omis ; besoin backend consigné |

---

## 5. Ordre d'exécution retenu pour la suite

1. `cake_order` — seule maquette non portée ;
2. `product_detail` — écarts du §4 réalisables (puce « Popular », partage,
   accès aux avis) ;
3. cohérence de navigation — `orders`, `profile`, `notifications` ;
4. `flutter analyze` + `flutter test` ;
5. `UI_REDESIGN_ISSUES.md` et `UI_REDESIGN_FINAL_REPORT.md`.

Ce qui n'est **pas** touché, et ne doit pas l'être : backend, base, contrat
d'API, authentification, PayDunya, Firebase, Google Maps, panier, commandes,
notifications, nom et identité **El Corazón**.
