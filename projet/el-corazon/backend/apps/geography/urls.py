"""Routes de la géographie — montées sous `/api/v1/geography/`."""

from __future__ import annotations

from django.urls import include, path
from rest_framework.routers import DefaultRouter

from apps.geography import views

app_name = "geography"

router = DefaultRouter()
router.register("countries", views.CountryViewSet, basename="country")
router.register("cities", views.CityViewSet, basename="city")

urlpatterns = [
    # Déclarée **avant** le routeur : `zones/resolve/` n'est pas un détail de
    # collection, et un routeur qui la capterait la traiterait comme un
    # identifiant de zone.
    path("zones/resolve/", views.ZoneResolutionView.as_view(), name="zone-resolve"),
    path("", include(router.urls)),
]
