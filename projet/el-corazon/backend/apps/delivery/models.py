"""Flotte et courses.

Trois invariants prouvés de la Phase 1 sont défendus ici :

* **L1** — seul un dossier `approved` peut accepter une course. Le statut de
  vérification est sur le profil, et le service le relit ; il n'est jamais
  déduit d'un jeton ni d'un champ client.
* **L2** — l'acceptation est exclusive. La contrainte d'unicité sur la course
  active d'une commande la rend impossible à violer même si deux requêtes
  concurrentes passent la garde applicative.
* **L4** — les compteurs ne sont incrémentés qu'à la transition vers
  `delivered`, qui est terminale : le graphe rend le rejeu inexprimable.
"""

from __future__ import annotations

from django.contrib.gis.db import models as gis
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models

from apps.accounts.models import User
from apps.delivery.states import (
    DELIVERY_MACHINE,
    VERIFICATION_MACHINE,
    DeliveryStatus,
    VerificationStatus,
)
from apps.orders.models import Order
from apps.restaurants.models import Restaurant
from common.fields import MoneyField
from common.models import TimeStampedModel, UUIDModel, state_check_constraint

__all__ = ["Assignment", "CourierProfile", "VehicleType"]


class VehicleType(models.TextChoices):
    MOTORCYCLE = "motorcycle", "Moto"
    BICYCLE = "bicycle", "Vélo"
    CAR = "car", "Voiture"
    SCOOTER = "scooter", "Scooter"


class CourierProfile(UUIDModel, TimeStampedModel):
    """Dossier livreur : pièces, validation, disponibilité, position.

    Séparé de `User` parce que la vérification, les statistiques et la position
    ne concernent qu'une population, et que la position est réécrite toutes les
    dix secondes — ce qu'on ne veut pas faire sur la table d'authentification.
    """

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="courier_profile")
    restaurant = models.ForeignKey(Restaurant, on_delete=models.PROTECT, related_name="couriers")

    # --- Dossier ---------------------------------------------------------
    verification_status = models.CharField(
        max_length=16,
        choices=VerificationStatus.choices,
        default=VerificationStatus.PENDING,
        db_index=True,
    )
    verification_notes = models.TextField(blank=True)
    verified_by = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    verified_at = models.DateTimeField(null=True, blank=True)

    national_id_number = models.CharField(max_length=64, blank=True)
    licence_number = models.CharField(max_length=64, blank=True)
    vehicle_type = models.CharField(max_length=16, choices=VehicleType.choices)
    vehicle_plate = models.CharField(max_length=32, blank=True)

    # Pièces justificatives. Stockage privé, jamais public : les URL signées
    # de `django-storages` expirent en quinze minutes (réglage `AWS_QUERYSTRING_EXPIRE`).
    id_document = models.FileField(upload_to="couriers/id/", null=True, blank=True)
    licence_document = models.FileField(upload_to="couriers/licence/", null=True, blank=True)
    vehicle_document = models.FileField(upload_to="couriers/vehicle/", null=True, blank=True)

    # --- Disponibilité et position ---------------------------------------
    is_online = models.BooleanField(
        default=False, help_text="Bascule volontaire du livreur : accepte-t-il des courses ?"
    )
    last_location = gis.PointField(geography=True, srid=4326, null=True, blank=True)
    last_location_at = models.DateTimeField(null=True, blank=True)

    # --- Statistiques (L4) ------------------------------------------------
    deliveries_completed = models.PositiveIntegerField(default=0)
    deliveries_cancelled = models.PositiveIntegerField(default=0)
    rating_average = models.DecimalField(
        max_digits=3,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0), MaxValueValidator(5)],
    )
    rating_count = models.PositiveIntegerField(default=0)
    total_earnings = MoneyField(null=True)

    class Meta:
        verbose_name = "profil livreur"
        verbose_name_plural = "profils livreurs"
        constraints = [
            state_check_constraint(
                VERIFICATION_MACHINE, "verification_status", "courier_verification_in_enum"
            ),
        ]
        indexes = [
            # La requête d'affectation : les livreurs joignables d'un
            # restaurant. Le filtre géographique s'applique ensuite, sur un
            # ensemble déjà réduit.
            models.Index(fields=["restaurant", "is_online", "verification_status"]),
            gis.Index(fields=["last_location"]),
        ]

    def __str__(self) -> str:
        return f"{self.user.full_name} ({self.get_vehicle_type_display()})"

    @property
    def can_accept_orders(self) -> bool:
        """L1 — la seule porte d'entrée de l'éligibilité.

        Un livreur hors ligne ou dont le dossier n'est pas validé ne prend
        aucune course. Exposé en propriété pour qu'aucun appelant ne
        recompose la condition à sa façon, en en oubliant un terme.
        """
        return (
            self.is_online
            and self.verification_status == VerificationStatus.APPROVED
            and self.user.is_active
        )


class Assignment(UUIDModel, TimeStampedModel):
    """Course : l'attribution d'une commande à un livreur.

    Plusieurs affectations peuvent exister pour une même commande — une course
    proposée puis refusée, une autre proposée ensuite. Une seule peut être
    **active** à la fois, ce que garantit un index unique partiel.
    """

    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name="assignments")
    courier = models.ForeignKey(
        CourierProfile, on_delete=models.PROTECT, related_name="assignments"
    )

    status = models.CharField(
        max_length=16, choices=DeliveryStatus.choices, default=DeliveryStatus.OFFERED
    )

    offered_at = models.DateTimeField(auto_now_add=True)
    accepted_at = models.DateTimeField(null=True, blank=True)
    picked_up_at = models.DateTimeField(null=True, blank=True)
    delivered_at = models.DateTimeField(null=True, blank=True)

    # Rémunération figée à l'acceptation : le barème peut changer, ce qui est
    # dû au livreur pour cette course ne change pas.
    courier_fee = MoneyField(null=True)

    decline_reason = models.TextField(blank=True)
    proof_of_delivery = models.ImageField(upload_to="deliveries/", null=True, blank=True)

    class Meta:
        verbose_name = "course"
        ordering = ["-offered_at"]
        constraints = [
            state_check_constraint(DELIVERY_MACHINE, "status", "assignment_status_in_enum"),
            # L2 — une seule course active par commande.
            #
            # La garde applicative (SELECT FOR UPDATE dans le service) traite le
            # cas courant ; cette contrainte traite le cas où elle est
            # contournée — un script d'exploitation, un correctif à chaud, un
            # bug futur. Deux livreurs acceptant simultanément : le second se
            # heurte à la base, pas à un état incohérent.
            models.UniqueConstraint(
                fields=["order"],
                condition=~models.Q(
                    status__in=[
                        DeliveryStatus.DECLINED,
                        DeliveryStatus.CANCELLED,
                        DeliveryStatus.DELIVERED,
                    ]
                ),
                name="one_active_assignment_per_order",
            ),
        ]
        indexes = [
            models.Index(fields=["courier", "-offered_at"]),
            models.Index(fields=["order", "status"]),
        ]

    def __str__(self) -> str:
        return f"{self.order.reference} → {self.courier.user.full_name}"

    @property
    def is_active(self) -> bool:
        return self.status in {
            DeliveryStatus.OFFERED,
            DeliveryStatus.ACCEPTED,
            DeliveryStatus.PICKED_UP,
            DeliveryStatus.ON_THE_WAY,
        }
