from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('card', '0002_card_item_delivery_status'),
    ]

    operations = [
        migrations.AddField(
            model_name='card',
            name='buyer_username_snapshot',
            field=models.CharField(
                blank=True,
                default='',
                max_length=150,
                verbose_name='Логин покупателя на момент заказа',
            ),
        ),
        migrations.AddField(
            model_name='card',
            name='buyer_phone_snapshot',
            field=models.CharField(
                blank=True,
                default='',
                max_length=50,
                verbose_name='Телефон покупателя на момент заказа',
            ),
        ),
        migrations.AddField(
            model_name='card',
            name='buyer_address_snapshot',
            field=models.TextField(
                blank=True,
                default='',
                verbose_name='Адрес покупателя на момент заказа',
            ),
        ),
        migrations.AddField(
            model_name='card_item',
            name='product_snapshot',
            field=models.JSONField(
                blank=True,
                default=dict,
                verbose_name='Снимок товара на момент покупки',
            ),
        ),
        migrations.AddField(
            model_name='card_item',
            name='unit_price_snapshot',
            field=models.DecimalField(
                blank=True,
                decimal_places=2,
                max_digits=12,
                null=True,
                verbose_name='Цена за единицу на момент покупки',
            ),
        ),
        migrations.AddField(
            model_name='card_item',
            name='company_id_snapshot',
            field=models.PositiveBigIntegerField(
                blank=True,
                db_index=True,
                null=True,
                verbose_name='ID компании на момент покупки',
            ),
        ),
        migrations.AddField(
            model_name='card_item',
            name='product_slug_snapshot',
            field=models.CharField(
                blank=True,
                db_index=True,
                default='',
                max_length=255,
                verbose_name='Slug товара на момент покупки',
            ),
        ),
        migrations.AddField(
            model_name='card_item',
            name='product_type_snapshot',
            field=models.CharField(
                blank=True,
                db_index=True,
                default='',
                max_length=20,
                verbose_name='Тип товара на момент покупки',
            ),
        ),
    ]
