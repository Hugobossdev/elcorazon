"""Périmètre d'un membre du personnel — ADR-005, troisième étage.

Le modèle d'autorisation a trois étages : le type de compte, la permission
nommée, et **l'appartenance de la ressource**. Les deux premiers vivent dans
`common.permissions` ; le troisième est ici, et il s'applique dans les
`get_queryset` — pas dans une permission d'objet, sinon la ressource interdite
serait d'abord chargée puis refusée, ce qui trahit son existence par le code de
statut.

Sans ce filtre, « personnel » désigne une population indistincte : un opérateur
du restaurant de Kara lit et fait avancer les commandes de Lomé. La permission
dit ce qu'on a le droit de faire ; ce module dit sur quoi.
"""

from __future__ import annotations

import uuid

from apps.accounts.models import User
from apps.restaurants.models import StaffMembership

__all__ = ["is_unscoped", "staff_restaurant_ids"]


def is_unscoped(user: User) -> bool:
    """Vrai pour les comptes qui voient l'enseigne entière.

    Seul le superutilisateur en fait partie. Le rendre explicite évite qu'un
    appelant confonde « aucun rattachement » — un membre du personnel qu'on a
    oublié de rattacher, qui ne doit donc rien voir — avec « tous les
    établissements ». C'est exactement l'ambiguïté qui transforme un oubli de
    configuration en fuite de données.
    """
    return user.is_superuser


def staff_restaurant_ids(user: User) -> set[uuid.UUID]:
    """Établissements sur lesquels ce compte a un rattachement.

    Ensemble vide pour un membre du personnel non rattaché : il ne verra rien,
    et c'est le bon défaut. Une panne visible se corrige en une ligne de
    back-office ; un accès trop large, silencieux, ne se découvre pas.
    """
    return set(StaffMembership.objects.filter(user=user).values_list("restaurant_id", flat=True))
