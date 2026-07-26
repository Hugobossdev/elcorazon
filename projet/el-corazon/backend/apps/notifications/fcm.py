"""Connecteur Firebase Cloud Messaging — API HTTP v1.

**Avertissement, comme pour PayDunya.** Le contrat suivi ici est celui que
Google documente pour l'API v1, mais il n'a pas pu être confronté au service
réel depuis ce dépôt : aucun projet Firebase n'y est configuré. Avant la mise
en service, envoyer une notification à un appareil de test et **comparer** la
réponse d'erreur reçue à `_ERREURS_DEFINITIVES` — c'est la classification des
erreurs qui compte, pas l'envoi lui-même.

Trois choses distinguent cette intégration d'un simple POST :

* **l'authentification est un jeton OAuth**, pas une clé d'API. L'ancienne clé
  serveur a été retirée par Google ; il faut désormais signer une assertion
  avec un compte de service, et le jeton obtenu expire. `google-auth` s'en
  charge — c'est exactement le genre de code qu'on n'écrit pas soi-même ;
* **l'envoi est unitaire.** L'API v1 n'a pas de diffusion groupée : c'est une
  requête par appareil. Un client à cinq téléphones coûte cinq appels, et c'est
  pourquoi tout cela vit dans une tâche Celery et jamais dans le cycle de
  requête ;
* **la réponse d'erreur porte la décision.** Distinguer l'appareil
  définitivement injoignable de la panne passagère est toute la raison d'être
  de ce module : confondre les deux donne soit une purge d'appareils sains au
  premier hoquet, soit la boucle infinie de l'implémentation précédente.
"""

from __future__ import annotations

import logging
from typing import Any

import httpx
from django.conf import settings

from apps.notifications.push import PushMessage, PushResult

__all__ = ["FirebaseCloudMessagingBackend"]

logger = logging.getLogger(__name__)

#: Portée OAuth exigée par l'API d'envoi.
SCOPE = "https://www.googleapis.com/auth/firebase.messaging"

#: Codes signalant un appareil **définitivement** injoignable.
#:
#: `UNREGISTERED` — l'application a été désinstallée ou le jeton régénéré.
#: `INVALID_ARGUMENT` — le jeton ne correspond à rien de valide.
#: `SENDER_ID_MISMATCH` — le jeton appartient à un autre projet Firebase ; il
#: ne fonctionnera jamais depuis celui-ci, et le garder ferait réessayer
#: éternellement une erreur de configuration.
ERREURS_DEFINITIVES = frozenset({"UNREGISTERED", "INVALID_ARGUMENT", "SENDER_ID_MISMATCH"})


class FirebaseCloudMessagingBackend:
    """Envoi par l'API HTTP v1 de FCM."""

    def send(self, tokens: list[str], message: PushMessage) -> PushResult:
        """Adresse le message à chaque appareil, un appel par jeton.

        Un échec sur un appareil n'interrompt pas les autres : les trois listes
        rendues sont indépendantes, et c'est ce qui permet à la tâche de
        supprimer les morts, de reprendre les indécis et de laisser tranquilles
        ceux qui ont reçu.
        """
        livres: list[str] = []
        morts: list[str] = []
        rates: list[str] = []

        try:
            entete = self._authorization()
        except Exception as exc:
            # Sans jeton, aucun envoi ne peut aboutir. Tous les appareils sont
            # donc « en échec passager » et non « morts » : c'est notre
            # configuration qui est en cause, pas leurs jetons, et les purger
            # serait la pire réaction possible.
            logger.error("fcm.authentification", extra={"detail": str(exc)})
            return PushResult(failed=tuple(tokens))

        url = f"https://fcm.googleapis.com/v1/projects/{settings.FCM_PROJECT_ID}/messages:send"
        with httpx.Client(timeout=settings.FCM_TIMEOUT_SECONDS) as client:
            for token in tokens:
                issue = self._send_one(client, url, entete, token, message)
                {"delivered": livres, "unregistered": morts, "failed": rates}[issue].append(token)

        return PushResult(delivered=tuple(livres), unregistered=tuple(morts), failed=tuple(rates))

    # ------------------------------------------------------ authentification

    def _authorization(self) -> dict[str, str]:
        """Jeton d'accès OAuth, rafraîchi si nécessaire.

        L'objet d'identifiants est mis en cache au niveau du module : il
        conserve le jeton et sa date d'expiration, et le redemande seul quand
        il expire. Le recréer à chaque envoi provoquerait un aller-retour
        OAuth par notification, soit plusieurs centaines de millisecondes pour
        rien.
        """
        credentials = _credentials()
        if not credentials.valid:
            from google.auth.transport.requests import Request as GoogleRequest

            credentials.refresh(GoogleRequest())

        return {
            "Authorization": f"Bearer {credentials.token}",
            "Content-Type": "application/json",
        }

    # ---------------------------------------------------------------- envoi

    def _send_one(
        self,
        client: httpx.Client,
        url: str,
        entete: dict[str, str],
        token: str,
        message: PushMessage,
    ) -> str:
        try:
            response = client.post(url, json=self._payload(token, message), headers=entete)
        except httpx.HTTPError as exc:
            logger.warning("fcm.reseau", extra={"detail": str(exc)})
            return "failed"

        if response.status_code == httpx.codes.OK:
            return "delivered"

        return "unregistered" if self._definitif(response) else "failed"

    @staticmethod
    def _payload(token: str, message: PushMessage) -> dict[str, Any]:
        """Corps d'un envoi.

        `data` ne contient que des chaînes — l'API refuse tout autre type, et
        la conversion a déjà été faite en amont. La priorité haute sur Android
        et le réveil sur iOS ne sont pas décoratifs : sans eux, une
        notification de commande arrive quand le système le décide, c'est-à-dire
        parfois après la livraison.
        """
        return {
            "message": {
                "token": token,
                "notification": {"title": message.title, "body": message.body},
                "data": message.data,
                "android": {"priority": "high"},
                "apns": {"headers": {"apns-priority": "10"}},
            }
        }

    @staticmethod
    def _definitif(response: httpx.Response) -> bool:
        """L'appareil est-il définitivement injoignable ?

        La décision se lit dans `error.details[].errorCode` et **pas** dans le
        statut HTTP : un 400 peut signaler un jeton mort comme une charge utile
        mal formée, et purger sur le second effacerait des appareils sains à
        cause d'un défaut de notre côté.
        """
        try:
            corps: dict[str, Any] = response.json()
        except ValueError:
            return False

        erreur = corps.get("error", {})
        for detail in erreur.get("details", []):
            if isinstance(detail, dict) and detail.get("errorCode") in ERREURS_DEFINITIVES:
                return True

        # Certaines réponses ne portent que le statut canonique. `NOT_FOUND` y
        # désigne un jeton qui n'existe plus ; le reste est passager.
        return bool(erreur.get("status") == "NOT_FOUND")


_cache: dict[str, Any] = {}


def _credentials() -> Any:
    """Identifiants du compte de service, chargés une seule fois.

    Le fichier est monté en volume — comme les clés JWT — et non passé en
    variable : c'est un JSON multiligne, et c'est la forme qu'attendent les
    `Secret` Kubernetes.
    """
    chemin = settings.FCM_CREDENTIALS_PATH
    if not chemin:
        raise RuntimeError(
            "FCM_CREDENTIALS_PATH n'est pas renseigné : aucune notification ne peut partir."
        )

    if chemin not in _cache:
        from google.oauth2 import service_account

        # `google-auth` publie des annotations partielles : cette fabrique n'en
        # a pas, et le mode strict refuse d'appeler une fonction non typée.
        _cache[chemin] = service_account.Credentials.from_service_account_file(  # type: ignore[no-untyped-call]
            chemin, scopes=[SCOPE]
        )

    return _cache[chemin]
