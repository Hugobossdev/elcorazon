"""Réglages de production.

Toute valeur sensible vient de l'environnement, sans valeur par défaut : une
variable manquante doit faire échouer le démarrage, pas produire un service qui
tourne avec une configuration dégradée sans que personne ne le sache.
"""

from __future__ import annotations

from decouple import config

from .base import *  # noqa: F403

DEBUG = False

# --------------------------------------------------------------- transport

SECURE_SSL_REDIRECT = True
SECURE_HSTS_SECONDS = 31_536_000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_REFERRER_POLICY = "same-origin"

SESSION_COOKIE_SECURE = True
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = "Lax"
CSRF_COOKIE_SECURE = True
CSRF_TRUSTED_ORIGINS = config("CSRF_TRUSTED_ORIGINS", default="", cast=lambda v: v.split(","))

X_FRAME_OPTIONS = "DENY"

# --------------------------------------------------------------- CORS

CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOWED_ORIGINS = config("CORS_ALLOWED_ORIGINS", default="", cast=lambda v: v.split(","))

# --------------------------------------------------------------- messagerie

EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_HOST = config("EMAIL_HOST")
EMAIL_PORT = config("EMAIL_PORT", default=587, cast=int)
EMAIL_HOST_USER = config("EMAIL_HOST_USER")
EMAIL_HOST_PASSWORD = config("EMAIL_HOST_PASSWORD")
EMAIL_USE_TLS = True
DEFAULT_FROM_EMAIL = config("DEFAULT_FROM_EMAIL")

# --------------------------------------------------------------- garde-fous

# Ces réglages n'ont pas de valeur par défaut acceptable en production.  Les
# lire ici, au chargement, transforme un oubli de configuration en échec de
# démarrage immédiat plutôt qu'en incident de sécurité découvert plus tard.
for _required in ("DJANGO_SECRET_KEY", "JWT_SIGNING_KEY", "JWT_VERIFYING_KEY", "POSTGRES_PASSWORD"):
    if not config(_required, default=""):
        raise RuntimeError(
            f"{_required} est absente de l'environnement. "
            "La production ne démarre pas sans configuration complète."
        )
