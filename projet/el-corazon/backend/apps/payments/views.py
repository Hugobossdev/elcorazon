"""Points d'entrée du paiement.

Trois routes, trois publics : le client initie, le prestataire notifie, le
personnel rembourse. La seule ouverte sans jeton est le webhook — un
prestataire n'a pas de compte utilisateur — et elle est authentifiée par la
signature du corps, ce qui est plus fort qu'un jeton porteur : une signature ne
peut pas être rejouée sur un autre corps.
"""

from __future__ import annotations

import json
from typing import Any

from django.db.models import QuerySet
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import status
from rest_framework.exceptions import AuthenticationFailed, ValidationError
from rest_framework.generics import get_object_or_404
from rest_framework.permissions import AllowAny
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from rest_framework.viewsets import ReadOnlyModelViewSet

from apps.accounts.models import UserType
from apps.orders.models import Order
from apps.payments.gateway import verify_signature
from apps.payments.models import PaymentProvider, Transaction
from apps.payments.serializers import (
    CheckoutSerializer,
    RefundRequestSerializer,
    RefundSerializer,
    TransactionSerializer,
    WebhookSerializer,
)
from apps.payments.services import PaymentService, RefundService
from apps.restaurants.scoping import is_unscoped, staff_restaurant_ids
from common.permissions import HasPermission, IsCustomer, authenticated_user

__all__ = ["InitiatePaymentView", "RefundView", "TransactionViewSet", "WebhookView"]

SIGNATURE_HEADER = "X-Signature"


class TransactionViewSet(ReadOnlyModelViewSet[Transaction]):
    """Historique des encaissements, filtré sur le demandeur."""

    serializer_class = TransactionSerializer
    queryset = Transaction.objects.none()
    filterset_fields = {"order": ["exact"], "status": ["exact"]}

    def get_queryset(self) -> QuerySet[Transaction]:
        user = authenticated_user(self.request)
        queryset = Transaction.objects.select_related("order").order_by("-created_at")
        if user.user_type == UserType.STAFF:
            if is_unscoped(user):
                return queryset
            # Même périmètre que les commandes : un encaissement appartient à
            # l'établissement qui l'a réalisé.
            return queryset.filter(order__restaurant_id__in=staff_restaurant_ids(user))
        # Le client voit les transactions de **ses** commandes, y compris
        # celles qu'un tiers a réglées pour lui — pas seulement celles dont il
        # est le payeur.
        return queryset.filter(order__customer=user)


class InitiatePaymentView(APIView):
    """`POST /payments/{order}/initiate/` — ouvre une demande de paiement."""

    permission_classes = [IsCustomer]

    @extend_schema(request=None, responses={201: CheckoutSerializer}, tags=["payments"])
    def post(self, request: Request, order_id: str) -> Response:
        user = authenticated_user(request)
        order = get_object_or_404(Order, pk=order_id, customer=user)

        txn, instruction = PaymentService.initiate(order=order, payer=user)
        return Response(
            CheckoutSerializer(
                {
                    "transaction": txn,
                    "checkout_url": instruction.checkout_url,
                    "instructions": instruction.instructions,
                }
            ).data,
            status=status.HTTP_201_CREATED,
        )


class WebhookView(APIView):
    """`POST /payments/webhook/{provider}/` — notification du prestataire.

    **Seule source de vérité de l'encaissement** (§6.3). Le retour du client
    sur l'application ne déclenche aucune écriture d'état : c'est ce qui rend
    l'auto-déclaration de paiement impossible plutôt qu'interdite.

    La réponse est un 200 dès que la notification a été **prise en compte**,
    même si elle ne correspond à rien de connu : un prestataire qui reçoit une
    erreur retente, indéfiniment, et finit par saturer la file de l'un comme de
    l'autre. Ce qui n'a pas pu être appliqué est tracé dans `WebhookEvent`.
    """

    permission_classes = [AllowAny]
    authentication_classes: list[type[Any]] = []
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "webhook"

    @extend_schema(
        request=WebhookSerializer,
        responses={200: None},
        parameters=[
            OpenApiParameter(
                name=SIGNATURE_HEADER,
                location=OpenApiParameter.HEADER,
                required=True,
                description="HMAC-SHA256 du corps brut, en hexadécimal.",
            )
        ],
        tags=["payments"],
    )
    def post(self, request: Request, provider: str) -> Response:
        if provider not in PaymentProvider.values:
            raise ValidationError({"provider": f"Prestataire inconnu : {provider}."})

        # Signature d'abord, sur le corps **brut**. Rien n'est enregistré tant
        # qu'elle n'est pas vérifiée, sans quoi n'importe qui remplirait la
        # table des événements en postant du JSON.
        # Le refus sort en 403 et non en 401 : la route ne déclare aucun
        # authentificateur DRF — la signature *est* le justificatif — donc
        # aucun schéma n'est proposé en défi.
        if not verify_signature(
            raw_body=request.body, signature=request.headers.get(SIGNATURE_HEADER, "")
        ):
            raise AuthenticationFailed("Signature invalide.")

        serializer = WebhookSerializer(data=json.loads(request.body or b"{}"))
        serializer.is_valid(raise_exception=True)

        outcome = PaymentService.handle_webhook(
            provider=provider, payload=serializer.validated_data
        )
        return Response({"accepted": outcome.accepted, "detail": outcome.detail})


class RefundView(APIView):
    """`POST /payments/{order}/refund/` — remboursement, réservé au personnel."""

    permission_classes = [HasPermission.of("orders.refund")]

    @extend_schema(
        request=RefundRequestSerializer, responses={201: RefundSerializer}, tags=["payments"]
    )
    def post(self, request: Request, order_id: str) -> Response:
        actor = authenticated_user(request)
        # La permission `orders.refund` dit qu'on sait rembourser ; le
        # rattachement dit sur quelles commandes. Sans ce filtre, un opérateur
        # de Kara rembourserait une commande de Lomé — avec l'argent de Lomé.
        scope = Order.objects.all()
        if not is_unscoped(actor):
            scope = scope.filter(restaurant_id__in=staff_restaurant_ids(actor))
        order = get_object_or_404(scope, pk=order_id)

        serializer = RefundRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        refund = RefundService.refund(
            order=order,
            transaction_id=str(serializer.validated_data["transaction"]),
            amount=serializer.validated_data["amount"],
            reason=serializer.validated_data["reason"],
            actor=actor,
        )
        return Response(RefundSerializer(refund).data, status=status.HTTP_201_CREATED)
