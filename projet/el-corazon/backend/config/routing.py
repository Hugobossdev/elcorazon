"""Routage WebSocket.

Le nommage des routes est hiérarchique et contient toujours l'identifiant de la
ressource : aucun groupe ne peut être rejoint sans que la vérification
d'autorisation ait porté sur cet identifiant (ADR-008).

`ws/couriers/me/` fait exception, délibérément : la file d'un livreur est
déduite de son jeton et non d'un paramètre d'URL. Sans identifiant à fournir,
il n'y a pas d'identifiant à falsifier.
"""

from __future__ import annotations

from django.urls import URLPattern, URLResolver, path

from apps.delivery.consumers import CourierFeedConsumer
from apps.groupcarts.consumers import GroupCartConsumer
from apps.restaurants.consumers import RestaurantDashboardConsumer
from apps.tracking.consumers import OrderChatConsumer, OrderTrackingConsumer

websocket_urlpatterns: list[URLPattern | URLResolver] = [
    path("ws/orders/<uuid:order_id>/tracking/", OrderTrackingConsumer.as_asgi()),
    path("ws/orders/<uuid:order_id>/chat/", OrderChatConsumer.as_asgi()),
    path("ws/group-carts/<uuid:group_cart_id>/", GroupCartConsumer.as_asgi()),
    path("ws/couriers/me/", CourierFeedConsumer.as_asgi()),
    path("ws/restaurants/<uuid:restaurant_id>/dashboard/", RestaurantDashboardConsumer.as_asgi()),
]
