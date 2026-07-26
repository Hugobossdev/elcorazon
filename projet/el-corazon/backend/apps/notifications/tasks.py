"""Tâches d'envoi — ADR-008.

**Tout appel réseau sortant quitte le cycle de requête.** Un envoi FCM demande
un jeton OAuth puis un POST par appareil : le faire dans la vue ajouterait des
centaines de millisecondes à chaque changement de statut de commande, et ferait
échouer la transaction métier quand le service push est indisponible.
"""

from __future__ import annotations

import datetime as dt
import logging

from celery import shared_task
from django.utils import timezone

from apps.accounts.models import Device
from apps.notifications.models import Notification
from apps.notifications.push import PushMessage, backend, payload_for

__all__ = ["purge_unregistered_devices", "send_push"]

logger = logging.getLogger(__name__)


@shared_task(
    bind=True,
    max_retries=3,
    # Report exponentiel avec dispersion : sans le `jitter`, les milliers de
    # tâches mises en échec par une même panne de service reviennent toutes à
    # la même seconde et la prolongent.
    retry_backoff=True,
    retry_jitter=True,
)
def send_push(self: object, notification_id: str) -> dict[str, int]:
    """Envoie une notification à tous les appareils de son destinataire.

    Les jetons **définitivement** injoignables sont supprimés dans la foulée.
    C'est la moitié qui manquait à l'implémentation précédente : elle retentait
    trois fois un appareil désinstallé, à chaque notification, indéfiniment.
    """
    notification = Notification.objects.select_related("user").filter(pk=notification_id).first()
    if notification is None:
        # La notification a été supprimée entre la programmation et l'exécution
        # — un compte effacé, par exemple. Ce n'est pas une erreur à retenter.
        logger.info("push.notification_absente", extra={"notification": notification_id})
        return {"delivered": 0, "purged": 0, "failed": 0}

    tokens = list(Device.objects.filter(user=notification.user).values_list("token", flat=True))
    if not tokens:
        return {"delivered": 0, "purged": 0, "failed": 0}

    result = backend().send(
        tokens,
        PushMessage(
            title=notification.title,
            body=notification.body,
            data=payload_for(notification.kind, notification.data),
        ),
    )

    purged = 0
    if result.unregistered:
        purged, _ = Device.objects.filter(token__in=result.unregistered).delete()

    return {
        "delivered": len(result.delivered),
        "purged": purged,
        "failed": len(result.failed),
    }


@shared_task
def purge_unregistered_devices(days: int = 180) -> int:
    """Supprime les appareils muets depuis longtemps.

    Complément de la purge à l'envoi : un appareil peut cesser de répondre sans
    que le service push le déclare jamais injoignable — téléphone perdu,
    application jamais rouverte. Six mois sans un seul rafraîchissement de
    jeton suffisent à conclure.
    """
    horizon = timezone.now() - dt.timedelta(days=days)
    deleted, _ = Device.objects.filter(last_used_at__lt=horizon).delete()
    return deleted
