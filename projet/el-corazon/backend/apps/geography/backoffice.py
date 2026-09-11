"""Administration de la hiérarchie géographique — ADR-006.

Pays, villes et zones sont des objets **d'enseigne** : aucun n'appartient à un
établissement. Le cloisonnement du personnel ne peut donc rien en dire, et le
défaut sûr est le refus — l'écriture est réservée aux comptes non cloisonnés
(`assert_unscoped`), la lecture ouverte à `restaurants.read`.

C'est ici que vit le barème de frais de livraison. L'implémentation précédente
n'en avait pas : une constante, contradictoire d'un fichier à l'autre (`5.00`
contre `500.0`), ce qui trahissait l'absence de toute règle. Un frais se décide
désormais par zone, en donnée, depuis cet écran.

La suppression n'est exposée nulle part. Un pays, une ville et une zone sont
référencés par des commandes, des adresses et des établissements — les clés
étrangères sont d'ailleurs en `PROTECT`, si bien qu'un `DELETE` échouerait en
violation d'intégrité plutôt que par une règle lisible. `is_active` est le
geste qui correspond à l'intention : on ferme un marché, on ne l'efface pas.
"""

from __future__ import annotations

from typing import Any, ClassVar

from rest_framework.mixins import (
    CreateModelMixin,
    ListModelMixin,
    RetrieveModelMixin,
    UpdateModelMixin,
)
from rest_framework.viewsets import GenericViewSet

from apps.geography.models import City, Country, DeliveryZone
from apps.geography.serializers import (
    ManagedCitySerializer,
    ManagedCountrySerializer,
    ManagedDeliveryZoneSerializer,
)
from common.audit import AuditAction, record_change
from common.permissions import HasReadWritePermission, assert_unscoped, authenticated_user

__all__ = ["ManagedCityViewSet", "ManagedCountryViewSet", "ManagedDeliveryZoneViewSet"]

GEOGRAPHY_PERMISSION = HasReadWritePermission.of(read="restaurants.read", write="restaurants.write")


class _SiegeViewSet[Model: (Country, City, DeliveryZone)](
    ListModelMixin,
    RetrieveModelMixin,
    CreateModelMixin,
    UpdateModelMixin,
    GenericViewSet[Model],
):
    """Ressource d'enseigne : lisible par le personnel, écrite par le siège."""

    permission_classes = (GEOGRAPHY_PERMISSION,)

    #: Ce qu'on refuse d'écrire, nommé pour le message d'erreur.
    quoi: str = ""

    def perform_create(self, serializer: Any) -> None:
        assert_unscoped(authenticated_user(self.request), self.quoi)
        serializer.save()

    def perform_update(self, serializer: Any) -> None:
        assert_unscoped(authenticated_user(self.request), self.quoi)
        serializer.save()


class ManagedCountryViewSet(_SiegeViewSet[Country]):
    quoi = "L'ouverture d'un pays"
    serializer_class = ManagedCountrySerializer
    queryset = Country.objects.order_by("name")
    # Adressé par son code ISO, comme la route publique — et comme le reste du
    # back-office adresse ses ressources par leur clé fonctionnelle (un
    # établissement par son slug, une ville par le code de son pays). La vue
    # attendait une clé primaire, seule de son espèce : `PATCH
    # /geography/manage/countries/CI/` sortait donc en 404, et fermer un marché
    # supposait de connaître l'UUID d'un pays — que rien, dans aucune des trois
    # applications, ne transporte.
    lookup_field = "iso_code"
    filterset_fields: ClassVar[dict[str, list[str]]] = {"is_active": ["exact"]}
    search_fields: ClassVar[list[str]] = ["name", "iso_code"]


class ManagedCityViewSet(_SiegeViewSet[City]):
    quoi = "L'ouverture d'une ville"
    serializer_class = ManagedCitySerializer
    queryset = City.objects.select_related("country").order_by("name")
    filterset_fields: ClassVar[dict[str, list[str]]] = {
        "country__iso_code": ["exact"],
        "is_active": ["exact"],
    }
    search_fields: ClassVar[list[str]] = ["name"]


class ManagedDeliveryZoneViewSet(_SiegeViewSet[DeliveryZone]):
    """Zones et barèmes — **journalisés**, contrairement au reste du back-office.

    Un contour redessiné et un forfait doublé ont une propriété qui les
    distingue : ils sont silencieux et coûteux. Un catalogue mal saisi se voit à
    l'écran ; un rayon réduit de deux kilomètres ne se voit que dans les
    commandes qu'on ne reçoit plus. C'est pourquoi ces deux écritures-là
    laissent une trace, et pas les autres — voir `common.audit`.
    """

    quoi = "Le barème d'une zone"
    serializer_class = ManagedDeliveryZoneSerializer
    queryset = DeliveryZone.objects.select_related("city__country", "restaurant").order_by(
        "city__name", "name"
    )
    filterset_fields: ClassVar[dict[str, list[str]]] = {
        "city": ["exact"],
        "city__slug": ["exact"],
        "restaurant__slug": ["exact"],
        "shape": ["exact"],
        "is_active": ["exact"],
    }
    search_fields: ClassVar[list[str]] = ["name"]

    def perform_update(self, serializer: Any) -> None:
        avant = _empreinte_de_zone(serializer.instance)
        super().perform_update(serializer)
        self._journaliser(avant, serializer.instance)

    def _journaliser(self, avant: dict[str, Any], zone: DeliveryZone) -> None:
        """Deux entrées possibles : le contour, et le barème.

        Séparées parce qu'elles répondent à deux questions différentes —
        « jusqu'où livre-t-on ? » et « combien fait-on payer ? » — et qu'on les
        pose rarement ensemble. Fondues, il faudrait lire les deux valeurs pour
        savoir laquelle a bougé.
        """
        acteur = authenticated_user(self.request)
        apres = _empreinte_de_zone(zone)

        if avant["geometrie"] != apres["geometrie"]:
            record_change(
                actor=acteur,
                action=AuditAction.ZONE_BOUNDARY,
                target_type="zone",
                target_id=zone.pk,
                target_label=f"{zone.name} — {zone.city.name}",
                before=avant["geometrie"],
                after=apres["geometrie"],
            )

        if avant["bareme"] != apres["bareme"]:
            record_change(
                actor=acteur,
                action=AuditAction.ZONE_TARIFF,
                target_type="zone",
                target_id=zone.pk,
                target_label=f"{zone.name} — {zone.city.name}",
                before=avant["bareme"],
                after=apres["bareme"],
            )

        if avant["is_active"] != apres["is_active"]:
            record_change(
                actor=acteur,
                action=AuditAction.ZONE_ACTIVATION,
                target_type="zone",
                target_id=zone.pk,
                target_label=f"{zone.name} — {zone.city.name}",
                before={"is_active": avant["is_active"]},
                after={"is_active": apres["is_active"]},
            )


def _empreinte_de_zone(zone: DeliveryZone) -> dict[str, Any]:
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
        "is_active": zone.is_active,
    }
