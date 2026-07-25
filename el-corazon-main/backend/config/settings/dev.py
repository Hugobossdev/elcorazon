"""Réglages de développement (docker compose up)."""

from __future__ import annotations

from .base import *  # noqa: F403
from .base import INSTALLED_APPS, MIDDLEWARE, REST_FRAMEWORK

DEBUG = True
ALLOWED_HOSTS = ["*"]

# Le schéma et l'interface d'exploration ne sont servis qu'ici.
INSTALLED_APPS = [*INSTALLED_APPS]

REST_FRAMEWORK = {
    **REST_FRAMEWORK,
    # Interface DRF navigable, pratique pour explorer l'API à la main.
    "DEFAULT_RENDERER_CLASSES": [
        "rest_framework.renderers.JSONRenderer",
        "rest_framework.renderers.BrowsableAPIRenderer",
    ],
}

CORS_ALLOW_ALL_ORIGINS = True  # le back-office Flutter Web tourne sur un autre port

EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

MIDDLEWARE = [*MIDDLEWARE]
