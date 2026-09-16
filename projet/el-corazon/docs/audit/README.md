# Audit El Corazón — septembre 2026

Relevé du 11 septembre 2026, branche `redesign-client-ui`, commit `50d0cea`.

**Méthode.** Le code et les migrations sont la source de vérité. Les documents
existants (`README.md`, `ETAT_FONCTIONNALITES.md`, `SCHEMA_BDD_COMPLET.md`,
`AUDIT_2026-09-07.md`) ont servi de carte, jamais de preuve. Chaque affirmation
de cet audit porte son emplacement dans le code ou la commande qui l'établit.

---

## Le résultat en une page

Le brief de refonte suppose un système truffé de données simulées, de logique
contradictoire et de fonctions fictives. **La mesure ne le confirme pas.**

```
TODO / FIXME / HACK / XXX   backend   →  0
TODO / FIXME                Flutter   →  0
mock / fake / dummy         Flutter   →  0 fichier
tests backend                         →  1 695 cas, plancher de couverture 92 %
vulnérabilités exploitables trouvées  →  0
```

Le cœur transactionnel — **commander, payer, livrer, suivre** — est en état de
production. Plusieurs phases du brief y sont déjà satisfaites : instantané de
commande (10), recalcul serveur du panier (11), acceptation atomique des courses
(16), webhooks idempotents (17), paiement partagé adossé à une transaction
vérifiée (18), séparation type d'utilisateur / permissions (19), multi-pays sans
valeur codée en dur (14), et les quatre scénarios de concurrence de la phase 32.

**Ce qui manque n'est pas de la qualité, c'est un étage de domaine : la
fabrication.**

> **Correction apportée par le lot 1.** Cette page affirmait le cœur
> transactionnel en état de production. Il ne l'était pas sur un point : **la
> création de commande n'appliquait ni les horaires d'ouverture ni la suspension
> des commandes**. Une cuisine fermée encaissait ; seul l'écran disait « Fermé ».
> L'audit l'avait classé en simple dispersion de règles (I2) ; le code, lu
> jusqu'au bout, le rangeait en `BROKEN`. Corrigé et verrouillé par des tests —
> document 03, I2.

| Entité attendue par le brief | Occurrences dans le backend |
|---|---|
| `Ingredient`, `Recipe`, `RecipeIngredient` | 0 |
| `Inventory`, `StockMovement` | 0 |
| `Station`, `ProductionTask` | 0 |
| `Menu` (entité), `Variant` | 0 |

> **État après les lots 2a, 2b et 2-bo** (arbre de travail, non commité) :
> `Ingredient`, `StockItem`, `StockMovement`, `Recipe`, `RecipeIngredient` et
> `AdjustmentRequest` existent, avec leur back-office. « Préparer » sort
> désormais la matière du stock. `Station`, `ProductionTask`, `Menu` et
> `Variant` restent absents : la production consomme, elle n'ordonnance pas
> encore.

Tant que « préparer » reste un changement de colonne sans consommation de
matière ni ordonnancement de poste, El Corazón est une place de marché de
restauration — pas une dark kitchen. Le système sait **vendre** un plat et le
faire **livrer** ; il ne sait pas le **fabriquer**, ni ce qu'il coûte.

**Le brief annonce une refonte. La mesure indique une extension.**

---

## Les documents

| # | Document | Ce qu'on y trouve |
|---|---|---|
| 01 | [Architecture actuelle](01-current-architecture.md) | Ce que le dépôt contient réellement, le graphe de domaine en base, les couches |
| 02 | [Audit fonctionnel](02-functional-audit.md) | Chaque fonctionnalité avec son statut, preuve à l'appui |
| 03 | [Incohérences métier](03-business-inconsistencies.md) | Huit incohérences vérifiées — et dix soupçons écartés |
| 04 | [Sécurité](04-security-audit.md) | Les dix-huit points de la phase 30, un par un |
| 05 | [UI / UX](05-ui-ux-audit.md) | Design fragmenté, deux écrans sous un libellé, et le KDS introuvable |
| 06 | [API](06-api-audit.md) | Conventions tenues, et les règles pour les routes à venir |
| 07 | [Base de données](07-database-audit.md) | 38 `CHECK`, 32 uniques, 26 verrous — et les règles du lot 2 |
| 08 | [Aptitude à la production](08-production-readiness.md) | La checklist de la phase 38, et les trois blocages réels |
| 09 | [Dette technique](09-technical-debt.md) | Code mort, dette assumée, et ce qui n'est pas de la dette |
| 10 | [Plan de refonte](10-refactoring-plan.md) | L'ordre d'exécution, et pourquoi il diverge du brief |

---

## Les trois choses à retenir

### 1. Les blocages de production ne sont pas dans le code

```yaml
# backend/render.yaml
databases:
  - name: elcorazon-db
    plan: free        # ← les commandes, les paiements, l'historique comptable
```

La base de production est sur l'offre gratuite, et les scripts de sauvegarde —
qui existent, `restore.sh` compris — ne sont **déclenchés par rien**. Il n'y a
donc aujourd'hui aucune sauvegarde automatique des données de production.

Cela se corrige sans écrire une ligne, et doit être fait avant tout le reste.
Détail au document 08.

### 2. Le poste de cuisine était caché derrière l'écran qu'il remplace

Le KDS a été construit (`42f24b0`) parce que le personnel faisait avancer les
commandes depuis 1 779 lignes d'écran d'administration — « on y pilote une
flotte ; on n'y tient pas un coup de feu ».

L'écran a été livré. La navigation du back-office comptait sept sections,
**aucune n'était « Cuisine »**, et le seul accès à `KitchenScreen` était un
bouton posé dans la barre d'outils de l'écran d'administration qu'il devait
remplacer.

**Corrigé au lot 0** : « Poste de cuisine » ouvre désormais la section
OPÉRATIONS, avant « Commandes ». Trente lignes, meilleur rapport gain/coût du
projet. Document 05, §1.

### 3. Le renommage `Restaurant` → `Kitchen` doit venir en dernier

| Périmètre | Fichiers |
|---|---|
| Backend + tests + migrations | 208 |
| Flutter (3 applications + socle) | 132 |
| **Total** | **340 fichiers, ≈ 1 700 occurrences** |

Plus une migration de données, la réécriture du contrat d'API, et trois
applications déployées qui ne se mettent pas à jour le même jour.

Valeur produite pour le client, le cuisinier, l'exploitant ou le coût matière :
**aucune**. Et le faire en premier fige le vocabulaire d'une entité dont l'audit
montre qu'il lui manque les postes, la capacité, les menus et l'inventaire — donc
rouvrir 340 fichiers deux fois.

Le vocabulaire **visible** — libellés, messages, documentation d'exploitation —
peut changer immédiatement, pour quelques heures de travail et l'essentiel du
gain de clarté. Document 10, §1.

---

## L'ordre proposé

| Lot | Contenu | Valeur produite |
|---|---|---|
| **Immédiat** | Base payante, sauvegardes planifiées et **testées**, Sentry | Les données cessent d'être en risque |
| **0** ✅ | Entrée « Poste de cuisine », convergence des écrans de commandes, vestige hors ligne | Le KDS devient utilisable en service |
| **1** ✅ | `AvailabilityService` — et la cuisine fermée qui encaissait | Une seule réponse à « peut-on commander ? », appliquée à la commande |
| **2** ⏳ | **Ingrédients, recettes, inventaire, postes, tâches, KDS branché** — inventaire, recettes, réservation et back-office livrés ; postes et tâches à venir | **El Corazón devient une dark kitchen** |
| **3** | Entité `Menu`, périmètre de flotte | Le réseau multi-cuisines devient exploitable |
| **4** | Design system unifié, puis `Kitchen` | Une seule identité, un seul vocabulaire |

**Le lot 2 est le projet.** Tout ce qui passe devant lui sans le servir retarde
la seule chose qui manque réellement à ce produit : savoir fabriquer ce qu'il
vend.
