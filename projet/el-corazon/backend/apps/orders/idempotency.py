"""Rejeu sûr des créations — ADR-009.

Le réseau mobile coupe pendant l'envoi bien plus souvent qu'on ne le croit. Un
client qui perd la connexion après avoir posté sa commande ne sait pas si elle
est passée ; il retente. Sans clé d'idempotence, il en crée une seconde, et le
problème se découvre à la livraison de deux repas.

La réponse d'origine est mémorisée, pas seulement le fait qu'un appel a eu
lieu : un rejeu doit renvoyer **exactement** la même chose, sans quoi le client
retenterait encore, faute de reconnaître ce qu'il reçoit.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

from django.db import IntegrityError, transaction
from rest_framework.renderers import JSONRenderer

from apps.accounts.models import User
from apps.orders.models import IdempotencyKey, Order

__all__ = ["StoredResponse", "recall", "remember"]


@dataclass(frozen=True, slots=True)
class StoredResponse:
    status: int
    body: Any


def recall(*, user: User, endpoint: str, key: str) -> StoredResponse | None:
    """Réponse déjà produite pour cette clé, ou `None`.

    La recherche est **portée à l'utilisateur** : deux clients peuvent tirer la
    même clé sans se gêner, et personne ne lit la réponse d'autrui en devinant
    la sienne.
    """
    record = IdempotencyKey.objects.filter(user=user, endpoint=endpoint, key=key).first()
    return None if record is None else StoredResponse(record.response_status, record.response_body)


def remember(
    *, user: User, endpoint: str, key: str, order: Order, status: int, body: Any
) -> StoredResponse:
    """Mémorise la réponse, ou rend celle qu'une requête concurrente a gagnée.

    Deux envois simultanés de la même clé — un client qui retente pendant que
    le premier appel est encore en vol — arrivent tous deux ici. L'unicité en
    base en laisse passer un ; l'autre relit et renvoie la réponse du premier.
    C'est la contrainte qui arbitre, pas un `if déjà_traité` qui aurait le
    temps de passer deux fois.
    """
    # Le corps est repassé par le rendu JSON de DRF avant d'être stocké : une
    # réponse fraîche contient des `UUID`, des `Decimal` et des `datetime` que
    # `JSONField` refuse. Le rejeu doit rendre *exactement* ce qu'a reçu le
    # premier appel, donc c'est bien la forme rendue qu'on mémorise.
    stored_body = json.loads(JSONRenderer().render(body))

    try:
        with transaction.atomic():
            IdempotencyKey.objects.create(
                user=user,
                endpoint=endpoint,
                key=key,
                order=order,
                response_status=status,
                response_body=stored_body,
            )
    except IntegrityError:
        stored = recall(user=user, endpoint=endpoint, key=key)
        if stored is not None:
            return stored
        raise

    return StoredResponse(status, stored_body)
