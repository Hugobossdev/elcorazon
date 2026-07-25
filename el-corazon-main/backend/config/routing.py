"""Routage WebSocket.

Le nommage des routes est hiérarchique et contient toujours l'identifiant de la
ressource : aucun groupe ne peut être rejoint sans que la vérification
d'autorisation ait porté sur cet identifiant (ADR-008).
"""

from __future__ import annotations

from django.urls import URLPattern, URLResolver

# Renseigné en Phase 5 :
#   ws/orders/<uuid:order_id>/tracking/   position du livreur + ETA
#   ws/orders/<uuid:order_id>/chat/       chat client ↔ livreur
#   ws/couriers/me/                       courses proposées au livreur connecté
#   ws/restaurants/<uuid:id>/dashboard/   tableau de bord du personnel
websocket_urlpatterns: list[URLPattern | URLResolver] = []
