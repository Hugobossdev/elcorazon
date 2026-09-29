"""« Tester une adresse » — le diagnostic de couverture du back-office.

## Pourquoi ici

La réponse assemble quatre domaines : la géographie (quelle zone, et
pourquoi), les cuisines (laquelle, dans quel état), le barème (combien), et la
flotte (qui peut rouler). `delivery` est le seul qui ait le droit de les
connaître tous (ADR-002) — `restaurants` ignore les livreurs.

## Ce que ce module ne fait pas

Il ne décide **rien**. La zone vient de `explain_resolution`, la cuisine, la
distance et les frais de `check_delivery` — la fonction même qu'appelle la
création de commande —, l'éligibilité des livreurs de
`CourierService.eligible_couriers`, celle du dispatch. L'outil montre donc ce
que la commande ferait, et ne peut pas en diverger.

    POST /delivery/coverage-test/           diagnostic d'un point
    GET  /delivery/zones/{id}/kitchens/     cuisines qui livrent la zone
    GET  /delivery/zones/{id}/couriers/     livreurs, éligibles ou non, et pourquoi
"""

from __future__ import annotations

import logging
from typing import Any

from django.contrib.gis.db.models.functions import Distance
from django.contrib.gis.geos import Point
from django.shortcuts import get_object_or_404
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema
from rest_framework import serializers
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import User
from apps.delivery.services import CourierService
from apps.geography.models import DeliveryZone
from apps.geography.states import ZoneStatus
from apps.orders.models import Order
from apps.orders.states import OrderStatus
from apps.restaurants.availability import kitchen_unavailability
from apps.restaurants.delivery import check_delivery
from apps.restaurants.models import Restaurant
from apps.restaurants.scoping import staff_restaurant_ids
from common.permissions import HasPermission, authenticated_user, is_unscoped
from common.serializers import MoneyField

__all__ = ["CoverageTestView", "ZoneCouriersView", "ZoneKitchensView"]

logger = logging.getLogger(__name__)

#: Ce qui occupe une cuisine — la définition retenue pour la capacité (lot 4) :
#: une commande compte dès `pending`, jusqu'à la sortie de cuisine.
_EN_CUISINE = (OrderStatus.PENDING, OrderStatus.CONFIRMED, OrderStatus.PREPARING)


class CoverageQuerySerializer(serializers.Serializer[Any]):
    lat = serializers.FloatField(min_value=-90, max_value=90)
    lon = serializers.FloatField(min_value=-180, max_value=180)
    subtotal = MoneyField(required=False, allow_null=True)
    restaurant = serializers.SlugField(required=False, allow_blank=True)
    at = serializers.DateTimeField(required=False, allow_null=True)


def _peut_voir(user: User, restaurant: Restaurant) -> bool:
    return is_unscoped(user) or restaurant.pk in staff_restaurant_ids(user)


def _zone_breve(zone: DeliveryZone) -> dict[str, Any]:
    return {
        "id": str(zone.pk),
        "name": zone.name,
        "status": zone.status,
        "priority": zone.priority,
        "city": zone.city.name,
        "restaurant": zone.restaurant.slug if zone.restaurant is not None else None,
    }


def _livreurs(restaurant: Restaurant, zone_id: Any) -> list[dict[str, Any]]:
    return [
        {
            "id": str(livreur.pk),
            "name": livreur.user.full_name,
            "is_online": livreur.is_online,
            "eligible": motif is None,
            "reason": motif,
        }
        for livreur, motif in CourierService.explain_eligibility(restaurant, zone_id)
    ]


def _charge(restaurant: Restaurant) -> int:
    return Order.objects.filter(restaurant=restaurant, status__in=_EN_CUISINE).count()


def _argent(montant: Any) -> dict[str, str] | None:
    return MoneyField().to_representation(montant) if montant is not None else None


class CoverageTestView(APIView):
    """`POST /delivery/coverage-test/` — ce que la commande ferait, à cette adresse."""

    permission_classes = (HasPermission.of("restaurants.read"),)

    @extend_schema(
        request=CoverageQuerySerializer, responses={200: OpenApiTypes.OBJECT}, tags=["delivery"]
    )
    def post(self, request: Request) -> Response:
        corps = CoverageQuerySerializer(data=request.data)
        corps.is_valid(raise_exception=True)
        donnees = corps.validated_data
        user = authenticated_user(request)
        point = Point(donnees["lon"], donnees["lat"], srid=4326)

        cuisine = None
        if donnees.get("restaurant"):
            cuisine = get_object_or_404(Restaurant, slug=donnees["restaurant"])

        verdict = check_delivery(
            point=point,
            restaurant=cuisine,
            subtotal=donnees.get("subtotal"),
            at=donnees.get("at"),
        )
        resolution = verdict.resolution
        zone = verdict.zone
        restaurant = verdict.restaurant
        quote = verdict.quote

        reponse: dict[str, Any] = {
            "point": {"lat": donnees["lat"], "lon": donnees["lon"]},
            "available": verdict.is_available,
            "unavailable_code": verdict.unavailable_code,
            "reason": verdict.reason,
            "zone": _zone_breve(zone) if zone is not None else None,
            "selection_reason": resolution.reason if resolution is not None else None,
            "candidates": [
                {
                    **_zone_breve(c.zone),
                    "surface_km2": round(c.surface_m2 / 1_000_000, 3),
                    "rank": c.rank,
                    "excluded_because": c.excluded_because,
                    "reopens_at": c.reopens_at.isoformat() if c.reopens_at else None,
                }
                for c in (resolution.candidates if resolution is not None else [])
            ],
            "country": zone.city.country.iso_code if zone is not None else None,
            "city": zone.city.name if zone is not None else None,
            "kitchen": None,
            "distance_m": round(verdict.distance_m) if verdict.distance_m is not None else None,
            "delivery_fee": _argent(quote.fee) if quote is not None else None,
            "gross_fee": _argent(quote.gross_fee) if quote is not None else None,
            "is_free": quote.is_free if quote is not None else None,
            "estimated_minutes": verdict.estimated_minutes,
            "min_order_amount": _argent(zone.min_order_amount) if zone is not None else None,
            "free_delivery_threshold": (
                _argent(zone.free_delivery_threshold) if zone is not None else None
            ),
            "couriers": None,
            "nearest_zone": None if zone is not None else _zone_la_plus_proche(point),
        }
        if restaurant is not None:
            refus = kitchen_unavailability(restaurant)
            reponse["kitchen"] = {
                "slug": restaurant.slug,
                "name": restaurant.name,
                "status": restaurant.status,
                "can_order_now": refus is None,
                "unavailable_code": str(refus.code) if refus is not None else None,
                "active_orders": _charge(restaurant),
            }
            if user.has_permission("couriers.read") and _peut_voir(user, restaurant):
                reponse["couriers"] = _livreurs(restaurant, zone.pk if zone else None)

        logger.info(
            "coverage_test",
            extra={
                "zone": str(zone.pk) if zone is not None else None,
                "kitchen": restaurant.slug if restaurant is not None else None,
                "available": verdict.is_available,
                "code": verdict.unavailable_code,
            },
        )
        return Response(reponse)


def _zone_la_plus_proche(point: Point) -> dict[str, Any] | None:
    """La zone publiée la plus proche d'un point non couvert — et à quelle distance."""
    proche = (
        DeliveryZone.objects.filter(
            status=ZoneStatus.PUBLISHED, city__is_active=True, city__country__is_active=True
        )
        .select_related("city", "restaurant")
        .annotate(vers=Distance("boundary", point))
        .order_by("vers", "pk")
        .first()
    )
    if proche is None:
        return None
    return {**_zone_breve(proche), "distance_m": round(proche.vers.m)}


def _cuisines_de(zone: DeliveryZone) -> list[Restaurant]:
    """Les cuisines que cette zone fait livrer — la règle de `_desservantes`.

    Zone propre : sa cuisine. Zone de ville : les cuisines **de cette ville**.
    """
    cuisines = Restaurant.objects.select_related("zone__city__country").annotate(
        vers=Distance("location", zone.boundary)
    )
    if zone.restaurant_id is not None:
        return list(cuisines.filter(pk=zone.restaurant_id))
    return list(cuisines.filter(zone__city_id=zone.city_id).order_by("vers", "name"))


class ZoneKitchensView(APIView):
    """`GET /delivery/zones/{id}/kitchens/` — qui livre cette zone, et dans quel état."""

    permission_classes = (HasPermission.of("restaurants.read"),)

    @extend_schema(responses={200: OpenApiTypes.OBJECT}, tags=["delivery"])
    def get(self, request: Request, zone_id: str) -> Response:
        zone = get_object_or_404(
            DeliveryZone.objects.select_related("city__country", "restaurant"), pk=zone_id
        )
        user = authenticated_user(request)
        lignes = []
        for cuisine in _cuisines_de(zone):
            if not _peut_voir(user, cuisine):
                continue
            refus = kitchen_unavailability(cuisine)
            lignes.append(
                {
                    "slug": cuisine.slug,
                    "name": cuisine.name,
                    "status": cuisine.status,
                    "city": cuisine.zone.city.name,
                    "can_order_now": refus is None,
                    "unavailable_code": str(refus.code) if refus is not None else None,
                    # Zéro quand la cuisine est dans la zone.
                    "distance_m": round(getattr(cuisine, "vers").m),  # noqa: B009
                    "active_orders": _charge(cuisine),
                }
            )
        return Response(
            {
                "zone": _zone_breve(zone),
                "country": zone.city.country.iso_code,
                "rule": "own" if zone.restaurant_id else "city",
                "kitchens": lignes,
            }
        )


class ZoneCouriersView(APIView):
    """`GET /delivery/zones/{id}/couriers/` — la flotte vue depuis une zone."""

    permission_classes = (HasPermission.of("couriers.read"),)

    @extend_schema(responses={200: OpenApiTypes.OBJECT}, tags=["delivery"])
    def get(self, request: Request, zone_id: str) -> Response:
        zone = get_object_or_404(DeliveryZone, pk=zone_id)
        user = authenticated_user(request)
        return Response(
            {
                "zone": str(zone.pk),
                "kitchens": [
                    {
                        "kitchen": cuisine.slug,
                        "name": cuisine.name,
                        "couriers": _livreurs(cuisine, zone.pk),
                    }
                    for cuisine in _cuisines_de(zone)
                    if _peut_voir(user, cuisine)
                ],
            }
        )
