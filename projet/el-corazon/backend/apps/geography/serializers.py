"""Contrats de la géographie — ADR-006, ADR-009.

Lecture seule côté client : la hiérarchie est administrée par le back-office.
Le contour des zones (`boundary`) n'est **jamais** exposé — c'est un
`MultiPolygon` de plusieurs kilo-octets qu'aucun écran n'affiche, et le client
n'a pas à savoir *où* passe la frontière : il demande si son point est
desservi, la base répond.
"""

from __future__ import annotations

from typing import Any

from rest_framework import serializers

from apps.geography.models import City, Country, DeliveryZone
from common.serializers import LocationField, MoneyField

__all__ = [
    "CitySerializer",
    "CountrySerializer",
    "DeliveryZoneSerializer",
    "ZoneResolutionQuerySerializer",
    "ZoneResolutionSerializer",
]


class CountrySerializer(serializers.ModelSerializer[Country]):
    class Meta:
        model = Country
        fields = [
            "id",
            "iso_code",
            "name",
            "currency",
            "phone_prefix",
            "timezone",
            "default_language",
        ]
        read_only_fields = fields


class CitySerializer(serializers.ModelSerializer[City]):
    # Le pays est imbriqué plutôt que référencé : sans lui le client ne connaît
    # pas la devise, et il ne peut donc pas formater un seul prix sans un
    # second appel.
    country = CountrySerializer(read_only=True)
    centroid = LocationField(read_only=True)

    class Meta:
        model = City
        fields = ["id", "name", "slug", "country", "centroid"]
        read_only_fields = fields


class DeliveryZoneSerializer(serializers.ModelSerializer[DeliveryZone]):
    city = CitySerializer(read_only=True)
    base_fee = MoneyField(read_only=True)
    fee_per_km = MoneyField(read_only=True)
    free_delivery_threshold = MoneyField(read_only=True)
    min_order_amount = MoneyField(read_only=True)

    class Meta:
        model = DeliveryZone
        fields = [
            "id",
            "name",
            "city",
            "base_fee",
            "fee_per_km",
            "free_delivery_threshold",
            "min_order_amount",
            "max_distance_km",
            "estimated_delivery_minutes",
        ]
        read_only_fields = fields


class ZoneResolutionQuerySerializer(serializers.Serializer[Any]):
    """Paramètres de `GET /geography/zones/resolve/`.

    Déclarés en sérialiseur plutôt que lus à la main : la validation des bornes
    est faite une fois, et `drf-spectacular` documente les paramètres depuis
    cette classe au lieu d'une annotation manuelle qui se périme.
    """

    lat = serializers.FloatField(min_value=-90, max_value=90)
    lon = serializers.FloatField(min_value=-180, max_value=180)


class ZoneResolutionSerializer(serializers.Serializer[Any]):
    """Réponse de la résolution.

    `is_covered` est redondant avec `zone is not null` — délibérément. Le
    booléen est ce que le client teste, et il reste juste si la réponse gagne
    un jour un cas « couvert mais momentanément suspendu ».
    """

    is_covered = serializers.BooleanField(read_only=True)
    zone = DeliveryZoneSerializer(read_only=True, allow_null=True)
