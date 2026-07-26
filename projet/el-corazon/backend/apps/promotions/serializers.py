"""Contrats des promotions — ADR-009, invariant F4.

Ce module ne décrit **que** la promotion elle-même. La route qui l'évalue vit
dans `orders` et non ici, et ce n'est pas un détail de rangement : l'évaluer
demande de lire un panier et un barème de zone, donc de connaître `carts` et
`geography`. `promotions` est en amont de `orders` dans le graphe de
l'ADR-002 ; lui faire connaître le panier aurait été une dépendance de plus
dans le mauvais sens.

C'est un test d'architecture qui l'a signalé — la première rédaction plaçait
la route ici.
"""

from __future__ import annotations

from rest_framework import serializers

from apps.promotions.models import Promotion
from common.serializers import MoneyField

__all__ = ["PromotionSerializer"]


class PromotionSerializer(serializers.ModelSerializer[Promotion]):
    """Ce qu'on montre d'un code.

    Ni `used_count`, ni `usage_limit` : le nombre d'utilisations restantes est
    une information commerciale, et l'exposer inviterait à courir sur les
    derniers coupons — ou à découvrir qu'un code n'a servi à personne.
    """

    amount = MoneyField(read_only=True)
    min_order_amount = MoneyField(read_only=True)
    max_discount = MoneyField(read_only=True)

    class Meta:
        model = Promotion
        fields = [
            "id",
            "code",
            "description",
            "kind",
            "percentage",
            "amount",
            "min_order_amount",
            "max_discount",
            "starts_at",
            "ends_at",
        ]
        read_only_fields = fields
