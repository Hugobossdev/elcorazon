"""Points d'entrée de l'analytics.

`EventIngestView` est ouverte à tout compte authentifié — client ou livreur —
puisque les deux émettent des événements d'usage. Les rapports, eux, exigent
`analytics.read` : ce sont des chiffres d'exploitation, pas une donnée
personnelle du client qui appelle.
"""

from __future__ import annotations

import datetime as dt

from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.analytics.reports import ReportingService
from apps.analytics.serializers import (
    CourierPerformanceRowSerializer,
    EventWriteSerializer,
    ReportQuerySerializer,
    RevenueRowSerializer,
    TopProductRowSerializer,
)
from apps.analytics.services import AnalyticsService
from common.permissions import HasPermission, active_user

__all__ = [
    "CourierPerformanceReportView",
    "EventIngestView",
    "RevenueReportView",
    "TopProductsReportView",
]


class EventIngestView(APIView):
    """`POST /analytics/events/` — consigne un événement d'usage.

    Toujours 201 : refuser un événement mal formé n'aiderait ni le client ni
    l'exploitation, et un `event_type` inconnu d'aujourd'hui est peut-être le
    tableau de bord de demain — le fermer à la validation empêcherait de
    l'ajouter sans redéployer le serveur.
    """

    @extend_schema(request=EventWriteSerializer, responses={201: None}, tags=["analytics"])
    def post(self, request: Request) -> Response:
        serializer = EventWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        AnalyticsService.record(
            user=active_user(request),
            event_type=serializer.validated_data["event_type"],
            data=serializer.validated_data["event_data"],
            session_id=serializer.validated_data["session_id"],
        )
        return Response(status=status.HTTP_201_CREATED)


def _period(request: Request) -> tuple[dt.date, dt.date, int]:
    query = ReportQuerySerializer(data=request.query_params)
    query.is_valid(raise_exception=True)
    return query.validated_data["start"], query.validated_data["end"], query.validated_data["limit"]


class RevenueReportView(APIView):
    """`GET /analytics/reports/revenue/?start=&end=` — chiffre d'affaires par jour."""

    permission_classes = [HasPermission.of("analytics.read")]

    @extend_schema(responses={200: RevenueRowSerializer(many=True)}, tags=["analytics"])
    def get(self, request: Request) -> Response:
        start, end, _ = _period(request)
        rows = ReportingService.revenue_by_day(start=start, end=end)
        return Response(RevenueRowSerializer(rows, many=True).data)


class TopProductsReportView(APIView):
    """`GET /analytics/reports/top-products/?start=&end=&limit=` — articles les plus vendus."""

    permission_classes = [HasPermission.of("analytics.read")]

    @extend_schema(responses={200: TopProductRowSerializer(many=True)}, tags=["analytics"])
    def get(self, request: Request) -> Response:
        start, end, limit = _period(request)
        rows = ReportingService.top_products(start=start, end=end, limit=limit)
        return Response(TopProductRowSerializer(rows, many=True).data)


class CourierPerformanceReportView(APIView):
    """`GET /analytics/reports/couriers/?start=&end=` — livraisons et gains par livreur."""

    permission_classes = [HasPermission.of("analytics.read")]

    @extend_schema(responses={200: CourierPerformanceRowSerializer(many=True)}, tags=["analytics"])
    def get(self, request: Request) -> Response:
        start, end, _ = _period(request)
        rows = ReportingService.courier_performance(start=start, end=end)
        return Response(CourierPerformanceRowSerializer(rows, many=True).data)
