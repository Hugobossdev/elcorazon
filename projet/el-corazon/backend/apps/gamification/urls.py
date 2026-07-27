"""Routes de la gamification — montées sous `/api/v1/gamification/`."""

from __future__ import annotations

from rest_framework.routers import DefaultRouter

from apps.gamification import views

app_name = "gamification"

router = DefaultRouter()
router.register("achievements", views.AchievementViewSet, basename="achievement")
router.register("badges", views.BadgeViewSet, basename="badge")
router.register("challenges", views.ChallengeViewSet, basename="challenge")

urlpatterns = router.urls
