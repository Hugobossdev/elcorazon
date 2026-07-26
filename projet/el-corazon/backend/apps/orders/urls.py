"""Routes des commandes — montées sous `/api/v1/orders/`."""

from __future__ import annotations

from rest_framework.routers import DefaultRouter

from apps.orders import views

app_name = "orders"

router = DefaultRouter()
router.register("", views.OrderViewSet, basename="order")

urlpatterns = router.urls
