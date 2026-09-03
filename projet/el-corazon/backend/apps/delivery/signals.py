"""Événements de domaine émis par la livraison — ADR-002.

Même mécanisme que pour les commandes : `delivery` annonce qu'une course est
proposée, et ne sait pas qui l'écoute. C'est `notifications` aujourd'hui, ce
sera `analytics` demain, sans modifier ce module.
"""

from __future__ import annotations

import django.dispatch

__all__ = ["assignment_accepted", "assignment_offered"]

#: Arguments : `assignment`.
assignment_offered = django.dispatch.Signal()

#: Arguments : `assignment`.
#:
#: Distinct de `assignment_offered`, et la distinction compte : une course
#: **proposée** peut être refusée, et prévenir le client à ce moment-là
#: reviendrait à lui annoncer un livreur qui ne viendra pas. C'est
#: l'acceptation qui engage quelqu'un.
#:
#: La commande, elle, ne bouge pas à cet instant — `accepted` n'est
#: volontairement pas projeté sur son statut (voir `ORDER_STATUS_PROJECTION`) :
#: le repas n'est pas parti, la commande reste `ready`. C'est bien pourquoi ce
#: signal existe séparément.
assignment_accepted = django.dispatch.Signal()
