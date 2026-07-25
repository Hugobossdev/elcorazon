"""Établissements — ADR-006.

`Restaurant` est le point de rattachement du multi-site : le catalogue, les
commandes et la flotte portent tous une clé de restaurant **non nulle** dès le
premier jour. C'est cette colonne, présente dès l'origine, qui rendra
l'ouverture d'un second établissement indolore.
"""

from __future__ import annotations

import datetime as dt

from django.contrib.gis.db import models as gis
from django.db import models

from apps.geography.models import DeliveryZone
from common.models import TimeStampedModel, UUIDModel

__all__ = ["OpeningHours", "Restaurant", "Weekday"]


class Restaurant(UUIDModel, TimeStampedModel):
    name = models.CharField(max_length=120)
    slug = models.SlugField(max_length=120, unique=True)
    description = models.TextField(blank=True)

    zone = models.ForeignKey(DeliveryZone, on_delete=models.PROTECT, related_name="restaurants")
    address = models.TextField()
    location = gis.PointField(
        geography=True,
        srid=4326,
        help_text="Point de retrait des courses ; origine du calcul de distance.",
    )

    phone = models.CharField(max_length=16)
    email = models.EmailField(blank=True)
    cover_image = models.ImageField(upload_to="restaurants/", null=True, blank=True)

    # `is_active` est structurel — l'établissement existe-t-il ? —, tandis que
    # `accepts_orders` est conjoncturel : un coup de feu en cuisine, une panne
    # de four. Les confondre obligerait à désactiver un restaurant pour arrêter
    # les commandes une heure, ce qui le ferait disparaître de l'application.
    is_active = models.BooleanField(default=True)
    accepts_orders = models.BooleanField(default=True)

    default_preparation_minutes = models.PositiveSmallIntegerField(default=20)

    class Meta:
        verbose_name = "restaurant"
        ordering = ["name"]
        indexes = [
            gis.Index(fields=["location"]),
            models.Index(fields=["zone", "is_active"]),
        ]

    def __str__(self) -> str:
        return self.name

    @property
    def currency(self) -> str:
        """Devise héritée du pays — jamais choisie au niveau du restaurant."""
        return self.zone.city.country.currency


class Weekday(models.IntegerChoices):
    # Aligné sur `date.weekday()` : lundi = 0. Cet alignement évite la
    # conversion manuelle qui est la source classique du décalage d'un jour.
    MONDAY = 0, "Lundi"
    TUESDAY = 1, "Mardi"
    WEDNESDAY = 2, "Mercredi"
    THURSDAY = 3, "Jeudi"
    FRIDAY = 4, "Vendredi"
    SATURDAY = 5, "Samedi"
    SUNDAY = 6, "Dimanche"


class OpeningHours(UUIDModel):
    """Plage d'ouverture.

    Plusieurs plages par jour sont possibles — service du midi et du soir. Une
    plage qui franchit minuit (`22:00 → 02:00`) est représentée par
    `closes_at < opens_at` ; le service d'ouverture en tient compte, plutôt que
    d'obliger à saisir deux plages sur deux jours.
    """

    restaurant = models.ForeignKey(
        Restaurant, on_delete=models.CASCADE, related_name="opening_hours"
    )
    weekday = models.SmallIntegerField(choices=Weekday.choices)
    opens_at = models.TimeField()
    closes_at = models.TimeField()

    class Meta:
        verbose_name = "horaire d'ouverture"
        verbose_name_plural = "horaires d'ouverture"
        ordering = ["weekday", "opens_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["restaurant", "weekday", "opens_at"],
                name="opening_hours_unique_slot",
            ),
            models.CheckConstraint(
                condition=~models.Q(opens_at=models.F("closes_at")),
                name="opening_hours_not_empty",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.get_weekday_display()} {self.opens_at:%H:%M}–{self.closes_at:%H:%M}"

    @property
    def crosses_midnight(self) -> bool:
        return self.closes_at < self.opens_at

    def covers(self, moment: dt.time) -> bool:
        if self.crosses_midnight:
            return moment >= self.opens_at or moment < self.closes_at
        return self.opens_at <= moment < self.closes_at
