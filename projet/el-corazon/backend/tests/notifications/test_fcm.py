"""Connecteur FCM — testé hors réseau.

Ce qui compte dans ce connecteur n'est pas l'envoi, qui est un POST. C'est la
**classification des erreurs** : distinguer l'appareil définitivement
injoignable de la panne passagère. Confondre les deux donne soit une purge
d'appareils sains au premier hoquet, soit la boucle infinie de
l'implémentation précédente, qui retentait un téléphone désinstallé à chaque
notification.

Ces tests ne prouvent pas que Google renvoie bien ces codes-là : cela demande
un projet Firebase et un appareil réel. Ils prouvent que, s'il les renvoie,
nous en tirons la bonne conséquence.
"""

from __future__ import annotations

import json
from typing import Any

import httpx
import pytest

from apps.notifications.fcm import ERREURS_DEFINITIVES, FirebaseCloudMessagingBackend
from apps.notifications.push import PushMessage

MESSAGE = PushMessage(title="Livrée", body="Bon appétit !", data={"order": "abc"})


@pytest.fixture
def configure(settings: Any) -> Any:
    settings.FCM_PROJECT_ID = "el-corazon-test"
    settings.FCM_CREDENTIALS_PATH = "/run/secrets/fcm.json"
    return settings


@pytest.fixture
def backend(monkeypatch: pytest.MonkeyPatch, configure: Any) -> FirebaseCloudMessagingBackend:
    """Connecteur dont l'authentification est court-circuitée.

    Le jeton OAuth demande un compte de service réel et un aller-retour vers
    Google : le simuler ici laisse le test porter sur ce qui nous appartient.
    """
    monkeypatch.setattr(
        FirebaseCloudMessagingBackend,
        "_authorization",
        lambda self: {"Authorization": "Bearer jeton-de-test"},
    )
    return FirebaseCloudMessagingBackend()


def transport(handler: Any, monkeypatch: pytest.MonkeyPatch) -> None:
    vrai_client = httpx.Client

    def client_simule(*args: Any, **kwargs: Any) -> httpx.Client:
        kwargs.pop("timeout", None)
        return vrai_client(transport=httpx.MockTransport(handler), **kwargs)

    monkeypatch.setattr(httpx, "Client", client_simule)


def erreur(code: str, statut: int = 400) -> httpx.Response:
    return httpx.Response(
        statut,
        json={"error": {"status": "INVALID_ARGUMENT", "details": [{"errorCode": code}]}},
    )


class TestEnvoi:
    def test_un_appareil_servi_est_compte_comme_livre(
        self, backend: FirebaseCloudMessagingBackend, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        transport(
            lambda request: httpx.Response(200, json={"name": "projects/x/messages/1"}), monkeypatch
        )

        resultat = backend.send(["jeton-a"], MESSAGE)

        assert resultat.delivered == ("jeton-a",)
        assert resultat.unregistered == ()
        assert resultat.failed == ()

    def test_l_envoi_est_unitaire(
        self, backend: FirebaseCloudMessagingBackend, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """L'API v1 n'a pas de diffusion groupée : un client à trois téléphones
        coûte trois appels. C'est pourquoi tout cela vit dans une tâche."""
        appels: list[str] = []

        def handler(request: httpx.Request) -> httpx.Response:
            appels.append(json.loads(request.content)["message"]["token"])
            return httpx.Response(200, json={})

        transport(handler, monkeypatch)

        backend.send(["a", "b", "c"], MESSAGE)

        assert appels == ["a", "b", "c"]

    def test_le_message_porte_titre_corps_et_donnees(
        self, backend: FirebaseCloudMessagingBackend, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        vus: dict[str, Any] = {}

        def handler(request: httpx.Request) -> httpx.Response:
            vus.update(json.loads(request.content)["message"])
            return httpx.Response(200, json={})

        transport(handler, monkeypatch)

        backend.send(["jeton"], MESSAGE)

        assert vus["notification"] == {"title": "Livrée", "body": "Bon appétit !"}
        assert vus["data"] == {"order": "abc"}

    def test_la_priorite_haute_est_demandee(
        self, backend: FirebaseCloudMessagingBackend, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """Sans elle, une notification de commande arrive quand le système le
        décide — parfois après la livraison."""
        vus: dict[str, Any] = {}

        def handler(request: httpx.Request) -> httpx.Response:
            vus.update(json.loads(request.content)["message"])
            return httpx.Response(200, json={})

        transport(handler, monkeypatch)

        backend.send(["jeton"], MESSAGE)

        assert vus["android"]["priority"] == "high"
        assert vus["apns"]["headers"]["apns-priority"] == "10"


class TestClassementDesErreurs:
    """Le cœur du connecteur."""

    @pytest.mark.parametrize("code", sorted(ERREURS_DEFINITIVES))
    def test_un_appareil_definitivement_injoignable_est_signale(
        self, backend: FirebaseCloudMessagingBackend, monkeypatch: pytest.MonkeyPatch, code: str
    ) -> None:
        transport(lambda request: erreur(code), monkeypatch)

        resultat = backend.send(["mort"], MESSAGE)

        assert resultat.unregistered == ("mort",)
        assert resultat.failed == ()

    @pytest.mark.parametrize("code", ["QUOTA_EXCEEDED", "UNAVAILABLE", "INTERNAL"])
    def test_une_panne_passagere_n_efface_pas_l_appareil(
        self, backend: FirebaseCloudMessagingBackend, monkeypatch: pytest.MonkeyPatch, code: str
    ) -> None:
        """Purger sur un quota dépassé effacerait des appareils parfaitement
        sains, et le client cesserait de recevoir sans que rien ne l'explique."""
        transport(lambda request: erreur(code, statut=429), monkeypatch)

        resultat = backend.send(["vivant"], MESSAGE)

        assert resultat.failed == ("vivant",)
        assert resultat.unregistered == ()

    def test_le_statut_http_ne_decide_pas_seul(
        self, backend: FirebaseCloudMessagingBackend, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """Un 400 peut signaler un jeton mort comme une charge utile mal
        formée. Purger sur le second effacerait des appareils sains à cause
        d'un défaut de notre côté."""
        transport(
            lambda request: httpx.Response(400, json={"error": {"status": "INVALID_ARGUMENT"}}),
            monkeypatch,
        )

        resultat = backend.send(["jeton"], MESSAGE)

        assert resultat.failed == ("jeton",)

    def test_un_corps_illisible_ne_fait_rien_supprimer(
        self, backend: FirebaseCloudMessagingBackend, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        transport(lambda request: httpx.Response(500, content=b"<html>erreur</html>"), monkeypatch)

        resultat = backend.send(["jeton"], MESSAGE)

        assert resultat.failed == ("jeton",)

    def test_un_reseau_coupe_est_passager(
        self, backend: FirebaseCloudMessagingBackend, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        def handler(request: httpx.Request) -> httpx.Response:
            raise httpx.ConnectError("injoignable")

        transport(handler, monkeypatch)

        assert backend.send(["jeton"], MESSAGE).failed == ("jeton",)

    def test_un_echec_n_interrompt_pas_les_autres(
        self, backend: FirebaseCloudMessagingBackend, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """Les trois listes sont indépendantes : c'est ce qui permet à la tâche
        de supprimer les morts, reprendre les indécis et laisser tranquilles
        ceux qui ont reçu."""

        def handler(request: httpx.Request) -> httpx.Response:
            token = json.loads(request.content)["message"]["token"]
            if token == "mort":
                return erreur("UNREGISTERED")
            if token == "rate":
                return erreur("UNAVAILABLE", statut=503)
            return httpx.Response(200, json={})

        transport(handler, monkeypatch)

        resultat = backend.send(["vivant", "mort", "rate"], MESSAGE)

        assert resultat.delivered == ("vivant",)
        assert resultat.unregistered == ("mort",)
        assert resultat.failed == ("rate",)


class TestAuthentification:
    def test_sans_identifiants_aucun_appareil_n_est_purge(
        self, configure: Any, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """La panne est de notre côté, pas du leur : les compter comme morts
        viderait la table des appareils sur une erreur de configuration.
        """
        configure.FCM_CREDENTIALS_PATH = ""

        resultat = FirebaseCloudMessagingBackend().send(["a", "b"], MESSAGE)

        assert resultat.failed == ("a", "b")
        assert resultat.unregistered == ()
        assert resultat.delivered == ()
