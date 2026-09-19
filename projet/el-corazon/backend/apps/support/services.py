"""Ouverture de tickets, réclamations et demandes de retour.

La règle commune aux trois : un client n'agit que sur **sa** commande. Ni
`Complaint` ni `ReturnRequest` ne déclarent de relation entre `user` et
`order` qu'une contrainte de base saurait vérifier — la propriété se vérifie
donc ici, à la création, sur le modèle de S3 (partage de commande) : la
réclamation de quelqu'un d'autre n'est pas une ressource qu'on refuse, c'est
une ressource dont on tait jusqu'à l'existence.
"""

from __future__ import annotations

from django.db import transaction
from django.utils import timezone

from apps.accounts.models import User
from apps.orders.models import Order
from apps.orders.states import OrderStatus
from apps.support.models import (
    Complaint,
    ComplaintKind,
    ComplaintStatus,
    ReturnRequest,
    ReturnStatus,
    SupportMessage,
    SupportTicket,
    TicketCategory,
    TicketStatus,
)
from apps.support.signals import (
    complaint_decided,
    complaint_filed,
    return_decided,
    return_requested,
    ticket_answered,
    ticket_status_changed,
)
from common.exceptions import BusinessRuleViolation
from common.money import Money

__all__ = ["SupportDeskService", "SupportService"]

_TICKET_TERMINAL = frozenset({TicketStatus.RESOLVED, TicketStatus.CLOSED})
_COMPLAINT_TERMINAL = frozenset({ComplaintStatus.RESOLVED, ComplaintStatus.REJECTED})

#: Ce qu'une demande de retour peut devenir, depuis chaque état.
#:
#: Pas une machine à états complète — le module s'en passe à dessein (voir
#: `models`) — mais deux règles qu'il faut tenir, parce qu'elles touchent à
#: l'argent : un retour **refusé** ne devient pas remboursé par un clic
#: suivant, et « remboursé » ne se pose que sur un retour approuvé.
RETURN_TRANSITIONS: dict[str, frozenset[str]] = {
    ReturnStatus.PENDING: frozenset({ReturnStatus.APPROVED, ReturnStatus.REJECTED}),
    ReturnStatus.APPROVED: frozenset({ReturnStatus.REFUNDED, ReturnStatus.REJECTED}),
    ReturnStatus.REJECTED: frozenset(),
    ReturnStatus.REFUNDED: frozenset(),
}


class SupportService:
    @staticmethod
    def open_ticket(
        *,
        user: User,
        category: str = TicketCategory.OTHER,
        subject: str,
        description: str,
        attachments: list[str] | None = None,
    ) -> SupportTicket:
        return SupportTicket.objects.create(
            user=user,
            category=category,
            subject=subject,
            description=description,
            attachments=attachments or [],
        )

    @staticmethod
    def reply(*, ticket: SupportTicket, author: User, content: str) -> SupportMessage:
        return SupportMessage.objects.create(ticket=ticket, author=author, content=content)

    @staticmethod
    def file_complaint(
        *,
        user: User,
        order: Order,
        kind: str = ComplaintKind.OTHER,
        subject: str,
        description: str,
        photos: list[str] | None = None,
    ) -> Complaint:
        if order.customer_id != user.pk:
            raise BusinessRuleViolation("Vous ne pouvez réclamer que sur vos propres commandes.")

        complaint = Complaint.objects.create(
            user=user,
            order=order,
            kind=kind,
            subject=subject,
            description=description,
            photos=photos or [],
        )
        complaint_filed.send(sender=Complaint, complaint=complaint)
        return complaint

    @staticmethod
    def request_return(
        *, user: User, order: Order, reason: str, items: list[str], refund_amount: Money
    ) -> ReturnRequest:
        """Enregistre une demande — ne rembourse rien.

        Deux gardes avant l'écriture : la commande doit être **livrée** (on ne
        retourne pas un repas qu'on n'a pas reçu), et le montant demandé ne
        peut pas dépasser ce que la commande a coûté — le même plafond que P3
        applique au remboursement réel, posé ici avant même que la demande
        n'atteigne quiconque.
        """
        if order.customer_id != user.pk:
            raise BusinessRuleViolation("Vous ne pouvez retourner que vos propres commandes.")

        if order.status != OrderStatus.DELIVERED:
            raise BusinessRuleViolation("Seule une commande livrée peut faire l'objet d'un retour.")

        if refund_amount.currency != order.total.currency or refund_amount > order.total:
            raise BusinessRuleViolation(
                f"Le montant demandé dépasse le total de la commande ({order.total}).",
                order_total=str(order.total.amount_minor),
                currency=order.total.currency,
            )

        demande = ReturnRequest.objects.create(  # type: ignore[misc]
            user=user, order=order, reason=reason, items=items, refund_amount=refund_amount
        )
        return_requested.send(sender=ReturnRequest, return_request=demande)
        return demande


class SupportDeskService:
    """Le côté **personnel** du support : répondre, statuer.

    Rien de tout cela n'existait hors de l'administration Django. Un client
    écrivait, et n'apprenait jamais qu'on l'avait lu : aucune route ne
    permettait au back-office de lui répondre, et une réponse saisie dans
    l'administration ne partait vers personne.

    Chaque geste émet un signal que `notifications` relaie au client. Le
    motif d'une décision défavorable est **exigé** : c'est la phrase que le
    client lira, et « rejetée » sans raison se lit comme un mépris.
    """

    @staticmethod
    @transaction.atomic
    def answer(*, ticket: SupportTicket, author: User, content: str) -> SupportMessage:
        """Répond sur le fil d'un ticket.

        Un ticket **ouvert** passe « en cours » : quelqu'un s'en occupe, et le
        client le voit. Un ticket résolu ou fermé qui reçoit une réponse est
        rouvert — répondre sur un dossier clos sans le rouvrir laisserait la
        réponse sous un statut qui dit « c'est réglé ».
        """
        message = SupportMessage.objects.create(ticket=ticket, author=author, content=content)
        if ticket.status != TicketStatus.IN_PROGRESS:
            ticket.status = TicketStatus.IN_PROGRESS
            ticket.resolved_at = None
            ticket.save(update_fields=["status", "resolved_at", "updated_at"])
        ticket_answered.send(sender=SupportTicket, ticket=ticket, message=message)
        return message

    @staticmethod
    @transaction.atomic
    def set_ticket_status(
        *, ticket: SupportTicket, status: str, resolution: str = ""
    ) -> SupportTicket:
        """Change le statut d'un ticket. Résoudre exige de dire comment."""
        if status == TicketStatus.RESOLVED and not (resolution or ticket.resolution).strip():
            raise BusinessRuleViolation("Dites au client comment son problème a été résolu.")

        avant = ticket.status
        ticket.status = status
        if resolution.strip():
            ticket.resolution = resolution.strip()
        # L'horodatage suit le statut dans les deux sens : un ticket rouvert
        # n'est plus résolu, et garder sa date ferait mentir les délais.
        if status in _TICKET_TERMINAL:
            ticket.resolved_at = ticket.resolved_at or timezone.now()
        else:
            ticket.resolved_at = None
        ticket.save(update_fields=["status", "resolution", "resolved_at", "updated_at"])

        if avant != status:
            ticket_status_changed.send(sender=SupportTicket, ticket=ticket)
        return ticket

    @staticmethod
    @transaction.atomic
    def decide_complaint(*, complaint: Complaint, status: str, resolution: str = "") -> Complaint:
        """Statue sur une réclamation. Une décision finale exige un motif."""
        complaint = Complaint.objects.select_for_update().get(pk=complaint.pk)
        if complaint.status in _COMPLAINT_TERMINAL:
            raise BusinessRuleViolation(
                "Cette réclamation est déjà close : ouvrez un ticket pour la reprendre.",
                current_status=complaint.status,
            )
        if status in _COMPLAINT_TERMINAL and not resolution.strip():
            raise BusinessRuleViolation("Le client lira la réponse : elle est obligatoire.")

        complaint.status = status
        if resolution.strip():
            complaint.resolution = resolution.strip()
        complaint.save(update_fields=["status", "resolution", "updated_at"])

        if status in _COMPLAINT_TERMINAL:
            complaint_decided.send(sender=Complaint, complaint=complaint)
        return complaint

    @staticmethod
    @transaction.atomic
    def decide_return(
        *, return_request: ReturnRequest, status: str, resolution: str = ""
    ) -> ReturnRequest:
        """Statue sur une demande de retour — **sans rembourser**.

        « Remboursée » constate un remboursement fait par `payments` (fiche de
        la commande, puis « Remboursements ») ; elle ne le déclenche pas. Le
        support ne dépend pas des paiements (ADR-002), et un statut qui
        verserait de l'argent serait un second chemin, sans le plafond P3.
        """
        demande = ReturnRequest.objects.select_for_update().get(pk=return_request.pk)
        permis = RETURN_TRANSITIONS.get(demande.status, frozenset())
        if status not in permis:
            raise BusinessRuleViolation(
                f"Une demande « {demande.get_status_display()} » ne peut pas devenir "
                f"« {ReturnStatus(status).label} ».",
                current_status=demande.status,
                allowed=sorted(permis),
            )
        if status == ReturnStatus.REJECTED and not resolution.strip():
            raise BusinessRuleViolation("Dites au client pourquoi son retour est refusé.")

        demande.status = status
        if resolution.strip():
            demande.resolution = resolution.strip()
        if status in (ReturnStatus.REJECTED, ReturnStatus.REFUNDED):
            demande.resolved_at = timezone.now()
        demande.save(update_fields=["status", "resolution", "resolved_at", "updated_at"])

        return_decided.send(sender=ReturnRequest, return_request=demande)
        return demande
