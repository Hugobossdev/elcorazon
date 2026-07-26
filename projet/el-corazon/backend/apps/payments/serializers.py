"""Contrats du paiement — ADR-009.

Aucun sérialiseur d'entrée ne porte de statut de paiement. C'est structurel :
le seul chemin qui fasse passer une transaction en `completed` est le webhook
signé du prestataire, et il n'y a donc pas de champ à protéger.
"""

from __future__ import annotations

from typing import Any

from rest_framework import serializers

from apps.payments.models import Refund, Transaction
from common.serializers import MoneyField

__all__ = [
    "CheckoutSerializer",
    "RefundRequestSerializer",
    "RefundSerializer",
    "TransactionSerializer",
    "WebhookSerializer",
]


class TransactionSerializer(serializers.ModelSerializer[Transaction]):
    amount = MoneyField(read_only=True)

    class Meta:
        model = Transaction
        fields = [
            "id",
            "order",
            "provider",
            "provider_reference",
            "amount",
            "status",
            "completed_at",
            "failure_reason",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields


class CheckoutSerializer(serializers.Serializer[Any]):
    """Réponse à l'initiation : la transaction ouverte et où aller payer."""

    transaction = TransactionSerializer(read_only=True)
    checkout_url = serializers.URLField(read_only=True)
    instructions = serializers.CharField(read_only=True)


class WebhookSerializer(serializers.Serializer[Any]):
    """Notification du prestataire.

    Le corps est validé pour sa **forme** seulement. Son authenticité tient à
    la signature du corps brut, vérifiée avant que ce sérialiseur ne soit
    construit : un payload bien formé mais non signé n'atteint jamais ici.
    """

    event_id = serializers.CharField(max_length=128)
    provider_reference = serializers.CharField(max_length=128)
    status = serializers.CharField(max_length=16)
    reason = serializers.CharField(max_length=500, required=False, allow_blank=True, default="")


class RefundSerializer(serializers.ModelSerializer[Refund]):
    amount = MoneyField(read_only=True)

    class Meta:
        model = Refund
        fields = [
            "id",
            "order",
            "transaction",
            "amount",
            "reason",
            "status",
            "completed_at",
            "created_at",
        ]
        read_only_fields = fields


class RefundRequestSerializer(serializers.Serializer[Any]):
    transaction = serializers.UUIDField()
    amount = MoneyField()
    reason = serializers.CharField(max_length=500)
