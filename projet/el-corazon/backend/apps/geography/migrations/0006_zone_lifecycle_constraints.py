"""Contraintes et index du cycle de vie — posés une fois les statuts repris (0005)."""

from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("geography", "0005_zone_status_backfill")]

    operations = [
            migrations.AddIndex(
                model_name='deliveryzone',
                index=models.Index(fields=['city', 'status'], name='zone_city_status_idx'),
            ),
            migrations.AddConstraint(
                model_name='deliveryzone',
                constraint=models.CheckConstraint(condition=models.Q(models.Q(('is_active', True), ('status', 'published')), models.Q(models.Q(('status', 'published'), _negated=True), ('is_active', False)), _connector='OR'), name='zone_is_active_mirrors_status'),
            ),
            migrations.AddConstraint(
                model_name='deliveryzone',
                constraint=models.CheckConstraint(condition=models.Q(('estimated_delivery_minutes__gte', 1)), name='zone_eta_positive'),
            ),
    ]
