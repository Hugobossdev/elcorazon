"""Application Celery.

Tout appel réseau sortant quitte le cycle de requête (ADR-008) : un envoi FCM
demande un jeton OAuth puis un POST par appareil, ce qui ajouterait des
centaines de millisecondes à chaque changement de statut de commande.
"""

from __future__ import annotations

import os

from celery import Celery

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.dev")

app = Celery("elcorazon")
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()

# Tâches planifiées.
#
# Le calendrier est rempli **au fur et à mesure que les tâches existent** : une
# entrée pointant vers une tâche non enregistrée est envoyée à chaque tour par
# beat et rejetée par le worker, ce qui produit une alerte permanente à laquelle
# l'équipe finit par ne plus prêter attention.
#
# Planifications prévues, par ordre d'arrivée :
#
#   apps.tracking.tasks.purge_stale_locations      toutes les heures
#       Le suivi n'a de valeur qu'en direct.  Sans purge, `delivery_locations`
#       croît d'environ 1,7 M de lignes par jour à 200 livreurs actifs.
#
#   apps.orders.tasks.purge_idempotency_keys       toutes les heures
#       ADR-009 : les clés consommées ne servent plus au-delà de la fenêtre de
#       retry d'un client mobile.
#
#   apps.loyalty.tasks.renew_subscriptions         toutes les heures
#   apps.loyalty.tasks.expire_points               quotidienne
#
app.conf.beat_schedule = {}
