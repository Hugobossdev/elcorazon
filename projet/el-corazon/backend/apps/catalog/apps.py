from __future__ import annotations

from django.apps import AppConfig


class CatalogConfig(AppConfig):
    name = "apps.catalog"
    label = "catalog"
    verbose_name = "Catalogue"

    def ready(self) -> None:
        """Abonne le catalogue à la vérification de complétude d'un établissement.

        Même mécanisme que les signaux de `loyalty` : l'abonné connaît
        l'émetteur, et `restaurants` n'apprend rien de `catalog`. Sans cet
        abonnement, un établissement s'ouvrirait avec une carte vide.
        """
        from apps.catalog.readiness import catalogue_gaps
        from apps.restaurants.readiness import register_readiness_check

        register_readiness_check(catalogue_gaps)
