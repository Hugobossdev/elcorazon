"""Abonnements aux événements de domaine — ADR-002, ADR-008.

C'est ici que `notifications` réagit à ce que font les autres apps. La flèche va
dans ce sens et pas dans l'autre : `orders` et `delivery` annoncent sans savoir
qui écoute, ce module écoute sans qu'ils le sachent. Ajouter une notification
sur un événement existant ne touche aucune autre app.
"""

from __future__ import annotations

from typing import Any

from django.dispatch import receiver

from apps.delivery.models import Assignment
from apps.delivery.signals import assignment_accepted, assignment_offered
from apps.notifications.models import NotificationKind
from apps.notifications.services import notify, staff_to_alert
from apps.orders.models import Order
from apps.orders.signals import order_status_changed
from apps.orders.states import OrderStatus
from apps.payments.models import Transaction
from apps.payments.signals import payment_transaction_failed

__all__ = [
    "on_assignment_accepted",
    "on_assignment_offered",
    "on_order_status_changed",
    "on_order_status_changed_for_staff",
    "on_payment_failed",
]

#: Permission qu'il faut détenir pour être prévenu d'un événement de commande.
#:
#: C'est celle que l'écran opposera ensuite (`HasPermission.of("orders.read")`).
#: Alerter au-delà produirait des notifications qui mènent à un 403.
ORDERS_READ = "orders.read"

#: Étapes annoncées au client, et ce qu'on lui dit.
#:
#: La liste est délibérément courte. `preparing` et `ready` sont des étapes de
#: cuisine : les annoncer ferait vibrer le téléphone sans rien apprendre
#: d'actionnable. Notifier chaque transition est le meilleur moyen de se faire
#: couper les notifications — et de perdre du même coup celles qui comptent.
CUSTOMER_ANNOUNCEMENTS: dict[str, tuple[str, str]] = {
    OrderStatus.CONFIRMED: ("Commande confirmée", "Votre commande {reference} est confirmée."),
    OrderStatus.ON_THE_WAY: ("En route", "Votre commande {reference} arrive."),
    OrderStatus.DELIVERED: ("Livrée", "Votre commande {reference} a été livrée. Bon appétit !"),
    OrderStatus.CANCELLED: ("Commande annulée", "Votre commande {reference} a été annulée."),
}


@receiver(order_status_changed, sender=Order, dispatch_uid="notifications.order_status")
def on_order_status_changed(
    sender: type[Order], *, order: Order, target: str, **kwargs: Any
) -> None:
    """Prévient le client des étapes qui le concernent.

    `dispatch_uid` protège du double abonnement : sans lui, un module importé
    deux fois — ce qui arrive au rechargement automatique en développement —
    enverrait deux notifications par transition, et le défaut ne se verrait
    qu'à l'usage.
    """
    message = CUSTOMER_ANNOUNCEMENTS.get(target)
    if message is None:
        return

    title, body = message
    notify(
        user=order.customer,
        kind=NotificationKind.ORDER_STATUS,
        title=title,
        body=body.format(reference=order.reference),
        data={"order": str(order.pk), "status": target},
    )


#: Étapes annoncées au **personnel**, et ce qu'on lui dit.
#:
#: Volontairement disjointe de `CUSTOMER_ANNOUNCEMENTS` : les deux publics
#: n'attendent pas les mêmes moments. Le client veut savoir où en est son repas ;
#: l'exploitation veut savoir ce qui **entre** et ce qui **casse**. Personne au
#: back-office n'a besoin d'apprendre qu'une commande a été livrée normalement —
#: c'est le cas nominal, et le notifier noierait les deux qui comptent.
STAFF_ANNOUNCEMENTS: dict[str, tuple[str, str]] = {
    OrderStatus.CONFIRMED: ("Nouvelle commande", "Commande {reference} à préparer."),
    OrderStatus.CANCELLED: ("Commande annulée", "La commande {reference} a été annulée."),
}


@receiver(order_status_changed, sender=Order, dispatch_uid="notifications.order_status_staff")
def on_order_status_changed_for_staff(
    sender: type[Order], *, order: Order, target: str, **kwargs: Any
) -> None:
    """Prévient le personnel de l'établissement concerné.

    Second abonné au **même** signal, avec son propre `dispatch_uid` : le
    partager avec celui du client ferait que le dernier enregistré remplace
    l'autre en silence — Django indexe ses abonnements sur cet identifiant.

    Le destinataire n'est pas « les administrateurs » mais le personnel
    rattaché à *cet* établissement et habilité à lire les commandes — voir
    `staff_to_alert`. Un client ne reçoit jamais rien par ce chemin : la
    population est filtrée sur `user_type=staff`.
    """
    message = STAFF_ANNOUNCEMENTS.get(target)
    if message is None:
        return

    title, body = message
    for membre in staff_to_alert(restaurant_id=order.restaurant_id, permission=ORDERS_READ):
        notify(
            user=membre,
            kind=NotificationKind.ORDER_STATUS,
            title=title,
            body=body.format(reference=order.reference),
            data={"order": str(order.pk), "status": target},
        )


@receiver(
    payment_transaction_failed,
    sender=Transaction,
    dispatch_uid="notifications.payment_failed",
)
def on_payment_failed(
    sender: type[Transaction], *, transaction: Transaction, **kwargs: Any
) -> None:
    """Prévient le client qu'un paiement a échoué, et l'exploitation avec lui.

    Un paiement refusé était **entièrement muet** : la transaction passait en
    `failed`, la commande restait où elle était, et personne n'apprenait rien.
    Le client attendait devant une commande qui n'avancerait jamais, et le
    back-office la voyait vieillir sans savoir pourquoi. `NotificationKind.PAYMENT`
    existait dans l'énumération sans être émis une seule fois.

    C'est la seule notification qui parte aux deux publics pour un même
    événement, et c'est justifié : le client seul peut reprendre le paiement,
    l'exploitation seule peut le relancer ou libérer la commande.
    """
    order = transaction.order
    if order is None:
        # Un abonnement, un rechargement : rien à dire de plus que ce que
        # l'écran de paiement montre déjà, et aucune commande à désigner.
        return

    notify(
        user=order.customer,
        kind=NotificationKind.PAYMENT,
        title="Paiement refusé",
        body=f"Le paiement de la commande {order.reference} n'a pas abouti. Vous pouvez réessayer.",
        data={"order": str(order.pk), "transaction": str(transaction.pk)},
    )

    for membre in staff_to_alert(restaurant_id=order.restaurant_id, permission=ORDERS_READ):
        notify(
            user=membre,
            kind=NotificationKind.PAYMENT,
            title="Paiement en échec",
            body=f"Le paiement de la commande {order.reference} a échoué.",
            data={"order": str(order.pk), "transaction": str(transaction.pk)},
        )


@receiver(assignment_accepted, sender=Assignment, dispatch_uid="notifications.delivery_accepted")
def on_assignment_accepted(
    sender: type[Assignment], *, assignment: Assignment, **kwargs: Any
) -> None:
    """Prévient le client qu'un livreur a pris sa commande.

    L'acceptation et non la proposition : une course proposée peut être
    refusée, et annoncer un livreur qui ne viendra pas est pire que de ne rien
    dire.

    C'est le seul moment du parcours où le client n'apprenait rien alors qu'il
    se passait quelque chose : `accepted` n'est volontairement pas projeté sur
    le statut de la commande — le repas n'est pas parti, elle reste `ready` —
    si bien qu'entre « confirmée » et « en route » il n'y avait aucun signe de
    vie. C'est précisément l'intervalle où l'on se demande si quelqu'un a vu la
    commande.
    """
    order = assignment.order
    notify(
        user=order.customer,
        kind=NotificationKind.ORDER_STATUS,
        title="Un livreur arrive",
        body=(
            f"{assignment.courier.user.full_name} prend en charge votre "
            f"commande {order.reference}."
        ),
        data={"order": str(order.pk), "assignment": str(assignment.pk)},
    )


@receiver(assignment_offered, sender=Assignment, dispatch_uid="notifications.delivery_offer")
def on_assignment_offered(
    sender: type[Assignment], *, assignment: Assignment, **kwargs: Any
) -> None:
    """Prévient le livreur qu'une course l'attend.

    C'est le seul flux où rater un événement a un coût métier direct (ADR-008) :
    le livreur n'a pas son application au premier plan en roulant, et une
    course non vue est un repas qui refroidit. Le WebSocket ne suffit donc pas
    — la notification le double.
    """
    order = assignment.order
    notify(
        user=assignment.courier.user,
        kind=NotificationKind.DELIVERY_OFFER,
        title="Nouvelle course",
        body=f"{order.restaurant.name} — {order.delivery_address_line}",
        data={"assignment": str(assignment.pk), "order": str(order.pk)},
    )
