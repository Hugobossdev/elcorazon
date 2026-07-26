"""Contrats des notifications — ADR-009."""

from __future__ import annotations

from typing import Any

from rest_framework import serializers

from apps.notifications.models import Notification

__all__ = ["NotificationSerializer", "UnreadCountSerializer"]


class NotificationSerializer(serializers.ModelSerializer[Notification]):
    is_read = serializers.BooleanField(read_only=True)

    class Meta:
        model = Notification
        fields = ["id", "kind", "title", "body", "data", "is_read", "read_at", "created_at"]
        read_only_fields = fields


class UnreadCountSerializer(serializers.Serializer[Any]):
    unread = serializers.IntegerField(read_only=True)
