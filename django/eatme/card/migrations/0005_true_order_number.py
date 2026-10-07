from django.db import migrations, models


def backfill_order_numbers(apps, schema_editor):
    Card = apps.get_model('card', 'Card')
    OrderNumberCounter = apps.get_model('card', 'OrderNumberCounter')

    number = 0

    # Existing orders receive stable chronological numbers.
    # For historical rows, paid_at may itself be the fallback created time
    # from migration 0004; exact old checkout times did not previously exist.
    paid_cards = (
        Card.objects
        .filter(status='paided')
        .order_by('paid_at', 'created', 'id')
    )

    for number, card in enumerate(paid_cards.iterator(), start=1):
        Card.objects.filter(pk=card.pk).update(order_number=number)

    OrderNumberCounter.objects.update_or_create(
        key='orders',
        defaults={'last_value': number},
    )


class Migration(migrations.Migration):

    dependencies = [
        ('card', '0004_card_paid_at'),
    ]

    operations = [
        migrations.CreateModel(
            name='OrderNumberCounter',
            fields=[
                (
                    'key',
                    models.CharField(
                        default='orders',
                        editable=False,
                        max_length=32,
                        primary_key=True,
                        serialize=False,
                    ),
                ),
                (
                    'last_value',
                    models.PositiveBigIntegerField(default=0),
                ),
            ],
            options={
                'verbose_name': 'Счётчик номеров заказов',
                'verbose_name_plural': 'Счётчики номеров заказов',
            },
        ),
        migrations.AddField(
            model_name='card',
            name='order_number',
            field=models.PositiveBigIntegerField(
                blank=True,
                null=True,
                unique=True,
                verbose_name='Номер заказа',
            ),
        ),
        migrations.RunPython(
            backfill_order_numbers,
            migrations.RunPython.noop,
        ),
    ]
