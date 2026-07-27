"""Rapports agrégés — lecture seule, jamais de table dédiée.

Chaque rapport interroge directement les commandes, leurs lignes ou les
courses : ce sont elles la source de vérité du chiffre d'affaires, du produit
qui se vend et du livreur qui livre. Les recalculer à la demande coûte une
requête d'agrégation ; les dupliquer dans des tables de reporting coûterait un
second endroit où « le chiffre d'affaires » peut ne plus être le même chiffre
que celui des commandes.

Bornés en dates : un rapport sans fenêtre finirait par agréger toute la vie de
la plateforme à chaque appel, de plus en plus lentement à mesure qu'elle
grandit.
"""

from __future__ import annotations

import datetime as dt
from dataclasses import dataclass

from django.db.models import Count, Sum
from django.db.models.functions import TruncDate

from apps.delivery.models import Assignment
from apps.delivery.states import DeliveryStatus
from apps.orders.models import Order, OrderLine
from apps.orders.states import OrderStatus

__all__ = [
    "CourierPerformanceRow",
    "ReportingService",
    "RevenueRow",
    "TopProductRow",
]


@dataclass(frozen=True, slots=True)
class RevenueRow:
    day: dt.date
    orders_count: int
    revenue_minor: int


@dataclass(frozen=True, slots=True)
class TopProductRow:
    menu_item_id: str
    item_name: str
    quantity_sold: int
    revenue_minor: int


@dataclass(frozen=True, slots=True)
class CourierPerformanceRow:
    courier_id: str
    courier_name: str
    deliveries: int
    earnings_minor: int


class ReportingService:
    @staticmethod
    def revenue_by_day(*, start: dt.date, end: dt.date) -> list[RevenueRow]:
        rows = (
            Order.objects.filter(
                status=OrderStatus.DELIVERED, delivered_at__date__range=(start, end)
            )
            .annotate(day=TruncDate("delivered_at"))
            .values("day")
            .annotate(orders_count=Count("id"), revenue_minor=Sum("total_minor"))
            .order_by("day")
        )
        return [
            RevenueRow(
                day=row["day"], orders_count=row["orders_count"], revenue_minor=row["revenue_minor"]
            )
            for row in rows
        ]

    @staticmethod
    def top_products(*, start: dt.date, end: dt.date, limit: int = 10) -> list[TopProductRow]:
        rows = (
            OrderLine.objects.filter(
                order__status=OrderStatus.DELIVERED,
                order__delivered_at__date__range=(start, end),
            )
            .values("menu_item_id", "item_name")
            .annotate(quantity_sold=Sum("quantity"), revenue_minor=Sum("line_total_minor"))
            .order_by("-quantity_sold")[:limit]
        )
        return [
            TopProductRow(
                menu_item_id=str(row["menu_item_id"]),
                item_name=row["item_name"],
                quantity_sold=row["quantity_sold"],
                revenue_minor=row["revenue_minor"],
            )
            for row in rows
        ]

    @staticmethod
    def courier_performance(*, start: dt.date, end: dt.date) -> list[CourierPerformanceRow]:
        rows = (
            Assignment.objects.filter(
                status=DeliveryStatus.DELIVERED, delivered_at__date__range=(start, end)
            )
            .values("courier_id", "courier__user__full_name")
            .annotate(deliveries=Count("id"), earnings_minor=Sum("courier_fee_minor"))
            .order_by("-deliveries")
        )
        return [
            CourierPerformanceRow(
                courier_id=str(row["courier_id"]),
                courier_name=row["courier__user__full_name"],
                deliveries=row["deliveries"],
                earnings_minor=row["earnings_minor"] or 0,
            )
            for row in rows
        ]
