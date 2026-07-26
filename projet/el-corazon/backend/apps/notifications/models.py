"""Notifications in-app — ADR-008.

Le WebSocket et le push sont des **transports** : ils atteignent l'utilisateur
s'il est là, et se perdent sinon. La notification est la trace persistante du
même événement — ce que l'utilisateur retrouve en ouvrant son application deux
heures plus tard, quand le socket était fermé et la bannière push balayée.

D'où une table plutôt qu'un simple envoi. L'implémentation précédente n'en
avait pas : un changement de statut manqué était manqué pour toujours.
"""

from __future__ import annotations

from django.db import models

from apps.accounts.models import User
from common.models import TimeStampedModel, UUIDModel

__all__ = ["Notification", "NotificationKind"]


class NotificationKind(models.TextChoices):
    ORDER_STATUS = "order_status", "Statut de commande"
    DELIVERY_OFFER = "delivery_offer", "Course proposée"
    PAYMENT = "payment", "Paiement"
    ACCOUNT = "account", "Compte"
    MARKETING = "marketing", "Marketing"


class Notification(UUIDModel, TimeStampedModel):
    """Message destiné à une personne, lisible après coup.

    `kind` n'est pas décoratif : il porte la distinction entre le
    **transactionnel** et le **marketing**, qui décide si l'envoi respecte les
    préférences de l'utilisateur. « Votre livreur arrive » part quoi qu'il
    arrive ; « −20 % ce week-end » se coupe.
    """

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="notifications")
    kind = models.CharField(max_length=16, choices=NotificationKind.choices, db_index=True)

    title = models.CharField(max_length=120)
    body = models.TextField()

    # Charge utile minimale, à l'usage du client : de quoi ouvrir le bon écran.
    # Pas de duplication de l'objet métier — il aura changé d'ici la lecture.
    data = models.JSONField(default=dict, blank=True)

    read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = "notification"
        ordering = ["-created_at"]
        indexes = [
            # La requête de l'écran : mes notifications, les plus récentes
            # d'abord. Et le compteur de non-lues, qui est la même requête
            # filtrée.
            models.Index(fields=["user", "-created_at"]),
            models.Index(fields=["user", "read_at"]),
        ]

    def __str__(self) -> str:
        return f"{self.get_kind_display()} — {self.title}"

    @property
    def is_read(self) -> bool:
        return self.read_at is not None
