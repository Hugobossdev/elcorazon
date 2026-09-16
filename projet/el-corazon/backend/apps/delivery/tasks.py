"""Tâches planifiées de la livraison."""

from __future__ import annotations

from celery import shared_task

from apps.delivery.dispatch import DispatchService

__all__ = ["expire_stale_offers"]


@shared_task
def expire_stale_offers() -> dict[str, int]:
    """Clôt les propositions restées sans réponse, puis rattrape les commandes prêtes.

    Les deux dans le même tour, dans cet ordre : une proposition close libère sa
    commande, que le rattrapage propose aussitôt au suivant plutôt qu'au tour
    d'après.
    """
    closes = DispatchService.expire_stale_offers()
    proposees = DispatchService.dispatch_waiting()
    return {"expired": closes, "offered": proposees}
