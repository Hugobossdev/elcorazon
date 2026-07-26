"""Contrats de la livraison — ADR-009, invariants L1 et L5.

Aucun sérialiseur d'entrée ne porte `verification_status`, `deliveries_completed`
ni `total_earnings`. Un livreur qui pourrait écrire son propre statut de dossier
se validerait lui-même ; un livreur qui pourrait écrire ses compteurs se
paierait. Ces champs n'existent pas en écriture — il n'y a donc rien à valider.
"""

from __future__ import annotations

from typing import Any

from rest_framework import serializers

from apps.delivery.models import Assignment, CourierProfile
from apps.delivery.states import DELIVERY_MACHINE, VERIFICATION_MACHINE
from apps.restaurants.models import Restaurant
from common.serializers import LocationField, MoneyField

__all__ = [
    "AssignmentSerializer",
    "CourierProfileSerializer",
    "CourierPublicSerializer",
    "DeclineSerializer",
    "DeliveryTransitionSerializer",
    "DocumentsSerializer",
    "OfferSerializer",
    "OnlineSerializer",
    "VerificationSerializer",
]


class CourierPublicSerializer(serializers.ModelSerializer[CourierProfile]):
    """Ce qu'un client peut voir du livreur qui lui apporte sa commande.

    Prénom, véhicule, note — de quoi le reconnaître à la porte. Ni téléphone
    personnel, ni pièces d'identité, ni position hors course : suivre son
    livreur pendant sa livraison est un service, le suivre ensuite est une
    filature.
    """

    full_name = serializers.CharField(source="user.full_name", read_only=True)
    avatar = serializers.ImageField(source="user.avatar", read_only=True)

    class Meta:
        model = CourierProfile
        fields = ["id", "full_name", "avatar", "vehicle_type", "rating_average", "rating_count"]
        read_only_fields = fields


class CourierProfileSerializer(serializers.ModelSerializer[CourierProfile]):
    """Dossier complet — lisible par son titulaire et par le personnel."""

    full_name = serializers.CharField(source="user.full_name", read_only=True)
    email = serializers.EmailField(source="user.email", read_only=True)
    restaurant = serializers.SlugRelatedField[Restaurant](slug_field="slug", read_only=True)
    last_location = LocationField(read_only=True)
    total_earnings = MoneyField(read_only=True)
    can_accept_orders = serializers.BooleanField(read_only=True)

    class Meta:
        model = CourierProfile
        fields = [
            "id",
            "full_name",
            "email",
            "restaurant",
            "verification_status",
            "verification_notes",
            "verified_at",
            "vehicle_type",
            "vehicle_plate",
            "is_online",
            "can_accept_orders",
            "last_location",
            "last_location_at",
            "deliveries_completed",
            "deliveries_cancelled",
            "rating_average",
            "rating_count",
            "total_earnings",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields


class AssignmentSerializer(serializers.ModelSerializer[Assignment]):
    """Course, vue par le livreur ou par le personnel."""

    order_reference = serializers.CharField(source="order.reference", read_only=True)
    restaurant_name = serializers.CharField(source="order.restaurant.name", read_only=True)
    pickup_location = LocationField(source="order.restaurant.location", read_only=True)
    delivery_address_line = serializers.CharField(
        source="order.delivery_address_line", read_only=True
    )
    delivery_landmark = serializers.CharField(source="order.delivery_landmark", read_only=True)
    delivery_location = serializers.JSONField(source="order.delivery_location", read_only=True)
    recipient_name = serializers.CharField(source="order.recipient_name", read_only=True)
    recipient_phone = serializers.CharField(source="order.recipient_phone", read_only=True)
    courier = CourierPublicSerializer(read_only=True)
    courier_fee = MoneyField(read_only=True)
    allowed_transitions = serializers.SerializerMethodField()

    class Meta:
        model = Assignment
        fields = [
            "id",
            "order",
            "order_reference",
            "restaurant_name",
            "pickup_location",
            "delivery_address_line",
            "delivery_landmark",
            "delivery_location",
            "recipient_name",
            "recipient_phone",
            "courier",
            "status",
            "allowed_transitions",
            "courier_fee",
            "offered_at",
            "accepted_at",
            "picked_up_at",
            "delivered_at",
            "decline_reason",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields

    def get_allowed_transitions(self, obj: Assignment) -> list[str]:
        return sorted(DELIVERY_MACHINE.targets_from(obj.status))


class OfferSerializer(serializers.Serializer[Any]):
    courier = serializers.PrimaryKeyRelatedField[CourierProfile](
        queryset=CourierProfile.objects.all()
    )


class DeclineSerializer(serializers.Serializer[Any]):
    reason = serializers.CharField(max_length=500, required=False, allow_blank=True, default="")


class DeliveryTransitionSerializer(serializers.Serializer[Any]):
    status = serializers.ChoiceField(choices=sorted(DELIVERY_MACHINE.states))
    reason = serializers.CharField(max_length=500, required=False, allow_blank=True, default="")


class VerificationSerializer(serializers.Serializer[Any]):
    status = serializers.ChoiceField(choices=sorted(VERIFICATION_MACHINE.states))
    notes = serializers.CharField(max_length=1000, required=False, allow_blank=True, default="")


class OnlineSerializer(serializers.Serializer[Any]):
    is_online = serializers.BooleanField()


class DocumentsSerializer(serializers.Serializer[Any]):
    """Dépôt de pièces justificatives.

    Toutes facultatives : on remplace ce qu'on remplace. Mais déposer **une**
    pièce suffit à repasser le dossier en attente (L5) — un dossier validé sur
    des documents qu'on a ensuite changés n'est plus validé.
    """

    id_document = serializers.FileField(required=False)
    licence_document = serializers.FileField(required=False)
    vehicle_document = serializers.FileField(required=False)

    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        if not attrs:
            raise serializers.ValidationError("Aucune pièce fournie.")
        return attrs
