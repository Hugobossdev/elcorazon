"""Règles du catalogue qui ne tiennent pas dans une vue.

L'ADR-003 est explicite : le CRUD du catalogue va du ViewSet à l'ORM, sans
service. Ce module ne contient donc **que** ce qui porte une décision métier ou
une transaction — l'avis, qui a les deux :

* la mention « achat vérifié » est décidée par le serveur (S1) ;
* écrire l'avis et rafraîchir la note de l'article doivent réussir ou échouer
  ensemble, sinon la moyenne affichée cesse de correspondre aux avis affichés.
"""

from __future__ import annotations

import datetime as dt
from decimal import ROUND_HALF_UP, Decimal

from django.db import transaction
from django.db.models import Avg, Count

from apps.accounts.models import User
from apps.catalog.models import MenuItem, Review, VerifiedPurchase
from common.exceptions import BusinessRuleViolation

__all__ = ["ReviewService", "record_purchase"]


def record_purchase(*, user: User, menu_item: MenuItem, moment: dt.datetime) -> VerifiedPurchase:
    """Enregistre qu'un client a bien reçu un article.

    Appelée par `orders` à la livraison — le sens autorisé par le graphe de
    dépendances (ADR-002). Idempotente : dix commandes du même article
    n'écrivent qu'une ligne, dont seule la date se rafraîchit.
    """
    purchase, _ = VerifiedPurchase.objects.update_or_create(
        user=user, menu_item=menu_item, defaults={"last_purchased_at": moment}
    )
    return purchase


class ReviewService:
    """Écriture d'un avis et entretien des agrégats de note."""

    @staticmethod
    @transaction.atomic
    def submit(
        *, user: User, menu_item: MenuItem, rating: int, title: str = "", comment: str = ""
    ) -> Review:
        """Dépose un avis.

        S5 — un seul avis par article et par utilisateur. La contrainte est en
        base ; la vérification préalable n'est là que pour rendre le refus
        lisible (409 avec un code stable) plutôt qu'une violation d'intégrité.

        S1 — `is_verified_purchase` n'est jamais lu depuis la requête. Le champ
        est `editable=False`, donc absent des sérialiseurs générés : l'oubli
        est impossible, pas seulement improbable.
        """
        if Review.objects.filter(menu_item=menu_item, user=user).exists():
            raise BusinessRuleViolation(
                "Un avis a déjà été déposé sur cet article.", menu_item_id=str(menu_item.pk)
            )

        review = Review(
            menu_item=menu_item,
            user=user,
            rating=rating,
            title=title,
            comment=comment,
        )
        review.is_verified_purchase = VerifiedPurchase.objects.filter(
            user=user, menu_item=menu_item
        ).exists()
        review.save()

        ReviewService.refresh_rating(menu_item)
        return review

    @staticmethod
    def refresh_rating(menu_item: MenuItem) -> None:
        """Recalcule `rating_average` et `rating_count` depuis les avis.

        Recalcul complet plutôt que moyenne glissante : une moyenne entretenue
        par incréments dérive dès qu'un avis est supprimé ou modéré, et l'écart
        ne se voit jamais. Le coût est celui d'un `AVG` sur l'index
        `(menu_item, -created_at)`, payé à l'écriture d'un avis — soit
        plusieurs milliers de fois moins souvent qu'une lecture de menu.
        """
        aggregate = Review.objects.filter(menu_item=menu_item).aggregate(
            average=Avg("rating"), total=Count("id")
        )
        average = Decimal(aggregate["average"] or 0).quantize(
            Decimal("0.01"), rounding=ROUND_HALF_UP
        )

        MenuItem.objects.filter(pk=menu_item.pk).update(
            rating_average=average, rating_count=aggregate["total"]
        )
        # L'instance en mémoire est ressynchronisée : la vue la sérialise juste
        # après, et elle rendrait sinon la note d'avant l'avis qu'on vient
        # d'écrire.
        menu_item.rating_average = average
        menu_item.rating_count = aggregate["total"]
