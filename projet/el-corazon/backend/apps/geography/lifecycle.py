"""Gestes du cycle de vie d'une zone — **un seul endroit**, pour les deux routes.

Les zones de ville (`/geography/manage/zones/`) et les zones propres à une
cuisine (`/restaurants/manage/zones/`) se publient, se suspendent, se
dupliquent et se programment de la même façon. Écrits ici, ces gestes ne
peuvent pas diverger d'une route à l'autre ; les vues ne font que vérifier qui
a le droit, puis appellent.

Chaque geste :

* verrouille la ligne (`select_for_update`) — deux opérateurs qui publient et
  suspendent en même temps ne s'écrasent pas ;
* valide la transition contre `ZONE_MACHINE` — une transition non déclarée
  sort en 409, jamais en écriture silencieuse ;
* est idempotent — rejouer « publier » sur une zone publiée ne change rien et
  n'écrit rien au journal ;
* laisse une trace au journal, avec son motif.
"""

from __future__ import annotations

import datetime as dt
from collections.abc import Iterable
from dataclasses import dataclass
from typing import Any

from django.db import transaction
from django.utils import timezone

from apps.accounts.models import User
from apps.geography.journal import (
    record_zone_creation,
    record_zone_schedule,
    record_zone_status,
    schedule_fingerprint,
)
from apps.geography.models import (
    DeliveryZone,
    ZoneExceptionKind,
    ZoneOpeningHours,
    ZoneScheduleException,
)
from apps.geography.states import ZONE_MACHINE, ZoneStatus
from common.exceptions import BusinessRuleViolation

__all__ = [
    "SlotInput",
    "add_zone_exception",
    "duplicate_zone",
    "remove_zone_exception",
    "replace_zone_hours",
    "transition_zone",
]


@transaction.atomic
def transition_zone(
    zone: DeliveryZone,
    target: str,
    *,
    actor: User | None,
    reason: str = "",
    expected_end_at: dt.datetime | None = None,
) -> DeliveryZone:
    """Fait passer la zone à `target`, ou lève `IllegalTransition` (409)."""
    verrouillee = DeliveryZone.objects.select_for_update().get(pk=zone.pk)
    avant = verrouillee.status
    if ZONE_MACHINE.is_noop(avant, target):
        return verrouillee
    ZONE_MACHINE.validate(avant, target)

    if target == ZoneStatus.SUSPENDED and not reason.strip():
        # Une suspension sans motif ne se relit pas : « pourquoi Bè ne
        # livre-t-elle plus depuis mardi ? » doit avoir une réponse au journal.
        raise BusinessRuleViolation("Indiquez le motif de la suspension.", field_name="reason")
    maintenant = timezone.now()
    if expected_end_at is not None and expected_end_at <= maintenant:
        raise BusinessRuleViolation(
            "La fin annoncée de la suspension doit être dans le futur.",
            field_name="expected_end_at",
        )

    verrouillee.status = target
    verrouillee.updated_by = actor
    champs = {"status", "updated_by", "updated_at"}
    if target == ZoneStatus.PUBLISHED:
        verrouillee.published_by, verrouillee.published_at = actor, maintenant
        champs |= {"published_by", "published_at"}
    if target == ZoneStatus.SUSPENDED:
        verrouillee.suspension_reason = reason.strip()[:255]
        verrouillee.suspended_at, verrouillee.suspended_by = maintenant, actor
        verrouillee.suspension_expected_end_at = expected_end_at
    else:
        # Hors suspension, ces champs décriraient une suspension terminée : ils
        # vivent désormais au journal, pas sur la fiche.
        verrouillee.suspension_reason = ""
        verrouillee.suspended_at = verrouillee.suspended_by = None
        verrouillee.suspension_expected_end_at = None
    champs |= {
        "suspension_reason",
        "suspended_at",
        "suspended_by",
        "suspension_expected_end_at",
    }
    if target == ZoneStatus.ARCHIVED:
        verrouillee.archived_at = maintenant
        champs.add("archived_at")
    verrouillee.save(update_fields=champs)

    record_zone_status(
        actor,
        verrouillee,
        avant,
        reason=reason.strip(),
        expected_end_at=expected_end_at.isoformat() if expected_end_at else None,
    )
    return verrouillee


#: Ce qu'une duplication recopie. Ni l'identifiant, ni le statut, ni la
#: traçabilité, ni les exceptions datées (elles décrivent la vie de l'original),
#: ni rien de ce qui pointe vers lui — commandes, journal, statistiques.
_CHAMPS_DUPLIQUES = (
    "city_id",
    "restaurant_id",
    "shape",
    "boundary",
    "center",
    "radius_meters",
    "priority",
    "base_fee",
    "fee_per_km",
    "free_delivery_threshold",
    "min_order_amount",
    "max_distance_km",
    "estimated_delivery_minutes",
)


@transaction.atomic
def duplicate_zone(zone: DeliveryZone, *, actor: User | None, name: str) -> DeliveryZone:
    """Copie la zone **en brouillon**, avec ses plages hebdomadaires."""
    nom = name.strip()
    if not nom:
        raise BusinessRuleViolation("Donnez un nom à la nouvelle zone.", field_name="name")
    if DeliveryZone.objects.filter(city_id=zone.city_id, name=nom).exists():
        raise BusinessRuleViolation(
            f"Une zone « {nom} » existe déjà dans cette ville.", field_name="name"
        )
    copie = DeliveryZone(
        name=nom,
        status=ZoneStatus.DRAFT,
        created_by=actor,
        updated_by=actor,
        **{champ: getattr(zone, champ) for champ in _CHAMPS_DUPLIQUES},
    )
    copie.save()
    ZoneOpeningHours.objects.bulk_create(
        ZoneOpeningHours(zone=copie, weekday=h.weekday, opens_at=h.opens_at, closes_at=h.closes_at)
        for h in zone.opening_hours.all()
    )
    record_zone_creation(actor, copie)
    return copie


@dataclass(frozen=True, slots=True)
class SlotInput:
    weekday: int
    opens_at: dt.time
    closes_at: dt.time


@transaction.atomic
def replace_zone_hours(
    zone: DeliveryZone, slots: Iterable[SlotInput], *, actor: User | None
) -> DeliveryZone:
    """Remplace **toutes** les plages — l'écran envoie la semaine qu'il montre.

    Une liste vide rend la zone à sa cuisine : sans plage, elle suit les
    horaires de l'établissement.
    """
    verrouillee = DeliveryZone.objects.select_for_update().get(pk=zone.pk)
    plages = list(slots)
    vues: set[tuple[int, dt.time]] = set()
    for plage in plages:
        if plage.opens_at == plage.closes_at:
            raise BusinessRuleViolation(
                "Une plage ne peut pas s'ouvrir et se fermer à la même heure.",
                field_name="hours",
            )
        cle = (plage.weekday, plage.opens_at)
        if cle in vues:
            raise BusinessRuleViolation(
                "Deux plages commencent le même jour à la même heure.", field_name="hours"
            )
        vues.add(cle)

    avant = schedule_fingerprint(verrouillee)
    verrouillee.opening_hours.all().delete()
    ZoneOpeningHours.objects.bulk_create(
        ZoneOpeningHours(
            zone=verrouillee, weekday=p.weekday, opens_at=p.opens_at, closes_at=p.closes_at
        )
        for p in plages
    )
    verrouillee.updated_by = actor
    verrouillee.save(update_fields=["updated_by", "updated_at"])
    record_zone_schedule(actor, verrouillee, avant)
    return verrouillee


@transaction.atomic
def add_zone_exception(
    zone: DeliveryZone,
    *,
    kind: str,
    starts_at: dt.datetime,
    ends_at: dt.datetime,
    reason: str,
    actor: User | None,
) -> ZoneScheduleException:
    if kind not in ZoneExceptionKind.values:
        raise BusinessRuleViolation("Nature d'exception inconnue.", field_name="kind")
    if ends_at <= starts_at:
        raise BusinessRuleViolation("La fin doit suivre le début.", field_name="ends_at")
    if ends_at <= timezone.now():
        raise BusinessRuleViolation("Cette exception serait déjà terminée.", field_name="ends_at")
    verrouillee = DeliveryZone.objects.select_for_update().get(pk=zone.pk)
    avant = schedule_fingerprint(verrouillee)
    exception = ZoneScheduleException.objects.create(
        zone=verrouillee,
        kind=kind,
        starts_at=starts_at,
        ends_at=ends_at,
        reason=reason.strip()[:255],
        created_by=actor,
    )
    record_zone_schedule(actor, verrouillee, avant)
    return exception


@transaction.atomic
def remove_zone_exception(zone: DeliveryZone, exception_id: Any, *, actor: User | None) -> None:
    verrouillee = DeliveryZone.objects.select_for_update().get(pk=zone.pk)
    avant = schedule_fingerprint(verrouillee)
    supprimees, _ = verrouillee.exceptions.filter(pk=exception_id).delete()
    if not supprimees:
        raise BusinessRuleViolation("Exception introuvable pour cette zone.")
    record_zone_schedule(actor, verrouillee, avant)
