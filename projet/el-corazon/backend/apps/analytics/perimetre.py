"""Périmètre d'un rapport — le filtre pays / ville / établissement.

## Ce que ce module corrige

Les rapports agrégeaient **toute l'enseigne**, sans exception. Un gérant
rattaché au seul établissement de Lomé, muni de `analytics.read`, lisait le
chiffre d'affaires d'Abidjan, ses articles les plus vendus et la rémunération
de ses livreurs. Le cloisonnement de l'ADR-005 s'appliquait partout — commandes,
catalogue, personnel — sauf ici, à l'endroit précis où la donnée est agrégée et
donc la plus parlante.

Le défaut ne se voyait pas : un rapport rendait des chiffres justes, simplement
pas les siens. Rien dans la réponse ne disait sur quoi elle portait.

## Deux filtres qui n'ont pas le même statut

* **Le périmètre du compte** est une contrainte. Il n'est pas négociable et ne
  s'annonce pas dans la requête ; il vient de `staff_restaurant_ids`, le même
  point de passage que les autres écrans, si bien qu'un rattachement ajouté
  demain élargira les rapports sans qu'on y revienne.
* **Le filtre demandé** (`?country=`, `?city=`, `?restaurant=`) est un
  affinage. Il restreint, jamais il n'élargit : les deux se composent par
  **intersection**, et un compte cloisonné qui demande le pays entier obtient
  ce qu'il a le droit de voir de ce pays, pas le pays.

C'est cette composition qui permet de rendre le filtre au client sans le
transformer en levier : `?restaurant=el-corazon-abidjan` demandé par le gérant
de Lomé rend un périmètre vide, pas les chiffres d'Abidjan.

## Pourquoi un ensemble d'identifiants, et non un `Q`

Les six rapports partent de tables différentes — commandes, lignes de commande,
courses, articles — et le chemin vers l'établissement diffère à chaque fois
(`restaurant_id`, `order__restaurant_id`, `menu_item__restaurant_id`). Un
`Q` tout fait obligerait chaque appelant à connaître le sien ; un ensemble
d'identifiants se compose avec n'importe quel chemin par un simple `__in`.

L'ensemble est résolu en une requête, avant les agrégations : les rapports
n'ont alors plus de jointure à faire vers la géographie.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from typing import Any

from rest_framework import serializers

from apps.accounts.models import User
from apps.restaurants.models import Restaurant
from apps.restaurants.scoping import staff_restaurant_ids
from common.permissions import is_unscoped

__all__ = ["Perimetre", "PerimetreQuerySerializer", "resolve_perimetre"]


class PerimetreQuerySerializer(serializers.Serializer[Any]):
    """Les trois clés de lecture du réseau, toutes facultatives.

    Des **slugs** et un code ISO, pas des identifiants techniques : ce sont les
    valeurs que le back-office a déjà en main quand il affiche un filtre, et
    elles restent lisibles dans un journal ou une URL partagée.

    Aucune validation d'existence ici. Un pays inconnu doit rendre un rapport
    vide, pas une erreur : le filtre est un affinage, et une ville fermée hier
    est une réponse vide parfaitement correcte — la traiter en 400 ferait
    échouer un tableau de bord dont l'utilisateur n'a rien fait de mal.
    """

    country = serializers.CharField(required=False, help_text="Code ISO 3166-1 alpha-2, ex. TG.")
    city = serializers.CharField(required=False, help_text="Slug de la ville, ex. lome.")
    restaurant = serializers.CharField(
        required=False, help_text="Slug de l'établissement, ex. el-corazon-lome."
    )


@dataclass(frozen=True, slots=True)
class Perimetre:
    """Les établissements sur lesquels porte un rapport.

    `restaurant_ids` à `None` signifie « toute l'enseigne » et n'arrive que pour
    un compte non cloisonné qui n'a demandé aucun filtre. C'est délibérément
    distinct de l'ensemble vide, qui veut dire « rien à montrer » : confondre
    les deux ferait rendre les chiffres de l'enseigne à un compte dont le
    périmètre est vide — exactement l'élargissement silencieux que l'ADR-005
    cherche à empêcher.
    """

    restaurant_ids: frozenset[uuid.UUID] | None

    @property
    def is_global(self) -> bool:
        return self.restaurant_ids is None

    @property
    def is_empty(self) -> bool:
        """Rien à montrer — un filtre hors périmètre, ou un compte non rattaché."""
        return self.restaurant_ids is not None and not self.restaurant_ids

    def filtre(self, chemin: str) -> dict[str, Any]:
        """Clause `filter()` pour un chemin donné vers l'établissement.

        Rend un dictionnaire vide quand le périmètre est global : le rapport
        n'ajoute alors aucune condition, et ne paie pas la clause `IN` inutile
        qu'un `__in` sur tous les établissements coûterait.

        Exemple : `Order.objects.filter(**perimetre.filtre("restaurant_id"))`.
        """
        if self.restaurant_ids is None:
            return {}
        return {f"{chemin}__in": self.restaurant_ids}


def resolve_perimetre(*, user: User, params: dict[str, Any]) -> Perimetre:
    """Compose le périmètre du compte et le filtre demandé.

    L'ordre est ce qui compte : on part de ce que le compte a le droit de voir,
    **puis** on restreint. L'inverse — partir du filtre et vérifier ensuite —
    laisserait la fenêtre entre les deux, et c'est dans cette fenêtre que les
    fuites s'écrivent.
    """
    demande = _restaurants_demandes(params)
    autorise = None if is_unscoped(user) else frozenset(staff_restaurant_ids(user))

    if demande is None:
        return Perimetre(restaurant_ids=autorise)
    if autorise is None:
        return Perimetre(restaurant_ids=demande)
    return Perimetre(restaurant_ids=demande & autorise)


def _restaurants_demandes(params: dict[str, Any]) -> frozenset[uuid.UUID] | None:
    """Établissements désignés par les filtres, ou `None` si aucun n'est posé.

    Les trois filtres se cumulent au lieu de se remplacer : `?country=TG&
    city=lome` est « Lomé, si Lomé est au Togo », et non « Lomé ». Un filtre qui
    en écraserait un autre rendrait des chiffres justes pour une question que
    personne n'a posée.
    """
    conditions: dict[str, Any] = {}
    if pays := params.get("country"):
        # Les codes ISO sont stockés en majuscules ; un filtre saisi en
        # minuscules dans une URL ne doit pas rendre un rapport vide.
        conditions["zone__city__country__iso_code__iexact"] = pays
    if ville := params.get("city"):
        conditions["zone__city__slug"] = ville
    if etablissement := params.get("restaurant"):
        conditions["slug"] = etablissement

    if not conditions:
        return None
    return frozenset(Restaurant.objects.filter(**conditions).values_list("pk", flat=True))
