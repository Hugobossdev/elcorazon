"""Émission des notifications — ADR-008.

Un même événement métier produit jusqu'à trois choses : une ligne persistante,
un message WebSocket si l'écran est ouvert, un push si l'application est
fermée. Ce module décide **quoi partir où**, et c'est le seul endroit qui le
décide — sans quoi chaque appelant se ferait sa propre idée du transactionnel
et du marketing.

Rien ici n'appelle le réseau : l'envoi part par Celery (`tasks.py`). Un jeton
OAuth suivi d'un POST par appareil ajouterait des centaines de millisecondes à
chaque changement de statut de commande.
"""

from __future__ import annotations

from typing import Any

from django.db import transaction

from apps.accounts.models import User
from apps.notifications.models import Notification, NotificationKind

__all__ = ["MARKETING_KINDS", "notify"]

#: Catégories soumises au consentement de l'utilisateur.
#:
#: Tout le reste est transactionnel et part quoi qu'il arrive : « votre livreur
#: arrive » n'est pas une sollicitation commerciale, et le couper au motif que
#: l'utilisateur a refusé le marketing produirait un client planté devant sa
#: porte sans savoir que le repas est là.
MARKETING_KINDS = frozenset({NotificationKind.MARKETING})


def notify(
    *,
    user: User,
    kind: str,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
    push: bool = True,
) -> Notification | None:
    """Enregistre une notification et programme son envoi push.

    Renvoie `None` quand le consentement manque pour une catégorie qui l'exige
    — rien n'est alors écrit non plus : une notification marketing qu'on ne
    peut pas envoyer n'a pas à encombrer l'historique de quelqu'un qui l'a
    refusée.

    L'envoi est programmé **après le commit**. Une tâche postée pendant la
    transaction peut être consommée par un worker avant que celle-ci ne soit
    validée : le worker lit alors une notification qui n'existe pas encore, ou
    envoie un push pour une commande qui sera annulée par un `ROLLBACK`.
    """
    if kind in MARKETING_KINDS and not _accepts_marketing(user):
        return None

    notification = Notification.objects.create(
        user=user, kind=kind, title=title, body=body, data=data or {}
    )

    if push:
        transaction.on_commit(lambda: _dispatch(notification.pk))

    return notification


def _accepts_marketing(user: User) -> bool:
    """Consentement au marketing push.

    Absence de préférences enregistrées vaut acceptation — c'est le défaut du
    modèle, et le refuser ici ferait taire toute communication tant que
    l'utilisateur n'a pas visité un écran de réglages qu'il ne visitera jamais.
    """
    preferences = getattr(user, "preferences", None)
    return True if preferences is None else bool(preferences.marketing_push_enabled)


def _dispatch(notification_id: object) -> None:
    """Poste la tâche d'envoi.

    Importée ici et non en tête de module : `tasks` importe ce module pour
    lire les notifications, et l'import croisé au chargement ferait échouer le
    démarrage du worker.
    """
    from apps.notifications.tasks import send_push

    send_push.delay(str(notification_id))
