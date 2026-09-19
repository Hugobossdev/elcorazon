"""Contrats des notifications — ADR-009."""

from __future__ import annotations

from typing import Any

from rest_framework import serializers

from apps.notifications.models import Campaign, Notification

__all__ = ["CampaignSerializer", "NotificationSerializer", "UnreadCountSerializer"]


class NotificationSerializer(serializers.ModelSerializer[Notification]):
    is_read = serializers.BooleanField(read_only=True)

    class Meta:
        model = Notification
        fields = ["id", "kind", "title", "body", "data", "is_read", "read_at", "created_at"]
        read_only_fields = fields


class UnreadCountSerializer(serializers.Serializer[Any]):
    unread = serializers.IntegerField(read_only=True)


class CampaignSerializer(serializers.ModelSerializer[Campaign]):
    """Campagne : ce qu'on rédige, et ce que le serveur en dit après coup.

    `status`, `sent_at` et `recipient_count` sont en lecture seule — ils sont
    écrits par l'envoi lui-même. Les rendre inscriptibles permettrait de
    marquer « envoyée » une campagne jamais partie, ou d'annoncer un nombre de
    destinataires que personne n'a reçus.
    """

    created_by_email = serializers.EmailField(source="created_by.email", read_only=True)
    audience_label = serializers.CharField(source="get_audience_display", read_only=True)

    class Meta:
        model = Campaign
        fields = [
            "id",
            "title",
            "body",
            "audience",
            "audience_label",
            "segment_days",
            "status",
            "sent_at",
            "recipient_count",
            "created_by_email",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "audience_label",
            "status",
            "sent_at",
            "recipient_count",
            "created_by_email",
            "created_at",
            "updated_at",
        ]


class CampaignStatsSerializer(serializers.Serializer[Any]):
    """Le bilan d'une campagne envoyée — voir `campaign_stats`."""

    recipients = serializers.IntegerField()
    read = serializers.IntegerField()
    open_rate = serializers.FloatField(allow_null=True)
    window_days = serializers.IntegerField()
    customers_who_ordered = serializers.IntegerField()
    conversion_rate = serializers.FloatField(allow_null=True)
    revenue = serializers.ListField(
        child=serializers.DictField(), help_text="`amount` (unité mineure) et `currency`."
    )
