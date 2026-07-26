"""Points d'entrée des commandes.

Deux publics sur les mêmes objets, séparés par le `get_queryset` :

* le **client** ne voit que ses commandes, et n'a qu'un verbe d'écriture —
  annuler, et seulement tant que la cuisine n'a pas démarré ;
* le **personnel** voit celles de l'établissement et fait avancer le statut,
  sous permission nommée (`orders.update_status`).

L'appartenance est un filtre de requête et non une permission d'objet : une
commande d'autrui est introuvable, pas interdite. Un 403 confirmerait au
demandeur que la référence qu'il a devinée existe.
"""

from __future__ import annotations

from django.db.models import QuerySet
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import status
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.mixins import ListModelMixin, RetrieveModelMixin
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.serializers import BaseSerializer
from rest_framework.throttling import BaseThrottle
from rest_framework.viewsets import GenericViewSet

from apps.accounts.models import UserType
from apps.carts.services import CartService
from apps.orders.idempotency import complete, release, reserve
from apps.orders.models import Order
from apps.orders.serializers import (
    CancelSerializer,
    OrderCreateSerializer,
    OrderDetailSerializer,
    OrderPreviewSerializer,
    OrderQuoteSerializer,
    OrderSerializer,
    StatusTransitionSerializer,
)
from apps.orders.services import OrderService
from apps.restaurants.scoping import is_unscoped, staff_restaurant_ids
from common.permissions import HasPermission, IsCustomer, authenticated_user
from common.throttling import OrderCreationThrottle

__all__ = ["OrderViewSet"]

CREATE_ENDPOINT = "POST /api/v1/orders/"
IDEMPOTENCY_HEADER = "Idempotency-Key"


class OrderViewSet(ListModelMixin, RetrieveModelMixin, GenericViewSet[Order]):
    # Déclaré pour le générateur de schéma seulement — voir `get_queryset`.
    queryset = Order.objects.none()
    filterset_fields = {"status": ["exact"], "restaurant__slug": ["exact"]}

    def get_serializer_class(self) -> type[BaseSerializer[Order]]:
        return OrderDetailSerializer if self.action == "retrieve" else OrderSerializer

    def get_throttles(self) -> list[BaseThrottle]:
        """Quota resserré sur la seule création.

        Consulter son historique est bon marché ; passer commande verrouille,
        relit le catalogue, interroge PostGIS et écrit une dizaine de lignes.
        Appliquer le même quota aux deux reviendrait à choisir entre gêner la
        lecture et laisser l'écriture ouverte.
        """
        if self.action == "create":
            return [OrderCreationThrottle()]
        return super().get_throttles()

    def get_queryset(self) -> QuerySet[Order]:
        user = authenticated_user(self.request)
        queryset = Order.objects.select_related("restaurant").order_by("-placed_at")

        if user.user_type == UserType.COURIER:
            # Le livreur voit les commandes qu'on lui a confiées, et rien
            # d'autre : ni l'historique du client, ni les courses de ses
            # collègues.
            queryset = queryset.filter(assignments__courier__user=user).distinct()
        elif user.user_type == UserType.STAFF and not is_unscoped(user):
            queryset = queryset.filter(restaurant_id__in=staff_restaurant_ids(user))
        elif user.user_type != UserType.STAFF:
            queryset = queryset.filter(customer=user)

        if self.action == "retrieve":
            queryset = queryset.prefetch_related("lines__menu_item", "status_events")
        return queryset

    # ---------------------------------------------------------------- client

    @extend_schema(
        request=OrderCreateSerializer,
        responses={201: OrderDetailSerializer},
        parameters=[
            OpenApiParameter(
                name=IDEMPOTENCY_HEADER,
                location=OpenApiParameter.HEADER,
                required=True,
                description=(
                    "Clé tirée par le client, stable sur une même tentative de commande. "
                    "Un rejeu renvoie la réponse d'origine au lieu de créer une seconde "
                    "commande."
                ),
            )
        ],
        tags=["orders"],
    )
    def create(self, request: Request, *args: object, **kwargs: object) -> Response:
        key = request.headers.get(IDEMPOTENCY_HEADER, "").strip()
        if not key:
            # Exigée et non facultative : rendue optionnelle, elle serait
            # omise par le client le jour où le réseau coupe — c'est-à-dire le
            # seul jour où elle sert.
            raise ValidationError({IDEMPOTENCY_HEADER: "En-tête obligatoire sur cette route."})

        user = authenticated_user(request)

        # La clé est prise **avant** toute écriture. Créer la commande d'abord
        # laisserait deux requêtes simultanées en créer chacune une, et la
        # perdante abandonnerait la sienne en base — orpheline et impayée.
        deja = reserve(user=user, endpoint=CREATE_ENDPOINT, key=key)
        if deja is not None:
            return Response(deja.body, status=deja.status)

        try:
            serializer = OrderCreateSerializer(data=request.data, context={"request": request})
            serializer.is_valid(raise_exception=True)

            restaurant = serializer.validated_data.pop("restaurant")
            cart = CartService.cart_for(user, restaurant)
            order = OrderService.create_from_cart(user=user, cart=cart, **serializer.validated_data)
        except Exception:
            # Panier vide, adresse hors zone, validation refusée : la clé n'a
            # rien produit, elle doit redevenir libre. La garder bloquerait le
            # client qui corrige son panier et réessaie avec la même clé.
            release(user=user, endpoint=CREATE_ENDPOINT, key=key)
            raise

        body = OrderDetailSerializer(order).data
        stored = complete(
            user=user,
            endpoint=CREATE_ENDPOINT,
            key=key,
            order=order,
            status=status.HTTP_201_CREATED,
            body=body,
        )
        return Response(stored.body, status=stored.status)

    @extend_schema(
        request=OrderPreviewSerializer, responses={200: OrderQuoteSerializer}, tags=["orders"]
    )
    @action(detail=False, methods=["post"], permission_classes=[IsCustomer])
    def preview(self, request: Request) -> Response:
        """Combien coûterait ma commande, avec ce code ?

        Le client voit le détail avant de s'engager, et découvre un code refusé
        **là** plutôt qu'au moment où il appuie sur « commander ». Rien n'est
        réservé : le quota ne se décompte qu'à la création.
        """
        serializer = OrderPreviewSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)

        devis = OrderService.preview(user=authenticated_user(request), **serializer.validated_data)
        return Response(OrderQuoteSerializer(devis).data)

    @extend_schema(
        request=CancelSerializer, responses={200: OrderDetailSerializer}, tags=["orders"]
    )
    @action(detail=True, methods=["post"])
    def cancel(self, request: Request, pk: str) -> Response:
        serializer = CancelSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        order = OrderService.cancel_by_customer(
            order=self.get_object(),
            user=authenticated_user(request),
            reason=serializer.validated_data["reason"],
        )
        return Response(OrderDetailSerializer(order).data)

    # -------------------------------------------------------------- personnel

    @extend_schema(
        request=StatusTransitionSerializer,
        responses={200: OrderDetailSerializer},
        tags=["orders"],
    )
    @action(
        detail=True,
        methods=["post"],
        url_path="status",
        url_name="status",
        permission_classes=[HasPermission.of("orders.update_status")],
    )
    def update_status(self, request: Request, pk: str) -> Response:
        """Avance le statut — réservé au personnel muni de la permission.

        Aucune vérification de flux ici : la machine à états décide, et une
        transition refusée sort en 409 avec les cibles autorisées, ce qui
        permet au back-office d'afficher les boutons justes.
        """
        serializer = StatusTransitionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        order = OrderService.transition_to(
            order=self.get_object(),
            target=serializer.validated_data["status"],
            actor=authenticated_user(request),
            reason=serializer.validated_data["reason"],
        )
        return Response(OrderDetailSerializer(order).data)
