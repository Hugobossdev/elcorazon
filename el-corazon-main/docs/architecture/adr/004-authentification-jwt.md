# ADR-004 — Authentification JWT

**Statut** : accepté · **Date** : 2026-07-25

## Contexte

L'authentification actuelle repose sur Supabase Auth, appelé directement par les trois apps Flutter.
La v2 rapatrie l'identité côté Django : le backend doit être la seule autorité, y compris sur qui
est connecté.

Deux faiblesses avérées de l'existant doivent être fermées par conception :

- **T1** — aucune limitation de débit sur `/auth/login`, brute-force ouvert ;
- **T2** — un changement de mot de passe ne révoquait pas les sessions ouvertes ailleurs.

La mission impose JWT avec *refresh token*.

## Décision

`djangorestframework-simplejwt` avec la configuration suivante :

| Paramètre | Valeur | Raison |
|---|---|---|
| Durée du jeton d'accès | **15 min** | Fenêtre d'exploitation courte en cas de fuite |
| Durée du jeton de rafraîchissement | **30 jours** | Un livreur ne doit pas se reconnecter en tournée |
| Rotation au rafraîchissement | **activée** | Chaque usage produit un nouveau couple |
| Mise en liste noire de l'ancien | **activée** | Rejouer un jeton consommé est détecté |
| Algorithme | **RS256** | Clé publique vérifiable par un futur service tiers sans partager le secret |
| Revendications | `sub`, `role`, `jti`, `exp`, `iat` | `role` évite une requête par appel |

### Points d'entrée

```
POST /api/v1/auth/register/          POST /api/v1/auth/token/refresh/
POST /api/v1/auth/login/             POST /api/v1/auth/logout/
POST /api/v1/auth/password/change/   POST /api/v1/auth/password/reset/
POST /api/v1/auth/otp/verify/        GET  /api/v1/auth/me/
```

### Réponses aux faiblesses identifiées

- **T1** — limitation à deux niveaux sur `/auth/*` : par IP (20/min) **et** par identifiant tenté
  (5/min). Le second niveau est celui qui compte : sans lui, un attaquant distribué contourne le
  premier. Compteurs en Redis, réponse `429` avec `retry_after`.
- **T2** — un changement de mot de passe met en liste noire **tous** les jetons de rafraîchissement
  de l'utilisateur, sauf celui de la session courante. Même traitement lors d'une désactivation de
  compte ou d'un changement de rôle.

### Appareils et push

Les jetons FCM vivent dans une table `devices` distincte, liée à l'utilisateur et non à la session :
un jeton d'accès expire toutes les 15 minutes, un appareil doit rester joignable. L'enregistrement
d'un appareil est un `upsert` par jeton, ce qui réattribue correctement un téléphone qui change de
compte.

## Conséquences

- Le serveur reste sans état pour la vérification d'accès, mais **pas** pour la révocation : la liste
  noire exige une lecture base ou cache au rafraîchissement. C'est le prix de la révocabilité, et il
  est payé une fois par quart d'heure et par utilisateur, pas à chaque appel.
- La rotation des clés RS256 doit être outillée dès le départ (deux clés acceptées en vérification,
  une seule en signature) — sinon une rotation devient une déconnexion générale.
- Le `role` embarqué dans le jeton peut être périmé jusqu'à 15 minutes après un changement. Acceptable
  pour une montée en privilège (le changement de rôle révoque les jetons) ; les décisions sensibles
  relisent la base.

## Alternatives écartées

| Alternative | Raison du rejet |
|---|---|
| Jetons opaques en base (style Sanctum) | Une lecture base à chaque appel. Simple, mais c'est le point chaud garanti sous charge. |
| Sessions Django + cookies | Mal adapté à des clients mobiles multi-plateformes ; expose au CSRF et complique le partage entre les trois apps. |
| Conserver Supabase Auth | Maintient une seconde autorité d'identité hors du backend — exactement ce que la v2 supprime. |
| HS256 | Suffisant aujourd'hui, mais impose de partager le secret avec tout vérificateur futur. RS256 ne coûte presque rien de plus maintenant, et beaucoup moins à migrer plus tard. |
