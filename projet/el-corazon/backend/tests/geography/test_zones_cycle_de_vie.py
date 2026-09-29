"""Cycle de vie, horaires, départage et outillage des zones — chantier du 2026-09-28.

Ce que la suite garde fermé :

* une zone née au back-office **ne tarife rien** avant d'avoir été relue et
  publiée ; une zone suspendue ou fermée s'efface devant celle qui l'entoure,
  et sinon le refus dit *pourquoi* (`zone_closed`, `zone_suspended`) ;
* l'égalité parfaite entre deux zones rend **toujours la même** ;
* un point dans le trou d'un contour n'est pas couvert ;
* l'outil « Tester une adresse » rend ce que la commande ferait ;
* rien de tout cela ne s'écrit sans la permission, ni hors de son périmètre.
"""

from __future__ import annotations

import datetime as dt
from typing import Any

import pytest
from django.contrib.gis.geos import MultiPolygon, Point, Polygon
from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from apps.accounts.models import Role, User, UserType
from apps.delivery.models import CourierProfile
from apps.delivery.states import VerificationStatus
from apps.geography.models import (
    City,
    DeliveryZone,
    ZoneExceptionKind,
    ZoneOpeningHours,
    ZoneScheduleException,
)
from apps.geography.resolution import explain_resolution, resolve_zone
from apps.geography.states import ZoneStatus
from apps.restaurants.delivery import check_delivery
from apps.restaurants.models import Restaurant, StaffMembership
from common.models import AuditEntry
from common.money import Money

pytestmark = [pytest.mark.django_db, pytest.mark.postgis]

XOF = "XOF"
LOME = Point(1.2255, 6.1319, srid=4326)
LISTE = "v1:geography:managed-zone-list"


def carre(x0: float, y0: float, x1: float, y1: float) -> dict[str, Any]:
    return {
        "type": "Polygon",
        "coordinates": [[[x0, y0], [x1, y0], [x1, y1], [x0, y1], [x0, y0]]],
    }


def contour(x0: float, y0: float, x1: float, y1: float) -> MultiPolygon:
    return MultiPolygon(
        Polygon(((x0, y0), (x1, y0), (x1, y1), (x0, y1), (x0, y0)), srid=4326), srid=4326
    )


def zone_en_base(city: City, nom: str, forme: MultiPolygon, **champs: Any) -> DeliveryZone:
    return DeliveryZone.objects.create(
        city=city,
        name=nom,
        boundary=forme,
        base_fee=Money(champs.pop("forfait", 500), XOF),
        fee_per_km=Money(0, XOF),
        **champs,
    )


def connecte(user: User) -> APIClient:
    client = APIClient()
    client.force_authenticate(user)
    return client


def personnel(email: str, *permissions: str, restaurant: Restaurant | None = None) -> User:
    membre = User.objects.create_user(
        email, "motdepasse", full_name="Personnel", user_type=UserType.STAFF
    )
    membre.roles.add(Role.objects.create(name=f"Rôle {email}", permissions=list(permissions)))
    if restaurant is not None:
        StaffMembership.objects.create(user=membre, restaurant=restaurant)
    return membre


@pytest.fixture
def siege() -> APIClient:
    return connecte(User.objects.create_superuser("siege@elcorazon.test", "motdepasse"))


def geste(client: APIClient, nom: str, zone_id: Any, **corps: Any) -> Any:
    return client.post(
        reverse(f"v1:geography:managed-zone-{nom}", args=[zone_id]), corps, format="json"
    )


def creer(client: APIClient, city: City, nom: str = "Bè", **champs: Any) -> Any:
    corps = {
        "city": str(city.pk),
        "name": nom,
        "boundary": carre(1.20, 6.12, 1.24, 6.15),
        "base_fee": {"amount": "700", "currency": XOF},
        "fee_per_km": {"amount": "0", "currency": XOF},
        **champs,
    }
    return client.post(reverse(LISTE), corps, format="json")


def couverture(client: APIClient, **corps: Any) -> Any:
    return client.post(reverse("v1:delivery:coverage-test"), corps, format="json")


# ================================================================ cycle de vie


class TestCycleDeVie:
    def test_une_zone_creee_nait_en_brouillon_et_ne_tarife_rien(
        self, siege: APIClient, city: City, zone: DeliveryZone
    ) -> None:
        reponse = creer(siege, city, priority=10, is_active=True)

        assert reponse.status_code == 201, reponse.data
        assert reponse.data["status"] == "draft"
        assert reponse.data["is_active"] is False
        assert reponse.data["created_by"] is not None
        # La zone du décor, publiée, reste celle qui s'applique.
        assert resolve_zone(LOME) == zone

    def test_brouillon_revue_publication_puis_suspension_et_retour(
        self, siege: APIClient, city: City, zone: DeliveryZone
    ) -> None:
        cree = creer(siege, city, priority=10).data

        assert geste(siege, "submit", cree["id"]).data["status"] == "pending_review"
        publiee = geste(siege, "publish", cree["id"]).data
        assert publiee["status"] == "published"
        assert publiee["published_by"] is not None
        assert str(resolve_zone(LOME).pk) == cree["id"]  # type: ignore[union-attr]

        assert geste(siege, "suspend", cree["id"]).status_code == status.HTTP_409_CONFLICT

        fin = (timezone.now() + dt.timedelta(hours=6)).isoformat()
        suspendue = geste(siege, "suspend", cree["id"], reason="Coupure", expected_end_at=fin)
        assert suspendue.data["status"] == "suspended"
        assert suspendue.data["suspension_reason"] == "Coupure"
        # Suspendue, elle s'efface devant la zone qui l'entoure.
        assert resolve_zone(LOME) == zone

        assert geste(siege, "activate", cree["id"]).data["status"] == "published"

    def test_on_ne_publie_pas_un_brouillon_sans_revue(self, siege: APIClient, city: City) -> None:
        cree = creer(siege, city).data

        assert geste(siege, "publish", cree["id"]).status_code == status.HTTP_409_CONFLICT
        assert geste(siege, "activate", cree["id"]).status_code == status.HTTP_409_CONFLICT

    def test_archivee_est_terminale(self, siege: APIClient, zone: DeliveryZone) -> None:
        assert geste(siege, "archive", zone.pk).data["status"] == "archived"
        assert geste(siege, "activate", zone.pk).status_code == status.HTTP_409_CONFLICT
        assert geste(siege, "publish", zone.pk).status_code == status.HTTP_409_CONFLICT

    def test_rejouer_un_geste_ne_change_rien(self, siege: APIClient, zone: DeliveryZone) -> None:
        avant = AuditEntry.objects.filter(action="zone.status").count()

        assert geste(siege, "publish", zone.pk).status_code == 200

        assert AuditEntry.objects.filter(action="zone.status").count() == avant

    def test_chaque_passage_est_journalise_avec_son_motif(
        self, siege: APIClient, zone: DeliveryZone
    ) -> None:
        geste(siege, "suspend", zone.pk, reason="Inondations")

        entree = AuditEntry.objects.filter(action="zone.status", target_id=str(zone.pk)).get()
        assert entree.before == {"status": "published"}
        assert entree.after["status"] == "suspended"
        assert entree.after["reason"] == "Inondations"

    def test_l_ancien_is_active_passe_par_la_machine(
        self, siege: APIClient, city: City, zone: DeliveryZone
    ) -> None:
        fiche = reverse("v1:geography:managed-zone-detail", args=[zone.pk])

        eteinte = siege.patch(fiche, {"is_active": False}, format="json")
        assert eteinte.data["status"] == "suspended"
        rallumee = siege.patch(fiche, {"is_active": True}, format="json")
        assert rallumee.data["status"] == "published"

        brouillon = creer(siege, city).data
        refus = siege.patch(
            reverse("v1:geography:managed-zone-detail", args=[brouillon["id"]]),
            {"is_active": True},
            format="json",
        )
        assert refus.status_code == status.HTTP_409_CONFLICT

    def test_la_priorite_est_journalisee(self, siege: APIClient, zone: DeliveryZone) -> None:
        siege.patch(
            reverse("v1:geography:managed-zone-detail", args=[zone.pk]),
            {"priority": 5},
            format="json",
        )

        assert AuditEntry.objects.filter(action="zone.priority", target_id=str(zone.pk)).exists()


# ================================================================ validations


class TestValidations:
    @pytest.mark.parametrize(
        ("champ", "valeur"),
        [
            ("priority", -1),
            ("estimated_delivery_minutes", 0),
            ("max_distance_km", "0"),
            ("base_fee", {"amount": "-100", "currency": XOF}),
        ],
    )
    def test_valeurs_refusees(self, siege: APIClient, city: City, champ: str, valeur: Any) -> None:
        assert creer(siege, city, **{champ: valeur}).status_code == status.HTTP_400_BAD_REQUEST

    def test_un_contour_loin_de_sa_ville_est_refuse(self, siege: APIClient, city: City) -> None:
        # Abidjan, pour une zone de Lomé : un clic dans le mauvais onglet.
        reponse = creer(siege, city, boundary=carre(-4.05, 5.30, -3.95, 5.40))

        assert reponse.status_code == status.HTTP_400_BAD_REQUEST
        assert "Lomé" in str(reponse.data)

    def test_la_ville_d_une_zone_ne_change_pas(
        self, siege: APIClient, zone: DeliveryZone, city: City
    ) -> None:
        autre = City.objects.create(
            country=city.country, name="Kara", slug="kara", centroid=Point(1.19, 9.55, srid=4326)
        )
        reponse = siege.patch(
            reverse("v1:geography:managed-zone-detail", args=[zone.pk]),
            {"city": str(autre.pk)},
            format="json",
        )

        assert reponse.status_code == status.HTTP_400_BAD_REQUEST


# ================================================================ départage


class TestDepartage:
    def test_egalite_parfaite_toujours_la_meme(self, city: City) -> None:
        DeliveryZone.objects.filter(city=city).update(status="suspended", is_active=False)
        a = zone_en_base(city, "A", contour(1.20, 6.10, 1.25, 6.15))
        b = zone_en_base(city, "B", contour(1.20, 6.10, 1.25, 6.15))
        attendue = min(a, b, key=lambda z: str(z.pk))

        assert {resolve_zone(LOME) for _ in range(5)} == {attendue}
        assert "identifiant" in explain_resolution(LOME).reason

    def test_la_priorite_l_emporte_sur_la_surface_et_s_explique(
        self, city: City, zone: DeliveryZone
    ) -> None:
        DeliveryZone.objects.filter(city=city).update(status="suspended", is_active=False)
        zone_en_base(city, "Petite", contour(1.22, 6.12, 1.23, 6.14))
        grande = zone_en_base(city, "Grande", contour(1.10, 6.00, 1.35, 6.25), priority=3)

        explication = explain_resolution(LOME)

        assert explication.zone == grande
        assert "Priorité" in explication.reason
        exclues = {c.zone.name: c.excluded_because for c in explication.candidates}
        assert exclues["Petite"] is None  # concourait, a perdu
        assert exclues["Centre"] == "suspended"

    def test_un_point_dans_le_trou_n_est_pas_couvert(self, city: City) -> None:
        DeliveryZone.objects.filter(city=city).update(status="suspended", is_active=False)
        exterieur = ((1.10, 6.00), (1.35, 6.00), (1.35, 6.25), (1.10, 6.25), (1.10, 6.00))
        trou = ((1.22, 6.12), (1.23, 6.12), (1.23, 6.14), (1.22, 6.14), (1.22, 6.12))
        deux_morceaux = MultiPolygon(
            Polygon(exterieur, trou, srid=4326),
            Polygon(((1.40, 6.0), (1.45, 6.0), (1.45, 6.1), (1.40, 6.1), (1.40, 6.0)), srid=4326),
            srid=4326,
        )
        anneau = zone_en_base(city, "Anneau", deux_morceaux)

        assert resolve_zone(LOME) is None
        assert resolve_zone(Point(1.15, 6.05, srid=4326)) == anneau
        assert resolve_zone(Point(1.42, 6.05, srid=4326)) == anneau


# ================================================================ horaires


def a_lome(heure: int, jour: int = 30) -> dt.datetime:
    """Un instant fixe de septembre 2026 à Lomé (UTC+0) ; le 30 est un mercredi."""
    return dt.datetime(2026, 9, jour, heure, 0, tzinfo=dt.UTC)


class TestHoraires:
    def test_sans_plage_la_zone_suit_sa_cuisine(self, zone: DeliveryZone) -> None:
        assert resolve_zone(LOME, at=a_lome(3)) == zone

    def test_hors_plage_la_zone_est_fermee_et_le_refus_le_dit(
        self, restaurant: Restaurant, zone: DeliveryZone
    ) -> None:
        ZoneOpeningHours.objects.create(
            zone=zone, weekday=2, opens_at=dt.time(11), closes_at=dt.time(22)
        )
        ZoneOpeningHours.objects.create(
            zone=zone, weekday=3, opens_at=dt.time(11), closes_at=dt.time(22)
        )

        assert resolve_zone(LOME, at=a_lome(12)) == zone
        verdict = check_delivery(point=LOME, restaurant=restaurant, at=a_lome(23))

        assert not verdict.is_available
        assert verdict.unavailable_code == "zone_closed"
        assert verdict.resolution is not None
        assert verdict.resolution.reopens_at == dt.datetime(2026, 10, 1, 11, tzinfo=dt.UTC)

    def test_une_plage_qui_franchit_minuit(self, zone: DeliveryZone) -> None:
        ZoneOpeningHours.objects.create(
            zone=zone, weekday=1, opens_at=dt.time(20), closes_at=dt.time(2)
        )

        assert resolve_zone(LOME, at=a_lome(1)) == zone  # mercredi 1 h, plage du mardi
        assert resolve_zone(LOME, at=a_lome(3)) is None

    def test_fermeture_puis_ouverture_exceptionnelles(self, zone: DeliveryZone) -> None:
        moment = a_lome(12)
        ZoneScheduleException.objects.create(
            zone=zone,
            kind=ZoneExceptionKind.CLOSED,
            starts_at=moment - dt.timedelta(hours=1),
            ends_at=moment + dt.timedelta(hours=1),
            reason="Fête nationale",
        )
        assert resolve_zone(LOME, at=moment) is None
        assert resolve_zone(LOME, at=moment + dt.timedelta(hours=2)) == zone

        ZoneOpeningHours.objects.create(
            zone=zone, weekday=2, opens_at=dt.time(11), closes_at=dt.time(14)
        )
        ZoneScheduleException.objects.create(
            zone=zone,
            kind=ZoneExceptionKind.OPEN,
            starts_at=a_lome(20),
            ends_at=a_lome(23),
            reason="Finale",
        )
        assert resolve_zone(LOME, at=a_lome(19)) is None
        assert resolve_zone(LOME, at=a_lome(21)) == zone

    def test_zone_suspendue_sans_relais(self, restaurant: Restaurant, zone: DeliveryZone) -> None:
        zone.status = ZoneStatus.SUSPENDED
        zone.save()

        verdict = check_delivery(point=LOME, restaurant=restaurant)

        assert verdict.unavailable_code == "zone_suspended"

    @pytest.mark.parametrize("ecartee", ["suspended", "closed"])
    def test_une_zone_englobante_prend_le_relais(
        self, restaurant: Restaurant, zone: DeliveryZone, city: City, ecartee: str
    ) -> None:
        """Une zone écartée **passe la main** à la suivante qui couvre le point.

        Une petite zone posée dans une grande est une exception (tarif, délai) ;
        la suspendre ou la fermer rend ses adresses à la règle générale, elle ne
        les coupe pas. Pour cesser de livrer un quartier, il faut écarter
        **toutes** les zones qui le couvrent — la fiche de la zone le rappelle.
        """
        quartier = zone_en_base(city, "Quartier", contour(1.22, 6.12, 1.23, 6.14), priority=5)
        assert check_delivery(point=LOME, restaurant=restaurant, at=a_lome(20)).zone == quartier

        if ecartee == "suspended":
            quartier.status = ZoneStatus.SUSPENDED
            quartier.save()
        else:
            ZoneOpeningHours.objects.create(
                zone=quartier, weekday=2, opens_at=dt.time(11), closes_at=dt.time(12)
            )
        verdict = check_delivery(point=LOME, restaurant=restaurant, at=a_lome(20))

        assert verdict.is_available
        assert verdict.zone == zone
        assert verdict.resolution is not None
        exclues = {c.zone.name: c.excluded_because for c in verdict.resolution.candidates}
        assert exclues["Quartier"] == ecartee

    def test_la_semaine_s_ecrit_entiere_et_se_journalise(
        self, siege: APIClient, zone: DeliveryZone
    ) -> None:
        url = reverse("v1:geography:managed-zone-schedule", args=[zone.pk])
        reponse = siege.put(
            url,
            {"hours": [{"weekday": 0, "opens_at": "11:00", "closes_at": "22:00"}]},
            format="json",
        )

        assert reponse.status_code == 200, reponse.data
        assert zone.opening_hours.count() == 1
        assert AuditEntry.objects.filter(action="zone.schedule").exists()

        vide = siege.put(url, {"hours": []}, format="json")
        assert vide.data == {"hours": []}

    def test_exception_creee_puis_retiree(self, siege: APIClient, zone: DeliveryZone) -> None:
        debut = timezone.now() + dt.timedelta(days=1)
        cree = siege.post(
            reverse("v1:geography:managed-zone-exceptions", args=[zone.pk]),
            {
                "kind": "closed",
                "starts_at": debut.isoformat(),
                "ends_at": (debut + dt.timedelta(hours=4)).isoformat(),
                "reason": "Jour férié",
            },
            format="json",
        )
        assert cree.status_code == 201, cree.data

        retrait = siege.delete(
            reverse("v1:geography:managed-zone-remove-exception", args=[zone.pk, cree.data["id"]])
        )
        assert retrait.status_code == 204
        assert not zone.exceptions.exists()


# ================================================================ duplication et import


class TestDuplicationEtImport:
    def test_la_copie_nait_en_brouillon_avec_horaires_sans_exceptions(
        self, siege: APIClient, zone: DeliveryZone
    ) -> None:
        ZoneOpeningHours.objects.create(
            zone=zone, weekday=0, opens_at=dt.time(11), closes_at=dt.time(22)
        )
        ZoneScheduleException.objects.create(
            zone=zone,
            kind=ZoneExceptionKind.CLOSED,
            starts_at=timezone.now(),
            ends_at=timezone.now() + dt.timedelta(hours=1),
        )

        copie = geste(siege, "duplicate", zone.pk, name="Centre bis")

        assert copie.status_code == 201, copie.data
        assert copie.data["status"] == "draft"
        cree = DeliveryZone.objects.get(pk=copie.data["id"])
        assert cree.base_fee == zone.base_fee
        assert cree.boundary.equals(zone.boundary)
        assert cree.opening_hours.count() == 1
        assert not cree.exceptions.exists()

    def test_la_copie_refuse_un_nom_pris(self, siege: APIClient, zone: DeliveryZone) -> None:
        assert geste(siege, "duplicate", zone.pk, name="Centre").status_code == 409

    def test_import_previsualise_puis_cree(
        self, siege: APIClient, city: City, zone: DeliveryZone
    ) -> None:
        collection = {
            "type": "FeatureCollection",
            "features": [
                {
                    "type": "Feature",
                    "properties": {},
                    "geometry": {
                        "type": "Polygon",
                        "coordinates": [
                            [[1.10, 6.00], [1.35, 6.00], [1.35, 6.25], [1.10, 6.25], [1.10, 6.00]],
                            [[1.22, 6.12], [1.23, 6.12], [1.23, 6.14], [1.22, 6.14], [1.22, 6.12]],
                        ],
                    },
                }
            ],
        }
        url = reverse("v1:geography:managed-zone-import-geojson")
        corps = {"city": str(city.pk), "name": "Import", "geojson": collection}

        apercu = siege.post(url, corps, format="json")
        assert apercu.status_code == 200, apercu.data
        assert apercu.data["holes"] == 1
        assert [c["name"] for c in apercu.data["overlaps"]] == ["Centre"]
        assert not DeliveryZone.objects.filter(name="Import").exists()

        cree = siege.post(url, {**corps, "dry_run": False}, format="json")
        assert cree.status_code == 201, cree.data
        assert cree.data["status"] == "draft"

    @pytest.mark.parametrize(
        "geojson",
        [
            {"type": "Point", "coordinates": [1.2, 6.1]},
            {"type": "FeatureCollection", "features": []},
            {"type": "Polygon", "coordinates": [[[1.2, 6.1], [1.3, 6.1], [1.3, 200], [1.2, 6.1]]]},
            "pas du json",
        ],
    )
    def test_import_refuse(self, siege: APIClient, city: City, geojson: Any) -> None:
        reponse = siege.post(
            reverse("v1:geography:managed-zone-import-geojson"),
            {"city": str(city.pk), "name": "X", "geojson": geojson},
            format="json",
        )

        assert reponse.status_code == 400


# ================================================================ couverture


class TestTesterUneAdresse:
    def test_adresse_couverte(
        self, siege: APIClient, restaurant: Restaurant, zone: DeliveryZone
    ) -> None:
        livreur = User.objects.create_user("livreur@x.test", "mdp", full_name="Kofi")
        profil = CourierProfile.objects.create(
            user=livreur,
            restaurant=restaurant,
            is_online=False,
            verification_status=VerificationStatus.APPROVED,
        )

        reponse = couverture(
            siege, lat=6.1319, lon=1.2255, subtotal={"amount": "5000", "currency": XOF}
        )

        assert reponse.status_code == 200, reponse.data
        assert reponse.data["available"] is True
        assert reponse.data["zone"]["name"] == "Centre"
        assert reponse.data["kitchen"]["slug"] == restaurant.slug
        assert reponse.data["delivery_fee"] == {"amount": "500", "currency": XOF}
        assert reponse.data["country"] == "TG"
        assert reponse.data["couriers"] == [
            {
                "id": str(profil.pk),
                "name": "Kofi",
                "is_online": False,
                "eligible": False,
                "reason": "offline",
            }
        ]

    def test_adresse_non_couverte_donne_la_zone_la_plus_proche(
        self, siege: APIClient, restaurant: Restaurant
    ) -> None:
        reponse = couverture(siege, lat=6.40, lon=1.20)

        assert reponse.data["available"] is False
        assert reponse.data["nearest_zone"]["name"] == "Centre"
        assert reponse.data["nearest_zone"]["distance_m"] > 10_000

    def test_cuisines_et_livreurs_de_la_zone(
        self, siege: APIClient, restaurant: Restaurant, zone: DeliveryZone
    ) -> None:
        cuisines = siege.get(reverse("v1:delivery:zone-kitchens", args=[zone.pk]))
        livreurs = siege.get(reverse("v1:delivery:zone-couriers", args=[zone.pk]))

        assert cuisines.data["rule"] == "city"
        assert [c["slug"] for c in cuisines.data["kitchens"]] == [restaurant.slug]
        assert cuisines.data["kitchens"][0]["distance_m"] == 0
        assert livreurs.data["kitchens"][0]["kitchen"] == restaurant.slug


# ================================================================ permissions


class TestPermissions:
    def test_sans_ecriture_on_lit_mais_on_ne_suspend_pas(
        self, zone: DeliveryZone, restaurant: Restaurant
    ) -> None:
        lecteur = connecte(personnel("lecteur@x.test", "restaurants.read"))

        assert geste(lecteur, "suspend", zone.pk, reason="x").status_code == 403
        assert couverture(lecteur, lat=6.13, lon=1.22).status_code == 200

    def test_un_gerant_ne_suspend_pas_une_zone_de_ville(
        self, zone: DeliveryZone, restaurant: Restaurant
    ) -> None:
        gerant = connecte(
            personnel(
                "gerant@x.test", "restaurants.read", "restaurants.write", restaurant=restaurant
            )
        )

        assert geste(gerant, "suspend", zone.pk, reason="x").status_code == 403

    def test_sans_permission_pas_d_outil_de_couverture(self) -> None:
        assert couverture(connecte(personnel("rien@x.test")), lat=6.13, lon=1.22).status_code == 403


# ================================================================ suppression


class TestSuppressionDUneZonePropre:
    def test_une_zone_qui_a_tarife_est_archivee_pas_effacee(
        self, siege: APIClient, city: City, restaurant: Restaurant, order: Any
    ) -> None:
        propre = zone_en_base(
            city, "Propre", contour(1.20, 6.12, 1.24, 6.15), restaurant=restaurant
        )
        order.delivery_zone = propre
        order.save(update_fields=["delivery_zone"])

        reponse = siege.delete(
            reverse("v1:restaurants:managed-restaurant-zone-detail", args=[propre.pk])
        )

        assert reponse.status_code == 204
        propre.refresh_from_db()
        assert propre.status == ZoneStatus.ARCHIVED
        order.refresh_from_db()
        assert order.delivery_zone_id == propre.pk
