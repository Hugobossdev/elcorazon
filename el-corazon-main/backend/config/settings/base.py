"""Réglages communs à tous les environnements.

Aucune valeur secrète ni spécifique à un environnement ici : tout ce qui varie
est lu depuis l'environnement, et `base.py` ne doit jamais être importé
directement — voir `dev.py`, `prod.py`, `test.py`.
"""

from __future__ import annotations

from datetime import timedelta
from pathlib import Path

from decouple import Csv, config

BASE_DIR = Path(__file__).resolve().parent.parent.parent

# --------------------------------------------------------------- sécurité

SECRET_KEY: str = config("DJANGO_SECRET_KEY")
DEBUG: bool = config("DJANGO_DEBUG", default=False, cast=bool)
ALLOWED_HOSTS: list[str] = config("DJANGO_ALLOWED_HOSTS", default="", cast=Csv())

# --------------------------------------------------------------- applications

DJANGO_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
]

THIRD_PARTY_APPS = [
    "rest_framework",
    "rest_framework_simplejwt.token_blacklist",
    "django_filters",
    "drf_spectacular",
    "corsheaders",
    "channels",
]

# Applications métier — voir ADR-002.  L'ordre suit le graphe de dépendances :
# une app ne dépend que de celles qui la précèdent.
LOCAL_APPS: list[str] = [
    # Chemin critique — construit en premier
    "apps.accounts",
    "apps.geography",
    "apps.restaurants",
    "apps.profiles",
    "apps.catalog",
    "apps.carts",
    "apps.orders",
    "apps.payments",
    "apps.delivery",
    "apps.tracking",
    # "apps.notifications",
    #
    # Second temps
    # "apps.inventory", "apps.promotions", "apps.loyalty",
    # "apps.gamification", "apps.social", "apps.support", "apps.analytics",
]

INSTALLED_APPS = DJANGO_APPS + THIRD_PARTY_APPS + LOCAL_APPS

# --------------------------------------------------------------- géospatial

# GeoDjango exige GDAL et GEOS, qui sont des bibliothèques *système*.  Elles
# sont présentes dans l'image Docker et en CI, absentes d'un poste Windows nu.
# Ce drapeau permet à un développeur sans Docker d'exécuter le sous-ensemble
# non géospatial de la suite (voir Phase 8), sans que la production ait le
# moindre chemin de code différent.
GIS_ENABLED: bool = config("GIS_ENABLED", default=True, cast=bool)

if GIS_ENABLED:
    INSTALLED_APPS = [*INSTALLED_APPS, "django.contrib.gis"]

# --------------------------------------------------------------- middleware

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

# --------------------------------------------------------------- base de données

DATABASES = {
    "default": {
        "ENGINE": (
            "django.contrib.gis.db.backends.postgis"
            if GIS_ENABLED
            else "django.db.backends.postgresql"
        ),
        "NAME": config("POSTGRES_DB", default="elcorazon"),
        "USER": config("POSTGRES_USER", default="elcorazon"),
        "PASSWORD": config("POSTGRES_PASSWORD", default=""),
        "HOST": config("POSTGRES_HOST", default="localhost"),
        "PORT": config("POSTGRES_PORT", default="5432"),
        "CONN_MAX_AGE": config("POSTGRES_CONN_MAX_AGE", default=60, cast=int),
        "ATOMIC_REQUESTS": False,  # les transactions sont explicites, dans les services
    }
}

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"  # tables techniques uniquement

AUTH_USER_MODEL = "accounts.User"

# --------------------------------------------------------------- cache et files

REDIS_URL: str = config("REDIS_URL", default="redis://localhost:6379/0")

CACHES = {
    "default": {
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": REDIS_URL,
        "OPTIONS": {"CLIENT_CLASS": "django_redis.client.DefaultClient"},
    }
}

CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {"hosts": [REDIS_URL]},
    }
}

CELERY_BROKER_URL = config("CELERY_BROKER_URL", default=REDIS_URL)
CELERY_RESULT_BACKEND = config("CELERY_RESULT_BACKEND", default=REDIS_URL)
CELERY_TASK_ACKS_LATE = True
CELERY_TASK_REJECT_ON_WORKER_LOST = True
CELERY_WORKER_PREFETCH_MULTIPLIER = 1
CELERY_TASK_TIME_LIMIT = 300
CELERY_TASK_SOFT_TIME_LIMIT = 240
CELERY_TIMEZONE = "UTC"

# --------------------------------------------------------------- API

REST_FRAMEWORK = {
    # ADR-005 : refus par défaut.  Toute route publique le déclare explicitement,
    # ce qui rend la liste des points d'entrée ouverts auditable en une recherche.
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ],
    "DEFAULT_PAGINATION_CLASS": "common.pagination.StandardPagination",
    "PAGE_SIZE": 20,
    "DEFAULT_FILTER_BACKENDS": ["django_filters.rest_framework.DjangoFilterBackend"],
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "EXCEPTION_HANDLER": "common.exceptions.problem_detail_handler",
    "DEFAULT_THROTTLE_RATES": {
        "anon": "60/min",
        "user": "120/min",
        "auth_ip": "20/min",  # T1 — force brute par adresse
        "auth_identifier": "5/min",  # T1 — force brute par identifiant tenté
        "webhook": "60/min",
    },
    "UNAUTHENTICATED_USER": None,
}

SPECTACULAR_SETTINGS = {
    "TITLE": "El Corazón API",
    "DESCRIPTION": "API de la plateforme de commande et de livraison El Corazón.",
    "VERSION": "1.0.0",
    "SERVE_INCLUDE_SCHEMA": False,
    "COMPONENT_SPLIT_REQUEST": True,
    "SCHEMA_PATH_PREFIX": "/api/v1",
}

# --------------------------------------------------------------- JWT (ADR-004)


def _read_key(path_var: str, inline_var: str) -> str:
    """Lit une clé depuis un fichier monté, sinon depuis l'environnement.

    Le fichier est la voie recommandée : une clé PEM est multiligne, ce que ni
    `env_file` de Docker Compose ni la plupart des gestionnaires de
    configuration ne savent porter sans échappement fragile. C'est aussi la
    forme qu'attendent les `Secret` Kubernetes montés en volume.

    La variable en clair reste acceptée pour les déploiements simples.
    """
    path = config(path_var, default="")
    if path:
        return Path(path).read_text(encoding="utf-8")
    return config(inline_var, default="").replace("\\n", "\n")


SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=15),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=30),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "UPDATE_LAST_LOGIN": True,
    "ALGORITHM": "RS256",
    "SIGNING_KEY": _read_key("JWT_PRIVATE_KEY_PATH", "JWT_SIGNING_KEY"),
    "VERIFYING_KEY": _read_key("JWT_PUBLIC_KEY_PATH", "JWT_VERIFYING_KEY"),
    "AUTH_HEADER_TYPES": ("Bearer",),
    "USER_ID_FIELD": "id",
    "USER_ID_CLAIM": "sub",
    "TOKEN_TYPE_CLAIM": "typ",
}

# --------------------------------------------------------------- stockage

STORAGES = {
    "default": {"BACKEND": "storages.backends.s3.S3Storage"},
    "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
}

AWS_S3_ENDPOINT_URL = config("S3_ENDPOINT_URL", default="")
AWS_STORAGE_BUCKET_NAME = config("S3_BUCKET", default="elcorazon")
AWS_S3_REGION_NAME = config("S3_REGION", default="us-east-1")
AWS_ACCESS_KEY_ID = config("S3_ACCESS_KEY", default="")
AWS_SECRET_ACCESS_KEY = config("S3_SECRET_KEY", default="")
AWS_QUERYSTRING_AUTH = True  # les pièces d'identité livreurs ne sont jamais publiques
AWS_QUERYSTRING_EXPIRE = 900

STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

# --------------------------------------------------------------- localisation

LANGUAGE_CODE = "fr"
LANGUAGES = [("fr", "Français"), ("en", "English")]
TIME_ZONE = "UTC"  # figé en UTC ; l'affichage local est la responsabilité du client
USE_I18N = True
USE_TZ = True

# --------------------------------------------------------------- métier

DEFAULT_CURRENCY = config("DEFAULT_CURRENCY", default="XOF")

# --------------------------------------------------------------- journalisation

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {"json": {"()": "config.logging.JSONFormatter"}},
    "handlers": {
        "console": {"class": "logging.StreamHandler", "formatter": "json"},
    },
    "root": {"handlers": ["console"], "level": config("LOG_LEVEL", default="INFO")},
    "loggers": {
        "django.db.backends": {"level": "WARNING", "propagate": True},
    },
}
