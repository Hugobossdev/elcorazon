# Besoins backend issus du redesign Stitch

> Ce que les maquettes dessinent et que `/api/v1/` ne sait pas servir.
> Établi pendant l'intégration du second lot Stitch (14 maquettes), et complété
> des manques du premier lot (`UI_REDESIGN_ISSUES.md`).
>
> **Aucun de ces manques n'a été simulé côté client.** L'élément concerné est
> soit omis, soit remplacé par ce que le contrat sait réellement rendre.

Priorités : **P1** bloque une fonction vendue · **P2** dégrade l'expérience ·
**P3** confort.

---

## BR-001 — Connexion Google et Apple

**Fonctionnalité :** `onboarding_authentication_options` propose « Continue
with Google » et « Continue with Apple ».

**Endpoint nécessaire :** `POST /auth/oauth/{provider}/`
**Méthode :** POST
**Payload :** `{ "id_token": "<jeton du fournisseur>" }`
**Réponse :** identique à `POST /auth/login/` — `{ access, refresh, user }`
**Authentification :** aucune (c'est l'entrée)
**Temps réel :** non
**Priorité :** P2

**Note.** `auth_screen.dart:493` documente déjà le retrait de ces méthodes à la
Phase 6. Côté client il faudra aussi `google_sign_in` et
`sign_in_with_apple`, plus la configuration des identifiants OAuth par
plateforme. Les deux boutons ne sont **pas** dessinés tant que la route
n'existe pas : un bouton « Continuer avec Google » qui ouvre un formulaire
e-mail trompe l'utilisateur sur ce qui va se passer.

---

## BR-002 — Pourboire au livreur

**Fonctionnalité :** `rate_delivery` propose « Tip your driver » —
No Tip / 500 F / 1 000 F / 2 000 F — avec la mention « 100 % of the tip goes
directly to Koffi A. ».

**Endpoint nécessaire :** `POST /payments/{orderId}/tip/`
**Méthode :** POST
**Payload :** `{ "amount_minor": 100000, "currency": "XOF" }`
**Réponse :** une `Transaction` (`provider`, `status`, `amount`), pour que le
client suive l'encaissement comme un paiement ordinaire
**Authentification :** jeton du client, propriétaire de la commande
**Temps réel :** non — mais l'état suit le webhook du prestataire, comme tout
paiement
**Priorité :** P2

**Ce que cela suppose côté serveur**, au-delà de la route : le reversement au
livreur (le « 100 % » de la maquette est un engagement comptable), et le
traitement d'un second encaissement sur une commande déjà réglée.

**Décision côté client :** le bloc n'est pas dessiné. Un sélecteur de
pourboire qui ne débite rien est le pire cas de figure sur un écran d'argent —
le client croit avoir donné, le livreur ne reçoit rien.

---

## BR-003 — Réglages de notification (« Mute »)

**Fonctionnalité :** `notifications` place en tête un interrupteur « Mute
Notifications — Pause all alerts temporarily ».

**Endpoints nécessaires :**
`GET /notifications/preferences/` · `PATCH /notifications/preferences/`
**Méthode :** GET, PATCH
**Payload (PATCH) :**
```json
{ "muted_until": "2026-09-01T20:00:00Z",
  "kinds_disabled": ["marketing"] }
```
**Réponse :** l'objet de préférences complet
**Authentification :** jeton du client
**Temps réel :** non
**Priorité :** P2

**Pourquoi la route est indispensable.** Un interrupteur purement local
n'arrêterait **pas** les notifications : FCM pousse depuis le serveur, et le
système d'exploitation les affiche sans passer par l'application. Un « Mute »
côté client ne ferait que cacher les entrées d'une liste, pendant que le
téléphone continue de sonner. C'est une promesse que le client ne peut pas
tenir seul.

`NotificationRepository` n'expose aujourd'hui que `getUnreadCount`,
`markRead` et `markAllRead` — vérifié.

---

## BR-004 — Historique de conversation avec le livreur

**Fonctionnalité :** `chat_with_driver` montre un fil déjà garni à
l'ouverture, avec horodatage et double coche « lu ».

**État actuel :** `ws/orders/{id}/chat/` **relaie sans écrire** (ADR-008,
Phase 1 §5), ce que `ChatService` documente explicitement. Rien n'est
persisté ; le fil part vide à chaque ouverture, et un message envoyé pendant
que l'autre partie est absente est perdu.

**Endpoints nécessaires :**
`GET /orders/{orderId}/messages/` (historique paginé) et la persistance côté
consommateur WebSocket.
**Méthode :** GET
**Payload :** —
**Réponse :** `{ results: [ { id, sender, content, created_at, read_at } ], next }`
**Authentification :** jeton du client, partie à la commande
**Temps réel :** oui — le canal existe, il faut qu'il **écrive** avant de
relayer
**Priorité :** **P1**

**Pourquoi P1.** Sans persistance, la conversation n'est pas une
fonctionnalité mais une coïncidence : elle ne marche que si les deux parties
regardent l'écran en même temps. Un client qui écrit « laissez au portail »
pendant que le livreur roule ne sera jamais lu.

**Accusé de lecture** (`read_at`) : même route, P3.

**Décision côté client :** le fil s'ouvre vide, avec un état explicite qui dit
que la conversation commence maintenant. Aucun stockage local ne vient
fabriquer un faux historique.

---

## BR-005 — Moyens de paiement enregistrés

**Fonctionnalité :** `profile` liste « Payment Methods ».

**État actuel :** PayDunya ouvre une session par commande
(`POST /payments/{orderId}/initiate/`). Aucun instrument n'est conservé, donc
il n'y a rien à lister ni à supprimer.

**Endpoints nécessaires :**
`GET /payments/methods/` · `POST /payments/methods/` ·
`DELETE /payments/methods/{id}/`
**Réponse :** `[ { id, provider, label, masked_identifier, is_default } ]`
**Authentification :** jeton du client
**Temps réel :** non
**Priorité :** P3

**Note de conformité.** Enregistrer un instrument suppose une tokenisation
chez le prestataire — **jamais** de numéro chez nous. À arbitrer avec PayDunya
avant toute implémentation.

**Décision côté client :** l'entrée n'est pas ajoutée au profil.

---

## BR-006 — Paliers de fidélité publiés par le serveur

**Fonctionnalité :** `rewards` affiche « Gold Member », une progression
« 550 pts to Platinum » et un seuil « Platinum (3000 pts) ».

**État actuel :** `palierDeFidelite()` est **écrit côté client**
(`lib/presentation/profil_utilisateur.dart`), avec des seuils 200 et 500 et
les noms « Standard », « Fidèle », « VIP » — qui ne correspondent ni aux noms
ni aux seuils de la maquette. `GET /loyalty/account/` rend `balance`,
`lifetime_earned`, `lifetime_spent`, sans notion de palier.

**Endpoint nécessaire :** `GET /loyalty/tiers/`, ou un bloc `tier` ajouté à
`GET /loyalty/account/`
**Réponse :**
```json
{ "current": { "code": "gold", "label": "Gold", "min_points": 1000 },
  "next":    { "code": "platinum", "label": "Platinum", "min_points": 3000 },
  "points_to_next": 550 }
```
**Authentification :** jeton du client
**Temps réel :** non
**Priorité :** P2

**Pourquoi cela compte.** Un palier calculé côté client est une promesse
commerciale que le serveur ne connaît pas : deux versions de l'application en
circulation annonceront deux paliers différents pour le même solde, et aucune
ne fera foi au moment d'accorder l'avantage.

**Décision côté client :** l'écran affiche les paliers tels que
`palierDeFidelite()` les définit **aujourd'hui**, en attendant la route. Les
noms de la maquette (« Gold », « Platinum ») ne sont pas repris, faute de
correspondance.

---

## BR-007 — Vote d'utilité sur un avis

**Fonctionnalité :** `product_reviews` (premier lot) affiche « 👍 12 » par
avis.

**État actuel — correction d'ISSUE-015 :** `Review` porte **bien**
`helpfulCount` et `isVerifiedPurchase`. Le compteur est donc affichable dès
maintenant. Ce qui manque, c'est la route pour **voter**.

**Endpoint nécessaire :** `POST /catalog/reviews/{id}/helpful/` (et son
`DELETE` pour retirer son vote)
**Réponse :** l'avis, avec son `helpful_count` à jour
**Authentification :** jeton du client, un vote par personne et par avis
**Temps réel :** non
**Priorité :** P3

---

## BR-008 — Valeurs nutritionnelles détaillées

Reprise d'ISSUE-011 (premier lot).

**Champs nécessaires :** `proteins_g`, `carbs_g`, `fats_g` sur `MenuItem` et
son sérialiseur de détail, plus la saisie au back-office.
**Priorité :** P3

**Décision côté client :** le bloc « Nutritional Info » n'est pas dessiné.
Seules les calories, qui existent, s'affichent en puce. Inventer « 42 g de
protéines » serait une information fausse sur un sujet qui touche à l'allergie
et au régime.

---

## BR-009 — Prix de référence barré

Reprise d'ISSUE-012.

**Champ nécessaire :** `compare_at_price` sur `MenuItem`, ou exposition au
client des promotions applicables à un article.
**Priorité :** P3

---

## BR-010 — Catalogue d'offres promotionnelles côté client

Reprise d'ISSUE-013.

**Endpoint nécessaire :** `GET /promotions/available/`
**Réponse :** promotions actives applicables au compte, avec seuil minimum,
échéance et état d'éligibilité
**Priorité :** P2

`GET /promotions/` existe mais sert le back-office. Le client n'a que
`POST /orders/preview/ { promo_code }`, qui **valide** un code sans jamais en
énumérer.

---

## BR-011 — Dépôt d'un fichier par le client

Reprise d'ISSUE-014, élargie : trois maquettes en dépendent.

**Fonctionnalités :** image de référence pour un gâteau sur mesure
(`cake_order`), photos jointes à un avis (`product_reviews`), photos jointes à
une réclamation (`SupportRepository.fileComplaint` **accepte déjà** une liste
`photos`, mais rien ne permet de les téléverser).

**Endpoint nécessaire :** `POST /media/uploads/`
**Payload :** `multipart/form-data`, borné en taille (5 Mo) et en type
(`image/jpeg`, `image/png`)
**Réponse :** `{ id, url }`, à référencer ensuite dans la ressource concernée
**Authentification :** jeton du client
**Priorité :** P2

**Note.** `fileComplaint(photos: [...])` existe au socle et n'est appelable
avec rien d'autre qu'une liste vide : c'est un paramètre sans producteur.

---

## BR-012 — Nom du livreur sur la commande

Reprise d'ISSUE-006, **avec une correction** : le nom est en réalité
disponible dans `OrderTracking.courier` (`GET /tracking/orders/{id}/`).

**Ce qui reste souhaitable :** l'exposer aussi sur `OrderSerializer`, pour
éviter un second appel réseau juste pour afficher un nom sur une carte de
liste.
**Priorité :** P3

---

## BR-013 — Documents légaux

Reprise d'ISSUE-007.

**Nécessaire :** politique de confidentialité et conditions d'utilisation
publiées à une URL stable. Les deux sont **exigés** par Google Play et l'App
Store avant publication, et les maquettes d'onboarding les référencent
explicitement (« By continuing, you agree to our Terms of Service and Privacy
Policy »).
**Priorité :** **P1** — bloque la mise en boutique.

---

## Récapitulatif

| # | Besoin | Priorité |
|---|---|---|
| BR-004 | Historique de conversation livreur | **P1** |
| BR-013 | Documents légaux publiés | **P1** |
| BR-001 | Connexion Google / Apple | P2 |
| BR-002 | Pourboire au livreur | P2 |
| BR-003 | Réglages de notification | P2 |
| BR-006 | Paliers de fidélité serveur | P2 |
| BR-010 | Catalogue d'offres client | P2 |
| BR-011 | Dépôt de fichier client | P2 |
| BR-005 | Moyens de paiement enregistrés | P3 |
| BR-007 | Vote d'utilité sur un avis | P3 |
| BR-008 | Valeurs nutritionnelles | P3 |
| BR-009 | Prix de référence barré | P3 |
| BR-012 | Nom du livreur sur la commande | P3 |
