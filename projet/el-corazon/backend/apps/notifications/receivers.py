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
from apps.delivery.signals import (
    assignment_accepted,
    assignment_cancelled,
    assignment_offered,
)
from apps.notifications.models import NotificationKind
from apps.notifications.services import notify, staff_to_alert
from apps.orders.models import Order
from apps.orders.signals import order_created, order_status_changed
from apps.orders.states import OrderStatus
from apps.payments.models import Transaction
from apps.payments.signals import payment_transaction_failed
from apps.restaurants.models import Restaurant
from apps.restaurants.signals import restaurant_status_changed
from apps.restaurants.states import RestaurantStatus

__all__ = [
    "on_assignment_accepted",
    "on_assignment_offered",
    "on_order_created_for_staff",
    "on_order_status_changed",
    "on_order_status_changed_for_staff",
    "on_payment_failed",
    "on_restaurant_status_changed",
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
    # « Nouvelle commande » a changé de place : c'est l'**arrivée** qui porte ce
    # titre désormais (`on_order_created_for_staff`), et non la confirmation.
    # Les deux moments sont distincts et le personnel doit pouvoir les
    # distinguer — surtout quand ils sont séparés par son propre geste, ce qui
    # est le cas d'un règlement en espèces.
    OrderStatus.CONFIRMED: ("Commande confirmée", "La commande {reference} est à préparer."),
    OrderStatus.CANCELLED: ("Commande annulée", "La commande {reference} a été annulée."),
}


@receiver(order_created, sender=Order, dispatch_uid="notifications.order_created_staff")
def on_order_created_for_staff(sender: type[Order], *, order: Order, **kwargs: Any) -> None:
    """Prévient l'établissement qu'une commande vient d'arriver.

    C'est le premier maillon, et il manquait. `STAFF_ANNOUNCEMENTS` est indexé
    sur des **transitions** ; or une commande naît en `pending` et la seule voie
    automatique vers `confirmed` est l'encaissement par webhook. Le règlement en
    espèces à la livraison — aujourd'hui le seul moyen actif dans l'application
    cliente — n'en émet aucun. Une commande passée un vendredi soir n'était donc
    annoncée à personne : elle attendait qu'un membre du personnel rafraîchisse
    la liste et remarque la ligne.

    Le client, lui, n'est pas notifié ici : il vient de valider sa commande et a
    l'écran de confirmation sous les yeux. Lui envoyer une notification pour le
    geste qu'il achève à l'instant est le genre d'envoi qui fait couper les
    notifications — et perdre du même coup celles qui comptent.
    """
    for membre in staff_to_alert(restaurant_id=order.restaurant_id, permission=ORDERS_READ):
        notify(
            user=membre,
            kind=NotificationKind.ORDER_STATUS,
            title="Nouvelle commande",
            body=f"Commande {order.reference} reçue.",
            data={"order": str(order.pk), "status": order.status},
        )


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
            f"{assignment.courier.user.full_name} prend en charge votre commande {order.reference}."
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


@receiver(assignment_cancelled, sender=Assignment, dispatch_uid="notifications.delivery_cancelled")
def on_assignment_cancelled(
    sender: type[Assignment], *, assignment: Assignment, reason: str = "", **kwargs: Any
) -> None:
    """Prévient le livreur qu'on lui a retiré sa course.

    ## Le défaut que ce receveur ferme

    Rien ne le lui disait. L'annulation par le personnel diffusait bien un
    événement, mais sur le canal de la **commande** (`order_group`) — celui que
    le client écoute pour suivre sa livraison. Le livreur, lui, n'écoute que sa
    propre file (`ws/couriers/me/`).

    Concrètement : un livreur en route vers le restaurant continuait d'y aller,
    et l'apprenait de la cuisine en arrivant. C'est le pendant exact de
    `on_assignment_offered`, et il manquait — on savait lui confier une course,
    pas la lui reprendre.

    ## Pourquoi le motif est repris

    Une annulation sans raison se lit comme une sanction. Le personnel en
    saisit une (`decline_reason`), et c'est elle qui distingue « le client a
    annulé » d'« on vous retire cette course ». Absent, on ne prétend pas en
    avoir un.
    """
    order = assignment.order
    notify(
        user=assignment.courier.user,
        kind=NotificationKind.DELIVERY_OFFER,
        title="Course annulée",
        body=(
            f"{order.restaurant.name} — {reason}"
            if reason
            else f"La course pour {order.restaurant.name} vous a été retirée."
        ),
        data={"assignment": str(assignment.pk), "order": str(order.pk)},
    )


#: Permission qu'il faut détenir pour être prévenu d'un événement d'établissement.
#:
#: C'est celle que l'écran opposera ensuite (`restaurants.read`). Alerter
#: au-delà produirait des notifications qui mènent à un 403.
RESTAURANTS_READ = "restaurants.read"

#: Ce qu'on annonce, selon l'état d'arrivée.
#:
#: Indexé sur la cible et non sur la paire (précédent, cible) : seule
#: l'inauguration se distingue d'une réouverture, et elle se lit sur le
#: précédent au moment de composer le message. Une table à quinze entrées pour
#: cette seule nuance serait plus difficile à relire que la condition.
LIFECYCLE_ANNOUNCEMENTS: dict[str, tuple[str, str]] = {
    RestaurantStatus.ACTIVE: (
        "{name} est en service",
        "L'établissement est visible des clients et prend les commandes.",
    ),
    RestaurantStatus.INACTIVE: (
        "{name} est suspendu",
        "L'établissement n'apparaît plus dans l'application cliente et ne reçoit "
        "plus de commandes.",
    ),
    RestaurantStatus.CONFIGURING: (
        "{name} entre en configuration",
        "L'établissement est retiré de l'application cliente le temps des réglages.",
    ),
    RestaurantStatus.READY: (
        "{name} est prêt à ouvrir",
        "La configuration est complète : la mise en service peut être demandée.",
    ),
}


@receiver(
    restaurant_status_changed,
    sender=Restaurant,
    dispatch_uid="notifications.restaurant_status",
)
def on_restaurant_status_changed(
    sender: type[Restaurant],
    *,
    restaurant: Restaurant,
    previous: str,
    target: str,
    **kwargs: Any,
) -> None:
    """Prévient le personnel qu'un établissement change d'état.

    ## Pourquoi cela manquait

    Suspendre un établissement le fait disparaître de l'application cliente à
    la seconde. Personne n'était prévenu : l'équipe l'apprenait en constatant
    que les commandes ne rentraient plus, et cherchait la panne du côté du
    réseau. Une suspension est une décision, pas un incident — elle doit
    s'annoncer comme telle.

    ## Qui est prévenu

    Le personnel dont le périmètre couvre cet établissement, et qui est habilité
    à le lire (`staff_to_alert`) : ses gérants, mais aussi le directeur du
    marché depuis que le cloisonnement a ce palier. Pas les clients — ils voient
    la conséquence dans l'application, et une notification « le restaurant est
    suspendu » sur le téléphone de quelqu'un qui n'y commande pas serait du
    bruit.

    Pas non plus les livreurs : leur travail dépend des courses proposées, qui
    s'arrêtent d'elles-mêmes quand l'établissement ne prend plus de commandes.
    Les prévenir de l'état d'un établissement les rendrait dépendants d'une
    information qu'ils n'ont pas à suivre.

    ## `account` et non un genre dédié

    C'est une nouvelle d'exploitation qui concerne le compte de celui qui la
    reçoit, comme une suspension de dossier livreur. Créer un genre
    `restaurant_status` obligerait chaque client — trois applications — à savoir
    le ranger avant d'avoir un écran qui l'affiche, et un genre inconnu se
    range mal.
    """
    message = LIFECYCLE_ANNOUNCEMENTS.get(target)
    if message is None:
        return

    titre, corps = message

    # Le sens du geste est dans la **paire** (précédent, cible), pas dans la
    # seule cible. Deux nuances valent d'être dites, parce qu'elles changent ce
    # qu'on comprend en relisant ses notifications trois jours plus tard :
    #
    # * « suspendu → en service » est une réouverture, pas une inauguration ;
    # * « brouillon → en configuration » est un début, alors que « prêt → en
    #   configuration » ou « suspendu → en configuration » est un retour en
    #   arrière. Écrire « repasse » dans les trois cas laissait croire qu'un
    #   établissement qu'on vient de créer avait déjà été configuré une fois.
    #
    # Le reste des transitions ne demande pas cette distinction : leur cible
    # suffit à les décrire.
    if target == RestaurantStatus.ACTIVE and previous == RestaurantStatus.INACTIVE:
        titre = "{name} rouvre"
    elif target == RestaurantStatus.CONFIGURING and previous != RestaurantStatus.DRAFT:
        titre = "{name} repasse en configuration"

    for membre in staff_to_alert(restaurant_id=restaurant.pk, permission=RESTAURANTS_READ):
        notify(
            user=membre,
            kind=NotificationKind.ACCOUNT,
            title=titre.format(name=restaurant.name),
            body=corps,
            data={
                "restaurant": str(restaurant.pk),
                "slug": restaurant.slug,
                "previous": previous,
                "status": target,
            },
        )
