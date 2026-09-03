"""Supervision des commandes — l'API que consomme l'application `admin`.

C'est l'écran devant lequel se passe le service : la liste de ce qui est en
cours, l'avancement d'un statut, l'annulation de ce qui ne partira pas.

Séparé de `views.py` pour la raison qu'énonce `catalog/urls.py` — **un chemin,
un public, une permission**. Les deux publics vivaient jusqu'ici sur les mêmes
routes, distingués par le seul `get_queryset`, et cela avait deux conséquences
qui ne se voyaient pas :

* `orders.read` ne gardait rien. Le registre de l'ADR-005 la déclare, mais
  aucune route ne l'exigeait : tout compte du personnel lisait les commandes de
  son établissement, y compris celui à qui l'on avait précisément refusé ce
  droit. Une permission qui n'est appliquée nulle part est pire qu'absente —
  elle donne le sentiment d'avoir décidé ;
* le verbe d'annulation du client était joignable par le livreur. Son
  `permission_classes` implicite était « authentifié », et le `get_queryset`
  d'alors rendait au livreur les commandes qui lui étaient confiées : il pouvait
  donc annuler la commande qu'il transportait.

Ici, chaque action nomme sa permission, et l'audit statique de
`tests/architecture/test_layers.py` peut la lire sans exécuter la vue.

Le cloisonnement par établissement (ADR-005, troisième étage) reste un filtre de
requête : une commande hors périmètre est **introuvable**, pas interdite. Sur
une ressource dont les identifiants sont des UUID, la nuance est mince ; elle
compte tout de même sur `reference`, qui est séquentielle et se devine.
"""

from __future__ import annotations

from typing import ClassVar

from django.db.models import Count, QuerySet
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema
from rest_framework.decorators import action
from rest_framework.mixins import ListModelMixin, RetrieveModelMixin
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.serializers import BaseSerializer
from rest_framework.viewsets import GenericViewSet

from apps.orders.models import Order
from apps.orders.queries import avec_compteurs
from apps.orders.serializers import (
    OrderDetailSerializer,
    OrderSerializer,
    StaffCancelSerializer,
    StatusTransitionSerializer,
)
from apps.orders.services import OrderService
from apps.orders.states import OrderStatus
from apps.restaurants.scoping import is_unscoped, staff_restaurant_ids
from common.exceptions import BusinessRuleViolation
from common.permissions import HasPermission, authenticated_user

__all__ = ["ManagedOrderViewSet"]


class ManagedOrderViewSet(ListModelMixin, RetrieveModelMixin, GenericViewSet[Order]):
    """Commandes de l'établissement — lecture, avancement, annulation.

    Aucune création ici : une commande naît d'un panier client, jamais d'un
    écran d'exploitation. Aucune suppression non plus — c'est une pièce
    comptable, et ce qui n'a pas eu lieu s'annule au lieu de disparaître.
    """

    # En n-uplet et non en liste, comme dans les autres back-offices :
    # `permission_classes` est une variable d'instance sur `APIView`, et
    # l'annoter `ClassVar` — ce qu'exigerait une liste mutable — est refusé par
    # le vérificateur de types.
    permission_classes = (HasPermission.of("orders.read"),)

    # Déclaré pour le générateur de schéma seulement — voir `get_queryset`.
    queryset = Order.objects.none()

    #: `placed_at` en intervalle parce que l'écran de supervision demande
    #: toujours la même chose — « le service en cours » — et que la seule façon
    #: de l'exprimer sans borne serait de tout charger pour n'en afficher que la
    #: fin.
    filterset_fields: ClassVar[dict[str, list[str]]] = {
        "status": ["exact"],
        "restaurant__slug": ["exact"],
        "customer": ["exact"],
        "placed_at": ["gte", "lte"],
    }

    #: Ce sur quoi porte `?search=` — ce qu'un opérateur a sous les yeux quand
    #: il cherche : la référence que le client lui donne au téléphone, le nom
    #: ou le numéro du destinataire, l'adresse de livraison.
    #:
    #: La recherche est ici plutôt que dans l'application parce qu'elle doit
    #: composer avec la pagination : filtrer côté écran ne trouve que ce que la
    #: page courante contenait déjà, et « aucun résultat » y veut alors dire
    #: « pas sur cette page » — la plus trompeuse des réponses.
    search_fields: ClassVar[list[str]] = [
        "reference",
        "recipient_name",
        "recipient_phone",
        "delivery_address_line",
    ]

    #: L'ordre par défaut reste `-placed_at` (voir `get_queryset`) : ces champs
    #: ne s'appliquent que si l'appelant demande `?ordering=`.
    ordering_fields: ClassVar[list[str]] = ["placed_at", "total_minor", "status"]

    def get_serializer_class(self) -> type[BaseSerializer[Order]]:
        return OrderDetailSerializer if self.action == "retrieve" else OrderSerializer

    def _perimetre(self) -> QuerySet[Order]:
        """Les commandes que ce compte a le droit de voir, **sans annotation**.

        Séparé de [get_queryset] parce que `counts` en a besoin nu : une
        annotation posée avant un `values(...).annotate(...)` entre dans le
        `GROUP BY` de Django et scinde alors chaque statut en autant de lignes
        qu'il y a de valeurs annotées distinctes. Le compte de « Prêtes »
        tombait ainsi à 1 sur deux commandes, parce que leurs `items_count`
        différaient.
        """
        user = authenticated_user(self.request)
        queryset = Order.objects.select_related("restaurant", "customer").order_by("-placed_at")

        if is_unscoped(user):
            return queryset
        return queryset.filter(restaurant_id__in=staff_restaurant_ids(user))

    def get_queryset(self) -> QuerySet[Order]:
        queryset = avec_compteurs(self._perimetre())

        if self.action == "retrieve":
            queryset = queryset.prefetch_related("lines__menu_item", "status_events")
        return queryset

    @extend_schema(
        responses={200: OpenApiTypes.OBJECT},
        tags=["orders"],
        description=(
            "Nombre de commandes par statut, sur le périmètre du compte et les "
            "filtres passés en paramètres. Rend un objet `{statut: nombre}`."
        ),
    )
    @action(detail=False, methods=["get"], url_path="counts", url_name="counts")
    def counts(self, request: Request) -> Response:
        """Le compte de chaque statut, **en une requête**.

        Les onglets de la supervision annoncent « En attente (5) ». Les obtenir
        autrement demanderait une requête paginée par onglet — cinq appels pour
        cinq nombres, à chaque ouverture de l'écran — ou de charger toutes les
        commandes pour les compter côté client, ce que la pagination vient
        précisément d'éviter.

        Le filtrage est celui de la vue : `get_queryset` applique le
        cloisonnement, et `filter_queryset` la période et la recherche
        éventuelles. Les compteurs portent donc sur **la même sélection** que la
        liste — sans quoi un onglet annoncerait douze commandes et en
        afficherait trois.

        Les statuts absents sont rendus à zéro plutôt qu'omis : l'appelant n'a
        pas à distinguer « aucune commande » de « clé manquante ».
        """
        # Trois précautions, et chacune corrige une erreur de comptage que
        # Django produit en silence :
        #
        # * `_perimetre()` et non `get_queryset()` — une annotation posée avant
        #   un `values(...).annotate(...)` entre dans le `GROUP BY`, et scinde
        #   chaque statut en autant de lignes qu'il y a de valeurs distinctes
        #   (ici `items_count`) ;
        # * `.order_by()` vide — l'ordre par défaut du modèle est ajouté au
        #   `GROUP BY` de la même façon. C'est le piège le plus discret des
        #   deux : le compte tombe sans qu'aucune requête n'échoue ;
        # * `Count("id")` et non `Count("*")` — sur une jointure, seul le
        #   comptage d'une colonne de la table de base reste juste.
        comptes = (
            self.filter_queryset(self._perimetre())
            .order_by()
            .values("status")
            .annotate(total=Count("id"))
        )
        resultat = {statut: 0 for statut in OrderStatus.values}
        resultat.update({ligne["status"]: ligne["total"] for ligne in comptes})
        return Response(resultat)

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
        """Avance le statut.

        Aucune vérification de flux ici : la machine décide, et une transition
        refusée sort en 409 avec les cibles autorisées, ce qui permet à
        l'application d'afficher les boutons justes.

        `cancelled` en est **exclu**, et c'est le seul cas particulier du
        module. La machine l'accepte comme cible depuis quatre états, si bien
        que le laisser passer ici ferait de `orders.update_status` un droit
        d'annuler — et viderait `orders.cancel` de son sens. Le registre
        distingue les deux parce que l'exploitation les distingue : faire
        avancer le service est le geste de tous les jours, annuler la commande
        d'un tiers ne l'est pas.
        """
        serializer = StatusTransitionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        target = serializer.validated_data["status"]
        if target == OrderStatus.CANCELLED:
            raise BusinessRuleViolation(
                "L'annulation ne passe pas par cette route : appelez `cancel`, "
                "qui exige la permission `orders.cancel` et un motif.",
                current_status=self.get_object().status,
            )

        order = OrderService.transition_to(
            order=self.get_object(),
            target=target,
            actor=authenticated_user(request),
            reason=serializer.validated_data["reason"],
        )
        return Response(OrderDetailSerializer(order).data)

    @extend_schema(
        request=StaffCancelSerializer, responses={200: OrderDetailSerializer}, tags=["orders"]
    )
    @action(
        detail=True,
        methods=["post"],
        permission_classes=[HasPermission.of("orders.cancel")],
    )
    def cancel(self, request: Request, pk: str) -> Response:
        """Annule une commande, motif obligatoire.

        Va plus loin que l'annulation du client — jusqu'à `ready` — parce que
        c'est le cas qu'elle ne couvre pas : la rupture découverte en cuisine,
        l'adresse introuvable, le client injoignable.
        """
        serializer = StaffCancelSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        order = OrderService.cancel_by_staff(
            order=self.get_object(),
            actor=authenticated_user(request),
            reason=serializer.validated_data["reason"],
        )
        return Response(OrderDetailSerializer(order).data)
