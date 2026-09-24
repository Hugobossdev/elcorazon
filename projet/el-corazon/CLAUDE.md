# EL CORAZON — CONTRAT MÉTIER COMMUN AUX 3 APPLICATIONS

Tu travailles sur une partie du système El Corazon.

El Corazon est une **dark kitchen en ligne spécialisée dans la livraison de repas en Afrique**.

Le système est composé de trois applications Flutter, adossées à un backend Django :

| Application | Dossier          | Rôle                                         |
|-------------|------------------|----------------------------------------------|
| FASTFOOD    | `apps/fastfood/` | client : catalogue, panier, commande, suivi  |
| DELY        | `apps/dely/`     | livreur : courses, enlèvement, livraison     |
| ADMIN       | `apps/admin/`    | cuisine, opérations, supervision             |

Code partagé côté Flutter : `packages/elcorazon_core/`. Backend : `backend/apps/`.

Architecture détaillée : `docs/architecture/` (analyse fonctionnelle, architecture générale, modèle de données, ADR).

## RÈGLE ABSOLUE

Les trois applications constituent **un seul système métier**.

Ne crée jamais une règle métier différente simplement parce qu'elle est implémentée dans une autre application.

Le backend et la base de données sont la source de vérité pour toutes les données critiques. Les applications frontend ne doivent jamais devenir une deuxième source de vérité.

---

## ARCHITECTURE LOGIQUE

```text
                    EL CORAZON
                        │
                   BACKEND / API
                        │
              ┌─────────┼─────────┐
              │         │         │
              ▼         ▼         ▼
          FASTFOOD    DELY      ADMIN
                        │
                    DATABASE (accès backend uniquement)
```

Les applications consomment les mêmes règles métier.

---

# DOMAINES MÉTIER COMMUNS

Les trois applications doivent respecter les mêmes concepts :

```text
User
Role
Permission

Country
City
Zone
Address

Kitchen

Menu
Product
Variant
Ingredient
Modifier
Customization

Cart
Order
OrderItem

Payment
Refund

Inventory
StockMovement

Driver
Delivery

Promotion
Commission
Withdrawal

Notification
AuditLog
Settings
```

---

# SOURCE DE VÉRITÉ

Les informations suivantes appartiennent au serveur :

```text
Prix
Panier
Stock
Disponibilité
Taxes
Frais de livraison
Promotions
Total commande
État commande
État paiement
État livraison
Utilisateurs
Permissions
Attribution cuisine
Attribution livraison
Commissions
Remboursements
Retraits
```

Le frontend peut afficher ces informations mais ne doit jamais pouvoir imposer leur valeur finale.

---

# MACHINE À ÉTATS

Les états sont définis côté backend. Chaque application utilise les états retournés par l'API et n'invente jamais un état local qui contredit le backend.

Pour chaque transition :

```text
état actuel
→ action
→ validation
→ nouvel état
→ effets secondaires
→ notification
→ historique
```

## États réels du backend

Ces valeurs font foi. Les fichiers cités sont la source ; en cas d'écart avec ce tableau, c'est le code qui a raison et ce fichier qu'il faut corriger.

**Commande** — `backend/apps/orders/states.py` (`OrderStatus`, `ORDER_TRANSITIONS`)

```text
pending → confirmed → preparing → ready → picked_up → on_the_way → delivered
   └──────────┴───────────┴─────────┴──→ cancelled
```

Après `picked_up`, l'annulation n'existe plus : un incident relève du remboursement.

**Course (livraison)** — `backend/apps/delivery/states.py` (`DeliveryStatus`, `DELIVERY_TRANSITIONS`)

```text
offered → accepted → picked_up → on_the_way → delivered
   ├──→ declined
   └──────────┴──→ cancelled
```

**Paiement** — `backend/apps/payments/models.py` (`PaymentStatus`, `PAYMENT_TRANSITIONS`)

```text
pending → processing → completed → refunded
   ├──→ cancelled         └──→ failed
   └──→ failed
```

`completed` ne redescend jamais : un webhook rejoué ne peut pas rétrograder un encaissement.

**Stock** — `backend/apps/inventory/models.py` (`MovementKind`)

Deux colonnes, `on_hand` et `reserved`. Chaque mouvement agit sur une seule :

```text
on_hand  : purchase, receipt (+) · consumption, waste (−) · adjustment, transfer (±)
reserved : reservation (+) · release (−)
```

Consommer de la matière réservée s'écrit `release` puis `consumption`. Le signe est imposé par le type, jamais par l'appelant.

Les noms génériques qu'on trouve dans d'autres documents (`SUCCESS`, `EXPIRED`, `SEARCHING_DRIVER`, `ASSIGNED`, `IN_DELIVERY`, `Available/Consumed`…) **n'existent pas** dans ce backend. Ne pas les introduire côté Dart : la CI refuse un statut ou une permission absents du registre Django (`tools/contrat_vocabulaire.py`), et une route ou un verbe HTTP inventés (`tools/contrat_routes.py`).

---

# PARCOURS D'UNE COMMANDE

```text
FASTFOOD   création                        → order pending
BACKEND    validation + paiement           → order confirmed / payment completed
ADMIN      prise en charge, préparation    → order preparing → ready
BACKEND    course proposée à un livreur    → delivery offered
DELY       acceptation, enlèvement         → delivery accepted → picked_up
DELY       livraison                       → on_the_way → delivered
FASTFOOD   suivi et statut final           → order delivered
```

---

# PAIEMENT

Le frontend ne décide jamais qu'un paiement est réussi : le statut final est confirmé par le serveur.

Gérer : double paiement, double commande, retry, webhook reçu plusieurs fois, perte réseau.

---

# STOCK

Le stock est géré par le backend. Ne jamais décrémenter une valeur locale. Toute variation passe par un mouvement (`StockMovement`) côté serveur.

---

# LIVRAISON

Une course est liée à une commande et suit la machine `DeliveryStatus`. Deux livreurs ne peuvent pas accepter la même course : c'est le backend qui arbitre.

---

# PERMISSIONS

Les permissions sont vérifiées côté serveur. Cacher un bouton dans une application n'est pas une sécurité.

L'interface ne propose que ce que le serveur accordera.

---

# IDENTIFIANTS

Tous les objets métier utilisent leurs identifiants backend. Ne crée pas de faux identifiants uniquement côté frontend.

---

# ERREURS

Utiliser un format d'erreur API cohérent.

Une erreur backend ne doit jamais être transformée arbitrairement en succès côté frontend.

---

# IDEMPOTENCE

Les opérations sensibles sont protégées contre les doublons :

```text
Création commande
Paiement
Confirmation paiement
Affectation livreur
Acceptation livraison
Changement d'état
Remboursement
Retrait
```

---

# CONCURRENCE

Prendre en compte les actions simultanées :

```text
Deux clients commandent le dernier produit.
Deux administrateurs modifient une cuisine.
Deux livreurs acceptent la même livraison.
Un paiement est reçu deux fois.
```

Le backend garantit l'intégrité.

---

# COMMUNICATION ENTRE APPLICATIONS

Ne jamais accéder directement à la base de données depuis une application frontend.

Utiliser, selon l'architecture existante :

```text
API
WebSocket / realtime si disponible
Notifications
Jobs
Webhooks
```

---

# RÈGLE DE COHÉRENCE

Avant de modifier une fonctionnalité :

1. rechercher son modèle backend ;
2. rechercher son API ;
3. rechercher ses règles métier ;
4. rechercher son utilisation dans FASTFOOD ;
5. rechercher son utilisation dans DELY ;
6. rechercher son utilisation dans ADMIN ;
7. vérifier ses états ;
8. vérifier ses permissions ;
9. vérifier ses effets secondaires ;
10. implémenter uniquement la partie correspondant à l'application concernée.

Si une incohérence est découverte : **ne pas inventer une solution locale.** Documenter l'incohérence et corriger la source commune (backend, `elcorazon_core`) lorsque c'est nécessaire.

---

# TESTS INTER-APPLICATIONS

Chaque fonctionnalité importante est testée de bout en bout, en suivant le parcours d'une commande ci-dessus : FASTFOOD → BACKEND → ADMIN → BACKEND → DELY → FASTFOOD.

---

# RÈGLE DE FINITION

Une fonctionnalité n'est terminée que si ces éléments fonctionnent ensemble :

```text
UI
API
Business logic
Database
Permissions
States
Validation
Error handling
Notifications
Tests
```

Ne jamais déclarer une fonctionnalité terminée uniquement parce que l'écran s'affiche.

---

# MÉTHODE OBLIGATOIRE

```text
AUDITER
→ COMPRENDRE
→ IDENTIFIER LA CAUSE RACINE
→ DÉFINIR LA RÈGLE
→ CORRIGER
→ TESTER
→ TESTER LES RÉGRESSIONS
→ VALIDER
```

- Ne pas faire de patch superficiel.
- Ne jamais désactiver une validation uniquement pour faire passer un test.
- Ne jamais supprimer un test qui échoue sans avoir identifié sa cause.

---

# OBJECTIF GLOBAL

Les trois applications doivent se comporter comme :

> **une seule plateforme El Corazon avec trois interfaces spécialisées.**

Aucune application ne doit devenir une île indépendante. Toute modification doit préserver cette cohérence.
