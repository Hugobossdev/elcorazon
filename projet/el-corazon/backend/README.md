# Backend El Corazón v2

API et logique métier de la plateforme. **Le backend est la seule autorité
métier** — les applications Flutter sont des clients, sans accès direct à la
base.

Conception : [`docs/architecture/`](../docs/architecture/README.md).

## Démarrage

### Avec Docker (recommandé)

```bash
cp .env.example .env
# renseigner DJANGO_SECRET_KEY, POSTGRES_PASSWORD, JWT_SIGNING_KEY, JWT_VERIFYING_KEY
docker compose up
```

- API : <http://localhost:8000>
- Documentation OpenAPI : <http://localhost:8000/api/v1/docs/>
- Console MinIO : <http://localhost:9001>

PostgreSQL est exposé sur **5433** et non 5432, pour ne pas entrer en conflit
avec une instance déjà installée sur le poste.

### Tests

La suite s'exécute **dans l'image**, parce que GeoDjango s'appuie sur GDAL et
GEOS — des bibliothèques système, pas des paquets Python, absentes d'un poste
Windows nu :

```bash
docker compose up -d db redis
docker compose run --rm api pytest
```

La création de la base de test rejoue toutes les migrations, ce qui domine la
durée d'une exécution. En boucle de développement :

```bash
docker compose run --rm api pytest --reuse-db     # réutilise la base existante
docker compose run --rm api pytest --create-db    # après une nouvelle migration
```

Les tests purement algorithmiques (montants, machine à états, identifiants) ne
touchent ni la base ni le réseau et tournent aussi dans un simple virtualenv :

```bash
python -m venv .venv
.venv/Scripts/python -m pip install -e ".[dev]"     # Linux/macOS : .venv/bin/python
.venv/Scripts/python -m pytest tests/common
```

> Il n'existe **pas** de repli SQLite. Le schéma emploie des types propres à
> PostgreSQL — `ArrayField`, `geography`, index GiST — qu'un autre moteur ne
> peut pas porter. Un vert obtenu sur un schéma dégradé ne prouverait rien.

## Structure

```
config/       réglages (base/dev/prod/test), routage, ASGI, Celery
common/       socle transverse, sans dépendance aux apps métier
  money.py            montants : entier mineur + devise (ADR-007)
  identifiers.py      UUIDv7 (ADR-007)
  state_machine.py    transitions déclaratives (ADR-010)
  exceptions.py       erreurs métier → RFC 9457 (ADR-009)
  pagination.py       page / curseur (ADR-009)
apps/         18 applications par domaine métier (ADR-002)
tests/        suite de tests
deploy/       Nginx
```

## Points d'entrée ouverts

Le refus étant le défaut (`IsAuthenticated`), voici la liste — auditable — de ce
qui se lit **sans compte** : un visiteur doit pouvoir savoir si on le livre et
voir un prix avant de s'inscrire.

| Route | Verbe | Accès |
|---|---|---|
| `/api/v1/auth/register\|login\|token/refresh` | POST | public, limité en débit |
| `/api/v1/geography/countries\|cities` | GET | public |
| `/api/v1/geography/zones/resolve/?lat=&lon=` | GET | public |
| `/api/v1/restaurants/` (`?lat=&lon=` trie par proximité) | GET | public |
| `/api/v1/catalog/categories\|items` | GET | public |
| `/api/v1/catalog/reviews/` | GET | public |
| `/api/v1/catalog/reviews/` | POST | client authentifié |
| `/api/v1/payments/webhook/{provider}/` | POST | **signature HMAC**, pas de jeton |

Le webhook est la seule route ouverte en écriture sans compte : un prestataire
n'en a pas. Son justificatif est la signature HMAC-SHA256 du corps brut,
vérifiée avant toute écriture — plus fort qu'un jeton porteur, qu'il suffirait
d'intercepter pour rejouer sur un autre corps.

Tout le reste exige un jeton.

**Le personnel a deux clés, pas une.** La permission nommée dit *ce qu'on a le
droit de faire* (`orders.refund`), le rattachement à un établissement
(`restaurants.StaffMembership`) dit **sur quoi**. Un membre du personnel sans
rattachement ne voit rien : un oubli de configuration produit une panne
visible, jamais un accès trop large et silencieux.

## Back-office

`/admin/` — outil d'**exploitation**, pas seconde API. Il sert à valider un
dossier livreur, retrouver une transaction, corriger un repère d'adresse.

Trois règles y sont tenues par le code, parce qu'un back-office est le chemin
le plus court pour contourner ses propres garde-fous :

- **les statuts ne sont pas des champs.** Une liste déroulante sur `status`
  suffirait à écrire « livrée » sur une commande jamais partie — sans machine à
  états, sans journal, sans créditer le livreur. Ils se changent par des
  actions, qui appellent les mêmes services que l'API et sont refusées de la
  même façon ;
- **les montants ne s'éditent pas.** Ils sont recomposés serveur (C2) : un
  total saisi à la main serait un total faux qui a l'air juste ;
- **les écritures comptables ne se suppriment pas.** Commandes, lignes,
  transactions, remboursements et journaux d'événements sont conservés.

Les paiements sont intégralement en lecture seule : le webhook signé est la
seule source de vérité de l'encaissement, et un formulaire qui écrirait
`completed` rouvrirait ici la faille que P2 ferme partout ailleurs.

```bash
docker compose run --rm api python -m django createsuperuser
```

## WebSocket

| Route | Qui |
|---|---|
| `ws/orders/{id}/tracking/` | le client de la commande, son livreur assigné, le personnel de l'établissement |
| `ws/couriers/me/` | le livreur, sur sa propre file — aucun identifiant dans l'URL |

Le jeton se présente en en-tête `Authorization: Bearer …`, ou à défaut en
`?token=` pour les navigateurs, qui ne savent pas poser d'en-tête sur un
WebSocket. **L'autorisation est vérifiée avant l'acceptation** : un socket
refusé est fermé avec un code de la plage 4000 (`4401` jeton, `4403` droit,
`4409` geste interdit sur un socket pourtant ouvert), jamais laissé ouvert en
lecture seule.

Chaque message porte un `seq` croissant par groupe. À la reconnexion, le client
redemande la suite avec `?since=<seq>` ; s'il a été absent plus longtemps que
le journal, il reçoit un `realtime.gap` qui lui dit de recharger par HTTP
plutôt que de croire qu'il n'a rien manqué.

Le contrat complet est dans le schéma OpenAPI, généré depuis les
sérialiseurs :

```bash
docker compose run --rm api python -m django spectacular --fail-on-warn
```

## Qualité

```bash
ruff check .          # style et bogues probables
ruff format .         # format
mypy common config apps
pytest --cov
```

Deux familles de tests ne vérifient pas du métier mais des **règles** :

```bash
pytest -m architecture   # graphe de dépendances, couches, surface publique
pytest -m contract       # forme des réponses face au schéma OpenAPI
```

La première rend exécutable ce que l'ADR-002 annonçait comme « vérifié en CI » :
une dépendance hors du graphe, un cycle entre apps ou une route ouverte sans
figurer dans la liste déclarée font échouer la construction. La seconde ferme
le piège nº 3 de la Phase 1 — un champ déclaré non nul qui sort absent fait
planter les clients Dart, qui appellent `DateTime.parse` sans garde.

Ces quatre commandes sont celles qu'exécute la CI
([`.github/workflows/backend-ci.yml`](../../.github/workflows/backend-ci.yml)).

## Points d'attention

**Les montants ne sont jamais des flottants.** `Money` refuse un `float` à la
construction. Sur un total de commande l'écart est invisible ; sur un cumul de
commissions livreur en fin de mois, il devient un litige.

**Les statuts ne s'écrivent pas directement.** Toute transition passe par la
machine à états, qui vérifie, journalise et émet l'événement dans une seule
transaction. C'est ce qui ferme quatre des douze failles relevées sur
l'implémentation précédente.

**Le refus est le défaut.** La permission globale est `IsAuthenticated` ; toute
route publique se déclare explicitement, ce qui rend la liste des points
d'entrée ouverts auditable en une recherche.

**Aucun secret dans le dépôt.** `.env` et les `*.pem` sont ignorés par git — ce
qui a été vérifié. `.env.example` documente chaque variable sans valeur.
