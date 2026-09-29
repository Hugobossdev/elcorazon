"""Ce qu'une écriture de zone laisse au journal — pour les zones de ville comme
pour les zones propres à une cuisine.

Une seule règle pour les deux routes (`geography` et `restaurants`) : les zones
propres consignaient toute modification comme un « barème » et leur suppression
comme une « activation », pendant que les zones de ville distinguaient déjà le
contour, le barème et l'ouverture. Écrite ici, la règle ne peut plus diverger.

Vit dans `geography`, que `restaurants` a le droit de connaître (ADR-002) ; le
sens inverse est interdit.
"""

from __future__ import annotations

from typing import Any

from apps.accounts.models import User
from apps.geography.models import DeliveryZone
from common.audit import AuditAction, record_change

__all__ = [
    "record_zone_changes",
    "record_zone_creation",
    "record_zone_deletion",
    "record_zone_schedule",
    "record_zone_status",
    "schedule_fingerprint",
    "zone_fingerprint",
    "zone_label",
]


def zone_label(zone: DeliveryZone) -> str:
    """« Tokoin — El Corazón » pour une zone propre, « Tokoin — Lomé » sinon."""
    porteur = zone.restaurant.name if zone.restaurant is not None else zone.city.name
    return f"{zone.name} — {porteur}"


def _instantane(zone: DeliveryZone) -> dict[str, Any]:
    empreinte = zone_fingerprint(zone)
    return {
        **empreinte["geometrie"],
        **empreinte["bareme"],
        "priority": zone.priority,
        "status": zone.status,
        "is_active": zone.is_active,
    }


def record_zone_creation(actor: User | None, zone: DeliveryZone) -> None:
    record_change(
        actor=actor,
        action=AuditAction.ZONE_CREATE,
        target_type="zone",
        target_id=zone.pk,
        target_label=zone_label(zone),
        before={},
        after=_instantane(zone),
        scope_restaurant_id=zone.restaurant_id,
    )


def record_zone_deletion(actor: User | None, zone: DeliveryZone) -> None:
    record_change(
        actor=actor,
        action=AuditAction.ZONE_DELETE,
        target_type="zone",
        target_id=zone.pk,
        target_label=zone_label(zone),
        before=_instantane(zone),
        after={},
        scope_restaurant_id=zone.restaurant_id,
    )


def record_zone_changes(actor: User | None, avant: dict[str, Any], zone: DeliveryZone) -> None:
    """Trois entrées possibles : le contour, le barème, l'ouverture.

    Séparées parce qu'elles répondent à des questions différentes — « jusqu'où
    livre-t-on ? », « combien fait-on payer ? », « livre-t-on encore ? » — et
    qu'on les pose rarement ensemble. Rien n'est écrit pour ce qui n'a pas
    changé (`record_change`).
    """
    apres = zone_fingerprint(zone)
    for cle, action in (
        ("geometrie", AuditAction.ZONE_BOUNDARY),
        ("bareme", AuditAction.ZONE_TARIFF),
    ):
        record_change(
            actor=actor,
            action=action,
            target_type="zone",
            target_id=zone.pk,
            target_label=zone_label(zone),
            before=avant[cle],
            after=apres[cle],
            scope_restaurant_id=zone.restaurant_id,
        )
    record_change(
        actor=actor,
        action=AuditAction.ZONE_PRIORITY,
        target_type="zone",
        target_id=zone.pk,
        target_label=zone_label(zone),
        before={"priority": avant["priority"]},
        after={"priority": apres["priority"]},
        scope_restaurant_id=zone.restaurant_id,
    )
    # L'ouverture ne change plus par une écriture de fiche : elle passe par
    # `apps.geography.lifecycle`, qui journalise `zone.status` avec son motif.


def record_zone_status(
    actor: User | None,
    zone: DeliveryZone,
    before: str,
    *,
    reason: str = "",
    expected_end_at: str | None = None,
) -> None:
    after: dict[str, Any] = {"status": zone.status}
    if reason:
        after["reason"] = reason
    if expected_end_at:
        after["expected_end_at"] = expected_end_at
    record_change(
        actor=actor,
        action=AuditAction.ZONE_STATUS,
        target_type="zone",
        target_id=zone.pk,
        target_label=zone_label(zone),
        before={"status": before},
        after=after,
        scope_restaurant_id=zone.restaurant_id,
    )


def schedule_fingerprint(zone: DeliveryZone) -> dict[str, Any]:
    """Plages et exceptions à venir, sous une forme qui se relit au journal."""
    return {
        "hours": [
            f"{h.weekday}:{h.opens_at:%H:%M}-{h.closes_at:%H:%M}"
            for h in zone.opening_hours.order_by("weekday", "opens_at")
        ],
        "exceptions": [
            f"{e.kind}:{e.starts_at.isoformat()}/{e.ends_at.isoformat()}:{e.reason}"
            for e in zone.exceptions.order_by("starts_at")
        ],
    }


def record_zone_schedule(actor: User | None, zone: DeliveryZone, avant: dict[str, Any]) -> None:
    record_change(
        actor=actor,
        action=AuditAction.ZONE_SCHEDULE,
        target_type="zone",
        target_id=zone.pk,
        target_label=zone_label(zone),
        before=avant,
        after=schedule_fingerprint(zone),
        scope_restaurant_id=zone.restaurant_id,
    )


def zone_fingerprint(zone: DeliveryZone) -> dict[str, Any]:
    """Ce qu'on compare pour décider s'il faut journaliser.

    Le contour n'est **pas** repris tel quel : plusieurs kilo-octets de sommets
    dans chaque entrée rendraient le journal impossible à lire et lourd à
    stocker. Ce qu'on garde est ce qui se relit — la forme, le centre, le rayon
    — plus une empreinte du contour, qui suffit à dire *qu'il* a changé sans
    dire en quoi.
    """
    import hashlib

    def montant(valeur: object) -> str | None:
        return str(valeur) if valeur is not None else None

    return {
        "geometrie": {
            "shape": zone.shape,
            "center": ([round(zone.center.y, 6), round(zone.center.x, 6)] if zone.center else None),
            "radius_meters": zone.radius_meters,
            "boundary_digest": hashlib.sha256(zone.boundary.wkb).hexdigest()[:16],
        },
        "bareme": {
            "base_fee": montant(zone.base_fee),
            "fee_per_km": montant(zone.fee_per_km),
            "free_delivery_threshold": montant(zone.free_delivery_threshold),
            "min_order_amount": montant(zone.min_order_amount),
            "max_distance_km": str(zone.max_distance_km),
            "estimated_delivery_minutes": zone.estimated_delivery_minutes,
        },
        "priority": zone.priority,
        "is_active": zone.is_active,
    }
