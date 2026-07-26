"""Sortie vers les prestataires d'encaissement.

Le backend a besoin de deux choses d'un prestataire : ouvrir une demande de
paiement, et signer les notifications qu'il renvoie. Le reste — le portail, les
écrans, les relances — ne le concerne pas.

D'où ce port réduit à une méthode. Il isole le seul morceau de la chaîne qui
dépende d'un compte marchand et d'un réseau, si bien que **tout ce qui décide**
— gardes, idempotence, transitions, plafond de remboursement — se teste sans
appeler personne.

`SandboxGateway` est l'implémentation fournie et celle des tests. Le connecteur
PayDunya s'ajoutera ici, sans toucher au service : c'est le sens de ce
découpage, et non un contournement de son absence.
"""

from __future__ import annotations

import hashlib
import hmac
from dataclasses import dataclass
from typing import Protocol

from django.conf import settings
from django.utils.module_loading import import_string

from apps.payments.models import Transaction

__all__ = ["CheckoutInstruction", "PaymentGateway", "SandboxGateway", "gateway", "verify_signature"]


@dataclass(frozen=True, slots=True)
class CheckoutInstruction:
    """Ce que le client doit faire pour payer.

    `provider_reference` est la clé de rapprochement : c'est elle que le
    webhook citera, et son unicité en base empêche d'enregistrer deux fois le
    même encaissement.
    """

    provider_reference: str
    checkout_url: str
    instructions: str = ""


class PaymentGateway(Protocol):
    def open_checkout(self, transaction: Transaction) -> CheckoutInstruction: ...


class SandboxGateway:
    """Prestataire de bac à sable — aucun appel réseau.

    Il produit une référence déterministe et une URL locale. Le paiement est
    ensuite confirmé comme en production : par un webhook signé, seule source
    de vérité de l'encaissement (§6.3). Rien dans le service ne sait qu'il
    s'agit d'un bac à sable.
    """

    def open_checkout(self, transaction: Transaction) -> CheckoutInstruction:
        return CheckoutInstruction(
            provider_reference=f"SBX-{transaction.pk.hex[:16].upper()}",
            checkout_url=f"{settings.SANDBOX_CHECKOUT_BASE_URL}/{transaction.pk}",
            instructions="Bac à sable : confirmez par un webhook signé.",
        )


def gateway() -> PaymentGateway:
    """Prestataire configuré, résolu au moment de l'appel.

    Résolu à l'appel et non à l'import : les tests peuvent le remplacer par
    `override_settings`, et un déploiement change de prestataire par une
    variable d'environnement plutôt que par un déploiement de code.
    """
    resolved: PaymentGateway = import_string(settings.PAYMENT_GATEWAY)()
    return resolved


def verify_signature(*, raw_body: bytes, signature: str) -> bool:
    """Vérifie la signature HMAC-SHA256 d'une notification.

    Sur le corps **brut** et non sur le JSON reparsé : deux sérialisations du
    même objet diffèrent par l'ordre des clés et les espaces, et la signature
    ne tomberait juste que par chance.

    `compare_digest` et non `==` : la comparaison naïve s'arrête au premier
    octet différent, et le temps qu'elle met révèle combien de caractères sont
    justes — de quoi reconstituer une signature valide en quelques milliers de
    requêtes.
    """
    expected = hmac.new(
        settings.PAYMENT_WEBHOOK_SECRET.encode(), raw_body, hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature)
