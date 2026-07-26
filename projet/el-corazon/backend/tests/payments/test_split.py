"""Paiement partagé — invariant P2.

Cette suite est écrite comme une suite d'attaques sur **la faille la plus grave
de l'implémentation précédente** : n'importe quel participant pouvait se
déclarer payé, ce qui basculait la commande entière en `completed`. Un repas
gratuit, reproduit à l'époque. Le correctif d'alors avait restreint l'action aux
administrateurs, sans construire le vrai flux.

Le test qui porte l'ensemble est
`test_une_part_ne_se_solde_que_par_l_encaissement` : la part suit sa
transaction, elle ne décide de rien.
"""

from __future__ import annotations

import hashlib
import hmac
import json
from typing import Any

import pytest
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.orders.models import Order
from apps.orders.states import OrderStatus
from apps.payments.models import PaymentProvider, PaymentStatus, SplitPayment, SplitShare
from apps.payments.split import ParticipantInput, SplitService
from common.money import Money

pytestmark = [pytest.mark.django_db, pytest.mark.postgis]

XOF = "XOF"
SECRET = "secret-de-test"


@pytest.fixture
def webhook_secret(settings: Any) -> None:
    settings.PAYMENT_WEBHOOK_SECRET = SECRET


@pytest.fixture
def client() -> APIClient:
    return APIClient()


@pytest.fixture
def as_customer(customer: User) -> APIClient:
    separate = APIClient()
    separate.force_authenticate(customer)
    return separate


@pytest.fixture
def convives(customer: User) -> list[ParticipantInput]:
    return [
        ParticipantInput(display_name="Ama", user=customer),
        ParticipantInput(display_name="Kossi", phone="+22890111222"),
        ParticipantInput(display_name="Yao", phone="+22890333444"),
    ]


@pytest.fixture
def split(order: Order, customer: User, convives: list[ParticipantInput]) -> SplitPayment:
    return SplitService.create(order=order, initiator=customer, participants=convives)


def encaisse(client: APIClient, share: SplitShare) -> object:
    """Fait encaisser la transaction d'une part, par notification signée."""
    share.refresh_from_db()
    payload = {
        "event_id": f"evt-{share.pk}",
        "provider_reference": share.transaction.provider_reference,
        "status": PaymentStatus.COMPLETED,
    }
    body = json.dumps(payload).encode()
    signature = hmac.new(SECRET.encode(), body, hashlib.sha256).hexdigest()
    return client.post(
        reverse("v1:payments:webhook", args=[PaymentProvider.PAYDUNYA]),
        data=body,
        content_type="application/json",
        headers={"X-Signature": signature},
    )


class TestRepartition:
    def test_le_total_se_divise_sans_perdre_un_franc(self, split: SplitPayment) -> None:
        """4 000 F en trois donne 1 334, 1 333 et 1 333. Une division naïve en
        perdrait un à chaque commande, et l'écart ne se verrait qu'au
        rapprochement comptable."""
        montants = [part.amount.amount_minor for part in split.shares.all()]

        assert sum(montants) == 4_000
        assert sorted(montants) == [1_333, 1_333, 1_334]

    def test_des_montants_explicites_doivent_tomber_juste(
        self, order: Order, customer: User
    ) -> None:
        """Accepter un écart reviendrait à décider en silence qui paie la
        différence."""
        from common.exceptions import BusinessRuleViolation

        with pytest.raises(BusinessRuleViolation, match="ne fait pas le total"):
            SplitService.create(
                order=order,
                initiator=customer,
                participants=[
                    ParticipantInput(display_name="Ama", amount=Money(1_000, XOF)),
                    ParticipantInput(display_name="Kossi", amount=Money(1_000, XOF)),
                ],
            )

    def test_des_montants_explicites_justes_sont_acceptes(
        self, order: Order, customer: User
    ) -> None:
        """Quelqu'un a pris le dessert."""
        split = SplitService.create(
            order=order,
            initiator=customer,
            participants=[
                ParticipantInput(display_name="Ama", amount=Money(3_000, XOF)),
                ParticipantInput(display_name="Kossi", amount=Money(1_000, XOF)),
            ],
        )

        assert sorted(p.amount.amount_minor for p in split.shares.all()) == [1_000, 3_000]

    def test_un_participant_sans_compte_est_admis(self, split: SplitPayment) -> None:
        """La moitié des convives d'un repas partagé n'ont pas de compte, et
        exiger une inscription ferait échouer la fonctionnalité sur son cas le
        plus courant."""
        sans_compte = split.shares.filter(participant__isnull=True)

        assert sans_compte.count() == 2
        assert all(part.share_token for part in sans_compte)


class TestGardesDOuverture:
    def test_seul_le_client_ouvre_un_partage(
        self, order: Order, courier_user: User, convives: list[ParticipantInput]
    ) -> None:
        from common.exceptions import BusinessRuleViolation

        with pytest.raises(BusinessRuleViolation, match="Seul le client"):
            SplitService.create(order=order, initiator=courier_user, participants=convives)

    def test_pas_deux_partages_sur_une_commande(
        self, split: SplitPayment, order: Order, customer: User, convives: list[ParticipantInput]
    ) -> None:
        from common.exceptions import BusinessRuleViolation

        with pytest.raises(BusinessRuleViolation, match="déjà un partage"):
            SplitService.create(order=order, initiator=customer, participants=convives)

    def test_pas_de_partage_sur_une_commande_annulee(
        self, order: Order, customer: User, convives: list[ParticipantInput]
    ) -> None:
        from common.exceptions import BusinessRuleViolation

        Order.objects.filter(pk=order.pk).update(status=OrderStatus.CANCELLED)
        order.refresh_from_db()

        with pytest.raises(BusinessRuleViolation, match="annulée"):
            SplitService.create(order=order, initiator=customer, participants=convives)

    def test_un_partage_demande_au_moins_deux_convives(self, order: Order, customer: User) -> None:
        from common.exceptions import BusinessRuleViolation

        with pytest.raises(BusinessRuleViolation, match="deux participants"):
            SplitService.create(
                order=order,
                initiator=customer,
                participants=[ParticipantInput(display_name="Seul")],
            )

    def test_une_commande_partagee_ne_se_paie_plus_en_entier(
        self, as_customer: APIClient, split: SplitPayment, order: Order
    ) -> None:
        """Payer le tout solderait la commande en laissant des parts ouvertes :
        les autres paieraient une commande déjà réglée, ou ne paieraient
        jamais."""
        response = as_customer.post(reverse("v1:payments:initiate", args=[order.pk]))

        assert response.status_code == status.HTTP_409_CONFLICT
        assert "partagée" in response.data["detail"]


class TestP2:
    """Une part ne se solde que par un encaissement vérifié."""

    def test_une_part_ne_se_solde_que_par_l_encaissement(
        self, client: APIClient, split: SplitPayment, webhook_secret: None
    ) -> None:
        """Le cœur de la faille refermé : la part suit sa transaction, elle ne
        décide de rien."""
        part = split.shares.first()
        assert part is not None

        client.post(reverse("v1:payments:share", args=[part.share_token]))
        part.refresh_from_db()
        assert part.status == PaymentStatus.PROCESSING

        encaisse(client, part)

        part.refresh_from_db()
        assert part.status == PaymentStatus.COMPLETED
        assert part.transaction.is_settled

    def test_aucun_champ_d_entree_ne_porte_le_statut_d_une_part(self) -> None:
        """Il n'existe pas de chemin pour marquer une part payée : le champ
        n'est dans aucun sérialiseur d'entrée."""
        from apps.payments.serializers import ParticipantSerializer, SplitCreateSerializer

        assert "status" not in ParticipantSerializer().fields
        assert set(SplitCreateSerializer().fields) == {"participants"}

    def test_ouvrir_un_reglement_ne_solde_rien(
        self, client: APIClient, split: SplitPayment, order: Order
    ) -> None:
        part = split.shares.first()
        assert part is not None

        client.post(reverse("v1:payments:share", args=[part.share_token]))

        order.refresh_from_db()
        assert order.status == OrderStatus.PENDING
        part.refresh_from_db()
        assert part.status != PaymentStatus.COMPLETED

    def test_la_commande_n_est_confirmee_qu_au_dernier_paiement(
        self, client: APIClient, split: SplitPayment, order: Order, webhook_secret: None
    ) -> None:
        """Le paiement partiel ne confirme pas : c'est ce qui distingue un
        partage d'un acompte."""
        parts = list(split.shares.all())

        for part in parts[:-1]:
            client.post(reverse("v1:payments:share", args=[part.share_token]))
            encaisse(client, part)

        order.refresh_from_db()
        assert order.status == OrderStatus.PENDING

        client.post(reverse("v1:payments:share", args=[parts[-1].share_token]))
        encaisse(client, parts[-1])

        order.refresh_from_db()
        split.refresh_from_db()
        assert order.status == OrderStatus.CONFIRMED
        assert split.status == PaymentStatus.COMPLETED


class TestAccesParJeton:
    def test_un_convive_sans_compte_voit_sa_part(
        self, client: APIClient, split: SplitPayment
    ) -> None:
        part = split.shares.filter(participant__isnull=True).first()
        assert part is not None

        response = client.get(reverse("v1:payments:share", args=[part.share_token]))

        assert response.status_code == status.HTTP_200_OK
        assert response.data["display_name"] == part.display_name

    def test_le_lien_ne_montre_ni_la_commande_ni_les_autres(
        self, client: APIClient, split: SplitPayment
    ) -> None:
        """Le jeton donne accès à **une part**, pas au repas de quelqu'un
        d'autre."""
        part = split.shares.first()
        assert part is not None

        response = client.get(reverse("v1:payments:share", args=[part.share_token]))

        assert set(response.data) == {
            "id",
            "display_name",
            "phone",
            "amount",
            "status",
            "share_token",
            "created_at",
        }

    def test_un_jeton_inconnu_est_introuvable(self, client: APIClient) -> None:
        response = client.get(reverse("v1:payments:share", args=["jeton-invente"]))

        assert response.status_code == status.HTTP_404_NOT_FOUND

    def test_le_jeton_n_est_pas_derive_de_la_part(self, split: SplitPayment) -> None:
        """Les UUIDv7 sont ordonnés dans le temps, donc partiellement
        devinables. Un lien qui circule sur une messagerie ne peut pas s'appuyer
        dessus."""
        for part in split.shares.all():
            assert str(part.pk) not in part.share_token
            assert len(part.share_token) >= 32

    def test_une_part_deja_reglee_ne_se_repaie_pas(
        self, client: APIClient, split: SplitPayment, webhook_secret: None
    ) -> None:
        part = split.shares.first()
        assert part is not None
        client.post(reverse("v1:payments:share", args=[part.share_token]))
        encaisse(client, part)

        response = client.post(reverse("v1:payments:share", args=[part.share_token]))

        assert response.status_code == status.HTTP_409_CONFLICT
        assert "déjà réglée" in response.data["detail"]

    def test_un_reglement_en_cours_n_en_ouvre_pas_un_second(
        self, client: APIClient, split: SplitPayment
    ) -> None:
        """Deux transactions ouvertes sur une même part feraient payer deux
        fois le même convive."""
        part = split.shares.first()
        assert part is not None
        client.post(reverse("v1:payments:share", args=[part.share_token]))

        response = client.post(reverse("v1:payments:share", args=[part.share_token]))

        assert response.status_code == status.HTTP_409_CONFLICT


class TestApiDuPartage:
    def test_le_client_ouvre_un_partage(
        self, as_customer: APIClient, order: Order, customer: User
    ) -> None:
        response = as_customer.post(
            reverse("v1:payments:split", args=[order.pk]),
            {
                "participants": [
                    {"display_name": "Ama", "user": str(customer.pk)},
                    {"display_name": "Kossi", "phone": "+22890111222"},
                ]
            },
            format="json",
        )

        assert response.status_code == status.HTTP_201_CREATED
        assert len(response.data["shares"]) == 2
        assert response.data["total_amount"] == {"amount": "4000", "currency": XOF}

    def test_le_client_consulte_son_partage(
        self, as_customer: APIClient, split: SplitPayment, order: Order
    ) -> None:
        response = as_customer.get(reverse("v1:payments:split", args=[order.pk]))

        assert response.status_code == status.HTTP_200_OK
        assert len(response.data["shares"]) == 3

    def test_le_partage_d_autrui_est_introuvable(
        self, client: APIClient, courier_user: User, split: SplitPayment, order: Order
    ) -> None:
        client.force_authenticate(courier_user)

        response = client.get(reverse("v1:payments:split", args=[order.pk]))

        assert response.status_code in (status.HTTP_403_FORBIDDEN, status.HTTP_404_NOT_FOUND)

    def test_un_seul_convive_est_refuse_par_le_contrat(
        self, as_customer: APIClient, order: Order
    ) -> None:
        response = as_customer.post(
            reverse("v1:payments:split", args=[order.pk]),
            {"participants": [{"display_name": "Seul"}]},
            format="json",
        )

        assert response.status_code == status.HTTP_400_BAD_REQUEST
