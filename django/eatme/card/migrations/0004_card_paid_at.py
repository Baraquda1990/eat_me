from django.db import migrations, models
from django.db.models import F


def backfill_paid_at(apps, schema_editor):
    """
    Exact checkout time did not exist historically.
    For old paid cards, use created as the safest available fallback.
    All new paid cards will receive the real payment time automatically.
    """
    Card = apps.get_model('card', 'Card')
    Card.objects.filter(
        status='paided',
        paid_at__isnull=True,
    ).update(paid_at=F('created'))


class Migration(migrations.Migration):

    dependencies = [
        ('card', '0003_order_snapshots'),
    ]

    operations = [
        migrations.AddField(
            model_name='card',
            name='paid_at',
            field=models.DateTimeField(
                blank=True,
                db_index=True,
                null=True,
                verbose_name='Дата оплаты',
            ),
        ),
        migrations.RunPython(
            backfill_paid_at,
            migrations.RunPython.noop,
        ),
    ]
