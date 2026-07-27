"""Contrats de la fidélité — ADR-009.

**Tout est en lecture seule, et c'est l'essentiel de ce module.** Un point ne
s'obtient qu'en se faisant livrer une commande, ne se dépense qu'en échangeant
une récompense au catalogue. Aucun sérialiseur d'entrée n'accepte de `delta`, de
`balance`, de `points_cost` ni de `discount` : c'est C1 transposé à la fidélité.
Un client qui annoncerait son propre solde serait la même faille que celui qui
annonçait son propre prix.

L'échange n'a donc **aucun corps de requête** : la récompense est désignée par
l'URL, son coût est lu en base, et le solde est celui du jeton. Il n'y a rien
que l'appelant puisse déclarer, donc rien à valider — ce qui vaut mieux qu'une
validation à écrire correctement.
"""

from __future__ import annotations

from typing import Any

from rest_framework import serializers

from apps.loyalty.models import PointsAccount, PointsEntry, Reward, RewardRedemption
from apps.promotions.serializers import PromotionSerializer
from common.serializers import MoneyField

__all__ = [
    "PointsAccountSerializer",
    "PointsEntrySerializer",
    "RedemptionResultSerializer",
    "RewardRedemptionSerializer",
    "RewardSerializer",
]


class PointsAccountSerializer(serializers.ModelSerializer[PointsAccount]):
    """Le solde, tel que l'écran de fidélité l'affiche.

    Ni `id` ni horodatages de création : le compte est un singleton par
    utilisateur, dont l'identifiant ne sert à aucune route. L'exposer inviterait
    à le passer en paramètre quelque part, et donc à écrire un jour un
    cloisonnement de plus à tenir.

    Les cumuls de vie (`lifetime_earned`, `lifetime_spent`) sont là parce qu'un
    client qui voit « 120 points » sans savoir combien il en a gagné en tout n'a
    aucun moyen de vérifier que rien n'a disparu.
    """

    class Meta:
        model = PointsAccount
        fields = ["balance", "lifetime_earned", "lifetime_spent", "last_activity_at"]
        read_only_fields = fields


class PointsEntrySerializer(serializers.ModelSerializer[PointsEntry]):
    """Une ligne du journal (F5).

    C'est la pièce qui permet à un client de **contester** son solde : sans le
    détail des mouvements, « vous avez 120 points » est à prendre ou à laisser.
    D'où `balance_after`, qui fige ce que valait le compte à cet instant — un
    écart avec le solde courant devient visible au lieu d'être supposé absent.
    """

    class Meta:
        model = PointsEntry
        fields = ["id", "kind", "delta", "balance_after", "description", "order", "created_at"]
        read_only_fields = fields


class RewardSerializer(serializers.ModelSerializer[Reward]):
    """Une récompense du catalogue.

    `discount` sort en `Money` — `{"amount": "500", "currency": "XOF"}` — et non
    en entier nu : la règle de l'ADR-007 vaut pour tous les montants du projet,
    et une exception ici obligerait le client à traiter ce champ autrement que
    les vingt autres.
    """

    discount = MoneyField(read_only=True)

    class Meta:
        model = Reward
        fields = [
            "id",
            "name",
            "description",
            "kind",
            "points_cost",
            "discount",
            "validity_days",
            "restaurant",
        ]
        read_only_fields = fields


class RewardRedemptionSerializer(serializers.ModelSerializer[RewardRedemption]):
    """Un échange passé.

    `promotion_code` est repris ici plutôt que suivi par une clé étrangère vers
    la promotion : le code est ce que le client recopie dans son panier, et il
    doit rester lisible dans l'historique même si la promotion a expiré et
    qu'elle est purgée du catalogue.
    """

    reward = RewardSerializer(read_only=True)

    class Meta:
        model = RewardRedemption
        fields = ["id", "reward", "points_spent", "promotion_code", "created_at"]
        read_only_fields = fields


class RedemptionResultSerializer(serializers.Serializer[Any]):
    """Réponse d'un échange : ce qui a été acheté, le code, et le solde restant.

    Le solde est renvoyé avec le code pour épargner au client un second appel
    juste après le premier — l'écran qui affiche « voici votre code » affiche le
    nouveau solde à côté, et deux requêtes pour un geste laisseraient une
    fenêtre où l'un des deux nombres est périmé.
    """

    redemption = RewardRedemptionSerializer(read_only=True)
    promotion = PromotionSerializer(read_only=True)
    balance = serializers.IntegerField(read_only=True)
