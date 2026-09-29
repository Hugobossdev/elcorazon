"""Gestes HTTP du cycle de vie d'une zone — partagés par les deux routes de zones.

`ManagedDeliveryZoneViewSet` (zones de ville, le siège) et
`ManagedRestaurantZoneViewSet` (zones propres, le gérant) exposent les mêmes
gestes aux mêmes adresses relatives. Seul change **qui a le droit** : chaque
vue le dit dans `check_zone_write`, et ce mixin ne décide rien d'autre.

    POST …/{id}/submit/            brouillon → en revue
    POST …/{id}/return-to-draft/   en revue → brouillon
    POST …/{id}/publish/           en revue → publiée
    POST …/{id}/suspend/           publiée → suspendue   (motif obligatoire)
    POST …/{id}/activate/          suspendue → publiée
    POST …/{id}/archive/           → archivée (terminal)
    POST …/{id}/duplicate/         copie en brouillon
    GET|PUT …/{id}/schedule/       plages hebdomadaires
    POST …/{id}/exceptions/        fermeture / ouverture exceptionnelle
    DELETE …/{id}/exceptions/{exception_id}/
"""

from __future__ import annotations

from typing import Any

from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.decorators import action
from rest_framework.request import Request
from rest_framework.response import Response

from apps.geography.lifecycle import (
    SlotInput,
    add_zone_exception,
    duplicate_zone,
    remove_zone_exception,
    replace_zone_hours,
    transition_zone,
)
from apps.geography.models import DeliveryZone
from apps.geography.serializers import (
    ZoneDuplicateSerializer,
    ZoneExceptionSerializer,
    ZoneHoursSerializer,
    ZoneTransitionSerializer,
)
from apps.geography.states import ZoneStatus
from common.exceptions import BusinessRuleViolation
from common.permissions import authenticated_user

__all__ = ["ZoneLifecycleMixin"]


class ZoneLifecycleMixin:
    """À mêler à un `GenericViewSet[DeliveryZone]` qui définit `check_zone_write`."""

    # Fournis par le viewset hôte.
    request: Any
    get_object: Any
    get_serializer: Any

    def check_zone_write(self, zone: DeliveryZone) -> None:  # pragma: no cover - abstrait
        raise NotImplementedError

    # --------------------------------------------------------- écriture de fiche

    def save_new_zone(self, serializer: Any, **extra: Any) -> DeliveryZone:
        """Toute zone née au back-office naît **en brouillon**.

        `is_active` envoyé à la création est ignoré : publier est un geste, qui
        passe par la revue. Le brouillon ne tarife rien, et ne se voit pas.
        """
        acteur = authenticated_user(self.request)
        serializer.validated_data.pop("is_active", None)
        zone: DeliveryZone = serializer.save(
            status=ZoneStatus.DRAFT, created_by=acteur, updated_by=acteur, **extra
        )
        return zone

    def save_zone_changes(self, serializer: Any) -> DeliveryZone:
        """Enregistre la fiche, puis traduit l'ancien `is_active` en geste.

        `false` suspend une zone publiée, `true` réactive une zone suspendue ;
        tout autre passage est refusé par la machine à états, comme par les
        gestes eux-mêmes — jamais écrit en contournant la transition.
        """
        acteur = authenticated_user(self.request)
        souhait = serializer.validated_data.pop("is_active", None)
        zone: DeliveryZone = serializer.save(updated_by=acteur)
        if souhait is not None and souhait != zone.is_active:
            cible = ZoneStatus.PUBLISHED if souhait else ZoneStatus.SUSPENDED
            if souhait and zone.status != ZoneStatus.SUSPENDED:
                raise BusinessRuleViolation(
                    "Seule une zone suspendue se réactive ; un brouillon se soumet puis se publie.",
                    current_status=zone.status,
                )
            zone = transition_zone(
                zone,
                cible,
                actor=acteur,
                reason="" if souhait else "Désactivée depuis la fiche de la zone.",
            )
            serializer.instance = zone
        return zone

    # --------------------------------------------------------------- transitions

    def _transition(self, request: Request, cible: str) -> Response:
        zone = self.get_object()
        self.check_zone_write(zone)
        corps = ZoneTransitionSerializer(data=request.data)
        corps.is_valid(raise_exception=True)
        zone = transition_zone(
            zone,
            cible,
            actor=authenticated_user(request),
            reason=corps.validated_data["reason"],
            expected_end_at=corps.validated_data["expected_end_at"],
        )
        return Response(self.get_serializer(zone).data)

    @extend_schema(request=ZoneTransitionSerializer, tags=["geography"])
    @action(detail=True, methods=["post"])
    def submit(self, request: Request, pk: Any = None) -> Response:
        return self._transition(request, ZoneStatus.PENDING_REVIEW)

    @extend_schema(request=ZoneTransitionSerializer, tags=["geography"])
    @action(detail=True, methods=["post"], url_path="return-to-draft")
    def return_to_draft(self, request: Request, pk: Any = None) -> Response:
        return self._transition(request, ZoneStatus.DRAFT)

    @extend_schema(request=ZoneTransitionSerializer, tags=["geography"])
    @action(detail=True, methods=["post"])
    def publish(self, request: Request, pk: Any = None) -> Response:
        return self._transition(request, ZoneStatus.PUBLISHED)

    @extend_schema(request=ZoneTransitionSerializer, tags=["geography"])
    @action(detail=True, methods=["post"])
    def suspend(self, request: Request, pk: Any = None) -> Response:
        return self._transition(request, ZoneStatus.SUSPENDED)

    @extend_schema(request=ZoneTransitionSerializer, tags=["geography"])
    @action(detail=True, methods=["post"])
    def activate(self, request: Request, pk: Any = None) -> Response:
        zone = self.get_object()
        if zone.status not in (ZoneStatus.SUSPENDED, ZoneStatus.PUBLISHED):
            # « Activer » est la réouverture d'une zone suspendue ; publier un
            # brouillon passe par la revue, avec `publish`.
            raise BusinessRuleViolation(
                "Seule une zone suspendue se réactive ; un brouillon se soumet puis se publie.",
                current_status=zone.status,
            )
        return self._transition(request, ZoneStatus.PUBLISHED)

    @extend_schema(request=ZoneTransitionSerializer, tags=["geography"])
    @action(detail=True, methods=["post"])
    def archive(self, request: Request, pk: Any = None) -> Response:
        return self._transition(request, ZoneStatus.ARCHIVED)

    # ---------------------------------------------------------------- duplication

    @extend_schema(request=ZoneDuplicateSerializer, tags=["geography"])
    @action(detail=True, methods=["post"])
    def duplicate(self, request: Request, pk: Any = None) -> Response:
        zone = self.get_object()
        self.check_zone_write(zone)
        corps = ZoneDuplicateSerializer(data=request.data)
        corps.is_valid(raise_exception=True)
        copie = duplicate_zone(
            zone, actor=authenticated_user(request), name=corps.validated_data["name"]
        )
        return Response(self.get_serializer(copie).data, status=status.HTTP_201_CREATED)

    # ------------------------------------------------------------------ horaires

    @extend_schema(methods=["GET"], responses={200: ZoneHoursSerializer}, tags=["geography"])
    @extend_schema(
        methods=["PUT"],
        request=ZoneHoursSerializer,
        responses={200: ZoneHoursSerializer},
        tags=["geography"],
    )
    @action(detail=True, methods=["get", "put"])
    def schedule(self, request: Request, pk: Any = None) -> Response:
        zone = self.get_object()
        if request.method == "PUT":
            self.check_zone_write(zone)
            corps = ZoneHoursSerializer(data=request.data)
            corps.is_valid(raise_exception=True)
            zone = replace_zone_hours(
                zone,
                [SlotInput(**plage) for plage in corps.validated_data["hours"]],
                actor=authenticated_user(request),
            )
        return Response(ZoneHoursSerializer({"hours": zone.opening_hours.all()}).data)

    @extend_schema(
        request=ZoneExceptionSerializer,
        responses={201: ZoneExceptionSerializer},
        tags=["geography"],
    )
    @action(detail=True, methods=["post"])
    def exceptions(self, request: Request, pk: Any = None) -> Response:
        zone = self.get_object()
        self.check_zone_write(zone)
        corps = ZoneExceptionSerializer(data=request.data)
        corps.is_valid(raise_exception=True)
        exception = add_zone_exception(
            zone, actor=authenticated_user(request), **corps.validated_data
        )
        return Response(ZoneExceptionSerializer(exception).data, status=status.HTTP_201_CREATED)

    @extend_schema(responses={204: None}, tags=["geography"])
    @action(
        detail=True,
        methods=["delete"],
        url_path=r"exceptions/(?P<exception_id>[0-9a-f-]{36})",
    )
    def remove_exception(
        self, request: Request, pk: Any = None, exception_id: str | None = None
    ) -> Response:
        zone = self.get_object()
        self.check_zone_write(zone)
        get_object_or_404(zone.exceptions.all(), pk=exception_id)
        remove_zone_exception(zone, exception_id, actor=authenticated_user(request))
        return Response(status=status.HTTP_204_NO_CONTENT)
