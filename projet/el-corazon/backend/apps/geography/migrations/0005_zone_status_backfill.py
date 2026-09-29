"""Reprise : chaque zone reçoit le statut que son `is_active` disait.

Active → publiée ; inactive → suspendue. Aucune zone existante ne devient un
brouillon : elles ont toutes été en service, ou le sont encore, et les
commandes qu'elles ont tarifées doivent rester lisibles.

Séparée du schéma (0004) et des contraintes (0006) : sur une base peuplée,
écrire des lignes puis poser un index dans la même transaction échoue en
`pending trigger events`.
"""

from django.db import migrations


def reprendre(apps, schema_editor):
    DeliveryZone = apps.get_model("geography", "DeliveryZone")
    DeliveryZone.objects.filter(is_active=True).update(status="published")
    DeliveryZone.objects.filter(is_active=False).update(status="suspended")


def revenir(apps, schema_editor):
    DeliveryZone = apps.get_model("geography", "DeliveryZone")
    DeliveryZone.objects.filter(status="published").update(is_active=True)
    DeliveryZone.objects.exclude(status="published").update(is_active=False)


class Migration(migrations.Migration):
    dependencies = [("geography", "0004_zone_lifecycle_schedule")]

    operations = [migrations.RunPython(reprendre, revenir)]
