"""Routes des notifications — montées sous `/api/v1/notifications/`."""

from __future__ import annotations

from rest_framework.routers import DefaultRouter

from apps.notifications import views

app_name = "notifications"

router = DefaultRouter()
router.register("", views.NotificationViewSet, basename="notification")

urlpatterns = router.urls
