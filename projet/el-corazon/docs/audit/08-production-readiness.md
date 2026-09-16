# 08 — Aptitude à la production

Checklist de la phase 38 du brief, remplie sur preuve.

**Le code est plus proche de la production que l'infrastructure qui l'héberge.**
C'est le déséquilibre principal de ce document : les blocages ne sont pas dans
les 39 464 lignes de Python, ils sont dans `backend/render.yaml`.

---

## Les trois blocages réels

### B1 — PostgreSQL de production est sur l'offre gratuite

```yaml
# backend/render.yaml:334-340
databases:
  - name: elcorazon-db
    plan: free          # ← ici
    postgresMajorVersion: "17"
```

C'est le point le plus grave de tout l'audit, et il ne se corrige pas par du
code.

Les offres gratuites de base de données n'ont **ni sauvegarde automatique, ni
garantie de rétention, ni engagement de disponibilité**, et plafonnent le
stockage. Les conditions exactes de Render sont à revérifier avant arbitrage —
elles changent — mais aucune lecture de ces conditions ne rend acceptable de
faire porter les commandes, les paiements et l'historique comptable d'une
enseigne par une base gratuite.

**Le contraste avec le reste du blueprint le confirme** : le courtier de tâches
a été délibérément passé en `starter`, avec une justification écrite de vingt
lignes — « une tâche acceptée ne doit pas disparaître ». Le même raisonnement
s'applique, en plus fort, à la base qui contient l'argent.

| Service | Plan | Commentaire |
|---|---|---|
| **PostgreSQL** | **`free`** | **à passer en payant — B1** |
| Web | `free` | mise en veille, démarrage à froid — B2 |
| Cache (keyvalue) | `free` | 25 Mio, `allkeys-lru` — **acceptable et argumenté** |
| Courtier (broker) | `starter` | `noeviction` — déjà arbitré, à raison |
| Worker Celery | `starter` | |
| Battement Celery | `starter` | |

### B2 — Le service web est sur l'offre gratuite

`render.yaml:41`. Un service web gratuit se met en veille après inactivité et
redémarre à froid à la requête suivante.

Pour une application de commande de repas, cela signifie qu'un client qui ouvre
l'application à 11 h après une matinée calme attend le démarrage du conteneur —
migrations, fichiers statiques et uvicorn compris, puisque c'est la séquence de
`deploy/start-api.sh`. Le premier client de chaque creux paie l'addition.

Moins grave que B1 — aucune donnée n'est en jeu — mais directement visible par
l'utilisateur.

### B3 — Les sauvegardes existent mais ne sont pas planifiées

`backend/deploy/backup.sh` et `restore.sh` existent, et le script porte la bonne
phrase : « Une sauvegarde qu'on ne restaure jamais n'est pas une sauvegarde » —
`restore.sh` est bien là, ce qui est plus rare que le script de sauvegarde.

Mais **rien ne les déclenche**. Aucune tâche planifiée dans `render.yaml` ; la
seule occurrence de `schedule` est le `--schedule` de `celery beat`. La
sauvegarde est donc une opération manuelle, à la main de quelqu'un qui doit y
penser.

Combiné à B1 — une base gratuite sans sauvegarde fournisseur — cela veut dire
qu'**il n'existe aujourd'hui aucune sauvegarde automatique des données de
production**.

B1 et B3 doivent être traités ensemble et avant tout le reste. Ils ne dépendent
d'aucun développement.

---

## La checklist de la phase 38

| # | Point | État | Preuve / réserve |
|---|---|---|---|
| 1 | Architecture cohérente | ✅ | ADR 001-012, graphe acyclique vérifié en CI |
| 2 | Kitchen correctement modélisée | ⚠️ | `Restaurant` solide ; manquent postes, capacité, menus, inventaire |
| 3 | Country/City/Zone cohérents | ✅ | FK non nulles, `resolve_zone()` unique depuis `50d0cea` |
| 4 | Catalogue cohérent | ⚠️ | Fonctionne ; dupliqué par cuisine faute d'entité `Menu` (I3) |
| 5 | Recettes | ❌ | **absent** |
| 6 | Ingrédients | ❌ | **absent** |
| 7 | Inventaire | ❌ | **absent** — `stock_quantity` compte des plats finis |
| 8 | Production | ❌ | **absent** |
| 9 | KDS | ⚠️ | Écran livré (`42f24b0`), entrée de navigation posée au lot 0 ; affiche des commandes, pas des tâches |
| 10 | Commandes | ✅ | Machine à états + `CHECK` généré, idempotence, instantanés |
| 11 | Paiement | ✅ | Webhook signé et idempotent, 26 `select_for_update` |
| 12 | Livraison | ✅ | Zones, barèmes, franco, `delivery_fee_gross` distinct |
| 13 | Livreurs | ✅ | Acceptation atomique ; réserve réseau — un livreur par cuisine (I4) |
| 14 | Tracking | ✅ | WebSocket dédié, 48 tests |
| 15 | Notifications | ✅ | 5 familles, push + in-app + campagnes |
| 16 | Admin | ⚠️ | 7 sections, « Poste de cuisine » ajouté au lot 0 ; pas de section Inventaire |
| 17 | RBAC | ✅ | Type d'utilisateur séparé des permissions (phase 19 satisfaite) |
| 18 | Sécurité | ✅ | Aucune vulnérabilité trouvée — document 04 |
| 19 | Tests | ✅ | **1 695 cas** (1 778 après le lot 2a), plancher 92 %, 4 scénarios de concurrence couverts |
| 20 | Migrations | ✅ | 51, propres ; **attention au double dépôt** |
| 21 | Performance | ⚠️ | 122 `select_related` / 14 `prefetch_related` — à mesurer (P1) |
| 22 | Monitoring | ⚠️ | Sentry **intégré mais inerte** tant que `SENTRY_DSN` est vide |
| 23 | Logs | ✅ | Identifiant de corrélation par requête, journalisation structurée |
| 24 | **Backups** | ❌ | **Scripts présents, jamais déclenchés — B3** |
| 25 | CI/CD | ✅ | ruff + mypy strict + PostGIS + Redis ; `autoDeployTrigger: checksPass` |
| 26 | Documentation | ⚠️ | Abondante ; parle de « Restaurant », pas de « Kitchen » |
| 27 | Responsive | ⚠️ | Back-office 5 `LayoutBuilder` pour 41 711 l. — insuffisant |
| 28 | Accessibility | ❌ | **0 `semanticLabel`** sur 124 450 lignes de Dart |
| 29 | Error handling | ✅ | RFC 9457, membres réservés protégés |
| 30 | Loading states | ✅ | 29/34 écrans client |
| 31 | Empty states | ✅ | 34/34 |
| 32 | Production configuration | ❌ | **`plan: free` sur la base et le web — B1, B2** |

**Décompte : 16 ✅ · 10 ⚠️ · 6 ❌**

---

## Ce qui est déjà exemplaire

Ces points n'appellent aucun travail et méritent d'être protégés d'une refonte
mal ciblée.

**Le déploiement ne peut livrer que du code testé.** `autoDeployTrigger:
checksPass`, et non `commit`. L'en-tête de la CI raconte l'incident qui a mené à
ce réglage : le correctif posant `PUSH_BACKEND` sur le vrai connecteur de
notifications existait, testé et vert, dans un commit **non poussé** — pendant
que la production envoyait ses notifications dans le vide et que le tableau de
bord des tests était au vert. Le code testé et le code déployé sont maintenant
le même commit, par construction.

**Les deux sondes sont distinguées, et pour la bonne raison.** `/health/` ne
touche pas la base : Render coupe le trafic et redéploie quand cette sonde
échoue, et la lier à PostgreSQL ferait redémarrer en boucle des conteneurs sains
le jour d'une indisponibilité de base. `/ready/`, qui interroge les dépendances,
sert au diagnostic. La confusion entre les deux est une cause classique
d'incident en cascade ; elle est évitée ici explicitement.

**Le courtier est séparé du cache.** `noeviction` pour la file de tâches,
`allkeys-lru` pour le cache. Un défaut de cache est sans conséquence ; une tâche
évincée silencieusement ne l'est pas.

**La région est choisie.** Francfort, ~90 ms depuis Lomé contre ~140 ms par la
Virginie. Décidé, pas subi.

---

## Le piège du double dépôt

Le backend vit dans **deux dépôts** : `elcorazon` (le projet complet) et
`elcorazon-backend` (**celui que Render déploie**). La CI a été dupliquée pour
rendre le second autonome, et les chemins sont la seule différence voulue entre
les deux fichiers.

**Conséquence opérationnelle, à ne pas perdre de vue pendant les lots à venir :**

1. Une migration écrite ici n'est pas déployée tant qu'elle n'est pas dans
   l'autre dépôt.
2. Un tableau de bord vert dans un dépôt ne dit **rien** de l'autre.
3. Une divergence entre les deux fichiers de CI ferait passer ici ce que là-bas
   refuse.

Le lot 2 ajoute six à huit modèles et autant de migrations. C'est le moment où
ce piège coûte le plus cher. **Fusionner les deux dépôts avant le lot 2 est
probablement le meilleur investissement d'infrastructure du projet** — cela
touche les historiques GitHub et la configuration Render, donc c'est une
décision, pas une tâche.

---

## Ordre d'exécution

### Immédiat — sans code

| # | Action | Effort |
|---|---|---|
| 1 | Passer PostgreSQL en plan payant (**B1**) | facturation |
| 2 | Planifier `backup.sh`, et **tester `restore.sh` une fois** (**B3**) | 1 h |
| 3 | Renseigner `SENTRY_DSN` — le SDK est déjà intégré | 10 min |
| 4 | Passer le service web en plan payant (**B2**) | facturation |

Le point 2 mérite d'être lu deux fois : une restauration jamais essayée est une
hypothèse, pas une sauvegarde. Le script existe précisément pour qu'on l'essaie.

### Lot 0 — une séance

| # | Action |
|---|---|
| 5 | ✅ Entrée « Poste de cuisine » en tête d'OPÉRATIONS |
| 6 | ✅ Profil et onglet convergent vers la même liste de commandes |
| 7 | ✅ Vestige `offline_orders` retiré, base locale en version 3 |

### Décision avant le lot 2

| # | Question |
|---|---|
| 8 | Fusionner `elcorazon` et `elcorazon-backend` ? |

### Lots 1 à 3

Voir document 10.

---

## Réponse à la question posée

> Le projet est-il prêt pour la production ?

**Pour vendre et livrer : oui, dès que B1, B2 et B3 sont réglés.** Le cycle
DISCOVER → ORDER → PAY → DELIVER → TRACK est complet, testé et sécurisé.

**Comme dark kitchen : non**, et aucun réglage d'infrastructure n'y changera
rien. Sans recettes, sans ingrédients, sans inventaire et sans production, le
système ne connaît pas son coût matière, ne détecte pas une rupture, n'ordonnance
aucun poste et ne peut pas promettre une heure qui tienne compte de ce qui a été
commandé.

Les deux réponses ne sont pas contradictoires : elles disent que le produit
exploitable aujourd'hui est une place de marché de restauration, et que la dark
kitchen reste à construire — sur des fondations qui, elles, sont bonnes.
