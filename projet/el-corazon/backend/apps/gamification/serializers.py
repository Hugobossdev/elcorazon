"""Contrats de la gamification.

Tout est en lecture seule : le progrès se calcule côté serveur depuis les
commandes livrées (voir `apps.gamification.services`), rien ne s'y déclare
depuis le client — même logique que la fidélité.

`progress`, `is_unlocked` et `unlocked_at` ne sont pas des colonnes du
catalogue : ils viennent de la ligne de progression **du client courant**,
injectée par la vue dans le contexte du sérialiseur (`context["progress"]`)
pour éviter une requête par ligne de catalogue.
"""

from __future__ import annotations

from typing import Any

from rest_framework import serializers

from apps.gamification.models import Achievement, Badge, Challenge

__all__ = ["AchievementSerializer", "BadgeSerializer", "ChallengeSerializer"]


def _progress_entry(serializer: serializers.BaseSerializer[Any], obj: Any) -> Any:
    """La ligne de progression du client courant, si la vue en a injecté une."""
    return serializer.context.get("progress", {}).get(obj.pk)


class AchievementSerializer(serializers.ModelSerializer[Achievement]):
    progress = serializers.SerializerMethodField()
    is_unlocked = serializers.SerializerMethodField()
    unlocked_at = serializers.SerializerMethodField()

    class Meta:
        model = Achievement
        fields = [
            "id",
            "name",
            "description",
            "icon",
            "condition_type",
            "condition_value",
            "points_reward",
            "progress",
            "is_unlocked",
            "unlocked_at",
        ]
        read_only_fields = fields

    def get_progress(self, obj: Achievement) -> int:
        entry = _progress_entry(self, obj)
        return int(entry.progress) if entry else 0

    def get_is_unlocked(self, obj: Achievement) -> bool:
        entry = _progress_entry(self, obj)
        return bool(entry and entry.is_unlocked)

    def get_unlocked_at(self, obj: Achievement) -> Any:
        entry = _progress_entry(self, obj)
        return entry.unlocked_at if entry else None


class BadgeSerializer(serializers.ModelSerializer[Badge]):
    is_unlocked = serializers.SerializerMethodField()
    unlocked_at = serializers.SerializerMethodField()

    class Meta:
        model = Badge
        fields = [
            "id",
            "title",
            "description",
            "icon",
            "points_required",
            "is_unlocked",
            "unlocked_at",
        ]
        read_only_fields = fields

    def get_is_unlocked(self, obj: Badge) -> bool:
        entry = _progress_entry(self, obj)
        return bool(entry and entry.is_unlocked)

    def get_unlocked_at(self, obj: Badge) -> Any:
        entry = _progress_entry(self, obj)
        return entry.unlocked_at if entry else None


class ChallengeSerializer(serializers.ModelSerializer[Challenge]):
    progress = serializers.SerializerMethodField()
    is_completed = serializers.SerializerMethodField()

    class Meta:
        model = Challenge
        fields = [
            "id",
            "title",
            "description",
            "challenge_type",
            "target_value",
            "reward_points",
            "starts_at",
            "ends_at",
            "progress",
            "is_completed",
        ]
        read_only_fields = fields

    def get_progress(self, obj: Challenge) -> int:
        entry = _progress_entry(self, obj)
        return int(entry.progress) if entry else 0

    def get_is_completed(self, obj: Challenge) -> bool:
        entry = _progress_entry(self, obj)
        return bool(entry and entry.is_completed)
