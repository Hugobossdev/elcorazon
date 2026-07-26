"""Routes des établissements — montées sous `/api/v1/restaurants/`."""

from __future__ import annotations

from rest_framework.routers import DefaultRouter

from apps.restaurants import views

app_name = "restaurants"

router = DefaultRouter()
router.register("", views.RestaurantViewSet, basename="restaurant")

urlpatterns = router.urls
