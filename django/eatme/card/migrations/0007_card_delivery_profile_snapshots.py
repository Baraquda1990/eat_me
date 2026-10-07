from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('card', '0006_card_item_review_available_at'),
    ]

    operations = [
        migrations.AddField(
            model_name='card',
            name='buyer_house_number_snapshot',
            field=models.CharField(
                blank=True,
                default='',
                max_length=50,
                verbose_name='Номер дома покупателя на момент заказа',
            ),
        ),
        migrations.AddField(
            model_name='card',
            name='buyer_floor_snapshot',
            field=models.CharField(
                blank=True,
                default='',
                max_length=20,
                verbose_name='Этаж покупателя на момент заказа',
            ),
        ),
        migrations.AddField(
            model_name='card',
            name='buyer_delivery_latitude_snapshot',
            field=models.FloatField(
                blank=True,
                null=True,
                verbose_name='Широта доставки на момент заказа',
            ),
        ),
        migrations.AddField(
            model_name='card',
            name='buyer_delivery_longitude_snapshot',
            field=models.FloatField(
                blank=True,
                null=True,
                verbose_name='Долгота доставки на момент заказа',
            ),
        ),
        migrations.AddField(
            model_name='card',
            name='buyer_delivery_additional_info_snapshot',
            field=models.TextField(
                blank=True,
                default='',
                verbose_name='Доп. информация доставки на момент заказа',
            ),
        ),
    ]
