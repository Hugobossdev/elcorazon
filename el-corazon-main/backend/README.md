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

### Sans Docker (poste de développement dégradé)

Le poste du projet n'a ni Docker, ni PostGIS, ni Redis. Le sous-ensemble de la
suite qui n'en dépend pas reste exécutable :

```bash
python -m venv .venv
.venv/Scripts/python -m pip install -e ".[dev]"     # Linux/macOS : .venv/bin/python
.venv/Scripts/python -m pytest tests -m "not postgis and not redis"
```

> Ce mode est un **confort de développement**, jamais une cible de livraison.
> Le géospatial et le temps réel ne sont vérifiés qu'en CI, qui dispose de
> PostGIS et de Redis. Rien ne doit être déclaré vert sur la seule foi d'une
> exécution locale.

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

## Qualité

```bash
ruff check .          # style et bogues probables
ruff format .         # format
mypy common config apps
pytest --cov
```

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
