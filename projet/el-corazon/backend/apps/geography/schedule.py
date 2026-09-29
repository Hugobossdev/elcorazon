"""Horaires — **la seule lecture d'une plage hebdomadaire**, pour les zones comme pour les cuisines.

Une plage peut franchir minuit (`22:00 → 02:00`, écrite `closes_at < opens_at`)
et couvrir alors le petit matin du lendemain. C'est le genre de règle qu'on
écrit juste une fois et faux la seconde : les horaires de cuisine
(`Restaurant.is_open_at`) et ceux des zones la lisent donc ici.

## L'état d'une zone à un instant

Trois sources, dans cet ordre :

1. une **fermeture exceptionnelle** en cours ferme la zone — dans le doute, on
   ne livre pas ;
2. une **ouverture exceptionnelle** en cours l'ouvre, même hors plage ;
3. sinon, les **plages hebdomadaires** ; une zone qui n'en a aucune suit sa
   cuisine et se dit ouverte ici.

L'heure est lue dans le fuseau du pays de la zone, jamais celui du serveur.
"""

from __future__ import annotations

import datetime as dt
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from typing import Protocol
from zoneinfo import ZoneInfo

from apps.geography.models import DeliveryZone, ZoneExceptionKind, ZoneScheduleException

__all__ = ["Slot", "ZoneScheduleState", "slots_cover", "zone_schedule_state"]

#: Horizon de recherche d'une réouverture : au-delà, l'écran dit « fermée »
#: sans date plutôt que de balayer un calendrier vide.
_HORIZON_JOURS = 8


class Slot(Protocol):
    weekday: int
    opens_at: dt.time
    closes_at: dt.time

    @property
    def crosses_midnight(self) -> bool: ...


def slots_cover(slots: Iterable[Slot], local: dt.datetime) -> bool:
    """Une des plages couvre-t-elle cet instant, déjà converti à l'heure locale ?"""
    now, weekday = local.time(), local.weekday()
    yesterday = (weekday - 1) % 7
    for slot in slots:
        if slot.weekday == weekday and slot.opens_at <= now:
            if slot.crosses_midnight or now < slot.closes_at:
                return True
        # Une plage ouverte hier et à cheval sur minuit couvre encore le petit
        # matin d'aujourd'hui.
        if slot.weekday == yesterday and slot.crosses_midnight and now < slot.closes_at:
            return True
    return False


@dataclass(frozen=True, slots=True)
class ZoneScheduleState:
    """La zone livre-t-elle à cet instant, et sinon pourquoi et jusqu'à quand."""

    is_open: bool
    #: Vrai si la zone porte des plages ; faux, elle suit sa cuisine.
    has_schedule: bool
    #: Fermeture exceptionnelle en cours, s'il y en a une.
    closure: ZoneScheduleException | None = None
    #: Premier instant d'ouverture connu, quand la zone est fermée.
    reopens_at: dt.datetime | None = None


def _exceptions(zone: DeliveryZone, moment: dt.datetime) -> list[ZoneScheduleException]:
    cache = getattr(zone, "_prefetched_objects_cache", {})
    if "exceptions" in cache:
        return [e for e in zone.exceptions.all() if e.ends_at > moment]
    return list(zone.exceptions.filter(ends_at__gt=moment).order_by("starts_at"))


def zone_schedule_state(zone: DeliveryZone, moment: dt.datetime) -> ZoneScheduleState:
    """L'état horaire d'une zone — **ne dit rien de son statut** (`status`)."""
    slots = list(zone.opening_hours.all())
    exceptions = _exceptions(zone, moment)
    fuseau = ZoneInfo(zone.timezone)

    def ouverte(instant: dt.datetime) -> tuple[bool, ZoneScheduleException | None]:
        en_cours = [e for e in exceptions if e.covers(instant)]
        fermeture = next((e for e in en_cours if e.kind == ZoneExceptionKind.CLOSED), None)
        if fermeture is not None:
            return False, fermeture
        if any(e.kind == ZoneExceptionKind.OPEN for e in en_cours):
            return True, None
        if not slots:
            return True, None
        return slots_cover(slots, instant.astimezone(fuseau)), None

    est_ouverte, fermeture = ouverte(moment)
    if est_ouverte:
        return ZoneScheduleState(is_open=True, has_schedule=bool(slots))

    return ZoneScheduleState(
        is_open=False,
        has_schedule=bool(slots),
        closure=fermeture,
        reopens_at=_prochaine_ouverture(moment, exceptions, slots, fuseau, ouverte),
    )


def _prochaine_ouverture(
    moment: dt.datetime,
    exceptions: list[ZoneScheduleException],
    slots: Sequence[Slot],
    fuseau: ZoneInfo,
    ouverte: object,
) -> dt.datetime | None:
    """Premier instant où la zone rouvre, parmi les bornes connues.

    Les seuls instants où l'état peut basculer sont les débuts de plage et les
    bornes d'exception : il suffit de les essayer dans l'ordre, sans balayer le
    temps minute par minute.
    """
    assert callable(ouverte)
    local = moment.astimezone(fuseau)
    bornes: set[dt.datetime] = set()
    for e in exceptions:
        for borne in (e.starts_at, e.ends_at):
            if borne > moment:
                bornes.add(borne)
    for decalage in range(_HORIZON_JOURS):
        jour = (local + dt.timedelta(days=decalage)).date()
        for slot in slots:
            if slot.weekday == jour.weekday():
                debut = dt.datetime.combine(jour, slot.opens_at, tzinfo=fuseau)
                if debut > moment:
                    bornes.add(debut)
    for borne in sorted(bornes):
        if ouverte(borne)[0]:
            return borne
    return None
