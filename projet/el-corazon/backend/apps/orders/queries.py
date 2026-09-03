"""Fragments de requête partagés par les deux publics des commandes.

`views.py` sert le client et le livreur, `backoffice.py` le personnel. Les deux
rendent `OrderSerializer`, donc les deux doivent poser les mêmes annotations —
et aucun des deux n'a de raison d'importer l'autre pour cela.
"""

from __future__ import annotations

from django.db.models import Count, QuerySet, Sum, Value
from django.db.models.functions import Coalesce

from apps.orders.models import Order

__all__ = ["avec_compteurs"]


def avec_compteurs(queryset: QuerySet[Order]) -> QuerySet[Order]:
    """Annote le nombre de lignes et le nombre d'articles d'une commande.

    **En base et en une seule requête**, pour toute la page.

    C'est ce qui permet à la forme de liste d'annoncer « 6 articles » sans
    porter les lignes. Sans ces compteurs, le back-office affichait « 0 article »
    sur *toutes* les commandes, suivi d'un bandeau « aucun article trouvé dans
    cette commande » — sur des commandes qui en contenaient. La carte lisait
    `lines`, que `OrderSerializer` ne rend pas et ne doit pas rendre : renvoyer
    les lignes de vingt commandes pour n'en afficher que le nombre multiplierait
    par dix le poids de chaque page.

    Deux détails qui comptent :

    * `distinct=True` sur `Count` — sans lui, la jointure des lignes se
      multiplie par toute autre jointure présente dans la requête, et un simple
      `select_related` suffit à fausser le compte ;
    * `Coalesce` — une commande sans ligne sortirait `null` plutôt que zéro, et
      le client aurait à distinguer les deux pour rien.

    `Sum` n'a pas besoin de `distinct` : il porte sur `lines__quantity`, dont
    chaque ligne est déjà unique par construction.
    """
    return queryset.annotate(
        lines_count=Coalesce(Count("lines", distinct=True), Value(0)),
        items_count=Coalesce(Sum("lines__quantity"), Value(0)),
    )
