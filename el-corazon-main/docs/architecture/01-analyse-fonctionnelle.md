# Phase 1 — Analyse fonctionnelle de l'existant

> **Objectif** : extraire le *produit* El Corazón — acteurs, parcours, règles métier, besoins d'API —
> indépendamment de la façon dont il a été codé jusqu'ici.
> Ce document est la **spécification d'entrée** de la v2. Aucune ligne de code Laravel, Supabase ou
> Dart existant n'y est reprise comme contrainte de conception.

**Statut** : clos · **Date** : 2026-07-25

---

## 1. Sources analysées

| Source | Ce qu'on en tire | Fiabilité |
|---|---|---|
| `CAHIER_DES_CHARGES.md` | Intention produit, exigences fonctionnelles par app | Déclaratif — décrit le *souhaité*, pas toujours le *fait* |
| `SCHEMA_BDD_COMPLET.md` (1255 l.) | 45 tables, contraintes `CHECK`, relations, triggers | Élevée — c'est le contrat de données réellement en production |
| `ETAT_FONCTIONNALITES.md` | Ce qui est réellement implémenté vs simulé | Élevée sur les manques (PayDunya simulé, Agora non configuré) |
| 3 apps Flutter (`fastfood`, `dely`, `admin`) | Parcours réels : ~80 écrans, ~130 services | Élevée — l'UI ne ment pas sur les parcours |
| Historique git (backend Laravel, 26 contrôleurs) | **Invariants métier découverts par audit de sécurité** | Très élevée — failles reproduites empiriquement (§6) |

L'apport le plus précieux n'est pas la liste des fonctionnalités : c'est le §6, qui recense les
règles métier dont la **violation a été prouvée** sur l'implémentation précédente. Elles constituent
le cahier de recette non négociable de la v2.

---

## 2. Le produit en une phrase

Plateforme de commande et de livraison de repas, opérée par **El Corazón** (dark kitchen / fast-food),
servant trois populations via trois applications Flutter distinctes, autour d'un cycle unique :
**catalogue → panier → commande → paiement → préparation → livraison géolocalisée → évaluation**,
enrichi d'une couche d'engagement (fidélité, gamification, social) et d'une couche d'exploitation
(back-office, analytics, gestion de flotte).

### Constat structurant

Le produit actuel est **mono-restaurant**. Le schéma n'a ni table `restaurants`, ni `cities`, ni
`countries` : `menu_items` est un catalogue global, `orders.delivery_fee` a un défaut fixe (`5.00`,
et `500.0` côté panier — incohérence relevée), et il n'existe aucune notion de zone de livraison
en base malgré un `delivery_zone_service.dart` côté admin.

> **Conséquence pour la v2** : le passage au multi-restaurants / multi-villes / multi-pays exigé par
> la mission n'est **pas une migration**, c'est une **extension de domaine**. Elle introduit un
> agrégat `Restaurant` (et sa hiérarchie géographique) qui n'a aucun équivalent à reprendre.
> Traité en Phase 3.

---

## 3. Acteurs et rôles

| Acteur | App | Rôle technique | Cycle de vie |
|---|---|---|---|
| **Visiteur** | `fastfood` | — | Consulte le catalogue sans compte (« mode invité »), converti au checkout |
| **Client** | `fastfood` | `client` | Inscription libre, actif immédiatement |
| **Livreur** | `dely` | `delivery` | Inscription → dépôt de pièces → **validation admin** (`pending`/`approved`/`rejected`) → actif |
| **Administrateur** | `admin` | `admin` | Créé par un pair. Rôles fins additionnels (`admin_roles` + permissions JSONB) : Super Admin / Manager / Opérateur |
| **Système** | — | — | Tâches planifiées : expiration de points, renouvellement d'abonnements, purge des positions GPS |

**Point d'attention** : le rôle est aujourd'hui une **colonne texte unique** sur `users`, doublée
d'un système de rôles admin granulaires dans deux tables séparées (`admin_roles`,
`user_admin_roles`). Deux mécanismes d'autorisation coexistent sans se parler. La v2 doit trancher
(voir Phase 2, ADR autorisation).

---

## 4. Domaines fonctionnels (bounded contexts)

Regroupement des 45 tables existantes par **cohérence métier**, pas par proximité technique.
C'est ce découpage qui donnera les applications Django de la Phase 2.

| Domaine | Responsabilité | Entités existantes couvertes |
|---|---|---|
| **Identité & accès** | Comptes, rôles, permissions, sessions, appareils | `users`, `admin_roles`, `user_admin_roles` |
| **Profils clients** | Adresses, préférences, favoris | `addresses`, `user_preferences` |
| **Flotte livreurs** | Dossier livreur, vérification, disponibilité, position, stats | `drivers` |
| **Catalogue** | Catégories, articles, options de personnalisation, avis | `menu_categories`, `menu_items`, `customization_options`, `menu_item_customizations`, `product_reviews` |
| **Stock** | Inventaire matières premières, disponibilité article | `inventory_items`, `menu_items.available_quantity` |
| **Panier** | Panier serveur persistant, par utilisateur | `user_carts`, `user_cart_items` |
| **Commandes** | Cycle de vie, lignes, historique de statut, réédition | `orders`, `order_items`, `order_status_updates` |
| **Paiements** | Encaissement, Mobile Money, paiement partagé, remboursements | `group_payments`, `group_payment_participants`, `orders.payment_*` |
| **Livraison** | Affectation, acceptation, étapes, preuve de livraison | `active_deliveries` |
| **Tracking** | Positions GPS temps réel, itinéraire, ETA | `delivery_locations`, `order_tracking` |
| **Promotions** | Codes promo, conditions, quotas d'usage | `promotions`, `promotion_usage` |
| **Fidélité** | Points, transactions, récompenses, échanges, abonnements | `loyalty_*`, `reward_redemptions`, `subscriptions`, `subscription_orders` |
| **Gamification** | Succès, défis, badges, séries | `achievements`, `challenges`, `badges`, `user_*` |
| **Social** | Groupes, publications, likes, commentaires | `social_groups`, `group_members`, `social_posts`, `post_likes`, `post_comments` |
| **Notifications** | Notifications in-app, push, préférences | `notifications` |
| **Support** | Tickets, messages, réclamations, retours/remboursements | `support_tickets`, `support_messages`, `complaints`, `return_requests` |
| **Analytics** | Événements, métriques, rapports, recommandations | `analytics_events`, `recommendations`, ~10 vues SQL |
| **Communication** | Chat client↔livreur, appels audio/vidéo | `calls` (migration Supabase), chat non persisté en base |

Deux tables sont **hors domaine** et abandonnées : `saved_forms` et `validation_history` — de
l'état d'UI persisté côté serveur, sans valeur métier.

---

## 5. Parcours utilisateurs

### 5.1 Client (`El Corazon fastfood` — 33 écrans)

```
Splash → [invité : catalogue en lecture seule]
       → Auth (email/mdp) → OTP → Accueil
                                   │
     ┌─────────────────────────────┼──────────────────────────────┐
     ▼                             ▼                              ▼
  Catalogue                     Profil                        Engagement
  · liste + catégories          · infos, photo                · points & niveau (6 paliers)
  · recherche avancée           · adresses (carte, GPS)       · badges, défis, série
  · détail + avis               · historique commandes        · récompenses échangeables
  · personnalisation ───┐       · portefeuille                · groupes sociaux, publications
    (burger/pizza/gâteau)│      · support / réclamations
                        ▼
                     Panier ──→ Checkout ──→ Paiement ──→ Suivi ──→ Réception
                        │        · adresse    · PayDunya   · carte    · notation produit
                        │        · promo      · wallet     · ETA      · notation livreur
                        │        · frais      · partagé    · chat     · réclamation / retour
                        │        · récap      · cash       · appel
                        │
                        └──→ Commande groupée (partage des frais entre participants)
```

**Modes dégradés supportés** : consultation du catalogue en cache (24 h), mise en file d'attente
d'une commande hors-ligne avec retry à backoff exponentiel.

### 5.2 Livreur (`El corazon dely` — 13 écrans)

```
Splash → Auth livreur ──(nouveau)──→ Inscription + dépôt de pièces
                                     (permis, CNI, véhicule) → EN ATTENTE DE VALIDATION
                                                                        │ admin
                                                                        ▼
         Accueil livreur ◄──────────────────────────────────────── APPROUVÉ
              │
              ├─ Bascule En ligne / Hors ligne
              ├─ Courses disponibles → accepter / refuser (délai de réponse)
              ├─ Course en cours : récupérée → en route → livrée
              │     · navigation GPS (restaurant puis client)
              │     · émission de position (~10 s)
              │     · chat + appel client
              ├─ Gains : jour / semaine / mois, historique, objectifs
              └─ Profil : stats, note moyenne, badges
```

**Détail critique** : un livreur peut voir des courses disponibles *avant* validation de son
dossier dans l'UI — le contrôle d'accès est donc entièrement à la charge du serveur (cf. §6.2).

### 5.3 Administrateur (`El Corazon admin` — 30 écrans)

```
Auth admin (+ rôle granulaire)
  │
  ├─ Tableau de bord : CA, volumes, conversion, satisfaction, graphiques
  ├─ Commandes : Kanban par statut, filtres, changement de statut,
  │              affectation livreur, annulation, remboursement
  ├─ Catalogue : CRUD articles & catégories, images, stock,
  │              options de personnalisation et groupes d'options
  ├─ Flotte : liste, carte temps réel, validation des pièces,
  │           historique des validations, planning, stats par livreur
  ├─ Clients : liste, détail, historique, blocage
  ├─ Marketing : promotions, codes, campagnes, push ciblés, gamification
  ├─ Analytics : revenus, top produits, performance livreurs, export PDF/CSV
  ├─ Rôles & permissions : rôles personnalisés, permissions par module, audit
  └─ Paramètres : zones de livraison, barème de frais, configuration
```

---

## 6. Règles métier — invariants non négociables

Cette section est le cœur de l'analyse. Chaque règle marquée **[PROUVÉE]** correspond à une faille
qui a été *reproduite empiriquement* sur l'implémentation précédente avant d'être corrigée : le test
d'attaque échouait sur le code d'origine. Ce sont des trous que la v2 doit fermer **par conception**,
pas par vigilance.

### 6.1 Commandes et prix

| # | Invariant | Origine |
|---|---|---|
| C1 | Le **prix, le libellé et l'image** d'une ligne sont relus depuis le catalogue au moment de l'ajout au panier et de la validation de commande. Jamais acceptés du client. | **[PROUVÉE]** — le panier acceptait le prix envoyé par le client |
| C2 | Le total commande est **recalculé serveur** : `Σ(lignes) + frais − remise`. La valeur cliente est ignorée. | Dérivé de C1 |
| C3 | Une transition de statut ne peut suivre que le flux défini ; **aucun retour arrière**. | **[PROUVÉE]** — rejouer `delivered` réincrémentait les compteurs du livreur |
| C4 | Tout statut écrit doit appartenir à l'énumération. Un statut hors liste viole la contrainte `CHECK` en production. | **[PROUVÉE]** — l'étape `accepted` écrivait un statut commande inexistant |
| C5 | Une commande annulée ou déjà payée n'accepte plus ni paiement ni prise en charge. | **[PROUVÉE]** — gardes absentes sur l'initiation de paiement |

**Flux de statut commande** (8 états) :
`pending → confirmed → preparing → ready → picked_up → on_the_way → delivered`, avec `cancelled`
atteignable depuis tout état non terminal.

### 6.2 Livraison

| # | Invariant | Origine |
|---|---|---|
| L1 | Seul un livreur au dossier **`approved`** peut accepter une course. | **[PROUVÉE]** — `verification_status` ignoré à l'acceptation |
| L2 | L'acceptation d'une course est **exclusive et atomique** (verrou) : deux livreurs concurrents ne peuvent pas prendre la même course. | **[PROUVÉE]** — course entre deux livreurs, aucun verrou |
| L3 | Un livreur ne peut émettre une position que pour une course **qui lui est assignée**. | **[PROUVÉE]** — falsification du suivi temps réel possible |
| L4 | Les compteurs (`total_deliveries`, `completed_deliveries`, gains) ne sont incrémentés qu'**une seule fois**, à la transition effective vers `delivered`. | Corollaire de C3 |
| L5 | Modifier ses pièces d'identité après approbation **repasse le dossier en `pending`**. | Règle de conformité |

**Flux de statut livraison** (5 états) : `assigned → accepted → picked_up → on_the_way → delivered`,
chaque étape projetant un statut commande correspondant.

### 6.3 Paiements

| # | Invariant | Origine |
|---|---|---|
| P1 | Le webhook du prestataire est **idempotent** : un paiement `completed` ne peut jamais être rétrogradé par un rejeu. | **[PROUVÉE]** |
| P2 | Une part de paiement partagé n'est réputée réglée que si elle est **adossée à une transaction vérifiée** chez le prestataire. | **[PROUVÉE — faille critique]** : n'importe quel participant pouvait se déclarer payé, ce qui basculait la commande entière en `completed` → **commande gratuite**. Le correctif d'urgence a restreint l'action aux admins ; **le vrai flux par part reste à construire** (chantier v2). |
| P3 | Un remboursement est **plafonné au total réellement payé** de la commande. | **[PROUVÉE]** — remboursement supérieur au montant payé possible |
| P4 | Le prix d'un abonnement provient d'un **catalogue de plans tarifés côté serveur**, jamais du client. | **[PROUVÉE]** — `monthly_price` accepté du client. Non corrigé : nécessite le catalogue, absent. |

### 6.4 Fidélité et promotions

| # | Invariant | Origine |
|---|---|---|
| F1 | Le débit de points est **atomique et conditionnel** : vérification du solde et retrait dans la même opération. | **[PROUVÉE — TOCTOU]** : deux échanges concurrents consommaient le même solde → solde négatif, deux récompenses pour le prix d'une |
| F2 | Le coût d'une récompense est **strictement positif**. | **[PROUVÉE]** — un coût négatif transformait le débit en crédit de points |
| F3 | Le solde de points ne peut jamais devenir négatif (invariant de base, pas de garde applicative). | Corollaire de F1 |
| F4 | Un code promo respecte : période de validité, montant minimum, plafond de remise, quota global et quota par utilisateur. | Schéma `promotions` |
| F5 | Chaque mouvement de points est tracé dans un **journal immuable** (`loyalty_transactions`) ; le solde en est dérivable. | Schéma existant, non appliqué |

### 6.5 Contenus et avis

| # | Invariant | Origine |
|---|---|---|
| S1 | La mention « achat vérifié » d'un avis est **calculée serveur** (l'article figure dans une commande `delivered` de l'auteur) ; jamais acceptée du client. | **[PROUVÉE]** — le champ n'était jamais renseigné |
| S2 | La visibilité d'une publication de groupe est contrôlée à **chaque accès** : lecture, commentaire, like. | **[PROUVÉE]** — un post privé était lisible et commentable par qui connaissait l'UUID |
| S3 | Partager une commande exige d'en être le **propriétaire** (elle expose l'adresse de livraison). | **[PROUVÉE]** — `order_id` validé par simple existence |
| S4 | Une publication rattachée à un groupe ne peut pas être marquée publique. | **[PROUVÉE]** — remontée dans le fil global |
| S5 | Un avis par (article, utilisateur). | Contrainte `UNIQUE` existante |

### 6.6 Transverses

| # | Invariant |
|---|---|
| T1 | **Rate limiting** obligatoire sur l'authentification (par IP *et* par identifiant) — absent à l'origine, brute-force ouvert. |
| T2 | Un changement de mot de passe **révoque les autres sessions**. **[PROUVÉE]** — les sessions ouvertes ailleurs survivaient. |
| T3 | Toute écriture est autorisée par une politique explicite ; le défaut est le refus. |
| T4 | Les montants sont manipulés en **décimal exact**, jamais en flottant. |
| T5 | Les identifiants exposés sont des **UUID** (pas de séquence devinable). |

---

## 7. Besoins d'API

Surface REST réellement consommée par les clients, par ordre de criticité :

| Priorité | Domaine | Consommateurs | Note |
|---|---|---|---|
| **P0** | Auth, catalogue, panier, adresses, commandes | client | Le chemin critique du chiffre d'affaires |
| **P0** | Livraison (courses, acceptation, étapes, position) | livreur | Aucune couche REST n'existait — 100 % Supabase direct |
| **P1** | Paiements, promotions, notifications, suivi | client, livreur | |
| **P1** | Back-office : commandes, catalogue, flotte, clients | admin | 100 % Supabase direct aujourd'hui |
| **P2** | Fidélité, gamification, social, support, abonnements | client | |
| **P2** | Analytics et rapports | admin | |

### Contraintes de contrat héritées

Deux pièges vérifiés sur l'implémentation précédente, à respecter par la v2 :

1. **Pagination** : les clients Dart lisent `current_page` / `last_page` / `total` **à la racine** de
   la réponse, pas sous une clé `meta`. Un enveloppement standard DRF casse les listes.
2. **Booléens en query string** : les clients envoient `?popular_only=true` (chaîne). Le parsing doit
   l'accepter.
3. **Dates non nullables côté client** : `User.fromMap` et `Address.fromJson` appellent
   `DateTime.parse` **sans garde nulle**. Omettre `created_at` d'une réponse ne dégrade pas
   l'affichage — **ça fait planter la connexion**.

> Ces contraintes ne s'appliquent que si l'on conserve les clients Dart actuels. La Phase 6
> (Clean Architecture Flutter) réécrit la couche data : c'est l'occasion de les lever et d'adopter
> un contrat propre. **Décision reportée en Phase 2.**

---

## 8. Besoins temps réel

Quatre flux justifient une connexion persistante plutôt que du polling :

| Flux | Émetteur → Récepteurs | Fréquence | Criticité |
|---|---|---|---|
| Position du livreur | livreur → client suivant la commande, admin | ~10 s pendant une course | Haute — cœur de l'expérience de suivi |
| Changement de statut commande | serveur → client, livreur, admin | événementiel | Haute |
| Nouvelle course disponible | serveur → livreurs en ligne éligibles | événementiel | Haute — conditionne le délai d'acceptation |
| Chat client ↔ livreur | bidirectionnel | conversationnel | Moyenne |

Les appels audio/vidéo (Agora) restent **hors périmètre du temps réel serveur** : le backend n'émet
qu'un jeton RTC, le média transite par le prestataire.

---

## 9. Décisions de périmètre pour la v2

### Repris tel quel (valeur métier avérée)
Catalogue et personnalisation · panier serveur · commandes · livraison géolocalisée · paiement
Mobile Money · promotions · fidélité par points · notifications · support et réclamations ·
back-office et analytics.

### Repris en étant repensé
- **Paiement partagé** — le flux par part doit être reconstruit autour de transactions vérifiées (P2).
- **Abonnements** — nécessitent un catalogue de plans tarifés serveur (P4).
- **Rôles admin** — unifier les deux mécanismes concurrents en un seul modèle de permissions.
- **Frais de livraison** — aujourd'hui une constante contradictoire (`5.00` / `500.0`) ; doivent
  devenir un barème par zone, calculé sur distance réelle.
- **Stock** — `menu_items.available_quantity` n'est décrémenté nulle part ; à relier au cycle de commande.

### Écarté
- `saved_forms`, `validation_history` — état d'UI persisté serveur, sans valeur métier.
- Recommandations « IA » — la table `recommendations` existe, l'algorithme est un placeholder.
  Reporté après la mise en production du socle.
- Commandes vocales et AR (`voice_service`, `ar_service`) — présents dans les 3 apps, aucun usage
  métier identifié, aucune donnée serveur associée.
- Duplication massive de services entre les 3 apps Flutter (~130 fichiers, dont une trentaine de
  quasi-doublons) — résorbée par le module partagé de la Phase 6.

### Nouveau (exigé par la mission, sans équivalent existant)
- Hiérarchie **pays → ville → zone → restaurant** et rattachement du catalogue, des commandes,
  de la flotte et du barème de frais à cette hiérarchie.
- Recherche géospatiale réelle (livreurs à proximité, zone couvrant un point) via PostGIS.

---

## 10. Exigences non fonctionnelles retenues

| Axe | Cible | Origine |
|---|---|---|
| Latence API | p95 < 300 ms (lecture), < 1 s (écriture) | CDC : « < 1 s » |
| Charge | 1 000 utilisateurs simultanés, croissance x10 sans réécriture | CDC + mission |
| Disponibilité | 99,5 % | CDC |
| Fraîcheur du suivi | position visible en < 2 s après émission | Déduit du pas de 10 s |
| Langues | Français, Anglais | CDC |
| Devise | FCFA (XOF) — **multi-devises requis** par le multi-pays | CDC + mission |
| Conformité | RGPD : droit à l'effacement, minimisation, journal d'accès aux données sensibles | CDC |
| Sécurité | Aucune régression sur les 20 invariants du §6 ; couverture par tests d'attaque | Analyse |

---

## 11. Ce qui entre en Phase 2

1. Découpage en applications Django à partir des 18 domaines du §4.
2. Arbitrage du modèle d'autorisation (rôle simple vs permissions granulaires) — §3.
3. Arbitrage du contrat d'API (compatibilité clients Dart actuels vs contrat propre) — §7.
4. Stratégie temps réel : périmètre Channels vs push FCM — §8.
5. Traitement du multi-tenant géographique — §2.
