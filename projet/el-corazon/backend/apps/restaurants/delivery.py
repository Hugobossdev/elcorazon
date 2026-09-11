"""Livrabilité d'une adresse — **le référentiel unique des trois applications**.

## La question, et pourquoi elle se pose une seule fois

« Puis-je me faire livrer ici, par qui, à quel prix, en combien de temps ? »

Le client la pose avant d'enregistrer une adresse. Le back-office la pose pour
vérifier une configuration. Dely s'appuie sur la même géographie pour situer une
course. Trois applications, une seule réponse possible — et pourtant, avant ce
module, aucune ne pouvait l'obtenir entière :

* `GET /geography/zones/resolve/` rendait **la zone seule** : ni établissement,
  ni frais, ni distance, ni délai ;
* le devis complet n'existait qu'à l'intérieur d'`OrderService`, donc seulement
  pour quelqu'un ayant déjà un panier ouvert sur un restaurant choisi.

Chaque écran recomposait donc le reste à sa façon. C'est exactement la
duplication qu'il faut éviter : trois implémentations d'une règle de tarification
finissent par donner trois prix, dont deux sont faux.

## Ce que ce module n'est pas

Il ne calcule rien lui-même. La zone vient de `apps.geography.resolution`, les
frais de `apps.geography.services.quote_delivery`, la distance de PostGIS. Il
**assemble**, et c'est sa seule raison d'être : le lieu où l'on peut à la fois
connaître les établissements et la géographie, sans que la géographie ait à
connaître les établissements (ADR-002).

## Pourquoi la route ne vit pas sous `/geography/`

Ce serait le chemin le plus lisible, et il est impossible : la vue devrait
importer `Restaurant`, ce que le graphe interdit à `geography`. La réponse porte
d'ailleurs surtout un établissement — c'est bien une question de restaurants,
posée à travers une position.
"""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal

from django.contrib.gis.db.models.functions import Distance
from django.contrib.gis.geos import Point
from django.db.models import Q

from apps.geography.models import DeliveryZone
from apps.geography.resolution import covering_zones, resolve_zone
from apps.geography.services import DeliveryQuote, quote_delivery
from apps.restaurants.models import Restaurant
from common.exceptions import BusinessRuleViolation
from common.money import Money

__all__ = ["DeliveryAvailability", "check_delivery", "overlapping_zones"]


@dataclass(frozen=True, slots=True)
class DeliveryAvailability:
    """Réponse complète à « puis-je être livré ici ? ».

    `is_available` répond à la question ; `reason` dit **pourquoi** quand la
    réponse est non. Les deux sont nécessaires : un booléen seul oblige chaque
    écran à inventer un message, et il en invente un différent dans chacune des
    trois applications — ce que le refus soit « hors zone », « trop loin »,
    « panier trop léger » ou « pas de cuisine ouverte ».

    `quote` est nul quand aucun sous-total n'a été fourni : on peut vouloir
    savoir si une adresse est desservie **avant** d'avoir un panier, et un
    montant minimum ne veut rien dire face à un panier vide.
    """

    is_available: bool
    restaurant: Restaurant | None
    zone: DeliveryZone | None
    distance_m: float | None
    quote: DeliveryQuote | None
    reason: str | None = None

    #: Le refus métier tel qu'il a été levé, quand il en vient un.
    #:
    #: Conservé **entier** plutôt que réduit à sa phrase : un
    #: `BusinessRuleViolation` porte des données contextuelles que le client
    #: exploite — `min_order_amount` pour dire combien il manque,
    #: `distance_km` et `max_distance_km` pour situer l'adresse. Reconstruire
    #: l'exception à partir du seul message les perdrait, et l'écran ne pourrait
    #: plus dire que « ce n'est pas possible ».
    #:
    #: C'est exactement ce qu'un test a attrapé : `min_order_amount` avait
    #: disparu de la réponse 409 du devis.
    refusal: BusinessRuleViolation | None = None

    @property
    def estimated_minutes(self) -> int | None:
        """Délai annoncé : préparation en cuisine **plus** course.

        Les deux, parce que c'est ce que le client attend réellement. La zone ne
        connaît que le trajet, et l'annoncer seul promettait un repas en
        trente minutes là où la cuisine en demande vingt de plus.
        """
        if self.zone is None:
            return None
        preparation = (
            self.restaurant.default_preparation_minutes if self.restaurant is not None else 0
        )
        return preparation + self.zone.estimated_delivery_minutes


def check_delivery(
    *,
    point: Point,
    restaurant: Restaurant | None = None,
    subtotal: Money | None = None,
) -> DeliveryAvailability:
    """Livrabilité d'un point : établissement, zone, distance, frais, délai.

    Sans `restaurant`, la fonction **choisit** le plus proche parmi ceux qui
    desservent le point. C'est ce que demande l'application cliente : obliger
    quelqu'un à désigner une cuisine que la géographie détermine est une étape
    sans décision.

    Avec `restaurant`, elle vérifie *celui-là* — le cas du panier déjà ouvert,
    où changer d'établissement changerait le catalogue et les prix.

    Les refus sont ordonnés du plus général au plus précis, pour que le message
    rendu soit le plus actionnable : d'abord « personne ne dessert ici »,
    ensuite « hors zone », ensuite « trop loin », enfin « panier trop léger ».
    Inverser cet ordre ferait dire « ajoutez un article » à quelqu'un qui habite
    à trois cents kilomètres.
    """
    if restaurant is None:
        restaurant = _plus_proche_desservant(point)
        if restaurant is None:
            return DeliveryAvailability(
                is_available=False,
                restaurant=None,
                zone=None,
                distance_m=None,
                quote=None,
                reason="Aucun établissement ne dessert cette adresse pour le moment.",
            )

    zone = resolve_zone(point, restaurant_id=restaurant.pk)
    if zone is None:
        return DeliveryAvailability(
            is_available=False,
            restaurant=restaurant,
            zone=None,
            distance_m=None,
            quote=None,
            reason="Cette adresse n'est couverte par aucune zone de livraison.",
            refusal=BusinessRuleViolation(
                "Cette adresse n'est couverte par aucune zone de livraison."
            ),
        )

    distance_m = _distance_metres(restaurant, point)

    # Au-delà du rayon maximal, la course est refusée **même si le point est
    # dans le contour** : un contour se dessine large, la distance réellement
    # parcourue est ce qui coûte. Le dire ici évite qu'un écran annonce
    # « desservi » et que la commande échoue trois écrans plus loin.
    if distance_m is not None and Decimal(str(distance_m)) / 1000 > zone.max_distance_km:
        return DeliveryAvailability(
            is_available=False,
            restaurant=restaurant,
            zone=zone,
            distance_m=distance_m,
            quote=None,
            reason=(
                f"Adresse à {distance_m / 1000:.1f} km, au-delà des "
                f"{zone.max_distance_km} km desservis depuis cet établissement."
            ),
            refusal=BusinessRuleViolation(
                f"Adresse à {distance_m / 1000:.1f} km, au-delà des "
                f"{zone.max_distance_km} km desservis depuis cet établissement.",
                distance_km=f"{distance_m / 1000:.2f}",
                max_distance_km=str(zone.max_distance_km),
            ),
        )

    quote = None
    if subtotal is not None and distance_m is not None:
        try:
            quote = quote_delivery(zone=zone, distance_m=distance_m, subtotal=subtotal)
        except BusinessRuleViolation as refus:
            # Un panier trop léger ou libellé dans une autre devise ne rend pas
            # l'adresse indesservie : il rend *cette commande* impossible. La
            # nuance décide de ce que l'écran propose — ajouter un article,
            # plutôt que changer d'adresse.
            return DeliveryAvailability(
                is_available=False,
                restaurant=restaurant,
                zone=zone,
                distance_m=distance_m,
                quote=None,
                reason=str(refus),
                refusal=refus,
            )

    return DeliveryAvailability(
        is_available=True,
        restaurant=restaurant,
        zone=zone,
        distance_m=distance_m,
        quote=quote,
    )


def overlapping_zones(zone: DeliveryZone) -> list[DeliveryZone]:
    """Zones actives dont le contour recoupe celui-ci — l'avertissement du back-office.

    **Un chevauchement n'est pas une faute.** Une zone « Centre-ville » posée
    dans une zone « Grand Lomé » est la façon normale d'exprimer une exception
    tarifaire, et `resolve_zone` sait laquelle l'emporte. L'écran le signale
    pour que la décision soit consciente, jamais pour empêcher l'écriture.

    La comparaison est faite en base, par `intersects` sur l'index GiST : la
    charger en Python obligerait à sortir des contours de plusieurs kilo-octets
    pour n'en garder qu'un booléen.
    """
    return list(
        DeliveryZone.objects.filter(
            boundary__intersects=zone.boundary,
            is_active=True,
            city__country=zone.city.country_id,
        )
        .exclude(pk=zone.pk)
        .select_related("city")
        .order_by("name")[:20]
    )


def _plus_proche_desservant(point: Point) -> Restaurant | None:
    """Établissement en service le plus proche dont une zone couvre ce point.

    La **couverture est vérifiée avant la proximité**, et l'ordre compte : le
    restaurant le plus proche à vol d'oiseau n'est pas nécessairement celui qui
    dessert l'adresse — un fleuve, une limite de zone ou un marché voisin
    peuvent l'en séparer. Trier d'abord par distance puis filtrer donnerait
    « aucun » là où un établissement un peu plus loin dessert parfaitement.
    """
    servants = Restaurant.objects.filter(
        is_active=True,
        zone__is_active=True,
        zone__city__is_active=True,
        zone__city__country__is_active=True,
    )

    # Deux familles de zones couvrent le point, et il faut les deux.
    #
    # **Les municipales désignent une ville, pas un établissement.** Une zone
    # appartient à une ville et décrit *où l'on livre* ; ce sont donc les
    # cuisines de cette ville qui la servent, et non les seules dont c'est aussi
    # la zone de rattachement. Confondre les deux — filtrer sur
    # `Restaurant.zone`, qui dit où l'établissement est **posé** — rendait
    # « personne ne dessert ici » dès que le client habitait une zone autre que
    # celle du restaurant, ce qui est le cas normal d'une ville à plusieurs
    # zones.
    villes = set(
        covering_zones(point).filter(restaurant__isnull=True).values_list("city_id", flat=True)
    )
    proprietaires = set(
        covering_zones(point)
        .filter(restaurant__isnull=False)
        .values_list("restaurant_id", flat=True)
    )

    candidats = servants.filter(Q(zone__city_id__in=villes) | Q(pk__in=proprietaires))

    return candidats.annotate(vers=Distance("location", point)).order_by("vers").first()


def _distance_metres(restaurant: Restaurant, point: Point) -> float | None:
    """Distance à vol d'oiseau, mesurée par PostGIS sur l'ellipsoïde.

    En mètres et sans projection à choisir : c'est ce que donne le type
    `geography`, et c'est ce qui rend la mesure juste à toute latitude. La
    calculer en Python demanderait de choisir une formule et une sphère, et de
    la maintenir cohérente avec celle que la base utilise déjà pour trier.
    """
    distance = (
        Restaurant.objects.filter(pk=restaurant.pk)
        .annotate(vers=Distance("location", point))
        .values_list("vers", flat=True)
        .first()
    )
    return distance.m if distance is not None else None
