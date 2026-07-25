# Image unique pour l'API, les workers et beat (ADR-001).
#
# Une seule image pour trois rôles : c'est ce qui garantit qu'un worker exécute
# exactement le code que l'API a validé. Le rôle est choisi par la commande.

# ---------------------------------------------------------------- base
FROM python:3.13-slim AS base

# `slim` et non `alpine` : GeoDjango s'appuie sur GDAL et GEOS, dont les
# binaires sont compilés contre glibc. Sur musl, il faudrait les recompiler.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# `gdal-bin` plutôt qu'un `libgdalNN` explicite : le numéro de SONAME change à
# chaque version de Debian, et l'épingler casse la construction au premier
# changement d'image de base. Le méta-paquet tire la bonne version de libgdal
# et de libproj.
RUN apt-get update && apt-get install --no-install-recommends -y \
        gdal-bin \
        libgeos-c1v5 \
        libpq5 \
        curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ---------------------------------------------------------------- dépendances
FROM base AS deps

RUN apt-get update && apt-get install --no-install-recommends -y \
        build-essential libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml ./

# Les dépendances sont installées avant le code : une modification de source
# n'invalide pas ce calque, ce qui rend les reconstructions quasi instantanées.
#
# `pyproject.toml` reste la source de vérité unique des dépendances. Les
# répertoires de paquets sont créés vides le temps de l'installation éditable,
# car setuptools exige leur existence — le code réel est copié au calque
# suivant et les remplace.
RUN mkdir -p config common apps \
    && touch config/__init__.py common/__init__.py apps/__init__.py \
    && python -m venv /opt/venv \
    && /opt/venv/bin/pip install --upgrade pip \
    && /opt/venv/bin/pip install -e . "uvicorn[standard]"

# ---------------------------------------------------------------- exécution
FROM base AS runtime

COPY --from=deps /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Utilisateur non privilégié : un conteneur compromis ne doit pas être root.
RUN useradd --create-home --uid 10001 corazon
COPY --chown=corazon:corazon . /app
USER corazon

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
    CMD curl -fsS http://localhost:8000/health/ || exit 1

# Rôle par défaut : l'API. Les autres sont choisis par `command:` dans compose
# ou par l'`args` du déploiement Kubernetes.
CMD ["uvicorn", "config.asgi:application", "--host", "0.0.0.0", "--port", "8000"]

# ---------------------------------------------------------------- développement
# Étage supplémentaire portant l'outillage de test et de qualité. C'est la cible
# utilisée par docker compose en local.
#
# `runtime` reste la cible livrée : pytest, ruff et mypy n'ont rien à faire dans
# une image de production — ils l'alourdissent et élargissent inutilement sa
# surface d'attaque.
FROM runtime AS dev

USER root
RUN /opt/venv/bin/pip install -e ".[dev]"
USER corazon
