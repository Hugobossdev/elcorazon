"""Tâches planifiées de la livraison."""

from __future__ import annotations

from datetime import timedelta

from celery import shared_task
from django.db.models import Q
from django.utils import timezone

from apps.delivery.dispatch import DispatchService
from apps.delivery.models import CourierProfile
from apps.delivery.services import CourierService
from apps.delivery.signals import document_expiring
from apps.delivery.states import VerificationStatus

__all__ = ["expire_stale_offers", "remind_document_expiry"]

#: Jours avant l'échéance où l'on prévient. Un mois pour renouveler un permis,
#: une semaine pour relancer, la veille et le jour même pour ne pas l'oublier.
#: Des échéances fixes plutôt qu'un rappel quotidien : prévenir chaque jour
#: pendant un mois, c'est apprendre à tout le monde à ignorer l'avis.
RAPPELS_EN_JOURS = (30, 7, 1, 0)


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


@shared_task
def remind_document_expiry() -> dict[str, int]:
    """Prévient livreurs et équipe des pièces qui arrivent à échéance.

    Seuls les dossiers **validés** sont concernés : un dossier en attente ou
    refusé n'est pas en service, et son instruction dira ce qui manque.
    """
    aujourd_hui = timezone.localdate()
    envoyes = 0
    for jours in RAPPELS_EN_JOURS:
        echeance = aujourd_hui + timedelta(days=jours)
        filtre = Q()
        for champ in CourierService.PIECES_DATEES.values():
            filtre |= Q(**{champ: echeance})
        concernes = CourierProfile.objects.filter(
            filtre, verification_status=VerificationStatus.APPROVED
        ).select_related("user")
        for courier in concernes:
            for piece, champ in CourierService.PIECES_DATEES.items():
                if getattr(courier, champ) == echeance:
                    document_expiring.send(
                        sender=CourierProfile,
                        courier=courier,
                        piece=piece,
                        expires_on=echeance,
                        days_left=jours,
                    )
                    envoyes += 1
    return {"reminders": envoyes}
