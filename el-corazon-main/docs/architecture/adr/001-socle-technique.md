# ADR-001 — Socle technique

**Statut** : accepté · **Date** : 2026-07-25

## Contexte

Le backend doit porter l'intégralité de la logique métier pour trois clients Flutter, servir une API
REST, diffuser des événements temps réel, exécuter des traitements asynchrones et interroger des
données géospatiales. Le socle est imposé par la mission : Python / Django / DRF / Channels.

Il reste à fixer les versions et les composants complémentaires, ce qui n'est pas neutre : la
version majeure de Django détermine la durée de support et donc le coût de maintenance sur trois ans.

## Décision

| Composant | Version | Rôle |
|---|---|---|
| Python | **3.13** (Docker et CI) | Runtime |
| Django | **5.2 LTS** (5.2.16) | Framework, ORM, migrations, GeoDjango |
| Django REST Framework | 3.17 | API REST |
| djangorestframework-simplejwt | 5.x | JWT + refresh rotatif |
| Django Channels + `channels-redis` | 4.3 | WebSocket |
| Celery + Redis | 5.6 | Tâches asynchrones et planifiées |
| psycopg | 3.3 (`[binary]`) | Pilote PostgreSQL |
| drf-spectacular | 0.30 | OpenAPI 3.1 |
| django-filter | 25.x | Filtres de liste |
| pytest + pytest-django + factory-boy | — | Tests |
| ruff + mypy | — | Qualité et typage |

**Django 5.2 LTS** plutôt que la dernière version : support de sécurité jusqu'en avril 2028, contre
un cycle court de 8 mois pour une version intermédiaire. Sur un produit qui doit vivre plusieurs
années avec une petite équipe, la fenêtre de support prime sur les nouveautés.

**Python 3.13** plutôt que 3.14 dans les images, malgré une vérification favorable. L'intégralité de
la pile a été installée et importée sur le Python 3.14.3 du poste : Django 5.2.16 (qui déclare
officiellement 3.14 dans ses classificateurs), DRF 3.17.1, psycopg 3.3.4, Channels 4.3.2,
Celery 5.6.3, drf-spectacular 0.30.0 — roues précompilées disponibles, aucun échec.

Le seul maillon non vérifié est GDAL/GEOS, dont dépend GeoDjango : ce sont des bibliothèques
système, pas des roues Python, et elles ne sont pas installables sur ce poste. Tant que la chaîne
géospatiale n'a pas tourné sur 3.14, les images restent en 3.13. Le passage à 3.14 est un
changement d'une ligne dans le `Dockerfile`, à faire une fois la validation faite.

**psycopg 3** plutôt que psycopg2 : c'est le pilote recommandé par Django 5.x, il gère nativement
l'asynchrone et les *connection pools*, ce dont Channels tirera parti.

## Conséquences

- Une seule image Docker sert l'API, les workers et beat. Moins de dérive entre environnements.
- GeoDjango impose GDAL et GEOS dans l'image : l'image de base ne peut pas être `alpine`
  (musl vs glibc sur les binaires géospatiaux) — ce sera `python:3.13-slim`.
- Le poste de développement courant tourne sur Python 3.14 sans PostGIS ; il ne peut donc pas
  exécuter la totalité de la suite de tests. Assumé (voir Phase 8).

## Alternatives écartées

| Alternative | Raison du rejet |
|---|---|
| FastAPI + SQLAlchemy | Aurait exigé de rebâtir l'admin, les migrations, l'authentification et les permissions. La mission impose Django, et ce choix est de toute façon le bon ici : le back-office bénéficie directement de l'écosystème. |
| Django 6.0 | Cycle de support court. À reconsidérer à la prochaine LTS. |
| WebSocket via un service Node séparé | Duplique le modèle d'autorisation dans un second langage. Channels partage l'ORM et les permissions. |
| Uvicorn seul sans Channels | Perd le *channel layer*, donc la diffusion multi-processus — indispensable dès deux répliques. |
