"""Affectation et cycle de vie des courses — invariants L1, L2, L4, L5.

Ce module est le seul chemin d'écriture du statut d'une course, et le seul
endroit qui projette ce statut sur la commande. La projection est **déclarée**
dans `states.ORDER_STATUS_PROJECTION` et appliquée ici : c'est une projection
écrite à la main, dispersée dans les contrôleurs, qui avait produit C4.

L2 mérite un mot. La contrainte d'unicité partielle en base suffit à empêcher
deux courses actives sur une commande ; le verrou applicatif qu'on pose en plus
n'est pas une redondance décorative. Sans lui, le second livreur reçoit une
`IntegrityError` — une erreur 500 illisible — au lieu d'un refus métier qui lui
dit que la course vient d'être prise.
"""

from __future__ import annotations

from django.conf import settings
from django.contrib.gis.db.models.functions import Distance
from django.db import transaction
from django.db.models import F, QuerySet
from django.utils import timezone

from apps.accounts.models import User
from apps.delivery.models import Assignment, CourierProfile
from apps.delivery.states import (
    DELIVERY_MACHINE,
    ORDER_STATUS_PROJECTION,
    VERIFICATION_MACHINE,
    DeliveryStatus,
    VerificationStatus,
)
from apps.orders.models import Order
from apps.orders.services import OrderService
from apps.orders.states import ORDER_MACHINE, OrderStatus
from common.exceptions import BusinessRuleViolation
from common.money import Money

__all__ = ["AssignmentService", "CourierService", "courier_fee_for"]

#: Statuts de commande depuis lesquels une course peut être proposée.
#:
#: Ni avant `confirmed` — le paiement n'est pas acquis et la cuisine n'a rien
#: lancé — ni après `ready`, où le repas est déjà parti. Proposer plus tôt
#: mobiliserait un livreur pour une commande qui peut encore être annulée sans
#: frais.
OFFERABLE_FROM = frozenset({OrderStatus.CONFIRMED, OrderStatus.PREPARING, OrderStatus.READY})


def courier_fee_for(order: Order) -> Money:
    """Part des frais de livraison revenant au livreur.

    Un pourcentage explicite et configurable plutôt qu'un montant recopié : la
    plateforme retient une commission, et l'écrire en dur ici obligerait à un
    déploiement pour la changer d'un point. La part est **figée sur la course à
    l'acceptation** — le barème peut évoluer, ce qui est dû pour cette course
    ne bouge plus.
    """
    return order.delivery_fee.percentage(settings.COURIER_FEE_SHARE_PERCENT)


class CourierService:
    """Dossier livreur : validation, disponibilité, pièces."""

    @staticmethod
    @transaction.atomic
    def review(
        *,
        courier: CourierProfile,
        target: str,
        actor: User,
        notes: str = "",
    ) -> CourierProfile:
        """Fait avancer le dossier — validation, rejet, suspension.

        La machine du dossier est la seule **cyclique** du projet : un dossier
        se ré-instruit, alors qu'une course ne se re-livre pas. Le passage par
        `VERIFICATION_MACHINE` garantit qu'on ne saute pas d'étape pour autant
        — on ne suspend pas un dossier jamais validé.
        """
        locked = CourierProfile.objects.select_for_update().get(pk=courier.pk)
        if VERIFICATION_MACHINE.is_noop(locked.verification_status, target):
            return locked

        VERIFICATION_MACHINE.validate(locked.verification_status, target)

        locked.verification_status = target
        locked.verification_notes = notes
        locked.verified_by = actor
        locked.verified_at = timezone.now()

        # Un dossier qui cesse d'être validé remet le livreur hors ligne. Sans
        # cela, il resterait « en ligne » et continuerait d'apparaître dans les
        # listes d'affectation, où seul `can_accept_orders` l'écarterait — une
        # garde de plus à ne pas oublier ailleurs.
        if target != VerificationStatus.APPROVED:
            locked.is_online = False

        locked.save(
            update_fields=[
                "verification_status",
                "verification_notes",
                "verified_by",
                "verified_at",
                "is_online",
                "updated_at",
            ]
        )
        return locked

    @staticmethod
    def set_online(*, courier: CourierProfile, is_online: bool) -> CourierProfile:
        """Bascule de disponibilité, à l'initiative du livreur.

        Se mettre en ligne exige un dossier validé (L1). Le refus est explicite
        plutôt que silencieux : un livreur qui bascule l'interrupteur et ne
        reçoit aucune course ne doit pas avoir à deviner que son dossier est en
        attente.
        """
        if is_online and courier.verification_status != VerificationStatus.APPROVED:
            raise BusinessRuleViolation(
                "Votre dossier n'est pas validé ; vous ne pouvez pas encore recevoir de courses.",
                verification_status=courier.verification_status,
            )

        courier.is_online = is_online
        courier.save(update_fields=["is_online", "updated_at"])
        return courier

    @staticmethod
    @transaction.atomic
    def replace_documents(*, courier: CourierProfile, **documents: object) -> CourierProfile:
        """Remplace des pièces justificatives — **et repasse le dossier en attente** (L5).

        C'est une règle de conformité, pas une commodité : un dossier validé
        sur des pièces qu'on a ensuite remplacées n'est plus un dossier validé.
        Laisser l'approbation en place reviendrait à valider des documents que
        personne n'a lus.
        """
        for field, value in documents.items():
            setattr(courier, field, value)

        touched = [*documents]
        if courier.verification_status == VerificationStatus.APPROVED:
            courier.verification_status = VerificationStatus.PENDING
            courier.is_online = False
            touched += ["verification_status", "is_online"]

        courier.save(update_fields=[*touched, "updated_at"])
        return courier

    @staticmethod
    def available_for(order: Order) -> QuerySet[CourierProfile]:
        """Livreurs éligibles pour cette commande, du plus proche au plus loin.

        Le tri est fait par PostGIS depuis la position du **restaurant** : le
        livreur doit d'abord y arriver. Trier depuis l'adresse de livraison
        privilégierait quelqu'un déjà à l'autre bout de la course.

        Un livreur sans position connue reste dans la liste, en fin de tri :
        l'écarter reviendrait à exclure celui qui vient de démarrer son
        application.
        """
        return (
            CourierProfile.objects.filter(
                restaurant=order.restaurant,
                is_online=True,
                verification_status=VerificationStatus.APPROVED,
                user__is_active=True,
            )
            .select_related("user")
            .annotate(to_restaurant=Distance("last_location", order.restaurant.location))
            .order_by("to_restaurant")
        )


class AssignmentService:
    # ---------------------------------------------------------------- offre

    @staticmethod
    @transaction.atomic
    def offer(*, order: Order, courier: CourierProfile, actor: User | None = None) -> Assignment:
        """Propose une course à un livreur.

        Le verrou porte sur la **commande** et non sur la course : ce qu'on
        protège est l'unicité de la course active, qui est une propriété de la
        commande. Verrouiller la course qu'on s'apprête à créer ne protégerait
        rien.
        """
        locked = Order.objects.select_for_update().get(pk=order.pk)

        if locked.status not in OFFERABLE_FROM:
            raise BusinessRuleViolation(
                "Une course ne se propose qu'entre la confirmation et la mise à "
                "disposition du repas.",
                current_status=locked.status,
            )
        if not courier.can_accept_orders:
            # L1 — relu depuis le dossier, jamais déduit d'un jeton ni d'un
            # champ envoyé par le client.
            raise BusinessRuleViolation(
                "Ce livreur n'est pas éligible : dossier non validé, hors ligne "
                "ou compte désactivé.",
                courier_id=str(courier.pk),
            )
        if courier.restaurant_id != locked.restaurant_id:
            raise BusinessRuleViolation(
                "Ce livreur n'est pas rattaché à l'établissement de la commande."
            )

        active = AssignmentService._active_for(locked)
        if active is not None:
            raise BusinessRuleViolation(
                "Cette commande a déjà une course en cours.",
                assignment_id=str(active.pk),
                assignment_status=active.status,
            )

        return Assignment.objects.create(order=locked, courier=courier)

    @staticmethod
    def _active_for(order: Order) -> Assignment | None:
        return order.assignments.exclude(
            status__in=[
                DeliveryStatus.DECLINED,
                DeliveryStatus.CANCELLED,
                DeliveryStatus.DELIVERED,
            ]
        ).first()

    # ----------------------------------------------------------- acceptation

    @staticmethod
    @transaction.atomic
    def accept(*, assignment: Assignment, courier: CourierProfile) -> Assignment:
        """Acceptation par le livreur — exclusive et atomique (L2).

        L'ancien code n'avait aucun verrou : deux livreurs pouvaient prendre la
        même course, et l'un des deux faisait le trajet pour rien. Le verrou
        est posé sur la commande, dans le même ordre que `offer`, pour que deux
        chemins concurrents ne s'interbloquent pas.
        """
        Order.objects.select_for_update().get(pk=assignment.order_id)
        current = Assignment.objects.select_related("order").get(pk=assignment.pk)

        if current.courier_id != courier.pk:
            raise BusinessRuleViolation("Cette course est proposée à un autre livreur.")
        if not courier.can_accept_orders:
            raise BusinessRuleViolation(
                "Votre dossier ne vous permet pas d'accepter une course.",
                verification_status=courier.verification_status,
            )

        DELIVERY_MACHINE.validate(current.status, DeliveryStatus.ACCEPTED)

        current.status = DeliveryStatus.ACCEPTED
        current.accepted_at = timezone.now()
        # Rémunération figée maintenant : le barème peut changer d'ici la
        # livraison, ce qui est dû pour cette course ne change plus.
        current.courier_fee = courier_fee_for(current.order)
        current.save(
            update_fields=[
                "status",
                "accepted_at",
                "courier_fee_minor",
                "courier_fee_currency",
                "updated_at",
            ]
        )
        return current

    @staticmethod
    @transaction.atomic
    def decline(*, assignment: Assignment, courier: CourierProfile, reason: str = "") -> Assignment:
        """Refus par le livreur : la commande redevient proposable à un autre."""
        if assignment.courier_id != courier.pk:
            raise BusinessRuleViolation("Cette course est proposée à un autre livreur.")

        DELIVERY_MACHINE.validate(assignment.status, DeliveryStatus.DECLINED)

        assignment.status = DeliveryStatus.DECLINED
        assignment.decline_reason = reason
        assignment.save(update_fields=["status", "decline_reason", "updated_at"])
        return assignment

    # ---------------------------------------------------------- progression

    @staticmethod
    @transaction.atomic
    def transition_to(
        *,
        assignment: Assignment,
        target: str,
        actor: User | None = None,
        reason: str = "",
    ) -> Assignment:
        """Fait avancer une course et **projette** son statut sur la commande.

        Un rejeu vers le statut courant ne fait rien : un livreur qui tapote
        deux fois « récupéré » dans une zone à réseau instable ne doit pas
        recevoir d'erreur, ni voir la commande avancer deux fois.
        """
        locked = (
            Assignment.objects.select_for_update()
            .select_related("order", "courier")
            .get(pk=assignment.pk)
        )
        if DELIVERY_MACHINE.is_noop(locked.status, target):
            return locked

        DELIVERY_MACHINE.validate(locked.status, target)

        # Une commande annulée arrête la course. La règle vit ici et non dans
        # une projection inverse : `orders` ne connaît pas `delivery` (ADR-002),
        # c'est donc à la course de se tenir au courant de sa commande. Sans
        # cette garde, un livreur continuerait à faire avancer — et à se faire
        # créditer — une course dont le repas ne partira jamais.
        if locked.order.status == OrderStatus.CANCELLED and target != DeliveryStatus.CANCELLED:
            raise BusinessRuleViolation(
                "La commande a été annulée ; cette course ne peut plus avancer.",
                order_status=locked.order.status,
            )

        locked.status = target
        touched = ["status"]
        if target == DeliveryStatus.PICKED_UP:
            locked.picked_up_at = timezone.now()
            touched.append("picked_up_at")
        elif target == DeliveryStatus.DELIVERED:
            locked.delivered_at = timezone.now()
            touched.append("delivered_at")
        elif target == DeliveryStatus.CANCELLED:
            locked.decline_reason = reason
            touched.append("decline_reason")

        locked.save(update_fields=[*touched, "updated_at"])

        AssignmentService._project(locked, target, actor=actor, reason=reason)

        if target == DeliveryStatus.DELIVERED:
            AssignmentService._credit(locked)
        elif target == DeliveryStatus.CANCELLED:
            # `F(...) + 1` plutôt qu'une lecture suivie d'une écriture : deux
            # annulations concurrentes en perdraient une, et le compteur du
            # livreur mentirait sans que rien ne le signale.
            CourierProfile.objects.filter(pk=locked.courier_id).update(
                deliveries_cancelled=F("deliveries_cancelled") + 1
            )

        return locked

    @staticmethod
    def _project(assignment: Assignment, target: str, *, actor: User | None, reason: str) -> None:
        """Répercute l'étape de course sur la commande, si elle en a une.

        `offered`, `accepted` et `declined` ne projettent rien : ce sont des
        événements internes à l'affectation. La commande reste `ready` tant que
        le repas n'est pas parti — c'est en voulant projeter `accepted` que
        l'ancien code écrivait un statut hors énumération.
        """
        projected = ORDER_STATUS_PROJECTION.get(target)
        if projected is None:
            return
        if not ORDER_MACHINE.can(assignment.order.status, projected):
            # La commande a été menée ailleurs entre-temps — annulée par le
            # restaurant, par exemple. La course, elle, a bien avancé : on ne
            # force pas la commande à suivre, et on ne fait pas échouer le
            # livreur pour une décision prise sans lui.
            return

        OrderService.transition_to(
            order=assignment.order, target=projected, actor=actor, reason=reason
        )

    @staticmethod
    def _credit(assignment: Assignment) -> None:
        """Incrémente les compteurs et les gains du livreur — **une seule fois** (L4).

        La garde n'est pas ici mais dans le graphe : `delivered` est terminal,
        donc la transition ne peut pas être rejouée, donc les compteurs ne
        peuvent pas l'être non plus. C'est ce qui ferme C3, où rejouer
        `delivered` réincrémentait les compteurs à chaque appel.
        """
        courier = CourierProfile.objects.select_for_update().get(pk=assignment.courier_id)
        courier.deliveries_completed += 1

        earned = assignment.courier_fee
        if earned is not None:
            current = courier.total_earnings or Money.zero(earned.currency)
            courier.total_earnings = current + earned

        courier.save(
            update_fields=[
                "deliveries_completed",
                "total_earnings_minor",
                "total_earnings_currency",
                "updated_at",
            ]
        )
