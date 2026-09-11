"""Journal des décisions d'exploitation — qui a changé quoi, et depuis quelle valeur.

## Ce que ce module comble

Aucune trace n'existait. Déplacer un établissement de trois cents mètres,
redessiner une zone, doubler un forfait de livraison : tout cela s'écrivait en
base sans que rien ne dise qui l'avait décidé ni ce qu'il y avait avant. Le jour
où les frais d'un quartier changent sans explication, la seule réponse
disponible était « c'est comme ça maintenant ».

Ces trois écritures ont une propriété commune qui les distingue du reste : elles
sont **silencieuses et coûteuses**. Un catalogue mal saisi se voit à l'écran ; un
rayon de zone réduit de deux kilomètres ne se voit que dans les commandes qu'on
ne reçoit plus.

## Ce qui est journalisé, et ce qui ne l'est pas

Seulement ce que l'exploitation a besoin de reconstituer : la géographie et les
barèmes. Journaliser toute écriture produirait un volume qui rend le journal
illisible — et donc inutilisé, ce qui est pire qu'absent.

Les transitions d'état ont déjà leur trace ailleurs (machines à états,
événements de domaine) ; les dupliquer ici ferait deux vérités.

## Pourquoi la cible n'est pas une clé étrangère

`target_id` est un UUID nu, doublé d'un `target_label` figé au moment du
changement. Trois raisons, et la troisième est décisive :

* une clé étrangère vers `Restaurant` ferait dépendre `common` de
  `restaurants`, ce que le graphe interdit (ADR-002) ;
* une même table doit pouvoir viser des pays, des zones et des établissements ;
* **un journal doit survivre à ce qu'il décrit.** Une entrée qui disparaîtrait
  avec la zone supprimée ne servirait précisément dans aucun des cas où l'on
  ouvre un journal.

Le libellé est recopié pour la même raison : « zone Cocody » reste lisible même
si la zone a depuis été renommée ou retirée.
"""

from __future__ import annotations

from typing import Any

from apps.accounts.models import User
from common.models import AuditEntry

__all__ = ["AuditAction", "AuditEntry", "record_change"]


class AuditAction:
    """Vocabulaire fermé des changements journalisés.

    Des constantes plutôt qu'un `TextChoices` : ce ne sont pas des états d'un
    objet, et le champ reste une chaîne libre en base pour qu'une action ajoutée
    demain n'impose pas de migration. Le registre existe pour que les appelants
    partagent les mêmes clés, pas pour que la base les valide.
    """

    RESTAURANT_LOCATION = "restaurant.location"
    RESTAURANT_ZONE = "restaurant.zone"
    ZONE_BOUNDARY = "zone.boundary"
    ZONE_TARIFF = "zone.tariff"
    ZONE_ACTIVATION = "zone.activation"
    COUNTRY_ACTIVATION = "country.activation"


def record_change(
    *,
    actor: User | None,
    action: str,
    target_type: str,
    target_id: Any,
    target_label: str,
    before: dict[str, Any],
    after: dict[str, Any],
) -> AuditEntry | None:
    """Consigne un changement — **et rien quand il n'y en a pas**.

    Rend `None` si `before == after`. Un formulaire de back-office renvoie tous
    ses champs à chaque enregistrement, y compris ceux qu'on n'a pas touchés :
    sans cette garde, corriger un numéro de téléphone écrirait une ligne
    « position inchangée », et le journal se remplirait de bruit jusqu'à ce que
    plus personne ne l'ouvre.

    L'acteur peut être nul : une commande de peuplement ou une correction en
    `shell` n'en ont pas, et refuser de journaliser dans ces cas-là ferait
    perdre précisément les changements qu'on cherche le plus souvent.
    """
    if before == after:
        return None

    return AuditEntry.objects.create(
        actor=actor,
        action=action,
        target_type=target_type,
        target_id=str(target_id),
        target_label=target_label,
        before=before,
        after=after,
    )
