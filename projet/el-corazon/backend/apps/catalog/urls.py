"""Routes du catalogue — montées sous `/api/v1/catalog/`."""

from __future__ import annotations

from rest_framework.routers import DefaultRouter

from apps.catalog import views

app_name = "catalog"

router = DefaultRouter()
router.register("categories", views.CategoryViewSet, basename="category")
router.register("items", views.MenuItemViewSet, basename="item")
router.register("reviews", views.ReviewViewSet, basename="review")

urlpatterns = router.urls
