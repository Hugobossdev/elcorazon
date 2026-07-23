# Couche API REST (Phase B)

Client REST vers le **backend Laravel** (remplace progressivement les appels
directs `supabase_flutter`). Voir l'architecture cible dans le dépôt racine.

## Fichiers

| Fichier | Rôle |
|---|---|
| `api_client.dart` | Client HTTP singleton : base URL, jeton Bearer auto, décodage JSON, erreurs |
| `api_exception.dart` | Exception typée (message, statut, erreurs de validation Laravel) |
| `auth_api.dart` | Inscription / connexion / déconnexion / profil (Sanctum) |

## Configuration `.env`

Ajouter l'URL du backend Laravel :

```
# Émulateur Android → 10.0.2.2 ; iOS simulateur/desktop → localhost
BACKEND_URL=http://10.0.2.2:8000
# (optionnel) surcharge complète du préfixe API
# API_BASE_URL=https://api.elcorazon.app/api
```

`ApiConfig.apiBaseUrl` vaut `BACKEND_URL + /api` par défaut.

## Jeton Sanctum

Le jeton renvoyé par Laravel est **opaque** (ex. `12|abc…`), pas un JWT. Il est
donc stocké par `ApiClient` dans `FlutterSecureStorage` (clé `api_sanctum_token`),
**indépendamment** de `SecureTokenStorageService` (qui valide un format JWT
propre à Supabase). Ne pas mélanger les deux.

## Exemple d'intégration (écran de connexion)

```dart
final authApi = AuthApi();

try {
  final user = await authApi.login(email: email, password: password);
  // naviguer vers l'accueil, stocker l'utilisateur dans le provider…
} on ApiException catch (e) {
  final message = e.firstValidationError ?? e.message;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
```

Au démarrage, vérifier la session : `if (await AuthApi().isAuthenticated) { … }`
puis `final user = await AuthApi().me();`.

## Intégration actuelle (pont)

`AppService.login/register` conserve la connexion **Supabase**, puis appelle
`AuthApi().exchangeSupabaseToken(session.accessToken)` pour obtenir et stocker un
jeton **Sanctum** (endpoint `POST /auth/exchange` du backend). `AppService.logout`
purge ce jeton. Au démarrage, `_loadUserSession` régénère le jeton si besoin.

Ainsi, **rien n'est cassé** : les lectures Supabase directes continuent, et les
nouveaux services API disposent d'un jeton valide.

## Services par domaine

| Service | Statut | Branché dans |
|---|---|---|
| `AuthApi` | ✅ (via pont) | `AppService.login/register/logout` |
| `MenuApi` | ✅ (API-first + repli Supabase) | `MenuItemCacheService` (transparent pour les écrans) |
| `OrderApi` | ✅ lecture + création branchées (repli Supabase) | `AppService._loadUserOrders`, `placeOrderFromCartService` |
| `AddressApi` | ✅ CRUD branché (repli Supabase) | `AddressService` (load/create/update/delete) |
| `CartApi` | ✅ lecture + vidage branchés ; écriture via Supabase (même table) | `CartService` (`_loadCartFromDatabase`, `clearForLogout`) |

> ⚠️ **Montants sérialisés en nombres** : les casts Eloquent `decimal:2`
> renvoient des **chaînes** (`"1500.00"`), ce que les parseurs Flutter
> (`as num`) rejettent → prix/​totaux à `0` ou crash. Tous les casts monétaires
> du backend ont été passés en `float` pour renvoyer des **nombres JSON**,
> comme Supabase.

> ℹ️ **Panier** : `CartService` reste local-first ; l'écriture (`upsertUserCart`)
> passe encore par Supabase, mais écrit dans la **même table Postgres** que lit
> l'API (`user_cart_items`) — donc cohérent. La lecture et le vidage passent par
> l'API.

### OrderApi — création & frais de livraison

`OrderApi.createOrder` délègue le **calcul des montants au serveur** (source de
vérité) : on n'envoie que les articles (`menu_item_id`, `quantity`,
`customizations`), l'adresse (avec lat/lng) et le mode de paiement.

- **Frais de livraison** : calculés par le backend (`DeliveryFeeService`), qui
  réplique la règle de l'app (base 500 + 200/km, gratuit ≥ 10 000 FCFA ou VIP,
  max 5 000, arrondi à la dizaine). Le client ne les envoie plus.
- **Branchement** : dans `placeOrderFromCartService`, après le paiement, la
  commande est persistée via l'API (création + articles + promo en une
  transaction). En cas d'échec (API indisponible, `menu_item_id` inconnu…),
  repli automatique sur la persistance Supabase existante.
- **Devis** : `POST /delivery/quote` renvoie le frais exact pour l'affichage.

> Réserve : après création via API, `payment_status` reste au défaut serveur
> (`pending`) hors PayDunya (dont le webhook confirme). À affiner quand le flux
> de paiement passera aussi par le backend.

`MenuApi` est branché au **point de fetch unique** du cache
(`MenuItemCacheService`) : l'API Laravel est la source primaire, avec repli
automatique sur Supabase en cas d'erreur. Le cache et le mode hors-ligne restent
intacts, et **aucun écran n'a été modifié**.

## Prochaines étapes de migration

1. ✅ Pont d'authentification (jeton Sanctum obtenu via échange).
2. ✅ `MenuApi` branché sur le cache menu.
3. ✅ `OrderApi` : lecture + création branchées (serveur calcule les frais).
4. Brancher l'**annulation** (`OrderApi.cancelOrder`) puis `CartApi`, `AddressApi`…
4. Basculer l'auth en **Sanctum pur** (login/register via `AuthApi`) une fois les
   mots de passe migrés ou réinitialisés.
5. Une fois tout migré : retirer `supabase_flutter`, `database_service.dart`,
   l'endpoint `/auth/exchange` et les `.sql` de `lib/`.
