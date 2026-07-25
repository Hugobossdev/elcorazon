"""Routage racine.

Le versionnement est porté par l'URL (`/api/v1/`) — voir ADR-009 : visible dans
les journaux et les traces, trivial à router côté Nginx, et une v2 pourra
coexister sans négociation de contenu.
"""

from __future__ import annotations

from django.conf import settings
from django.contrib import admin
from django.http import HttpRequest, JsonResponse
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView


def healthcheck(_request: HttpRequest) -> JsonResponse:
    """Sonde de vivacité, sans accès base.

    Volontairement dissociée de l'état de PostgreSQL : une sonde de *liveness*
    qui échoue parce que la base est momentanément indisponible ferait
    redémarrer en boucle des conteneurs parfaitement sains.
    """
    return JsonResponse({"status": "ok", "version": settings.SPECTACULAR_SETTINGS["VERSION"]})


api_v1 = [
    # Renseigné au fil des phases — voir docs/architecture/README.md
    # path("auth/", include("apps.accounts.urls")),
    # path("catalog/", include("apps.catalog.urls")),
    # path("orders/", include("apps.orders.urls")),
]

urlpatterns = [
    path("health/", healthcheck, name="health"),
    path("admin/", admin.site.urls),
    path("api/v1/", include((api_v1, "v1"), namespace="v1")),
    path("api/v1/schema/", SpectacularAPIView.as_view(), name="schema"),
]

if settings.DEBUG:
    urlpatterns += [
        path(
            "api/v1/docs/",
            SpectacularSwaggerView.as_view(url_name="schema"),
            name="docs",
        ),
    ]
