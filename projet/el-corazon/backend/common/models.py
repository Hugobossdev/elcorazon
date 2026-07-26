"""Modèles de base.

Ces classes abstraites portent les décisions transverses (ADR-007, ADR-010) une
seule fois. Un modèle métier qui n'hérite pas de `UUIDModel` est une anomalie :
un test d'architecture le signale.
"""

from __future__ import annotations

from typing import Any, TypeVar

from django.db import models
from django.utils import timezone

from common.identifiers import uuid7
from common.state_machine import StateMachine

__all__ = [
    "SoftDeleteManager",
    "SoftDeleteModel",
    "SoftDeleteQuerySet",
    "TimeStampedModel",
    "UUIDModel",
    "state_check_constraint",
]


class UUIDModel(models.Model):
    """Clé primaire UUIDv7 — opaque et ordonnée (ADR-007)."""

    id = models.UUIDField(primary_key=True, default=uuid7, editable=False)

    class Meta:
        abstract = True


class TimeStampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


_Model = TypeVar("_Model", bound=models.Model)


class SoftDeleteQuerySet(models.QuerySet[_Model]):
    """QuerySet générique : `MenuItem.objects.alive()` reste un
    `QuerySet[MenuItem]`, et non un `QuerySet[SoftDeleteModel]` sur lequel
    aucun champ concret ne serait résolvable."""

    def alive(self) -> SoftDeleteQuerySet[_Model]:
        return self.filter(deleted_at__isnull=True)

    def delete(self) -> tuple[int, dict[str, int]]:
        count = self.update(deleted_at=timezone.now())
        return count, {}


SoftDeleteManager = models.Manager.from_queryset(SoftDeleteQuerySet)


class SoftDeleteModel(models.Model):
    """Suppression logique.

    Réservée aux entités auxquelles des écritures comptables se réfèrent : un
    article de menu retiré du catalogue doit rester lisible depuis les commandes
    passées, sinon l'historique devient incohérent.

    À ne **pas** appliquer partout : une adresse supprimée par un client doit
    l'être réellement (RGPD, droit à l'effacement). Le critère est « une écriture
    financière y renvoie-t-elle ? ».
    """

    deleted_at = models.DateTimeField(null=True, blank=True, db_index=True)

    objects = SoftDeleteManager()

    class Meta:
        abstract = True

    def delete(self, *args: Any, **kwargs: Any) -> tuple[int, dict[str, int]]:
        self.deleted_at = timezone.now()
        self.save(update_fields=["deleted_at"])
        return 1, {}

    @property
    def is_deleted(self) -> bool:
        return self.deleted_at is not None


def state_check_constraint(machine: StateMachine, field: str, name: str) -> models.CheckConstraint:
    """Contrainte `CHECK` dérivée d'une machine à états.

    Le code applicatif est la première ligne de défense, le schéma est la
    dernière (ADR-010). Générer la contrainte depuis la machine garantit que
    les deux ne peuvent pas diverger — c'est exactement la divergence qui a
    produit C4, où le code écrivait un statut absent de l'énumération SQL.
    """
    return models.CheckConstraint(
        condition=models.Q(**{f"{field}__in": sorted(machine.states)}),
        name=name,
    )
