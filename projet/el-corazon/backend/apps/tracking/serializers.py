"""Contrats du suivi — ADR-009, invariant L3.

Le sérialiseur d'entrée ne porte **ni** la course **ni** le livreur : la
première vient de l'URL, le second du jeton. Un relevé dont l'émetteur serait
un champ du corps serait exactement la faille qu'on ferme — n'importe qui
écrirait le suivi de n'importe qui.
"""

from __future__ import annotations

import datetime as dt
from typing import Any

from django.utils import timezone
from rest_framework import serializers

from apps.tracking.models import LocationPing
from common.serializers import LocationField

__all__ = [
    "ChatMessageSerializer",
    "LocationPingSerializer",
    "PingWriteSerializer",
    "TrackingSerializer",
]


class LocationPingSerializer(serializers.ModelSerializer[LocationPing]):
    point = LocationField(read_only=True)

    class Meta:
        model = LocationPing
        fields = [
            "id",
            "point",
            "accuracy_m",
            "speed_mps",
            "heading_deg",
            "recorded_at",
            "received_at",
        ]
        read_only_fields = fields


#: Avance tolérée sur l'horloge du serveur.
#:
#: L'horloge d'un téléphone n'est pas la nôtre : quelques minutes de dérive sont
#: courantes, et refuser sur cette base couperait le suivi de livreurs
#: parfaitement honnêtes.
CLOCK_SKEW_AHEAD = dt.timedelta(minutes=5)

#: Retard toléré.
#:
#: Un livreur qui traverse une zone sans réseau émet en différé — c'est la
#: raison d'être de `recorded_at`. Une heure couvre largement le plus long
#: trou de couverture d'une course ; au-delà, le relevé décrit un endroit où
#: le livreur n'est plus, et l'écrire fausserait le tracé plutôt que de le
#: compléter.
CLOCK_SKEW_BEHIND = dt.timedelta(hours=1)


class PingWriteSerializer(serializers.Serializer[Any]):
    """Relevé émis par l'application du livreur.

    `recorded_at` est l'horodatage **de l'appareil**, distinct de la réception.
    Un livreur qui traverse une zone sans réseau émet en différé : sans cette
    distinction, une rafale de relevés rattrapés dessinerait un trajet
    instantané, et l'ETA calculé dessus serait absurde.

    Cet horodatage vient donc du client, et il était accepté **sans borne** —
    la seule valeur de ce contrat à ne pas être vérifiée. Trois choses en
    dépendent pourtant :

    * `CourierProfile.last_location_at`, que le back-office lit pour dire
      depuis quand un livreur n'a plus rien transmis. Une date dans le futur y
      rend un livreur éternellement « en direct », et le siège cesse de
      s'inquiéter d'un téléphone éteint ;
    * l'échantillonnage (`TrackingService._deserves_a_row`), qui compare au
      dernier relevé : une date en avance fait paraître tous les suivants plus
      anciens, et ils sont écartés jusqu'à ce que l'horloge la rattrape ;
    * l'ETA, calculé sur des relevés supposés ordonnés dans le temps.

    Les deux bornes sont larges à dessein : il s'agit d'écarter l'absurde, pas
    d'exiger une horloge juste.
    """

    point = LocationField()
    recorded_at = serializers.DateTimeField()

    accuracy_m = serializers.FloatField(required=False, allow_null=True, default=None)
    speed_mps = serializers.FloatField(required=False, allow_null=True, default=None, min_value=0)
    heading_deg = serializers.FloatField(
        required=False, allow_null=True, default=None, min_value=0, max_value=359.999
    )

    def validate_recorded_at(self, value: dt.datetime) -> dt.datetime:
        maintenant = timezone.now()
        if value > maintenant + CLOCK_SKEW_AHEAD:
            raise serializers.ValidationError(
                "Horodatage dans le futur : vérifiez l'heure de l'appareil."
            )
        if value < maintenant - CLOCK_SKEW_BEHIND:
            raise serializers.ValidationError(
                "Horodatage trop ancien ; ce relevé ne décrit plus une position utile."
            )
        return value


class ChatMessageSerializer(serializers.Serializer[Any]):
    """Message échangé sur `ws/orders/{order_id}/chat/`.

    Le chat n'est pas persisté (Phase 1 §5) : ce sérialiseur valide la forme
    du message avant relais, il ne porte ni modèle ni écriture en base.
    L'émetteur n'est **pas** un champ du corps — comme pour le suivi de
    position, il vient de la connexion authentifiée, jamais d'une valeur
    fournie par le client.
    """

    text = serializers.CharField(max_length=2000, allow_blank=False, trim_whitespace=True)


class TrackingSerializer(serializers.Serializer[Any]):
    """Suivi rendu au client d'une commande.

    Volontairement pauvre : la dernière position, le statut de la course et le
    livreur réduit à ce qu'on montre à la porte. Ni l'historique complet du
    trajet, ni l'identité étendue du livreur — le client suit son repas, il ne
    surveille pas un employé.
    """

    order = serializers.UUIDField(read_only=True)
    assignment_status = serializers.CharField(read_only=True)
    courier = serializers.DictField(read_only=True)
    last_position = LocationPingSerializer(read_only=True, allow_null=True)
    estimated_delivery_at = serializers.DateTimeField(read_only=True, allow_null=True)
