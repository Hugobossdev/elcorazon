"""Cycle de vie d'une zone de livraison — ADR-010.

`is_active` disait deux choses à la fois, et en taisait trois. Une zone
fraîchement dessinée entrait **en service à l'instant de sa création** : un
contour tracé de travers, un forfait saisi à zéro, et la zone tarifait déjà les
commandes. Désactivée, elle ne disait plus si c'était un brouillon jamais
publié, une suspension pour une nuit d'émeutes, ou un quartier abandonné pour
de bon.

    brouillon → en revue → publiée ⇄ suspendue
        └──────────┴───────────┴─────────┴──→ archivée

Seule `published` livre. `is_active` reste en base, **dérivé** du statut
(`DeliveryZone.save`) : les filtres de production qui l'interrogent — la
résolution, l'annuaire, le juge de cuisine — restent justes sans être réécrits,
et une contrainte interdit aux deux colonnes de se contredire.

Pas de double validation (décision du 2026-09-28) : la revue est une étape où
l'on relit, pas un second signataire. La personne qui soumet peut publier.

`archived` est terminal : une zone archivée a tarifé des commandes dont
l'historique doit rester lisible, elle ne se supprime pas et ne revient pas.
On en duplique une nouvelle.
"""

from __future__ import annotations

from django.db import models

from common.state_machine import StateMachine

__all__ = ["ZONE_MACHINE", "ZONE_TRANSITIONS", "ZoneStatus"]


class ZoneStatus(models.TextChoices):
    DRAFT = "draft", "Brouillon"
    PENDING_REVIEW = "pending_review", "En revue"
    PUBLISHED = "published", "Publiée"
    SUSPENDED = "suspended", "Suspendue"
    ARCHIVED = "archived", "Archivée"


#: Transitions autorisées.
#:
#: `PENDING_REVIEW → DRAFT` est le renvoi en correction : sans lui, une zone
#: relue et fausse ne pourrait que partir en service ou aux archives.
ZONE_TRANSITIONS: dict[str, set[str]] = {
    ZoneStatus.DRAFT: {ZoneStatus.PENDING_REVIEW, ZoneStatus.ARCHIVED},
    ZoneStatus.PENDING_REVIEW: {ZoneStatus.DRAFT, ZoneStatus.PUBLISHED, ZoneStatus.ARCHIVED},
    ZoneStatus.PUBLISHED: {ZoneStatus.SUSPENDED, ZoneStatus.ARCHIVED},
    ZoneStatus.SUSPENDED: {ZoneStatus.PUBLISHED, ZoneStatus.ARCHIVED},
    ZoneStatus.ARCHIVED: set(),
}

ZONE_MACHINE = StateMachine(ZONE_TRANSITIONS, name="zone", require_acyclic=False)
