# Rapport de phase — lot 4 (réseau de cuisines de bout en bout), lot 3 (cuisine résolue, erreurs distinctes), lot 2-bo (back-office de la matière), lot 1 (disponibilité), lot 2 (production, 2a et 2b)

> ## ⚠️ Bilan provisoire — 16 septembre 2026
>
> **Ce document n'atteste plus rien.** Les tableaux « Validation » de chaque lot
> décrivent des exécutions faites au moment de leur rédaction, sur un arbre de
> travail qui a continué de bouger ensuite. Au moins une de leurs affirmations
> était **fausse** au moment du gel : le lot 4 annonce « `flutter analyze` ×4 :
> No issues found » alors que `dely` portait trois erreurs de compilation dans
> `lib/` — la refonte de `Course`, qui retire le champ `commande`, était
> inachevée. Une application qui ne compile pas ne peut pas avoir été testée.
>
> Tant que les mesures n'auront pas été refaites et consignées ici, **aucune
> ligne verte de ce rapport ne doit être citée comme preuve**.
>
> Ce qui a changé depuis :
>
> - l'arbre de travail est **figé** dans le commit `ca0e47a`, sur la branche
>   `fix/audit-2026-09-15` — 185 entrées, dont 51 fichiers neufs ; ce commit ne
>   prétend pas que l'état est vert, il le rend reproductible ;
> - un audit des trois applications (16 septembre) a relevé 20 constats qui ne
>   figurent pas ici, dont quatre touchant la chaîne commande → cuisine →
>   livraison. Ils seront consignés dans `AUDIT_2026-09-15.md` ;
> - la compilation de `dely` a été rétablie (phase 0 du plan de correction).
>
> ### Mesures refaites — phases 0 et 1
>
> | Porte | Au gel (`ca0e47a`) | Après phase 0 (`05e72a2`) | Après phase 5 |
> | --- | --- | --- | --- |
> | `flutter analyze` socle / client / admin | No issues found | No issues found | No issues found |
> | `flutter analyze` dely | **13 problèmes, dont 3 erreurs en `lib/`** | No issues found | No issues found |
> | `flutter test` socle | non exécuté | 509 | **533** |
> | `flutter test` client | non exécuté | 443 | **461** |
> | `flutter test` admin | non exécuté | 238 | **267** |
> | `flutter test` livreur | non exécuté | 168 | **183** |
> | `pytest` | non exécuté | **2 041 passés, 2 échecs** | **2 102 passés, 0 échec** |
> | `ruff check` · `ruff format --check` · `mypy --strict` | non exécutés | verts | verts (444 fichiers, 296 sources) |
> | `spectacular --fail-on-warn` | non exécuté | non exécuté | vert |
> | `tools/code_mort.py` | aucun fichier injoignable | idem | idem |
> | `tools/contrat_routes.py` | 177 HTTP + 6 WS, toutes servies | idem | 178 HTTP + 6 WS, toutes servies |
>
> **Les deux échecs pytest de la phase 0 ont été isolés** sur l'arbre gelé, sans
> les modifications du lot, pour les distinguer d'une régression :
>
> * `delivery/test_affectation_automatique.py::…le_montant_a_encaisser…` —
>   **préexistant** : le contrat d'une course a gagné `item_image`, le test ne
>   l'avait pas suivi. Corrigé en phase 1 ;
> * `tracking/test_websocket.py` — **instable**. Trois cas différents de ce
>   fichier ont été vus rouges sur quatre exécutions complètes, jamais les
>   mêmes, et **tous passent isolément** (24 tests verts seuls). Le rattrapage
>   de messages manqués dépend d'un ordonnancement asynchrone sous charge.
>
> Une **seconde** famille s'est révélée aux exécutions suivantes, de même
> nature : `availability/test_acceptation_commande.py::TestLeVerrouDeLaCuisine::
> test_une_pause_attend_la_commande_qui_tient_la_cuisine` pose un `lock_timeout`
> de 300 ms et attend qu'un verrou concurrent le fasse expirer ; sous charge, la
> fenêtre se referme autrement. Le dossier passe seul, 70 tests.
>
> Ni l'une ni l'autre n'est une régression de ce chantier, et ni l'une ni
> l'autre n'est un test sur lequel on peut s'appuyer en l'état : elles rendent
> la suite complète rouge au hasard, ce qui est la façon la plus sûre de faire
> ignorer un vrai échec.
>
> La dernière exécution complète, elle, est **intégralement verte — 2 084
> passés**. C'est une bonne nouvelle et non une preuve : ces deux familles
> dépendent de la charge de la machine, et une exécution verte ne dit rien de
> la suivante. Ce qui est établi, c'est qu'aucun de leurs échecs n'a jamais
> survécu à une exécution isolée.
>
> Les sections ci-dessous sont conservées **telles qu'elles ont été écrites**,
> pour ce qu'elles documentent des intentions et des changements de chaque lot.
> Leur partie « Validation » est à lire comme un historique, pas comme un état.

---

# Chantier de correction — audit du 16 septembre 2026

Branche `fix/audit-2026-09-15`. Chaque phase est un commit, et chaque commit
porte ses mesures.

| Phase | Commit | Objet |
| --- | --- | --- |
| 0 | `ca0e47a`, `05e72a2` | geler l'arbre, rétablir la compilation de `dely` |
| 1 | `07ade33` | la chaîne commande → cuisine → livraison |
| 2 | `e81aec9` | client : session, annulation, suivi |
| 3 | `2d17eae` | livreur : encaissement, course refusée, hors ligne |
| 4 | `7686859` | back-office : refus affichés, affectation unique, fuseau, code mort |
| 5 | `d4b4bcf`, `f99b646` | contrats, scénarios, trace (`AUDIT_2026-09-15.md`) |
| 2 *(reprise)* | `39879e7`, `2a34956` | suivi après coupure, notification, barre de l'app |
| 3 *(reprise)* | `ba692ba` | le règlement cesse de se déduire du moyen de paiement |
| 4 *(reprise)* | — | la journée d'un rapport commence chez la cuisine |

**Deux phases ont été rouvertes**, et c'est le résultat de la relecture plutôt
qu'un oubli d'ordonnancement :

* la phase 2 a été complétée par les deux cas de suivi qui lui manquaient, et le
  premier test d'écran client a mis au jour un débordement d'un pixel qui
  rendait toute l'application cliente non testable à l'écran ;
* la phase 3 **se trompait sur son propre correctif**. Elle annonçait que le
  montant à encaisser venait désormais du serveur « qui connaît l'état réel du
  règlement » ; le serveur, lui, le déduisait du moyen de paiement. La
  déduction fautive avait été déplacée, pas corrigée ;
* la phase 4 avait corrigé **une** convention d'heure — les fermetures
  exceptionnelles — et laissé intacte celle des rapports, qui tranchait les
  journées à minuit UTC. Elle avait aussi retiré onze méthodes mortes en
  laissant les neuf de la couche suivante.

Voir `AUDIT_2026-09-15.md`, section B bis, pour les deux.

## Phase 1 — ce qui a changé de règle

**Une course n'avance plus sans sa commande.** Le geste « j'ai récupéré » est
refusé tant que la cuisine n'a pas déclaré le repas prêt, et une étape dont la
projection échoue annule la transaction entière — course comprise. Auparavant,
la projection retombait en silence : la course allait jusqu'à « livrée », le
livreur était crédité, et la commande restait « en préparation » pour le client.

**`OFFERABLE_FROM` se réduit à `ready`.** Une course ne se propose plus pendant
la préparation. C'est un **changement de règle d'exploitation**, assumé : on ne
pré-affecte plus un livreur pendant la cuisson. L'affectation automatique
fonctionnait déjà ainsi (`dispatch_on_ready`) ; seul le back-office pouvait
proposer plus tôt. Une constante à rouvrir si l'exploitation le demande — la
garde sur le retrait, elle, reste la règle de fond.

**Le livreur est publié sur le suivi, pas sur la commande.** `orders` n'a pas le
droit de connaître `delivery` (ADR-002, vérifié par `tests/architecture`) : le
contrat de la commande ne pouvait pas porter le livreur, et c'est pourquoi
« Message », « Appeler » et la notation étaient morts côté client. Identité dès
l'acceptation, téléphone tant que la course est engagée, plus rien après.

**Le poste de cuisine a son propre contrat.** `GET /orders/manage/kitchen/` rend
la file du service d'**une** cuisine, lignes comprises, sans montants ni
coordonnées du client. L'établissement est obligatoire et filtré côté serveur.

## Ce qui reste ouvert

* les écrans « carte temps réel », « historique livreur » et « statistiques
  livreur » déclarent désormais leur dépendance et distinguent la panne du vide,
  mais n'ont **pas** de test widget : leur montage réclame Google Maps. Le
  contrat qu'ils partagent, lui, est testé (`fenetres_de_supervision_test.dart`) ;
* le comportement de session est vérifié dans le socle
  (`verification_flow_test.dart`) **et**, côté client, de bout en bout
  (`session_du_compte_test.dart` : connexion, déconnexion, compte suivant sur le
  même téléphone). Côté livreur, l'état hors ligne n'est vérifié que dans le
  socle : le portail monte l'écran d'appel et le routeur de notifications, que
  ce test ne cherche pas à monter.

---

> Branche `redesign-client-ui`, au-dessus de `50d0cea`. **Rien n'est commité** :
> ce rapport décrit un arbre de travail, et la décision de commiter appartient à
> l'exploitant du dépôt. Les lots sont décrits du plus récent au plus ancien.
>
> _(Cette note date de la rédaction initiale : le travail est depuis figé dans
> `ca0e47a` — voir le bilan provisoire ci-dessus.)_

---

# Lot 4 — pays → ville → zone → cuisine → commande → livreur, sans trou

## Ce que l'audit a établi avant d'écrire

La hiérarchie demandée existe depuis l'ADR-006 sous d'autres noms :
`Country → City → DeliveryZone → Restaurant`. La résolution de cuisine
(`check_delivery`), le juge de commande (`can_accept_order`), le cloisonnement
et le cycle de vie des cuisines sont centralisés et testés. **Rien n'a été
recréé.** Les défauts étaient aux bords :

| # | Défaut | Conséquence |
|---|---|---|
| 1 | `resolve_zone` ne bornait pas les zones municipales à la ville de la cuisine désignée | un panier ouvert à Lomé se faisait livrer une adresse de la ville voisine, au barème de celle-ci, alors que le choix automatique la refusait |
| 2 | une cuisine pouvait se rattacher à la zone **propre** d'une autre, et se publier sur un marché fermé | tarif du voisin ; cuisine « En service » invisible des clients |
| 3 | la commande ne figeait ni pays, ni ville, ni **zone** | déplacer une cuisine réécrivait l'historique ; aucun rapport ni filtre par zone possible |
| 4 | aucune fermeture datée | fermer un jour férié = retirer une plage, donc tous les mêmes jours ; « Fermé » sans « jusqu'à quand » |
| 5 | livreur rattaché à une cuisine, sans zone | une course de Cocody pouvait partir chez le livreur de Yopougon |
| 6 | affectation **entièrement manuelle** | une commande prête attendait qu'un superviseur choisisse un livreur |
| 7 | la course ne portait ni consignes, ni zone, ni **montant à encaisser**, ni contenu du sac ; numéro du client lisible avant acceptation | le livreur apprenait le montant sur le pas de la porte |
| 8 | back-office : pas de filtre pays/ville/zone, pas de chiffres par zone ; formulaire livreur au type de véhicule inutilisable (`Moto` envoyé au lieu de `motorcycle`) et « préférences » inventées | |
| 9 | client : panier changé de cuisine sans un mot ; « zone non desservie » dont le bouton principal ne fermait pas le dialogue ; ni cuisine ni zone au paiement | |

## Ce qui change

**Serveur — 4 migrations additives** : `orders/0005` (colonnes), `0006` (index),
`0007` (reprise : 18/18 commandes locales situées), `restaurants/0008`
(`KitchenClosure`), `restaurants/0009` (`auto_dispatch_couriers`),
`delivery/0007` (`service_zones`). Réglage nouveau :
`DELIVERY_OFFER_TTL_SECONDS` (défaut 90). Tâche planifiée nouvelle :
`expire-stale-offers` (60 s) — **exige le worker et l'horloge Celery**.

| Où | Changement |
|---|---|
| `geography/resolution.py`, `restaurants/delivery.py` | `resolve_zone(city_id=…)` — défaut 1 |
| `restaurants/models.py`, `serializers.py` | `zone_anchoring_problem`, `configuration_gaps` (zone propre d'autrui, marché fermé) — défaut 2 |
| `orders/models.py`, `services.py`, `serializers.py`, `backoffice.py` | géographie figée, journal `order.created`, filtres `country__iso_code`, `city__slug`, `delivery_zone` — défaut 3 |
| `restaurants/availability.py`, `common/availability.py`, `backoffice.py`, `urls.py`, `admin.py` | `KitchenClosure`, `kitchen_temporarily_closed`, `next_opening`, `reopens_at`/`reopens_label`, `/restaurants/manage/closures/` — défaut 4 |
| `delivery/models.py`, `services.py`, `views.py`, `serializers.py` | `service_zones`, `set_service_zones`, `POST couriers/{id}/zones/`, garde de zone dans `offer` — défaut 5 |
| `delivery/dispatch.py`, `tasks.py`, `signals.py`, `config/celery.py` | affectation automatique — défaut 6 |
| `delivery/serializers.py` | course : `delivery_instructions`, `delivery_zone_name`, `city_name`, `payment_method`, `order_total`, `amount_to_collect`, `items` ; numéro masqué au livreur hors course engagée — défaut 7 |
| `analytics/reports.py`, `views.py` | `GET /analytics/reports/network/?level=` |
| `delivery/management/commands/audit_reseau.py` | audit de cohérence en lecture seule |

**Flutter** — socle : modèles et dépôts (`statusLabel`, `KitchenClosure`,
`NetworkRow`, `ZoneRef`, filtres de supervision, course enrichie). Client :
confirmation et avis de changement de cuisine, dialogue de zone non desservie
refait, cuisine et zone au récapitulatif, étiquette « Fermé — réouverture … ».
Admin : filtres Pays → Ville → Zone, fermetures exceptionnelles, zones du
livreur, affectation automatique sur la fiche, onglet **Réseau → Activité**.
Livreur : montant à encaisser, zone, consignes, zones du dossier, retrait d'une
proposition expirée.

## Validation

| Porte | Résultat |
|---|---|
| `ruff check`, `ruff format --check` | verts — 441 fichiers |
| `mypy --strict common config apps` | no issues found in 296 source files |
| `makemigrations --check` | No changes detected |
| `pytest --cov` (suite complète) | **2 041 passed**, couverture **93,02 %** (plancher 92 %) — 1 échec : `social/test_deux_j_aimes_concurrents…`, instable et antérieur (vert 3/3 seul, voir risques) |
| `pytest tests/delivery` après la dernière retouche | 195 passed |
| Parcours de bout en bout par l'API (`test_parcours_reseau_de_bout_en_bout`) | vert — marché, ville, 2 zones, cuisine, horaires, carte, 2 livreurs affectés par zone, mise en service, adresse, carte, panier personnalisé, commande (7 400 + 1 000 recalculés), cuisine confirmée → prête, **proposition automatique au livreur de Cocody et non au plus proche de Yopougon**, acceptation, retrait, livraison, client « livrée », supervision filtrée pays/ville/zone/cuisine, rapport par zone |
| `flutter analyze` ×4 | No issues found |
| `flutter test --coverage` | socle **509** (+11) · client **443** (+5) · admin **238** (+4) · livreur **166** (+2) |
| `tools/couverture.py` | planchers tenus — socle 68,95 %, client 12,17 %, livreur 9,68 %, admin 3,73 % |
| `tools/contrat_routes.py` | 177 adresses appelées, toutes servies |
| `tools/code_mort.py` | rouge **antérieur** inchangé : `fastfood/presentation/commande.dart` |
| Base locale | 4 migrations appliquées ; reprise 18/18 commandes situées ; `audit_reseau` : aucune anomalie sur 7 cuisines |
| API locale réelle | annuaire : « demain à 11 h 00 » (Lomé, Abidjan), « aujourd'hui à 10 h 00 » (Douala, UTC+1) ; rapport réseau par zone XOF/XAF séparés ; filtre de supervision par zone : 2 commandes d'Abidjan |

**Non vérifié :** les écrans ouverts à l'œil contre le serveur (analysés, compilés
par `flutter test`, logique testée), et `flutter build`.

## Risques ouverts

| # | Risque | Traitement |
|---|---|---|
| L4-R1 | Un livreur peut lire `GET /orders/{id}/` — numéro du client compris — pour une course seulement **proposée** ou refusée : le masquage posé sur la course est contourné par cette route | le graphe interdit à `orders` de connaître les statuts de course ; à traiter par une route de détail côté `delivery`, puis restreindre le `get_queryset` livreur de `orders` |
| L4-R2 | Sans l'horloge Celery, une proposition sans réponse n'expire jamais | `elcorazon-beat` est déclaré dans `render.yaml` ; vérifier qu'il tourne avant d'annoncer la fonctionnalité |
| L4-R3 | La reprise attribue l'historique d'une cuisine déjà déplacée à sa ville **actuelle** | aucune autre source ; écrit dans la migration `0007` |
| L4-R4 | Un livreur reste rattaché à **une** cuisine | voir ADR-006 : la zone couvre les cas rencontrés |
| L4-R5 | L'affectation s'exécute dans la requête qui passe la commande « prête » (après commit) | quelques requêtes de plus sur ce geste ; une panne n'annule pas le changement de statut, l'horloge rattrape |

## Déploiement

1. `migrate` puis `bootstrap_roles` — **chaque dépôt** (`elcorazon`, `elcorazon-backend`).
2. Vérifier que `elcorazon-worker` **et** `elcorazon-beat` tournent.
3. `python manage.py audit_reseau` sur la base servie : attendu « Aucune anomalie ».
4. Toutes les cuisines passent en affectation automatique (défaut vrai) : le dire aux superviseurs, ou la décocher par cuisine.

---

# Lot 3 — la cuisine du client, et une panne qui ne se dit plus « aucune cuisine »

## La panne du 13 septembre, et ses trois causes enchaînées

Le client affichait `AucunEtablissement(Aucun restaurant n'est en service)`, `Error loading menu items`, `annuaire illisible — network_error`.

| # | Où | Défaut | Preuve |
|---|---|---|---|
| 1 | Base locale | `restaurants/0007` (lot 2-bo) non appliquée : le conteneur ne migre qu'à son démarrage, uvicorn recharge le code à chaud | `GET /restaurants/` → **500** `column restaurants_restaurant.stock_adjustment_ceiling_minor does not exist` ; `/health/` → 200 |
| 2 | `ApiClient._mapDioError` (socle) | tout corps non JSON devenait `ApiException.network` : le 500 HTML de Django se lisait **`network_error`** | test `un 500 en HTML garde son statut` |
| 3 | `RestaurantContextService.resolve` | `if (_isLoading) return;` rendait la main **sans attendre** : le catalogue, lancé en parallèle, lisait un slug nul et `AucunEtablissement(null)` = « aucun restaurant en service » | test de mutation : rétablir la ligne fait échouer les deux tests de course |

S'y ajoutait `API_BASE_URL=localhost:8000/api/v1` sans schéma dans `apps/fastfood/.env` (rattrapé à l'exécution, mais faux dans le fichier).

## Ce qui change

**Serveur**

| Fichier | Changement |
|---|---|
| `common/availability.py` | codes `no_kitchen_available`, `address_not_served`, `kitchen_suspended`, `invalid_customization` ; exception `AddressNotServed` (409 `address_not_served`, remplace un `business_rule_violation` anonyme) |
| `apps/restaurants/availability.py` | `KitchenState` : `is_active`, `is_open`, `is_accepting_orders`, `is_suspended` séparés, verdict dérivé ; `lock_kitchen_for_order` relit la cuisine sous `FOR SHARE` |
| `apps/availability/services.py` | **`can_accept_order`** / `assert_can_accept_order` : cuisine relue → panier cohérent → desserte → articles, matière, personnalisations → barème ; journal `order.acceptance` |
| `apps/orders/services.py` | la création appelle la règle centrale ; la desserte est jugée **avant** le décompte du stock ; écrit d'après la cuisine relue |
| `apps/restaurants/delivery.py` | choisit la plus proche cuisine **qui peut commander** (elle prenait la plus proche, même fermée) ; `unavailable_code` ; journaux `kitchen.resolution.*` sans coordonnées |
| `apps/catalog/availability.py`, `apps/carts/services.py` | `customization_unavailability` : les bornes d'options, relues à la commande |
| `apps/orders/serializers.py`, `apps/restaurants/states.py` | une cuisine suspendue répond 409 `kitchen_suspended`, plus 400 « objet introuvable » ; un brouillon reste introuvable |
| `apps/restaurants/serializers.py`, `backoffice.py` | la fiche d'exploitation porte `is_open`, `can_order_now`, `unavailable_code/reason` |
| `config/urls.py` | `/ready/` → 503 `migrations: en attente` |

**Aucune migration.** Aucune variable d'environnement, aucune dépendance.

**Flutter**

| Fichier | Changement |
|---|---|
| socle `network/api_client.dart`, `api_exception.dart` | une réponse reçue garde son statut (`ApiException.unreadable`) ; seul « aucune réponse » est `network_error` |
| socle `network/api_failure.dart` (nouveau) | `ApiFailure.of` : réseau, authentification, autorisation, 404, 429, refus, serveur, réponse invalide |
| socle `indisponibilite.dart` | nouveaux motifs ; **`cuisineSuspendue` vaut désormais `kitchen_suspended`**, la pause s'appelle `cuisineEnPause` |
| socle `delivery_check.dart`, `managed_restaurant.dart` | `unavailableCode` ; verdict sur la fiche d'exploitation |
| client `services/kitchen_context_service.dart` (remplace `restaurant_context_service.dart`) | vol unique ; `EtatDuContexte`, `SituationCuisine`, `DesserteAdresse` ; suit l'adresse de livraison ; `CuisineIndisponible` remplace `AucunEtablissement` |
| client `presentation/situation_cuisine.dart` (nouveau) | une phrase par situation, vocabulaire de cuisine de livraison |
| client `app_service.dart`, `menu_screen.dart`, `selecteur_etablissement_sheet.dart` | échec du catalogue typé ; cache hors ligne réservé aux pannes ; recharge au changement de cuisine |
| admin `presentation/disponibilite_cuisine.dart` (nouveau), `reseau_screen.dart` | « Invisible des clients », « Fermée (hors horaires) », « Commandes en pause » |
| `tools/verifier_connexion.py` | lit `/ready/` ; ne conclut plus « le cache » quand c'est le schéma |

## Validation

| Porte | Résultat |
|---|---|
| `ruff check`, `ruff format --check`, `mypy --strict` | verts — 432 fichiers, 291 sources |
| `makemigrations --check` | No changes detected |
| `pytest --cov` | **1 984 passed**, 92,88 % |
| `flutter analyze` ×4 | No issues found |
| `flutter test` | socle 498 · client 438 · admin 234 |
| `tools/contrat_routes.py` | toutes servies |
| `tools/code_mort.py` | rouge **antérieur** : `fastfood/presentation/commande.dart` |
| `tools/verifier_connexion.py` | vert après `migrate` + `bootstrap_roles` en base locale |
| Parcours HTTP réel (client d'audit, cuisine de Lomé) | 14/14 — pause pendant le paiement 409 `kitchen_paused`, fermeture horaire 409 `kitchen_closed`, hors zone 409 `address_not_served`, ouverte 201 puis annulée ; état de la cuisine restauré |

Tests de mutation : sans relecture sous verrou, sans choix de la cuisine ouverte, sans vol unique — les tests correspondants échouent.

## Ce qui n'est pas fait, et pourquoi

| Point | Décision |
|---|---|
| Renommer `Restaurant` en `Kitchen` dans le modèle, la table et `/restaurants/` | **non** : clé étrangère de tout le domaine, route lue par des applications installées, second dépôt `elcorazon-backend`. Le domaine parle « cuisine » à ses frontières (motifs, règle, contexte client, textes), la persistance garde son nom |
| Minimum de commande | reste `business_rule_violation` sans code dédié |
| Écran de paiement | n'utilise pas encore `SituationCuisine` : il affiche le motif du serveur, désormais distinct |
| `apps/dely`, `apps/admin` | classent leurs erreurs par `messageErreurApi`, pas encore par `ApiFailure` |

---

# Lot 2-bo — le back-office de la matière

## Pourquoi ce lot passait devant les postes

Recettes, stock, réservation et juge de disponibilité existaient, et **personne
ne pouvait saisir une recette ni recevoir une livraison** autrement que par un
`shell` : ni route, ni administration Django. Tout le mécanisme était en place et
dormant — un plat sans recette ne consomme rien, et aucun plat n'en avait.

## Un défaut de conception trouvé avant qu'il n'ait coûté

**Le coût unitaire était tenu au gramme**, en entiers d'unités mineures. Le franc
CFA n'a pas de décimales : un oignon à 500 F le kilo coûtait 0,5 F le gramme,
arrondi à **0 ou 1 F** — cent pour cent d'erreur, sur la donnée même qui devait
rendre la marge calculable. Le back-office allait exposer ce coût et le faire
saisir.

Il se tient désormais **au kilogramme, au litre ou à l'unité**
(`common.quantities.COST_UNIT`), et `value_minor()` valorise une quantité en
entiers jusqu'au bout, avec un seul arrondi sur le résultat. **Aucune migration** :
la colonne est la même, sa définition a changé avant qu'aucune donnée n'existe.

## Ce qui est en place

### Serveur

| Route | Permission | Ce qu'elle tient |
|---|---|---|
| `inventory/manage/ingredients/` | `inventory.read` / `.write` + **siège** | le référentiel d'enseigne ; pas de suppression, la dimension ne change plus |
| `inventory/manage/stock/` | `inventory.read` / `.write` | ouvrir une ligne (idempotent), seuil d'alerte, filtre `?low=true` — **aucun champ n'écrit le stock** |
| `…/stock/{id}/receive/` | `inventory.receive` | le **prix du lot** devient un coût au kilogramme ; `Idempotency-Key` exigé |
| `…/stock/{id}/waste/`, `…/adjust/` | `inventory.adjust` | `201` écrit, `202` en attente de validation ; comptage (`counted`) ou écart (`delta`) |
| `inventory/manage/movements/` | `inventory.read` | le journal, par **curseur** |
| `inventory/manage/adjustment-requests/` | `inventory.read`, décider : `inventory.approve` | la file de validation |
| `production/manage/recipes/` | `recipes.read` / `.write` | recettes de plats **et d'options**, lignes, **couverture** de la carte |

Tout est cloisonné par cuisine : hors périmètre, une ressource est introuvable,
une création refusée.

### Le plafond et le quatre-yeux

`Restaurant.stock_adjustment_ceiling`, dans la devise du pays, fixé par
`restaurants.write` — le siège, pas le gérant qu'il encadre. Une perte ou une
correction **passe seule** si sa valeur est connue et au plus égale au plafond.
Sinon elle devient une `AdjustmentRequest`, **qui ne touche à rien** jusqu'à ce
qu'une **autre personne** la valide.

| Cas | Issue |
|---|---|
| Valeur ≤ plafond | écrite |
| Valeur > plafond | en attente |
| **Plafond non fixé** | en attente — défaut sûr, qu'on desserre en le fixant |
| **Coût inconnu** | en attente — une valeur inconnue ne se prouve pas sous le plafond |
| Perte > stock détenu | refusée tout de suite |
| Le déclarant valide ou refuse | refusé par le service **et par la base** (`adjustment_request_four_eyes`) |

### Administration

Groupe **INVENTAIRE** : **Stock** (réception, perte, comptage, seuil, journal),
**Validations**, **Recettes** (couverture en tête, éditeur des plats et de leurs
options), **Ingrédients**. Chaque bouton suit la permission du compte ; la clé
d'idempotence vit aussi longtemps que le formulaire, donc « Réessayer » après une
coupure ne crédite pas deux fois. Le plafond se règle sur la fiche
d'établissement.

## Défauts trouvés en écrivant les tests

| Défaut | Correction |
|---|---|
| « 20 ml » d'un ingrédient pesé sortait en **500** : `DimensionMismatch` n'était pas une erreur métier | `400 dimension_mismatch`, par le gestionnaire commun |
| DRF ajoutait un validateur d'unicité et refusait en 400 la seconde ouverture d'une ligne, que le service rend exprès idempotente | validateur implicite retiré ; l'unicité reste en base |
| `get_value`, méthode d'un champ calculé nommé `value`, écrasait `Field.get_value` de DRF (relevé par mypy) | méthode renommée |
| Un plat pouvait recevoir une quantité **négative**, que le plancher aurait ramenée à zéro en silence | refusé ; le négatif est réservé aux options qui retirent |
| Un ingrédient retiré pouvait entrer en stock ou dans une recette | refusé |
| **Rattrapage du lot 1** : `indisponibilite.dart` ajouté au socle sans régénérer le fichier de couverture — la porte `couverture.py` du socle était rouge | fichiers régénérés |

## Tests

```
backend     1 950 passed, 0 failed     (1 856 après le lot 1, + 94)
            couverture 92,85 %         (plancher 92 %)
flutter     socle 483 (+20) · admin 228 (+18) · client 416 · livreur 164 — tous verts
```

| Porte | Résultat |
|---|---|
| `ruff check .` · `ruff format --check .` | verts — 431 fichiers |
| `mypy --strict common config apps` | no issues found in 291 source files |
| `makemigrations --check` | No changes detected |
| `pytest --cov` | 1 950 passed, 92,85 % |
| `flutter analyze` ×4 | No issues found, partout |
| `tools/couverture.py` | les quatre planchers tenus — socle 67,7 %, client 11,3 %, livreur 9,6 %, admin 3,05 % |
| `tools/contrat_routes.py` | toutes les adresses appelées sont servies |
| `tools/code_mort.py` | admin, livreur : aucun fichier injoignable. Client : l'échec **antérieur** décrit au lot 1 |
| `flutter build web` (admin) | construit — tout le Dart de l'administration compile |

**Ce qui n'a pas été vérifié : les écrans à l'œil, contre un serveur réel.** Ils
sont analysés, compilés, et leur logique est testée ; ils n'ont pas été ouverts
dans un navigateur connecté à l'API. La base locale de développement porte les
migrations initiales d'`inventory` et de `production`, mais **pas les trois de
ce lot** (`accounts/0005`, `inventory/0002`, `restaurants/0007`) — vérifié dans
`django_migrations` ; les tests tournent sur leur propre base. Avant d'annoncer l'écran prêt au personnel :
`migrate`, `bootstrap_roles`, puis une réception, une perte au-delà du plafond,
et sa validation par un second compte.

**Deux mesures faussées, et pourquoi elles ne comptent pas.** Un premier passage
lancé en parallèle sur le client et le livreur a fait expirer trois fichiers de
test **au chargement** (« loading … TimeoutException », douze minutes) : aucun
échec d'assertion, mais deux fichiers non exécutés ont fait passer le livreur
sous son plancher. Relancés **en série**, tous passent et le plancher est tenu.
Les suites Flutter avec couverture ne se lancent pas en parallèle sur ce poste.

### Ce que les 94 cas verrouillent

| Propriété | Pourquoi |
|---|---|
| Sous le plafond écrit, au-delà en attente, **sans plafond ou sans coût en attente** | la seule règle qui empêche une perte de sortir du bilan sans contrôle |
| La demande **ne touche à rien** avant validation | le journal ne contient que des faits |
| Le déclarant ne valide ni ne refuse — service, API **et contrainte en base** | le quatre-yeux n'est pas une permission |
| Valider deux fois n'écrit qu'une perte ; une demande tranchée ne se retranche pas | double clic, et décision contraire |
| Validation qui échoue si le stock a été consommé entre-temps, demande restée en attente | le système ne force pas |
| Réception et perte **rejouées** comptées une fois ; **deux réceptions simultanées** de la même livraison créditent une fois | le réseau coupe |
| Même clé pour une autre écriture : refusée | une erreur d'intégration ne s'ignore pas en silence |
| Chaque route : permission exigée, **hors périmètre introuvable ou refusé** | ADR-005 |
| Le référentiel s'écrit au siège seulement ; un ingrédient ne se supprime pas | écriture d'enseigne |
| Le stock ne s'écrit par aucun `PATCH` | la correction porte un motif |
| Le prix du lot donne le bon coût au kilogramme ; le journal rend la valeur signée | la marge |
| Le gérant ne fixe pas son propre plafond ; un plafond dans une autre devise est refusé | gouvernance |
| **Le back-office n'appelle jamais `waste`, `adjust`, `consume`, `reserve`, `release`** (analyse d'AST) | aucune route ne contourne le plafond |
| Recettes : cible unique et immuable, dimension, négatif réservé aux options, couverture, cloisonnement | la nomenclature |
| 20 g à 500 F/kg valent 10 F ; un seul arrondi | le coût au kilogramme |

## Déploiement

**Trois migrations, toutes additives** : `accounts/0005` (registre des
permissions), `inventory/0002` (demandes, clés d'idempotence), `restaurants/0007`
(plafond). Aucune donnée déplacée. **Chacune dans les deux dépôts.**

**Relancer `bootstrap_roles`** après déploiement : les rôles système sont des
lignes en base, et c'est lui qui les réaligne sur le registre. Sans lui,
**personne ne voit le groupe INVENTAIRE, Super Admin compris** — l'application
masque une entrée d'après les permissions des rôles, et aucun rôle ne porte
encore les sept nouvelles. Le serveur, lui, laisse passer un superutilisateur ;
le compte verrait donc ses écrans refusés côté application et acceptés côté API.

**Aucun plafond n'est fixé au déploiement** : toute perte attendra une
validation jusqu'à ce que le siège le règle. C'est voulu ; il faut le dire aux
cuisines.

## Risques ouverts

| # | Risque | Traitement |
|---|---|---|
| BO-R1 | Un comptage (`counted`) calcule l'écart d'après le stock lu **avant** le verrou de la déclaration : une commande consommée dans la même seconde décale l'écart d'une portion | assumé et écrit dans le code ; le comptage suivant le rattrape |
| BO-R2 | Le déclarant ne peut pas **retirer** sa propre demande — la contrainte de quatre-yeux interdit toute décision par lui | une autre personne la refuse ; un retrait propre demanderait un statut de plus |
| BO-R3 | Le bouton « Nouvel ingrédient » s'affiche à tout compte muni d'`inventory.write` ; un compte rattaché reçoit le refus du serveur, dont la phrase dit « relève du siège » | le compte ne dit pas côté application s'il est cloisonné ; l'écran l'annonce en tête |
| BO-R4 | Les allergènes des ingrédients ne sont pas encore hérités par les plats | la donnée est saisissable ; l'héritage viendra avec l'affichage client |
| BO-R5 | La concurrence de deux déclarations de perte simultanées n'a pas de test dédié | même verrou de ligne que la réception, qui en a un |

---

# Lot 1 — le juge de disponibilité

## Le défaut trouvé, et qui prime sur tout le reste

**Une cuisine fermée encaissait.** La création de commande ne vérifiait que la
publication de l'établissement. Les horaires d'ouverture et le drapeau « accepte
les commandes » n'étaient lus que par un champ d'**affichage**
(`RestaurantSerializer.get_can_order_now`). L'application disait « Fermé » ; le
serveur acceptait toute commande qu'on lui envoyait — par l'API, ou depuis un
panier resté ouvert pendant la fermeture ou pendant un coup de feu.

| | |
|---|---|
| Preuve, avant correction | `POST /orders/` sur un établissement sans aucune plage d'ouverture → **201**, une commande en base |
| Pourquoi la suite ne l'a pas vu | sa fixture d'établissement n'avait **aucun** horaire, donc était fermée — et des centaines de tests y commandaient avec succès |
| Ce que l'audit en disait | « règles dispersées » (I2, `INCONSISTENT`). Le statut réel était `BROKEN` — l'audit est corrigé en conséquence (documents 02, 03, README) |

## Ce qui est en place

Un juge, `apps/availability`, qui **compose** trois niveaux sans en réécrire
aucun. Chaque règle reste où vivent ses données :

```
la cuisine    restaurants/availability.py    publiée, marché ouvert, dans ses horaires, prenant les commandes
l'article     catalog/availability.py        au menu, actif, catégorie active, stock de plats finis, options
la matière    production/services.py         de quoi le préparer, réservations déduites, cumul du panier
```

Il rend partout **un verdict et un motif stable** (`unavailable_code`,
`unavailable_reason`), jamais une collection de booléens à recomposer.

| Où | Ce qui change |
|---|---|
| `POST /orders/` | la cuisine est **rejugée au moment d'écrire** → `409 kitchen_not_orderable` ; le refus d'articles porte `unavailable_codes` par ligne |
| `POST /orders/preview/` | premier motif bloquant |
| `GET /carts/<slug>/`, `/group-carts/<id>/` | motif de la cuisine sur le panier, motif de chaque ligne — rupture de matière comprise, avec le nombre de portions possibles |
| `GET /catalog/items/` et fiche | **`is_available` devient le verdict** : un plat dont un ingrédient suivi manque sort grisé |
| `GET /restaurants/` et fiche | `can_order_now` lu dans le juge, avec son motif |
| Ajout au panier | un article d'une **catégorie éteinte** est refusé (il ne l'était pas) |

### Trois décisions qui divergent du plan de l'audit

1. **Le juge n'est ni dans `restaurants` ni dans `catalog`.** Le plan a été écrit
   avant les recettes. Le juge doit maintenant voir la matière, et le graphe
   l'interdit à ces deux modules, dont `production` dépend. Il vit dans sa propre
   application, sans modèle, et la carte l'interroge **sans l'importer** : il
   s'inscrit auprès de `catalog` au démarrage, par le mécanisme de registre que le
   dépôt emploie déjà pour la complétude d'un établissement.

2. **Pas de route dédiée.** Le verdict est porté par les routes que les
   applications lisent déjà. Une route de plus aurait obligé l'application à
   fusionner deux réponses, donc à recomposer encore. Surtout, garder le nom
   `is_available` fait qu'**un plat en rupture disparaît des applications déjà
   installées sans attendre leur mise à jour**. L'interrupteur brut que manipule
   la cuisine reste intact sur la forme back-office (`ManagedMenuItemSerializer`).

3. **La capacité de production n'a pas de branchement vide.** Il n'existe ni
   poste ni file : aucune donnée ne permet de dire qu'une cuisine est saturée.
   Une question qui répondrait toujours « oui » ferait croire qu'elle est posée.

### La lecture informe, la réservation tranche

Le juge lit le stock **sans verrou** — une page de carte ne peut pas tenir des
verrous de stock. Entre sa lecture et la commande, une autre commande peut
emporter le dernier pain : c'est alors `MaterialService.reserve`, sous verrou, qui
refuse. Un test simule exactement cette course, pour que le seul refus qui tienne
face à deux commandes simultanées reste exercé au niveau de la commande.

## Modifications

### Backend — créés

| Fichier | Rôle |
|---|---|
| `common/availability.py` | le vocabulaire des motifs, `Unavailability`, `KitchenNotOrderable` |
| `apps/restaurants/availability.py` | le niveau cuisine |
| `apps/catalog/availability.py` | le niveau article, et le registre du juge |
| `apps/availability/{apps,services}.py` | le juge, et son inscription auprès de la carte |
| `tests/availability/test_juge.py` | 38 cas |

### Backend — modifiés

| Fichier | Modification |
|---|---|
| `apps/production/services.py` | `ProductionService.portions` extrait de `requirements` (même plancher par ligne, une requête) ; `MaterialService.shortages`, lecture sans verrou |
| `apps/carts/services.py` | le juge ligne à ligne `_unavailability` est **supprimé** ; le panier interroge le juge, en une fois |
| `apps/orders/services.py` | la cuisine jugée à l'écriture ; motifs dans le refus et le devis |
| `apps/{carts,groupcarts,orders,catalog,restaurants}/serializers.py`, `groupcarts/views.py` | motifs exposés ; `is_available` public = verdict |
| `apps/catalog/filters.py` | commentaire : le filtre `is_available` porte sur l'interrupteur, pas sur le verdict |
| `config/settings/base.py`, `tests/architecture/test_dependency_graph.py` | `apps.availability` déclarée, arêtes `availability → {catalog, production, restaurants}`, `carts → availability`, `orders → availability` |
| `tests/fixtures.py` | l'établissement de test est **ouvert** (deux plages par jour, sans trou) |
| 4 tests existants | voir « Tests modifiés » |

**Aucune migration.** Aucune variable d'environnement. Aucune dépendance.

### Flutter

| Fichier | Modification |
|---|---|
| socle — `menu_item`, `restaurant`, `cart`, `order_quote`, `group_cart` | `unavailableCode` / `unavailableReason`, facultatifs : un cache ou un serveur antérieurs se lisent sans erreur |
| socle — `catalog/indisponibilite.dart` | les motifs, en constantes à comparer |
| client — `checkout_screen.dart` | le refus du serveur s'affiche **avant** la saisie, et le bouton est neutralisé — le client l'apprenait en appuyant sur « Commander » |
| client — `selecteur_etablissement_sheet.dart` | lit le motif au lieu de recomposer `isOpen` / `acceptsOrders` |
| client — fiche article | la phrase du serveur (« en rupture », « plus au menu ») à la place d'un texte unique |
| client, admin — deux fichiers de test | **correction d'une CI déjà rouge**, voir plus bas |

## Tests

```
backend     1 856 passed, 0 failed     (1 817 avant le lot, + 39)
            couverture 92,68 %         (plancher 92 %)
            les 5 modules du juge à 100 %
flutter     socle 463 · client 416 · admin 210 · livreur 164 — tous verts
```

| Porte | Résultat |
|---|---|
| `ruff check .` | All checks passed |
| `ruff format --check .` | 422 files already formatted |
| `mypy --strict common config apps` | no issues found in 285 source files |
| `pytest --cov` | 1 856 passed, 92,68 % |
| `flutter analyze` ×4 | No issues found, partout |
| `flutter build apk --debug` (client) | construit — tout le Dart de l'application compile, y compris ce que l'analyseur ne voit pas |
| `tools/contrat_routes.py` | 161 adresses appelées, toutes servies |
| `tools/code_mort.py` | **rouge, et antérieur** — voir ci-dessous |

### Tests modifiés, et pourquoi leur propriété est intacte

| Test | Changement |
|---|---|
| `test_un_ingredient_manquant_refuse_la_commande` (lot 2b) | le refus arrive plus tôt, par le juge, et nomme le plat au lieu de l'ingrédient. **Complété** par `test_la_lecture_informe_la_reservation_tranche`, qui garde exercé le refus sous verrou |
| `test_les_horaires_d_un_autre_etablissement_sont_invisibles` | `count == 0` ne tenait qu'à l'absence d'horaires propres ; il compare maintenant à l'ensemble exact attendu — plus fort qu'avant |
| deux décors d'horaires (`ouvert_le_mardi`, `source_garnie`) | repartent d'un horaire vide avant de poser le leur |
| `test_le_devis_donne_le_detail…` | la liste des champs du devis gagne les deux motifs |

### Ce que les 38 cas verrouillent

| Propriété | Pourquoi |
|---|---|
| Cuisine fermée, suspendue, marché fermé → **aucune commande créée** | le défaut de fond |
| Le panier n'est pas vidé par un refus | le client revient à l'ouverture |
| Le panier collaboratif passe par le même juge | la cuisine a pu fermer pendant l'heure où le groupe composait |
| Fermée **et** suspendue se dit « fermée » | « réessayez dans quelques minutes » serait faux jusqu'à l'ouverture |
| Horaires lus dans le fuseau du pays | un instant UTC ouvre ou ferme selon le marché |
| La fiche d'établissement et la commande disent la même chose | l'ancienne composition vivait dans le seul sérialiseur |
| Catégorie éteinte → ligne incommandable, ajout refusé | défaut voisin, fermé |
| La carte voit la matière, **réservations déduites** | juger sur `on_hand` annoncerait un plat que la réservation refuserait |
| Ingrédient non suivi, plat sans recette → rien ne bloque | la lecture n'est jamais plus stricte que l'écriture |
| La carte juge chaque plat seul ; le panier cumule | deux plats qui se disputent le même pain ne se voient qu'au cumul |
| « Sans pain » rend la ligne commandable | même nomenclature que la réservation |
| La carte publique ne dit pas combien il reste | l'état d'un stock n'a pas à se lire en public |
| **Page de 2 ou 8 plats : 2 requêtes** | posée par article, la question coûterait deux requêtes par plat |
| Lecture sans `FOR UPDATE` | une carte ne tient pas de verrous de stock |
| **Seul le juge lit `accepts_orders`** (analyse d'AST) | la forme exécutable du critère de fin d'I2 : un second lecteur rouvrirait le défaut |
| Sans juge inscrit, la carte répond avec ce qu'elle sait | moins précise, jamais permissive sur ce qui compte |

## Les portes de CI Flutter : une corrigée, une encore rouge

### Corrigée — l'analyse du client et de l'administration

`flutter-ci.yml` lance `flutter analyze` **sans** `--no-fatal-infos` dans la
matrice des applications. Huit diagnostics `info` antérieurs à ce lot — un dans
le client (`d8fee1a`), sept dans l'administration (`42f24b0`) — faisaient donc
échouer ces deux portes, localement avec le Flutter de ce poste et, à version
égale, en CI. Tous signalaient un argument égal à sa valeur par défaut dans un
test, là où le test nomme délibérément le statut qu'il vérifie : la valeur est
gardée, et la règle levée avec son motif, pas effacée en silence.

### Encore rouge — `code_mort.py`, et c'est une décision à prendre

`fastfood/lib/presentation/commande.dart` (200 lignes) n'est atteint par aucun
écran : seul le test de couverture l'importe. **Ce n'est pas ce lot** — les
rapports de la refonte UI le signalaient déjà, et vérifié sur `15ebe32`.

Le fichier porte le **bon** vocabulaire — les huit statuts que le serveur émet —,
pendant que les écrans lisent `models/order.dart`, qui en déclare dix, dont
`refunded` et `failed` que le serveur n'émet pas. Le supprimer ferait perdre le
vocabulaire juste ; le brancher demande de consolider les deux.

**Pourquoi cela devient pressant** : le lot 2c ajoutera l'état `queued` à la
machine de commande. Le client devra alors l'afficher, et il ne pourra le faire
proprement qu'avec un seul vocabulaire de statuts. La consolidation est donc un
**préalable du lot 2c côté client**, et non plus un chantier d'agrément.

## Déploiement

### À vérifier **avant** de déployer

La reprise de données `0005_restaurant_lifecycle` a passé « en service » les
établissements déjà actifs **sans contrôler leurs horaires**. Un établissement de
production sans aucune plage d'ouverture **cesserait de prendre des commandes**
au déploiement — ce qui est désormais la règle, et ce que son écran affiche déjà.

```sql
SELECT r.slug, r.name
FROM restaurants_restaurant r
WHERE r.is_active
  AND NOT EXISTS (
    SELECT 1 FROM restaurants_openinghours h WHERE h.restaurant_id = r.id
  );
```

Attendu : **aucune ligne**. Vérifié en local (sept établissements, tous à sept
plages). Les deux commandes de peuplement posent des horaires, donc la production
en a très probablement ; la requête le dit en une seconde. **Chaque dépôt** :
tant que `elcorazon` et `elcorazon-backend` ne sont pas fusionnés, c'est la base
servie par le second qu'il faut interroger.

### Ce qui change pour qui

| Qui | Ce qu'il voit |
|---|---|
| Client, application **installée** | un plat en rupture de matière sort grisé ; une commande sur cuisine fermée est refusée avec « … est fermé pour le moment » dans le bandeau d'erreur existant |
| Client, application **mise à jour** | en plus : le motif en tête de l'écran de paiement, bouton neutralisé ; le motif sur la fiche article |
| Cuisine | rien à faire. Le drapeau « accepte les commandes » **fait désormais ce qu'il annonce** |
| Essai manuel en local, **la nuit** | la commande est refusée : les établissements de démonstration ouvrent de 11 h à 23 h, heure de leur pays |

## Risques ouverts

| # | Risque | Traitement |
|---|---|---|
| L1-R1 | Un établissement de production sans horaires se fermerait au déploiement | la requête ci-dessus, avant |
| L1-R2 | Une lecture de panier coûte deux requêtes de plus (recettes, stock) | bornées, indépendantes du nombre de lignes, et testées comme telles |
| L1-R3 | Le filtre `?is_available=true` porte sur l'interrupteur : un plat en rupture passe le filtre et sort grisé | écrit dans le code ; même arbitrage que l'absence de filtre `open_now` — le verdict ne se filtre pas en base sans rendre des pages de taille arbitraire |
| L1-R4 | Les options ne sont pas jugées sur leur matière **à la carte** (un « supplément fromage » en rupture reste proposé) | le panier les juge, avec le cumul ; les griser à la carte demanderait de juger chaque option de chaque plat de la page |

---

# Lot 2 — la production (2a et 2b)

## Ce que cette phase a établi avant d'écrire

La phase 0 du brief — l'audit — **était déjà faite** : dix documents sourcés dans
[`docs/audit/`](docs/audit/). Elle a été *vérifiée*, pas refaite. Ses affirmations
centrales tiennent au contrôle (zéro `TODO` dans le backend, entités de
production absentes, quatre portes de qualité vertes), et sa conclusion gouverne
l'ordre des travaux :

> Le brief annonce une refonte. La mesure indique une extension. Le cœur
> transactionnel — commander, payer, livrer, suivre — est en état de production
> et ne doit pas être rouvert. Ce qui manque est un étage de domaine : la
> fabrication.

---

## Modifications

### Fichiers créés

| Fichier | Rôle |
|---|---|
| `backend/apps/production/models.py` | `Recipe`, `RecipeIngredient` |
| `backend/apps/production/services.py` | `ProductionService`, `MaterialService`, `ProducedLine` |
| `backend/apps/production/apps.py` | déclaration de l'application |
| `backend/apps/production/migrations/0001_initial.py` | deux tables, quatre contraintes |
| `backend/tests/production/test_recettes.py` | 24 cas — la nomenclature |
| `backend/tests/production/test_matiere_des_commandes.py` | 15 cas — l'engagement |

### Fichiers modifiés

| Fichier | Modification |
|---|---|
| `backend/config/settings/base.py` | `apps.production` déclarée après ses deux rives |
| `backend/apps/orders/services.py` | **2b** — réservation, consommation, libération ; `option_id` à l'instantané |
| `backend/tests/architecture/test_dependency_graph.py` | arêtes `production → {accounts, catalog, inventory, restaurants}` et `orders → production` |
| `backend/tests/delivery/test_gains_livreur.py` | correction d'un test instable — voir « Bugs » |

**Un seul fichier du domaine existant a été rouvert**, `orders/services.py`, et
uniquement par **ajout** : le décompte des plats finis (`StockService`) est
inchangé, la machine à états inchangée, le calcul des prix inchangé. Sa
substitution par la matière viendra quand les recettes de la carte seront
saisies — mêler une addition à une substitution aurait rendu les deux
irrelisibles.

---

## Fonctionnalités

### La nomenclature — le pont qui manquait

L'inventaire savait ce que la cuisine détient, le catalogue ce qu'elle vend, et
**rien ne reliait les deux**. `Recipe` est ce pont, et c'est la seule raison
d'être du module.

```
Ingredient (inventory)  ──┐
                          ├── RecipeIngredient ── Recipe ── MenuItem  (catalog)
                          │                              └─ Option    (catalog)
```

`ProductionService.requirements()` répond à la question que personne ne pouvait
poser : « trois burgers dont un sans oignon et un à double fromage, que sort-on
de la chambre froide ? » — en **une seule requête**, quel que soit le nombre de
lignes.

### Une recette vise un plat **ou** une option

Le supplément fromage consomme du fromage ; « sans oignon » n'en consomme pas.
La personnalisation n'est donc pas un décor de prix : elle déplace la matière, et
le brief le demande explicitement (§ « Groupe : Retirer »).

La cible exclusive reprend le motif d'`AreaMembership` — contrainte `CHECK`,
même raison : un état impossible doit être **irreprésentable**, pas seulement
évité.

### Le plancher à zéro, par ligne

Une option de retrait porte une quantité négative, à l'image de
`Option.price_delta` qui vaut déjà « −200 F » pour « sans fromage ». Mais retirer
l'oignon ne le **remet pas** en chambre froide : cela évite de l'en sortir.

Le plancher est donc posé **par ligne de commande**, jamais sur le total. C'est
le point de conception le plus important du lot, et celui qu'un test verrouille
nommément : posé sur le total, un « sans oignon » effacerait l'oignon d'un
*autre* plat du même panier — deux clients, une seule matière, et un stock qui
dérive **sans qu'aucune ligne ne soit fausse**.

### Les plats sans recette ne consomment rien

Délibéré : la carte existe, ses recettes non. Exiger qu'elles soient toutes
saisies le jour du déploiement fermerait la boutique. La bascule se fait plat par
plat.

La contrepartie est le silence — « rien à sortir » et « je ne sais pas quoi
sortir » se ressemblent. `missing_recipes()` rend l'écart mesurable, pour qu'il
se lise sur un tableau de bord plutôt que sur un inventaire qui ne tombe pas
juste.

---

## Lot 2b — « préparer » cesse d'être une écriture de colonne

C'est l'incohérence **I5** de l'audit, la plus structurelle : `CONFIRMED →
PREPARING → READY` validait l'enchaînement et jamais le contenu. Une cuisine
pouvait déclarer prêtes quarante commandes en quarante clics sans qu'un gramme
ne bouge.

### Les trois moments

```
création de commande    reserve    la matière est promise, sans être sortie
passage en préparation  consume    elle sort, et l'engagement est levé
annulation              release    elle redevient disponible — avant le feu
```

**Réserver plutôt que consommer d'emblée** n'est pas une subtilité : entre la
commande et le feu, la matière est due sans être partie. Un stock qui l'ignore
annonce « il reste 3 kg » quand 2,8 sont déjà promis, et c'est la commande
suivante qui découvre le mensonge.

### L'asymétrie de l'annulation

Avant le feu, la matière est rendue. Après, elle ne l'est plus : **on ne
décuisine pas un oignon**. La recréditer inventerait de la matière que
l'inventaire physique démentirait — la même asymétrie que le remboursement
connaît déjà, où l'on rend l'argent mais jamais le travail.

### Une arête, pas deux

`MaterialService` vit dans `production` et non dans `orders`. Le graphe y gagne
une seule arête (`orders → production`) au lieu de deux, et `orders` ignore
jusqu'au nom de `StockItem`. Le jour où la matière se réservera autrement, un
seul module changera.

### Ce que la garantie existante a offert gratuitement

`transition_to` est **le seul** chemin d'écriture du statut — vérifié : aucune
écriture directe n'existe dans le dépôt. Brancher la consommation à cet endroit
la rend donc active pour l'API, le back-office, l'admin Django **et le poste de
cuisine**, sans en énumérer aucun. C'est le rendement d'un invariant tenu.

### Le défaut trouvé en relisant, et corrigé

La première version libérait aveuglément la quantité consommée. Or trois chemins
mènent à une commande **sans engagement préalable**, dont deux sont certains le
jour du déploiement :

* une commande créée avant ce lot, préparée après ;
* une recette saisie entre la commande et le feu ;
* une ligne de stock ouverte entre les deux.

La libération aurait alors échoué sans contrepartie, et **la cuisine n'aurait
plus pu avancer une commande déjà payée** — pour une écriture comptable qui la
regarde à peine. La libération porte désormais sur ce qui est **promis**, jamais
sur ce qui sort. Le refus appartient à la commande ; jamais au feu.

---

## Bugs

### Un test instable une heure par jour, une moitié d'année

`test_les_bornes_suivent_le_fuseau_de_l_etablissement` échouait au premier
passage de la suite. Diagnostic : **ce n'était pas une régression du travail en
cours**, mais une hypothèse fausse sur le monde réel.

| | |
|---|---|
| Ce que le test affirmait | « `Africa/Cairo`, UTC+2, sans heure d'été depuis 2015 » |
| Ce qui est vrai | **L'Égypte a rétabli l'heure d'été en 2023** — Le Caire est à UTC+3 de fin avril à fin octobre |
| L'effet | Le test posait sa course avec un décalage écrit en dur (`+2`) ; la vue lisait le vrai fuseau (`+3`). « Aujourd'hui » cessait de désigner la même journée pour les deux |
| La fenêtre | 21 h–22 h UTC, une heure par jour, pendant l'heure d'été égyptienne |

Corrigé sur deux plans, et le second est le vrai :

* `Africa/Nairobi` est à `+3` **toute l'année** — ce que le commentaire précédent
  croyait de son propre fuseau ;
* l'heure locale est désormais **dérivée du fuseau du pays** au lieu d'être
  recopiée. Un test qui réécrit la règle qu'il vérifie ne la vérifie plus, et la
  prochaine réforme horaire le ferait mentir de nouveau.

**L'assertion n'a pas été touchée** : le test verrouille exactement la même
propriété qu'avant. Seule son hypothèse de départ était fausse.

La correction a été validée à 22 h 00 UTC, **dans la fenêtre d'échec**.

---

## Tests

```
1 817 passed          (1 778 avant ce lot, + 39)
    0 failed
    0 skipped
couverture      92,50 %   (plancher 92 %)
apps/production    100 %   (models et services)
```

Les quatre portes de la CI, lancées localement :

| Porte | Résultat |
|---|---|
| `ruff check .` | All checks passed |
| `ruff format --check .` | 414 files already formatted |
| `mypy --strict common config apps` | no issues found in 279 source files |
| `pytest --cov` | 1 817 passed, 92,50 % |

### Ce que les 24 cas du lot 2a verrouillent

| Propriété | Pourquoi elle compte |
|---|---|
| Le plancher est **par ligne**, pas sur le total | Le seul défaut du module qui fausserait un stock sans qu'aucune ligne ne soit fausse |
| Un retrait supérieur à la recette ne crée pas de matière | Une commande ne peut pas alimenter la chambre froide |
| Le retrait s'applique à **chaque** portion | Trois burgers sans oignon, c'est trois fois rien |
| Cible exclusive, refusée **par la base** | Une recette orpheline serait de la matière que personne ne consomme |
| Un ingrédient ne figure qu'une fois | Deux lignes se lisent comme un remplacement alors qu'elles s'ajoutent |
| Quantité nulle refusée par la base | Une ligne à zéro fait hériter un allergène d'un plat qui ne le contient pas |
| Dimension = celle de l'ingrédient | « 200 g » d'une matière tenue en volume : la faute qu'aucun `CHECK` ne peut voir |
| Une seule requête | Le calcul arrive dans une transaction qui tient déjà des verrous |

### Ce que les 15 cas du lot 2b verrouillent

| Propriété | Pourquoi elle compte |
|---|---|
| La création **réserve** sans sortir | Entre la commande et le feu, la matière est due, pas partie |
| Le mouvement porte la référence de commande | « Pourquoi 20 g sont-ils immobilisés ? » doit avoir une réponse |
| Une rupture refuse la commande, **et n'en laisse rien** | La rupture doit se voir ; l'atomicité fait le reste |
| Un ingrédient non suivi ne bloque rien | La bascule se fait par étapes, aucune ne ferme la boutique |
| La préparation sort la matière **et** libère l'engagement | Sans quoi elle serait comptée deux fois, due et partie |
| Le journal garde les quatre écritures | Réception, réservation, libération, consommation — en ajout seul |
| Annuler avant le feu rend la matière | |
| Annuler après le feu **ne rend rien** | On ne décuisine pas un oignon |
| Un rejeu d'annulation ne rend pas deux fois | `is_noop`, attesté ici sur la matière |
| L'instantané retient `option_id` | Sans lui, l'annulation ignore quelle recette d'option rendre |
| Une commande **antérieure** s'annule sans ses options | Les commandes ouvertes le jour du déploiement n'ont pas d'identifiant |
| Préparer **sans réservation préalable** sort quand même la matière | Le défaut trouvé en relecture — la cuisine ne doit pas être bloquée |
| Une réservation partielle se libère à hauteur du promis | L'engagement ne passe pas sous zéro |

---

## Migration

```
apps/production/migrations/0001_initial.py
  + Recipe, RecipeIngredient
  + recipe_targets_exactly_one          CHECK
  + one_recipe_line_per_ingredient      UNIQUE
  + recipe_line_quantity_not_zero       CHECK
  + index sur RecipeIngredient.ingredient
```

Additive : aucune table existante n'est touchée, aucune donnée déplacée. Elle
peut être appliquée avant le déploiement du code sans rien casser.

**Rappel de la discipline du dépôt** : tant que `elcorazon` et
`elcorazon-backend` ne sont pas fusionnés, **chaque migration doit arriver dans
les deux**. Un tableau de bord vert dans l'un ne dit rien de l'autre, et ce
mécanisme a déjà produit un incident réel.

---

## Déploiement

**Aucune variable d'environnement nouvelle.** Aucun service nouveau. Aucune
dépendance ajoutée.

---

## Risques

### Ce qui reste ouvert dans ce lot

| # | Risque | Traitement |
|---|---|---|
| R1 | Une recette n'est pas versionnée : la modifier change les besoins futurs | Sans effet sur l'histoire — le coût passé vit dans `StockMovement`, journal en ajout seul. Le versionnement serait du confort d'édition, pas une garantie |
| R2 | Aucune API n'expose encore les recettes | Volontaire : le back-office viendra avec le lot 2c, quand le domaine sera complet. Chaque entité arrivera **avec sa permission et ses tests de refus** |
| R3 | Aucune recette n'est saisie dans les données existantes | Sans effet immédiat : un plat sans recette se comporte exactement comme avant. Mais **tant que la carte n'est pas renseignée, le coût matière reste inconnu** — le mécanisme existe, la donnée manque. `missing_recipes()` mesure ce qui reste à saisir |
| R4 | Une consommation dont `on_hand` ne suffit pas fait échouer le passage en préparation | Ne peut survenir qu'après un ajustement manuel à la baisse, la réservation ayant garanti le stock. Laissé remontant **à dessein** : le forcer en silence rendrait le stock définitivement faux. Le modèle prévoit la sortie de secours — un type de mouvement autorisant la consommation saisie après coup, jamais la contrainte `on_hand >= 0` retirée |
| R5 | Les commandes ouvertes le jour du déploiement rendront leur recette de base, pas leurs suppléments | Leur instantané n'a pas d'`option_id`. L'écart s'éteint de lui-même en quelques heures. Les deux alternatives étaient pires : bloquer l'annulation, ou deviner l'option par un libellé que le catalogue peut renommer |

### Les deux mécanismes de stock coexistent

`MenuItem.tracks_stock` / `stock_quantity` (plats finis) **n'a pas été retiré**,
et tourne à côté de la matière première. Ce n'est pas un oubli :

* les deux cas sont réels — une bouteille importée se compte en unités, un
  burger se fabrique ;
* retirer le premier avant que les recettes ne soient saisies laisserait la
  carte sans aucun contrôle de stock ;
* sa **technique** est juste (décrément conditionnel évalué par la base) ; c'est
  sa granularité qui est fausse.

Sa substitution est un geste à part, qui se fera carte saisie — et il ne doit pas
être mêlé à l'addition que décrit ce rapport.

### Les blocages qui ne dépendent pas du code

Inchangés depuis l'audit, et ils priment sur tout ce qui précède :

| # | Blocage |
|---|---|
| **B1** | PostgreSQL de production sur `plan: free` — les commandes, les paiements, l'historique comptable |
| **B3** | `backup.sh` et `restore.sh` existent, **rien ne les déclenche** — il n'y a aujourd'hui aucune sauvegarde automatique |
| B2 | Service web sur `plan: free` — démarrage à froid pour le premier client de chaque creux |

---

## Validation

| Scénario | Résultat |
|---|---|
| Une portion sort la quantité de sa recette | ✅ |
| Trois portions multiplient | ✅ |
| Un supplément ajoute sa matière | ✅ |
| « Sans oignon » retranche exactement | ✅ |
| Un retrait supérieur à la recette ne crédite rien | ✅ |
| Deux plats, l'un sans oignon, l'autre avec → un seul est retranché | ✅ |
| Un plat sans recette traverse sans rien décompter | ✅ |
| Une recette sans cible / à deux cibles est refusée par PostgreSQL | ✅ |
| Une dimension incohérente est refusée par le service | ✅ |
| Un panier de trois lignes composées : une requête | ✅ |
| **Commander réserve la matière sans la sortir** | ✅ |
| **Un ingrédient en rupture refuse la commande, sans laisser de trace** | ✅ |
| **Préparer sort la matière et lève l'engagement** | ✅ |
| **Annuler avant le feu rend ; après le feu, non** | ✅ |
| **Préparer sans réservation préalable n'échoue pas** | ✅ |
| Un rejeu d'annulation ne rend pas deux fois | ✅ |

---

## Ce que ce lot débloque

| Devient possible | Pourquoi ce ne l'était pas |
|---|---|
| **La marge réelle** dans `analytics` | Le coût matière n'existait pas ; `StockItem.unit_cost` le porte désormais, en coût moyen pondéré |
| **La rupture d'ingrédient** | Une seule matière manquante refuse les plats concernés, au lieu d'une bascule manuelle plat par plat |
| Le retrait automatique de la carte | Prochaine étape : c'est `AvailabilityService` qui posera la question |
| La capacité de production | Huitième question de la disponibilité, quand les postes existeront |

---

## Suite proposée

*Mise à jour après le lot 1.*

| Lot | Contenu |
|---|---|
| **1** ✅ | `AvailabilityService` — fait, voir en tête de ce rapport |
| **2-bo** ✅ | Back-office de la matière — fait, voir en tête de ce rapport |
| **2c** | `Station`, `ProductionTask`, état `queued` — et le temps promis calculé depuis la charge des postes (I1). Préalable côté client : un seul vocabulaire de statuts |
| **2d** | Le KDS branché sur les tâches, canal `ws/kitchens/<id>/production/` |

**Le back-office passe devant les postes**, et c'est un changement d'ordre par
rapport à la version précédente de ce tableau. Recettes, stock, réservation et
juge existent désormais — mais aucune application n'est inscrite dans
l'administration Django pour `inventory` ni `production`, et aucune route ne les
expose. **Personne ne peut aujourd'hui saisir une recette ni recevoir une
livraison** autrement que par un `shell`. Tout le mécanisme de matière est donc
en place et dormant : un plat sans recette ne consomme rien, et aucun plat n'en
a. Construire les postes par-dessus une matière que personne ne peut renseigner
ajouterait un étage à un bâtiment sans porte.
