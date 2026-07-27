# Architecture El Corazón v2

Refonte de la plateforme sur **Flutter + Django + PostgreSQL/PostGIS + Redis + Celery + Channels**.

L'ancien backend Laravel et l'accès direct à Supabase depuis les applications Flutter ne sont pas
repris : ils servent de référence fonctionnelle, consultables dans l'historique git (jusqu'au
commit `56e0bec`).

## Documents

| Document | Contenu |
|---|---|
| [01 — Analyse fonctionnelle](01-analyse-fonctionnelle.md) | Acteurs, parcours, **20 invariants métier**, besoins d'API et de temps réel, périmètre v2 |
| [02 — Architecture générale](02-architecture-generale.md) | Composants, flux, découpage en applications, couches, déploiement |
| [03 — Modèle de données](03-modele-de-donnees.md) | Schéma PostgreSQL/PostGIS, invariants portés par la structure |
| [04 — Migration Flutter](04-migration-flutter.md) | Plan de la Phase 6 : rupture nette avec Supabase, module Dart partagé, ordre de migration par domaine et par app |

## Décisions (ADR)

| # | Décision | Enjeu |
|---|---|---|
| [001](adr/001-socle-technique.md) | Django 5.2 LTS + DRF + Channels, Python 3.13 | Durée de support, maturité géospatiale |
| [002](adr/002-decoupage-en-apps.md) | 18 apps par domaine, graphe de dépendances acyclique **vérifié en CI** | Empêcher le monolithe enchevêtré |
| [003](adr/003-couches-et-proportionnalite.md) | Services et repositories **conditionnels**, selon critères explicites | Éviter 400 fichiers de transport |
| [004](adr/004-authentification-jwt.md) | JWT RS256, refresh rotatif, révocation | Ferme T1 (brute-force) et T2 (sessions survivantes) |
| [005](adr/005-modele-d-autorisation.md) | Type de compte + permissions granulaires, refus par défaut | Unifie deux mécanismes qui s'ignoraient |
| [006](adr/006-multi-tenant-geographique.md) | Hiérarchie pays → ville → zone → restaurant, posée maintenant | Le coût est irrécupérable s'il est reporté |
| [007](adr/007-identifiants-et-montants.md) | UUIDv7 ; montants en entier mineur + devise | Index en écriture ; exactitude comptable |
| [008](adr/008-temps-reel-channels-vs-push.md) | WebSocket au premier plan, FCM en arrière-plan | Ferme L3 (falsification de suivi) |
| [009](adr/009-contrat-d-api.md) | Contrat propre, rupture coordonnée avec les clients Dart | Ne pas figer un plantage sur champ absent |
| [010](adr/010-machines-a-etats.md) | Transitions déclaratives, monotones, verrouillées | Ferme C3, C4, C5, P1, L2 |

## Fil conducteur

L'analyse de l'existant a produit 20 invariants métier, dont **12 correspondent à des failles
reproduites empiriquement** sur l'implémentation précédente. Chaque ADR indique lesquelles il ferme,
et par quel mécanisme.

La ligne de conduite est constante : **fermer une faille par conception plutôt que par vigilance**.
Une règle qu'on doit penser à appliquer sera oubliée ; une règle qu'on ne peut pas contourner, non.

## Avancement

- [x] Phase 1 — Analyse fonctionnelle
- [x] Phase 2 — Architecture générale et ADR
- [x] Phase 3 — Modèle de données du chemin critique (10 apps, 185 tests)
- [x] Phase 8 — Socle DevOps (Docker, Compose, Nginx, CI)
- [x] Phase 4 — API REST v1
  - [x] 4a — Authentification (`/auth/`)
  - [x] 4b — Découverte et catalogue (`/geography/`, `/restaurants/`, `/catalog/`)
  - [x] 4c — Profil, panier, commandes, paiements (`/profiles/`, `/carts/`, `/orders/`, `/payments/`)
  - [x] 4d — Livraison, suivi et périmètre du personnel (`/delivery/`, `/tracking/`)
- [x] Phase 5 — Temps réel
  - [x] 5a — WebSocket : suivi de commande, file du livreur, rattrapage par séquence
  - [x] 5b — Notifications, push par Celery, événements de domaine
- [ ] Phase 6 — Flutter Clean Architecture ([plan détaillé](04-migration-flutter.md), rupture nette
  avec Supabase — pas de coexistence transitoire)
- [x] Phase 7 — Tests et qualité (graphe vérifié, contrat vérifié, plancher de couverture)
- [x] Fidélité par points (F1-F5) — solde, journal, catalogue de récompenses, expiration par
  inactivité, échange contre un code promotionnel nominatif
- [x] Gamification (G1) — succès, badges, défis, débloqués par la livraison d'une commande,
  crédités une seule fois même si l'événement est rejoué
- [x] Social (S2-S4) — groupes à capacité vérifiée sous verrou, publications dont la visibilité
  se filtre à chaque accès, partage de commande restreint à son propriétaire
- [x] Support — tickets et fil de messages, réclamations et demandes de retour, toutes
  cloisonnées par propriétaire ; le montant d'un retour est plafonné au total payé
- [x] Analytics — journal d'événements immuable, rapports de chiffre d'affaires, produits et
  performance livreur agrégés à la demande depuis les commandes, jamais dupliqués
- [x] Abonnements (P4) — catalogue de plans tarifés serveur, le règlement initial et le
  renouvellement suivent le chemin normal d'un encaissement (`payments`, P1/P2), jamais une
  confirmation côté client

Ordre de construction retenu : **chemin critique d'abord** — identité, catalogue, panier, commandes,
paiements, livraison, suivi. Promotions, fidélité, gamification, social, support, analytics et
abonnements faits.
Il ne reste que la Phase 6 (Flutter).
