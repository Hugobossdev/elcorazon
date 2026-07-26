"""Contrats de la commande — ADR-009, invariants C1 et C2.

Aucun montant n'est accepté en entrée. Le sérialiseur de création ne porte que
des **choix** — quel panier, quelle adresse, quel moyen de paiement — et le
serveur en déduit tout le reste. C'est C1 rendu inexprimable plutôt que
vérifié : il n'existe pas de champ à valider.
"""

from __future__ import annotations

from typing import Any

from rest_framework import serializers

from apps.orders.models import Order, OrderLine, OrderStatusEvent, PaymentMethod
from apps.orders.states import ORDER_MACHINE
from apps.profiles.models import Address
from apps.restaurants.models import Restaurant
from common.serializers import MoneyField

__all__ = [
    "CancelSerializer",
    "OrderCreateSerializer",
    "OrderDetailSerializer",
    "OrderSerializer",
    "StatusTransitionSerializer",
]


class OrderLineSerializer(serializers.ModelSerializer[OrderLine]):
    unit_price = MoneyField(read_only=True)
    line_total = MoneyField(read_only=True)

    class Meta:
        model = OrderLine
        fields = [
            "id",
            "menu_item",
            "item_name",
            "item_image",
            "unit_price",
            "quantity",
            "line_total",
            "options",
            "notes",
        ]
        read_only_fields = fields


class OrderStatusEventSerializer(serializers.ModelSerializer[OrderStatusEvent]):
    class Meta:
        model = OrderStatusEvent
        fields = ["id", "from_status", "to_status", "reason", "created_at"]
        read_only_fields = fields


class OrderSerializer(serializers.ModelSerializer[Order]):
    """Forme de liste — l'historique du client.

    `allowed_transitions` est rendu par le serveur plutôt que déduit côté
    client : la table des transitions est déjà déclarée une fois (ADR-010), et
    la recopier dans trois applications Flutter garantirait qu'elles divergent.
    """

    restaurant = serializers.SlugRelatedField[Restaurant](slug_field="slug", read_only=True)
    restaurant_name = serializers.CharField(source="restaurant.name", read_only=True)
    subtotal = MoneyField(read_only=True)
    delivery_fee = MoneyField(read_only=True)
    discount = MoneyField(read_only=True)
    total = MoneyField(read_only=True)
    allowed_transitions = serializers.SerializerMethodField()

    class Meta:
        model = Order
        fields = [
            "id",
            "reference",
            "restaurant",
            "restaurant_name",
            "status",
            "allowed_transitions",
            "subtotal",
            "delivery_fee",
            "discount",
            "total",
            "payment_method",
            "delivery_address_line",
            "delivery_landmark",
            "delivery_location",
            "recipient_name",
            "recipient_phone",
            "placed_at",
            "estimated_delivery_at",
            "delivered_at",
            "cancelled_at",
            "cancellation_reason",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields

    def get_allowed_transitions(self, obj: Order) -> list[str]:
        return sorted(ORDER_MACHINE.targets_from(obj.status))


class OrderDetailSerializer(OrderSerializer):
    lines = OrderLineSerializer(many=True, read_only=True)
    status_events = OrderStatusEventSerializer(many=True, read_only=True)
    delivery_instructions = serializers.CharField(read_only=True)

    class Meta(OrderSerializer.Meta):
        fields = [
            *OrderSerializer.Meta.fields,
            "delivery_instructions",
            "lines",
            "status_events",
        ]
        read_only_fields = fields


class OrderCreateSerializer(serializers.Serializer[Any]):
    """Passage de commande.

    `restaurant` désigne le panier à valider — il y en a un par établissement
    entamé. Le code promo n'y figure pas encore : l'application `promotions`
    n'existe pas, et accepter un champ qu'on ignore ferait croire à une remise
    appliquée.
    """

    restaurant = serializers.SlugRelatedField[Restaurant](
        slug_field="slug", queryset=Restaurant.objects.filter(is_active=True)
    )
    address = serializers.PrimaryKeyRelatedField[Address](queryset=Address.objects.none())
    payment_method = serializers.ChoiceField(choices=PaymentMethod.choices)
    instructions = serializers.CharField(
        max_length=500, required=False, allow_blank=True, default=""
    )

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, **kwargs)
        # L'adresse est cherchée **dans le carnet de l'appelant**. Avec un
        # `queryset` global, un identifiant deviné ferait livrer la commande
        # chez quelqu'un d'autre — et le message d'erreur dirait au passage si
        # l'adresse existe. Ici, celle d'autrui est simplement invalide.
        request = self.context.get("request")
        if request is not None:
            self.fields["address"].queryset = Address.objects.filter(user=request.user)  # type: ignore[attr-defined]


class StatusTransitionSerializer(serializers.Serializer[Any]):
    status = serializers.ChoiceField(choices=sorted(ORDER_MACHINE.states))
    reason = serializers.CharField(max_length=500, required=False, allow_blank=True, default="")


class CancelSerializer(serializers.Serializer[Any]):
    reason = serializers.CharField(max_length=500, required=False, allow_blank=True, default="")
