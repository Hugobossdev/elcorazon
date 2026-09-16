# 04 — Audit de sécurité

Revue des dix-huit points de la phase 30 du brief. Chaque ligne a été vérifiée
dans le code ; aucune n'est déduite de la documentation.

**Verdict d'ensemble : la posture est bonne, et par endroits meilleure que ce
qu'on rencontre à ce stade de maturité.** Aucune vulnérabilité exploitable n'a
été trouvée. Quatre points méritent une décision d'exploitation, aucun n'est un
correctif urgent. Les manques à venir sont ceux du domaine qui n'existe pas
encore — l'inventaire et la production, qui introduiront de nouvelles surfaces.

---

## 1. Ce qui tient structurellement

Trois mécanismes sortent de l'ordinaire et méritent d'être nommés, parce qu'ils
transforment une discipline en **impossibilité**.

### Aucune route ne peut être publiée sans permission

`backend/tests/architecture/test_layers.py` :

```
test_aucune_route_n_est_sans_permission
test_la_liste_des_routes_ouvertes_est_exactement_celle_declaree
test_les_vues_a_permissions_dynamiques_sont_declarees
```

La liste des routes ouvertes est **déclarée**, et la CI vérifie qu'elle
correspond exactement à la réalité. Ajouter une vue en oubliant sa permission ne
produit pas une faille discrète : ça casse le build.

C'est la réponse à l'oubli de permission, qui est la première cause de fuite de
données dans les API REST — et ici, il est inexprimable.

### Le graphe de dépendances est vérifié

```
test_aucune_dependance_hors_du_graphe
test_le_graphe_est_acyclique
test_accounts_ne_depend_d_aucune_app
test_un_modele_n_importe_ni_vue_ni_serialiseur
test_les_services_ne_connaissent_pas_le_transport
test_aucune_app_ne_contourne_common_pour_les_montants
```

Une app ne peut pas court-circuiter `common.money` pour manipuler des montants,
ni un modèle importer une vue. Les chemins d'écriture restent là où ils sont
audités.

### Les statuts sont contraints par la base

`state_check_constraint()` **génère** la contrainte `CHECK` PostgreSQL depuis la
table de transitions. Une écriture directe en base — `django-admin`, `shell`,
script de reprise — ne peut pas poser un statut que le code ignore. Le dernier
rempart n'est pas la revue de code, c'est le moteur.

---

## 2. Revue point par point (phase 30)

| # | Point | État | Preuve |
|---|---|---|---|
| 1 | Authentication | **Solide** | JWT **RS256** (asymétrique), accès 15 min, rafraîchissement 30 j, `ROTATE_REFRESH_TOKENS`, `BLACKLIST_AFTER_ROTATION` (`base.py:448-454`) |
| 2 | Authorization | **Solide** | ADR-005, `HasPermission` / `HasReadWritePermission`, permissions par rôle |
| 3 | RBAC | **Solide** | Type d'utilisateur (`CUSTOMER`/`COURIER`/`STAFF`) **séparé** des permissions — exactement la phase 19 du brief |
| 4 | Object-level permissions | **Solide** | `IsOwner.has_object_permission`, 247 tests de refus |
| 5 | IDOR | **Solide** | Identifiants **UUID** partout (`test_tout_modele_metier_porte_une_cle_uuid`) ; énumération impossible ; `get_queryset()` filtré par périmètre |
| 6 | CSRF | **Solide** | `CSRF_COOKIE_SECURE`, `CSRF_TRUSTED_ORIGINS` ; API en jeton porteur, sans cookie de session |
| 7 | XSS | **Solide** | API JSON, pas de gabarit rendu côté serveur ; `SECURE_CONTENT_TYPE_NOSNIFF`, `X_FRAME_OPTIONS = DENY` |
| 8 | SQL injection | **Solide** | ORM exclusivement ; aucun `raw()` ni `extra()` sur les chemins métier |
| 9 | Rate limiting | **Remarquable** | Voir §3 |
| 10 | CORS | **À arbitrer** | Voir §4, point A |
| 11 | Secrets | **Solide** | Voir §4, point B |
| 12 | Uploads | **Solide** | Compartiments publics / privés séparés (`common/storage.py:84-88`) |
| 13 | Signed URLs | **Solide** | Pièces d'identité, permis, cartes grises et preuves de livraison en `type=private`, jamais servis en direct ; chaque lecture exige une URL signée (`storage.py:354-362`) |
| 14 | WebSocket authorization | **Solide** | Jeton validé **avant** acceptation, puis contrôle de permission ; `CLOSE_UNAUTHENTICATED` / `CLOSE_FORBIDDEN` distincts (`common/consumers.py:51-59`) |
| 15 | Webhooks | **Solide** | Signature du **corps**, pas jeton porteur ; `WebhookEvent` idempotent ; `provider_reference` unique |
| 16 | File access | **Solide** | `delete_replaced_files` / `delete_files_of_deleted_row` — pas de fichier orphelin lisible après suppression |
| 17 | Logs | **Solide** | Identifiant de corrélation par requête ; aucun montant ni secret journalisé en clair |
| 18 | Sensitive data | **Solide** | Adresse **copiée** dans la commande, pas référencée : une suppression RGPD n'ébrèche pas l'historique comptable |

---

## 3. La limitation de débit mérite un paragraphe

`backend/common/throttling.py` fait une distinction que la plupart des projets
ne font pas : **que se passe-t-il quand le cache tombe ?**

```
FailOpenOnCacheOutage    →  CartWriteThrottle, ReviewWriteThrottle,
                            TrackingPingThrottle, Anon/User par défaut
FailClosedOnCacheOutage  →  OrderCreationThrottle, PaymentInitiationThrottle,
                            RewardRedemptionThrottle
```

Une panne Redis ne doit pas empêcher un client de garnir son panier — mais elle
ne doit pas **ouvrir** la création de commandes, l'initiation de paiements ni la
consommation de récompenses. Ce sont les trois chemins où un compteur absent se
traduit en perte d'argent.

Cette asymétrie est la bonne, et elle est rarement faite.

---

## 4. Les quatre points à arbitrer

Aucun n'est une vulnérabilité. Chacun appelle une décision.

### A. Le repli CORS `localhost` est actif par défaut en production

`config/settings/prod.py:119`

```python
CORS_ALLOW_LOCAL_DEV_ORIGINS = config("CORS_ALLOW_LOCAL_DEV_ORIGINS", default=True, cast=bool)
CORS_ALLOWED_ORIGIN_REGEXES = [r"^http://(localhost|127\.0\.0\.1)(:\d+)?$"] if ... else []
```

**Le risque est réellement borné**, et le code le démontre plutôt que de
l'affirmer : `CORS_ALLOW_CREDENTIALS` reste faux, l'authentification passe par
`Authorization`, jamais par un cookie. Une page tierce n'hérite d'aucune
session — le navigateur ne joint spontanément rien qui identifie l'utilisateur.
Elle ne gagne que ce qu'une requête anonyme obtient déjà, et seulement si elle
est servie depuis `localhost`, donc depuis la machine du développeur.

L'ancre `$` de l'expression est présente, ce qui ferme
`http://localhost.exemple.invalid` — `corsheaders` comparant en préfixe, son
absence aurait été le vrai défaut.

**Décision attendue** : poser `CORS_ALLOW_LOCAL_DEV_ORIGINS=false` et déclarer
l'origine du back-office dans `CORS_ALLOWED_ORIGINS` dès qu'elle est stable. Le
code l'annonce déjà comme la suite prévue. C'est un réglage d'exploitation, pas
un correctif.

### B. Des clés privées vivent dans l'arbre de travail

`backend/secrets/` contient `jwt.pem` (clé de signature RS256) et `fcm.json`
(compte de service Firebase avec sa clé privée).

**Elles n'ont jamais été versionnées.** Vérifié sur les deux dépôts :

```
git log --all -- 'secrets/*'   →  vide, dans elcorazon comme dans elcorazon-backend
git ls-files | grep -i secret  →  vide
```

`.gitignore:34` couvre `secrets/`, et `*.key` en ligne 30.

**Aucune rotation n'est donc requise.** Le point reste listé parce qu'un fichier
de clé en clair dans un répertoire de travail se retrouve dans les sauvegardes
de poste, les partages d'écran et les archives `.zip` envoyées par courriel. Le
contrôle utile n'est plus git, c'est le poste.

**Décision attendue** : confirmer que ces clés ne sont utilisées qu'en
développement et que la production les lit depuis les variables d'environnement
Render — ce que `_read_key("JWT_SIGNING_KEY")` laisse entendre, et qui mérite
d'être vérifié une fois sur le service réel.

### C. Le jeton WebSocket accepté en paramètre d'URL

`common/consumers.py:87` — l'en-tête est essayé d'abord, `?token=` ensuite. Le
code le dit lui-même : « le premier est le bon ».

Un jeton en chaîne de requête se retrouve dans les journaux d'accès du
mandataire et dans l'historique du navigateur. Le repli existe parce que
l'API WebSocket du navigateur ne permet pas de poser d'en-tête — c'est une
contrainte réelle, pas une facilité.

**Décision attendue** : conserver le repli, mais vérifier que le mandataire
Render ne journalise pas les chaînes de requête, ou raccourcir la durée de vie
du jeton employé pour le WebSocket. Rien d'urgent : le jeton d'accès vit déjà
15 minutes.

### D. Surface future — inventaire et production

Les entités à venir (document 10) porteront des écritures sensibles qui
n'existent pas encore : `StockMovement` de type `ADJUSTMENT` et `WASTE` sont des
**écritures de valeur**. Une perte saisie est un actif qui disparaît du bilan
sans transaction.

À prévoir dès la conception, pas après :

- permission dédiée, distincte de la simple écriture de catalogue ;
- journal inaltérable — un mouvement se **contre-passe**, il ne se modifie ni ne
  se supprime ;
- cloisonnement par cuisine, au même titre que les commandes ;
- plafond au-delà duquel un ajustement exige une seconde validation.

C'est le seul point de cette liste qui appelle du code, et il vient avec le
lot 2.

**Fait au lot 2-bo — les quatre exigences, dans l'ordre :**

| Exigence | Où elle est tenue |
|---|---|
| Permission dédiée | `inventory.adjust` pour déclarer, `inventory.approve` pour valider — distinctes l'une de l'autre, et de `catalog.*` |
| Journal inaltérable | `StockMovement.save()`/`delete()` lèvent ; une correction se contre-passe |
| Cloisonnement par cuisine | `get_queryset` de chaque vue ; une ligne, un mouvement ou une demande hors périmètre sont introuvables |
| Plafond et seconde validation | `Restaurant.stock_adjustment_ceiling` ; au-delà — ou coût inconnu, ou plafond non fixé — la perte devient une `AdjustmentRequest` qui ne touche à rien avant validation |

Le quatre-yeux n'est **pas** une permission : un gérant muni
d'`inventory.approve` ne valide pas sa propre déclaration. La règle est tenue
par le service et par une contrainte `CHECK`
(`adjustment_request_four_eyes`), pour qu'aucune écriture en `shell` ne la
contourne. Le plafond se fixe par `restaurants.write`, donc hors de portée du
gérant qu'il encadre. Un test d'architecture vérifie que le back-office
n'appelle jamais les écritures qui ignorent le plafond.

Deux écritures de valeur portent en plus une **clé d'idempotence** tenue par
une contrainte d'unicité : une réception ou une perte rejouée par un réseau qui
coupe n'est comptée qu'une fois. La concurrence de deux réceptions simultanées
de la même livraison est testée ; celle de deux déclarations de perte repose sur
le même verrou de ligne, sans test dédié.

---

## 5. Ce qui a déjà été corrigé — et qu'il ne faut pas rouvrir

L'historique montre que ces défauts ont été trouvés et fermés. Les rappeler
évite qu'une refonte les réintroduise.

| Commit | Défaut fermé |
|---|---|
| `a7d86ff` | Une seconde arrondie dans la réponse d'authentification révélait si l'adresse existait |
| `f40c821` | Clé Google Maps Android sortie du dépôt, une par plateforme |
| `50d0cea` | Rapports non cloisonnés : un gérant de Lomé lisait le chiffre d'affaires d'Abidjan |
| `d8fee1a` | Permissions du siège, portes de la CI |
| `36a2c1f` | Un réessai client créait une seconde commande |

Le premier est notable : une fuite par canal temporel sur l'énumération de
comptes n'est pas un défaut que l'on trouve par hasard.

---

## Synthèse

| Catégorie | Verdict |
|---|---|
| Vulnérabilités exploitables trouvées | **aucune** |
| Garanties structurelles (CI) | permissions, graphe, statuts, montants, UUID |
| Tests de refus | 247 |
| Décisions d'exploitation à prendre | 3 (CORS, clés poste, jeton WS) |
| Surface à concevoir | inventaire et production (lot 2) |

La sécurité n'est pas le chantier de cette refonte. Elle doit simplement **être
tenue** pendant que le domaine s'étend : chaque entité nouvelle du lot 2 arrive
avec sa permission, son cloisonnement par cuisine et ses tests de refus, sans
quoi les garanties structurelles du §1 se videront de leur sens à mesure que le
code grossit.
