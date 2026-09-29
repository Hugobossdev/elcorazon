"""Résolution de zone — **la règle unique du produit**, et le seul endroit où elle vit.

## Le défaut que ce module ferme

La question « quelle zone s'applique à ce point ? » était résolue à **deux
endroits, par deux règles différentes** :

* `ZoneResolutionView` — le devis affiché au client avant qu'il commande —
  retenait la zone de **plus petite surface** ;
* `OrderService._quote_for` — le montant réellement facturé — retenait la zone
  de plus petit `max_distance_km`.

Les deux coïncident sur un réseau à une zone par ville, ce qui est l'état
actuel, et divergent dès qu'une zone « Centre-ville » est posée à l'intérieur
d'une zone « Grand Lomé » : l'écran annonce un tarif, la commande en applique un
autre. Personne ne le verrait avant la première réclamation, et le journal ne
dirait rien — les deux réponses sont individuellement cohérentes.

Il n'y avait donc pas à choisir arbitrairement entre les deux implémentations :
il fallait établir la règle métier une fois, ici, et la faire appeler par les
deux appelants.

## La règle : la plus spécifique gagne

Une zone incluse dans une autre est une **exception tarifaire** : on la dessine
précisément parce que son barème diffère de celui qui l'entoure. La plus petite
surface est donc la bonne réponse, et `max_distance_km` n'en était qu'un
approximant — deux zones peuvent partager un rayon maximal et couvrir des
surfaces sans rapport.

`priority` la précède, pour les cas que la géométrie ne tranche pas : deux zones
de surface voisine dont l'une doit l'emporter par décision commerciale. Elle est
explicite et rare ; la surface reste le départage ordinaire. L'identifiant clôt
l'ordre : deux zones de même priorité et de même surface — deux copies d'un
même contour — ne doivent pas rendre l'une ou l'autre selon le plan de requête.

## Qui concourt

Seules les zones **publiées** et **ouvertes à cet instant** (leurs horaires,
`apps.geography.schedule`) concourent. Une zone suspendue ou fermée s'efface
donc devant celle qui l'entoure, si elle en a une ; sinon, le refus dit
*pourquoi* — `zone_closed` ou `zone_suspended` — plutôt qu'un « hors zone »
qui serait faux.

`explain_resolution` rend le raisonnement entier — candidates, motif de chaque
exclusion, zone retenue — pour l'outil « Tester une adresse » du back-office.
`resolve_zone` n'en garde que la réponse. Les deux sont **la même fonction** :
l'explication ne peut pas diverger de la décision.

## Pourquoi ce module ne connaît pas les établissements

`geography` est près de la racine du graphe et ne dépend que d'`accounts`
(ADR-002) ; `restaurants` dépend de lui. Importer `Restaurant` ici créerait un
cycle que le test d'architecture refuse — à raison : la géographie doit pouvoir
répondre « quelle zone couvre ce point » sans savoir qu'il existe des cuisines.

Le rattachement d'un établissement voyage donc en **identifiant**, jamais en
objet. La question complète — « qui me livre, à quel prix, à quelle distance » —
se pose un étage plus haut, dans `apps.restaurants.delivery`.
"""

from __future__ import annotations

import datetime as dt
import uuid
from dataclasses import dataclass, field

from django.contrib.gis.db.models.functions import Area
from django.contrib.gis.geos import Point
from django.db.models import Prefetch, QuerySet
from django.utils import timezone

from apps.geography.models import DeliveryZone, ZoneScheduleException
from apps.geography.schedule import zone_schedule_state
from apps.geography.states import ZoneStatus

__all__ = [
    "Candidate",
    "ZoneResolution",
    "covering_zones",
    "explain_resolution",
    "resolve_zone",
]


def covering_zones(point: Point) -> QuerySet[DeliveryZone]:
    """Zones **publiées** dont le contour couvre ce point, marché ouvert compris.

    La cascade sur la ville et le pays n'est pas décorative : fermer un marché
    doit retirer ses zones du calcul, sans quoi une adresse resterait
    « livrable » dans un pays où l'enseigne n'opère plus.

    Ne regarde pas les horaires : elle dit *quelles zones existent ici*, pas
    lesquelles livrent à cette minute — c'est `explain_resolution` qui tranche.
    """
    return DeliveryZone.objects.filter(
        boundary__covers=point,
        is_active=True,
        city__is_active=True,
        city__country__is_active=True,
    ).select_related("city__country")


#: Motifs d'exclusion d'une candidate — stables, l'écran les traduit.
EXCLU_AUTRE_CUISINE = "other_kitchen"
EXCLU_AUTRE_VILLE = "other_city"
EXCLU_FERMEE = "closed"


@dataclass(frozen=True, slots=True)
class Candidate:
    """Une zone qui couvre le point, et ce qu'elle est devenue dans la résolution."""

    zone: DeliveryZone
    surface_m2: float
    #: Rang dans l'ordre de départage (0 = la plus forte), toutes zones confondues.
    rank: int
    #: Nul si elle concourait ; sinon le motif — un statut (`suspended`,
    #: `draft`…), `closed`, `other_kitchen` ou `other_city`.
    excluded_because: str | None
    reopens_at: dt.datetime | None = None


@dataclass(frozen=True, slots=True)
class ZoneResolution:
    zone: DeliveryZone | None
    candidates: list[Candidate] = field(default_factory=list)
    #: Quand aucune zone n'est retenue mais qu'une zone *applicable* couvre le
    #: point : `zone_closed` ou `zone_suspended`. Nul pour un point hors zone.
    blocked_code: str | None = None
    #: Pour `zone_closed` : la première réouverture connue.
    reopens_at: dt.datetime | None = None

    @property
    def reason(self) -> str:
        """Pourquoi cette zone — la phrase que montre le back-office."""
        if self.zone is None:
            return "Aucune zone applicable ne livre ce point à cet instant."
        concurrentes = [c for c in self.candidates if c.excluded_because is None]
        if len(concurrentes) == 1:
            return "Seule zone publiée et ouverte qui couvre ce point."
        gagnante, suivante = concurrentes[0], concurrentes[1]
        if gagnante.zone.restaurant_id is not None and suivante.zone.restaurant_id is None:
            return "Zone propre à la cuisine : elle passe avant les zones de la ville."
        if gagnante.zone.priority != suivante.zone.priority:
            return f"Priorité la plus haute ({gagnante.zone.priority})."
        if gagnante.surface_m2 != suivante.surface_m2:
            return "À priorité égale, la plus petite surface — la plus précise — l'emporte."
        return "Égalité parfaite : départagée par identifiant, de façon stable."


def explain_resolution(
    point: Point,
    *,
    restaurant_id: uuid.UUID | None = None,
    city_id: uuid.UUID | None = None,
    at: dt.datetime | None = None,
) -> ZoneResolution:
    """La zone qui s'applique à ce point, **et pourquoi** — l'unique règle du produit.

    L'ordre de départage, du plus fort au plus faible :

    1. les zones **de l'établissement concerné** passent avant les zones
       municipales, quand un établissement est désigné ;
    2. `priority` décroissante — la décision commerciale explicite ;
    3. surface croissante — la plus spécifique l'emporte ;
    4. identifiant — pour qu'une égalité parfaite rende toujours la même zone.

    Concourent : les zones publiées, ouvertes à `at`, municipales de `city_id`
    (quand elle est donnée) ou propres à `restaurant_id`. Sans `restaurant_id`,
    une zone propre à une cuisine ne tarife pas une question posée sans elle ;
    les zones d'un **autre** établissement sont toujours écartées.

    Une zone écartée (suspendue, fermée à `at`) **passe la main** à la suivante
    qui couvre le point : une petite zone posée dans une grande est une
    exception, l'écarter rend ses adresses à la règle générale. `zone_closed`
    et `zone_suspended` ne tombent que lorsque plus aucune zone ne sert.
    """
    moment = at if at is not None else timezone.now()
    zones = (
        DeliveryZone.objects.filter(
            boundary__covers=point,
            city__is_active=True,
            city__country__is_active=True,
        )
        .exclude(status=ZoneStatus.ARCHIVED)
        .select_related("city__country", "restaurant")
        .prefetch_related(
            "opening_hours",
            # Seulement les exceptions qui ne sont pas finies : l'historique
            # grandit d'année en année et n'intéresse aucun verdict.
            Prefetch(
                "exceptions", queryset=ZoneScheduleException.objects.filter(ends_at__gt=moment)
            ),
        )
        .annotate(surface=Area("boundary"))
    )

    def cle(zone: DeliveryZone) -> tuple[bool, int, float, str]:
        propre = restaurant_id is not None and zone.restaurant_id == restaurant_id
        return (not propre, -zone.priority, _surface(zone), str(zone.pk))

    candidates: list[Candidate] = []
    retenue: DeliveryZone | None = None
    fermees: list[dt.datetime | None] = []
    suspendue = False

    for rang, zone in enumerate(sorted(zones, key=cle)):
        motif: str | None = None
        reouverture: dt.datetime | None = None
        if zone.restaurant_id is not None and zone.restaurant_id != restaurant_id:
            motif = EXCLU_AUTRE_CUISINE
        elif zone.restaurant_id is None and city_id is not None and zone.city_id != city_id:
            motif = EXCLU_AUTRE_VILLE
        elif zone.status != ZoneStatus.PUBLISHED:
            motif = zone.status
            suspendue = suspendue or zone.status == ZoneStatus.SUSPENDED
        else:
            etat = zone_schedule_state(zone, moment)
            if not etat.is_open:
                motif, reouverture = EXCLU_FERMEE, etat.reopens_at
                fermees.append(reouverture)
            elif retenue is None:
                retenue = zone
        candidates.append(
            Candidate(
                zone=zone,
                surface_m2=_surface(zone),
                rank=rang,
                excluded_because=motif,
                reopens_at=reouverture,
            )
        )

    if retenue is not None:
        return ZoneResolution(zone=retenue, candidates=candidates)
    if fermees:
        connues = [r for r in fermees if r is not None]
        return ZoneResolution(
            zone=None,
            candidates=candidates,
            blocked_code="zone_closed",
            reopens_at=min(connues) if connues else None,
        )
    if suspendue:
        return ZoneResolution(zone=None, candidates=candidates, blocked_code="zone_suspended")
    return ZoneResolution(zone=None, candidates=candidates)


def _surface(zone: DeliveryZone) -> float:
    """Surface annotée par `Area`, en mètres carrés."""
    return float(getattr(zone, "surface").sq_m)  # noqa: B009 — annotation de requête


def resolve_zone(
    point: Point,
    *,
    restaurant_id: uuid.UUID | None = None,
    city_id: uuid.UUID | None = None,
    at: dt.datetime | None = None,
) -> DeliveryZone | None:
    """La zone qui s'applique à ce point — voir `explain_resolution`.

    Rend `None` quand aucune zone ne couvre le point. **Ce n'est pas une
    erreur** : « je viens d'emménager hors zone » est une réponse légitime à une
    question légitime, et la traiter en exception obligerait chaque appelant à
    la ranger dans sa branche d'échec.
    """
    return explain_resolution(point, restaurant_id=restaurant_id, city_id=city_id, at=at).zone
