"""Réglages de test.

La base de test est **PostgreSQL/PostGIS**, servi par `docker compose up db`
en local et par un service GitHub Actions en CI. Il n'y a pas de repli SQLite :
le schéma emploie des types propres à PostgreSQL (`ArrayField`, `geography`,
contraintes d'exclusion), et une base de test d'un autre moteur ne pourrait pas
les porter. Un vert obtenu sur un schéma dégradé ne prouverait rien.

    docker compose up -d db redis
    pytest

Les services externes (cache, channel layer, files, stockage objet) sont
remplacés par des équivalents en mémoire : ils n'apportent rien à la
vérification du métier et rendraient la suite lente et instable.
"""

from __future__ import annotations

import os

# Valeurs par défaut posées avant l'import de `base`, qui lit l'environnement.
os.environ.setdefault("DJANGO_SECRET_KEY", "test-only-not-a-secret")
os.environ.setdefault("DJANGO_DEBUG", "False")
os.environ.setdefault("GIS_ENABLED", "True")
# `docker compose` expose PostgreSQL sur 5433 pour ne pas heurter une instance
# déjà installée sur le poste. La CI, elle, utilise 5432.
os.environ.setdefault("POSTGRES_HOST", "localhost")
os.environ.setdefault("POSTGRES_PORT", "5433")
os.environ.setdefault("POSTGRES_DB", "elcorazon")
os.environ.setdefault("POSTGRES_USER", "elcorazon")
os.environ.setdefault("POSTGRES_PASSWORD", "elcorazon")

from .base import *  # noqa: F403
from .base import BASE_DIR, REST_FRAMEWORK

TESTING = True

# --------------------------------------------------------------- sans service externe

CACHES = {"default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache"}}
CHANNEL_LAYERS = {"default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}}

CELERY_TASK_ALWAYS_EAGER = True
CELERY_TASK_EAGER_PROPAGATES = True  # une tâche qui échoue fait échouer le test

STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.InMemoryStorage"},
    "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
}

# --------------------------------------------------------------- rapidité

PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]

# La limitation de débit est désactivée par défaut : sinon le 6ᵉ test qui
# s'authentifie reçoit un 429.  Les tests qui vérifient *le limiteur lui-même*
# la réactivent explicitement (T1).
REST_FRAMEWORK = {**REST_FRAMEWORK, "DEFAULT_THROTTLE_RATES": {}}

# --------------------------------------------------------------- JWT

# Paire RSA de test, régénérée à chaque session : aucune clé privée en dépôt,
# même de test — c'est la seule façon d'être sûr qu'aucune ne fuite en
# production par copier-coller.
try:
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import rsa

    _key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    SIMPLE_JWT = {
        **globals()["SIMPLE_JWT"],
        "SIGNING_KEY": _key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption(),
        ).decode(),
        "VERIFYING_KEY": _key.public_key()
        .public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.SubjectPublicKeyInfo,
        )
        .decode(),
    }
except ImportError:  # pragma: no cover - cryptography absent : tests purs seulement
    pass

LOGGING = {"version": 1, "disable_existing_loggers": False, "root": {"handlers": []}}

MEDIA_ROOT = BASE_DIR / ".pytest-media"
