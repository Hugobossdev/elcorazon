"""Événements de domaine émis par les paiements — ADR-002.

Même mécanisme que `orders.signals` : un encaissement peut régler autre chose
qu'une commande — un abonnement, demain peut-être un portefeuille rechargé —
et `payments` ne doit connaître aucun de ces domaines pour rester réutilisable
par le prochain. L'abonné se branche depuis son propre `AppConfig.ready()` ;
`payments` ne change pas d'une ligne quand `loyalty` s'y met.

Émis **dans** la transaction qui solde la `Transaction` : un abonné qui écrit
en base — l'activation d'un abonnement en est une — doit le faire de façon
atomique avec l'encaissement qui la déclenche.
"""

from __future__ import annotations

import django.dispatch

__all__ = ["payment_transaction_failed", "payment_transaction_settled"]

#: Argument : `transaction` (l'instance `payments.models.Transaction` soldée).
payment_transaction_settled = django.dispatch.Signal()

#: Argument : `transaction` (l'instance soldée en échec).
#:
#: Émis **en plus** de `payment_transaction_settled`, et non à sa place : les
#: deux issues n'intéressent pas les mêmes abonnés. Un encaissement réussi
#: active un abonnement et confirme une commande ; un échec ne fait avancer
#: aucun domaine — il se dit, au client qui doit reprendre son paiement et à
#: l'exploitation qui verra la commande rester en attente.
#:
#: Sans lui, un paiement refusé était **entièrement muet** : la transaction
#: passait en `failed`, la commande restait où elle était, et personne
#: n'apprenait rien. `NotificationKind.PAYMENT` existait sans jamais être émis.
payment_transaction_failed = django.dispatch.Signal()
