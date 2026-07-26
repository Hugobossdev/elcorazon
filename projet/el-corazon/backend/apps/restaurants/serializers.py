"""Contrats des établissements — ADR-006, ADR-009.

Trois booléens sortent séparément — `is_open`, `accepts_orders`,
`can_order_now` — au lieu d'un seul « disponible ». C'est ce qui permet à
l'application de dire *pourquoi* : « fermé, ouvre à 11 h » n'est pas
« débordé, réessayez dans dix minutes », et les deux n'appellent pas le même
geste de la part du client.
"""

from __future__ import annotations

import datetime as dt
from typing import Any

from django.utils import timezone
from rest_framework import serializers

from apps.restaurants.models import OpeningHours, Restaurant
from common.serializers import LocationField, MoneyField

__all__ = [
    "NearbyQuerySerializer",
    "OpeningHoursSerializer",
    "RestaurantDetailSerializer",
    "RestaurantSerializer",
]


class OpeningHoursSerializer(serializers.ModelSerializer[OpeningHours]):
    crosses_midnight = serializers.BooleanField(read_only=True)

    class Meta:
        model = OpeningHours
        fields = ["id", "weekday", "opens_at", "closes_at", "crosses_midnight"]
        read_only_fields = fields


class RestaurantSerializer(serializers.ModelSerializer[Restaurant]):
    """Forme de liste.

    `distance_m` n'apparaît que si la requête portait un point de référence :
    l'annotation est absente sinon, et inventer un `0` ou un `null` ferait
    croire à une proximité qu'on n'a pas mesurée.
    """

    location = LocationField(read_only=True)
    city = serializers.CharField(source="zone.city.name", read_only=True)
    currency = serializers.CharField(read_only=True)
    delivery_fee_from = MoneyField(source="zone.base_fee", read_only=True)
    estimated_delivery_minutes = serializers.IntegerField(
        source="zone.estimated_delivery_minutes", read_only=True
    )

    is_open = serializers.SerializerMethodField()
    can_order_now = serializers.SerializerMethodField()
    distance_m = serializers.SerializerMethodField()

    class Meta:
        model = Restaurant
        fields = [
            "id",
            "name",
            "slug",
            "description",
            "address",
            "location",
            "city",
            "phone",
            "cover_image",
            "currency",
            "delivery_fee_from",
            "estimated_delivery_minutes",
            "default_preparation_minutes",
            "is_open",
            "accepts_orders",
            "can_order_now",
            "distance_m",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields

    def _now(self) -> dt.datetime:
        """Instant de référence, calculé **une fois** par réponse.

        Sans cette mise en cache, une liste de vingt restaurants appellerait
        vingt fois `timezone.now()` et pourrait, à la seconde près, se retrouver
        à cheval sur une ouverture — deux établissements de la même ville
        rendus dans deux états contradictoires.
        """
        now: dt.datetime = self.context.setdefault("now", timezone.now())
        return now

    def get_is_open(self, obj: Restaurant) -> bool:
        return obj.is_open_at(self._now())

    def get_can_order_now(self, obj: Restaurant) -> bool:
        return obj.is_active and obj.accepts_orders and obj.is_open_at(self._now())

    def get_distance_m(self, obj: Restaurant) -> float | None:
        distance = getattr(obj, "distance", None)
        return round(distance.m, 1) if distance is not None else None


class RestaurantDetailSerializer(RestaurantSerializer):
    opening_hours = OpeningHoursSerializer(many=True, read_only=True)

    class Meta(RestaurantSerializer.Meta):
        fields = [*RestaurantSerializer.Meta.fields, "email", "opening_hours"]
        read_only_fields = fields


class NearbyQuerySerializer(serializers.Serializer[Any]):
    """Point de référence facultatif de `GET /restaurants/`.

    Les deux coordonnées vont ensemble : une latitude seule ne situe rien, et
    l'accepter en silence produirait un tri par proximité à une dimension —
    faux, mais plausible à la lecture.
    """

    lat = serializers.FloatField(min_value=-90, max_value=90, required=False)
    lon = serializers.FloatField(min_value=-180, max_value=180, required=False)

    def validate(self, attrs: dict[str, float]) -> dict[str, float]:
        if ("lat" in attrs) != ("lon" in attrs):
            raise serializers.ValidationError("lat et lon se fournissent ensemble.")
        return attrs
