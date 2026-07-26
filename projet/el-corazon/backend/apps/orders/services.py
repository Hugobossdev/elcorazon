"""Création et cycle de vie des commandes — invariants C1 à C5, ADR-010.

C'est l'agrégat comptable du produit, et le seul module du backend qui écrive
un statut de commande. Trois choses s'y jouent :

* **la valorisation** — les prix sont relus du catalogue sous verrou, jamais
  reçus du client (C1), et le total est recomposé serveur (C2) ;
* **la transition** — elle passe par la machine à états, qui vérifie, journalise
  et rend le retour arrière inexprimable (C3, C4) ;
* **la copie figée** — la commande garde son propre exemplaire de l'adresse et
  des libellés, si bien qu'une adresse effacée ou un article renommé ne
  réécrivent pas l'histoire.
"""

from __future__ import annotations

import datetime as dt

from django.contrib.gis.db.models.functions import Distance
from django.db import connection, transaction
from django.utils import timezone

from apps.accounts.models import User
from apps.carts.models import Cart
from apps.carts.services import CartService, price_cart
from apps.catalog.services import record_purchase
from apps.geography.models import DeliveryZone
from apps.geography.services import DeliveryQuote, quote_delivery
from apps.orders.models import Order, OrderLine, OrderStatusEvent
from apps.orders.signals import order_status_changed
from apps.orders.states import ORDER_MACHINE, OrderStatus
from apps.profiles.models import Address
from apps.restaurants.models import Restaurant
from common.exceptions import BusinessRuleViolation
from common.money import Money
from common.realtime import order_group, publish

__all__ = ["OrderService", "next_reference"]

#: Statuts depuis lesquels le client peut encore annuler lui-même.
#:
#: La machine autorise l'annulation jusqu'à `ready` ; cette liste est plus
#: étroite, et c'est une décision commerciale et non technique : une fois la
#: cuisine lancée, l'annulation appartient au restaurant, qui sait ce qui est
#: déjà perdu. Le personnel muni de `orders.cancel` n'est pas concerné.
CUSTOMER_CANCELLABLE = frozenset({OrderStatus.PENDING, OrderStatus.CONFIRMED})


def next_reference() -> str:
    """Référence courte et lisible — `EC000001`.

    Tirée d'une séquence PostgreSQL et non d'un `COUNT` : deux commandes
    simultanées obtiendraient le même numéro avec un compteur applicatif, et le
    second `INSERT` échouerait sur l'unicité — un client sur deux verrait une
    erreur aux heures de pointe. La séquence n'est pas transactionnelle, donc
    elle ne bloque personne ; les trous qu'elle laisse sur une transaction
    annulée sont sans conséquence, une référence n'étant pas un numéro de
    facture réglementaire.
    """
    with connection.cursor() as cursor:
        cursor.execute("SELECT nextval('order_reference_seq')")
        (value,) = cursor.fetchone()
    return f"EC{value:06d}"


class OrderService:
    # ------------------------------------------------------------- création

    @staticmethod
    @transaction.atomic
    def create_from_cart(
        *,
        user: User,
        cart: Cart,
        address: Address,
        payment_method: str,
        instructions: str = "",
    ) -> Order:
        """Transforme un panier en commande.

        Tout se passe dans une transaction : la commande, ses lignes et le
        vidage du panier réussissent ou échouent ensemble. Un panier vidé sans
        commande créée serait la pire des deux issues — le client a perdu sa
        sélection et n'a rien commandé.
        """
        cart = CartService.load(cart)
        restaurant = cart.restaurant
        priced = price_cart(cart)

        if not priced.lines:
            raise BusinessRuleViolation("Le panier est vide.")
        if not priced.is_orderable:
            indisponibles = [
                line.line.menu_item.name for line in priced.lines if not line.is_orderable
            ]
            raise BusinessRuleViolation(
                "Certains articles ne sont plus commandables : "
                f"{', '.join(indisponibles)}. Retirez-les du panier.",
                unavailable=indisponibles,
            )

        # Le numéro est celui du destinataire s'il diffère du titulaire —
        # livraison à un tiers — sinon celui du compte. Aucun des deux n'est
        # obligatoire pris isolément, mais une course sans numéro joignable est
        # une course perdue : à Lomé, le livreur appelle pour trouver la porte.
        recipient_phone = address.recipient_phone or user.phone
        if not recipient_phone:
            raise BusinessRuleViolation(
                "Un numéro joignable est nécessaire à la livraison : renseignez "
                "celui du compte ou celui de l'adresse."
            )

        quote = OrderService._quote_for(restaurant, address, priced.subtotal)

        # C2 — le total est recomposé ici, à partir de valeurs dont aucune n'a
        # traversé le réseau depuis le client.
        discount = Money.zero(priced.currency)
        total = priced.subtotal + quote.fee - discount

        # `subtotal`, `delivery_fee`, `discount` et `total` sont des
        # `MoneyField` : deux colonnes réelles derrière une propriété, que le
        # greffon django-stubs ne sait pas relier au nom qu'on passe ici.
        order = Order.objects.create(  # type: ignore[misc]
            reference=next_reference(),
            restaurant=restaurant,
            customer=user,
            delivery_address_line=", ".join(filter(None, [address.line1, address.line2])),
            delivery_landmark=address.landmark,
            delivery_location={"lat": address.location.y, "lon": address.location.x},
            delivery_instructions=instructions or address.delivery_instructions,
            recipient_name=address.recipient_name or user.full_name,
            recipient_phone=recipient_phone,
            subtotal=priced.subtotal,
            delivery_fee=quote.fee,
            discount=discount,
            total=total,
            payment_method=payment_method,
            estimated_delivery_at=timezone.now()
            + dt.timedelta(
                minutes=restaurant.default_preparation_minutes + quote.estimated_minutes
            ),
        )

        OrderLine.objects.bulk_create(
            OrderLine(  # type: ignore[misc]
                order=order,
                menu_item=priced_line.line.menu_item,
                item_name=priced_line.line.menu_item.name,
                unit_price=priced_line.unit_price,
                quantity=priced_line.line.quantity,
                line_total=priced_line.total,
                # Copie figée : le libellé du groupe et celui de l'option sont
                # recopiés, pour qu'un renommage au catalogue ne réécrive pas
                # ce que le client a commandé.
                options=[
                    {
                        "group": option.group.name,
                        "option": option.name,
                        "delta": option.price_delta.amount_minor,
                        "currency": option.price_delta.currency,
                    }
                    for option in priced_line.options
                ],
                notes=priced_line.line.notes,
            )
            for priced_line in priced.lines
        )

        CartService.clear(cart)
        return order

    @staticmethod
    def _quote_for(restaurant: Restaurant, address: Address, subtotal: Money) -> DeliveryQuote:
        """Zone et frais de la course, calculés par PostGIS.

        La zone est celle qui couvre l'**adresse de livraison**, pas celle du
        restaurant : c'est le point d'arrivée qui détermine ce qu'on facture et
        ce qu'on refuse de desservir.
        """
        zone = (
            DeliveryZone.objects.filter(
                boundary__covers=address.location,
                is_active=True,
                city__is_active=True,
                city__country__is_active=True,
            )
            .order_by("max_distance_km")
            .first()
        )
        if zone is None:
            raise BusinessRuleViolation(
                "Cette adresse n'est desservie par aucune zone de livraison.",
                address_id=str(address.pk),
            )

        distance = (
            Restaurant.objects.filter(pk=restaurant.pk)
            .annotate(to_address=Distance("location", address.location))
            .values_list("to_address", flat=True)
            .first()
        )
        if distance is None:  # pragma: no cover - le restaurant vient d'être lu
            raise BusinessRuleViolation("Établissement introuvable.")

        return quote_delivery(zone=zone, distance_m=distance.m, subtotal=subtotal)

    # ---------------------------------------------------------- transitions

    @staticmethod
    @transaction.atomic
    def transition_to(
        *,
        order: Order,
        target: str,
        actor: User | None = None,
        reason: str = "",
    ) -> Order:
        """Fait avancer une commande — **le seul** chemin d'écriture du statut.

        La commande est verrouillée le temps de la transition : deux membres du
        personnel qui cliquent en même temps produiraient sinon deux
        événements de journal pour un seul changement, et l'un des deux
        écraserait l'autre.

        Un rejeu vers le statut courant ne fait rien et ne lève pas : c'est P1
        transposé aux commandes, et cela évite qu'un client qui tapote deux
        fois reçoive une erreur pour une action déjà accomplie.
        """
        locked = Order.objects.select_for_update().get(pk=order.pk)
        if ORDER_MACHINE.is_noop(locked.status, target):
            return locked

        ORDER_MACHINE.validate(locked.status, target)

        previous = locked.status
        locked.status = target
        touched = ["status"]

        if target == OrderStatus.DELIVERED:
            locked.delivered_at = timezone.now()
            touched.append("delivered_at")
        elif target == OrderStatus.CANCELLED:
            locked.cancelled_at = timezone.now()
            locked.cancellation_reason = reason
            touched += ["cancelled_at", "cancellation_reason"]

        locked.save(update_fields=[*touched, "updated_at"])

        # Le journal est écrit dans la même transaction que le changement :
        # l'historique est un sous-produit gratuit, pas une écriture séparée
        # qu'on peut oublier d'appeler depuis un nouveau point d'entrée.
        OrderStatusEvent.objects.create(
            order=locked, from_status=previous, to_status=target, actor=actor, reason=reason
        )

        if target == OrderStatus.DELIVERED:
            OrderService._record_purchases(locked)

        # La diffusion part **après le commit** et non pendant : annoncer
        # « commande confirmée » sur une transaction qui échoue ensuite laisse
        # le client devant un écran qui ment, et aucun événement ultérieur ne
        # vient le corriger.
        transaction.on_commit(
            lambda: publish(
                order_group(locked.pk),
                "order.status",
                {
                    "order": str(locked.pk),
                    "reference": locked.reference,
                    "from_status": previous,
                    "status": target,
                    "reason": reason,
                },
            )
        )

        # L'événement de domaine part d'ici. `orders` ne connaît aucun de ses
        # abonnés — c'est le second mécanisme de l'ADR-002, et la seule façon
        # pour `notifications` de réagir sans que le graphe de dépendances
        # devienne cyclique.
        order_status_changed.send(
            sender=Order, order=locked, previous=previous, target=target, reason=reason
        )

        return locked

    @staticmethod
    def _record_purchases(order: Order) -> None:
        """Informe le catalogue que ces articles ont été reçus (S1).

        `orders` connaît `catalog`, jamais l'inverse : c'est donc ici que part
        l'information, et c'est ce qui permet à un avis d'être marqué « achat
        vérifié » sans que le catalogue ait à interroger les commandes.
        """
        moment = order.delivered_at or timezone.now()
        for line in order.lines.select_related("menu_item"):
            record_purchase(user=order.customer, menu_item=line.menu_item, moment=moment)

    @staticmethod
    def cancel_by_customer(*, order: Order, user: User, reason: str) -> Order:
        """Annulation à l'initiative du client.

        Plus restrictive que la machine : passé la confirmation, la cuisine a
        engagé des denrées, et c'est au restaurant de décider ce qui est
        récupérable. Le refus cite l'état courant, pour que l'application
        puisse proposer d'appeler le restaurant plutôt que d'insister.
        """
        if order.status not in CUSTOMER_CANCELLABLE:
            raise BusinessRuleViolation(
                "Cette commande ne peut plus être annulée depuis l'application ; "
                "contactez le restaurant.",
                current_status=order.status,
            )
        return OrderService.transition_to(
            order=order, target=OrderStatus.CANCELLED, actor=user, reason=reason
        )
