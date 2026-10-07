from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('products', '0015_products_location_fields'),
    ]

    operations = [
        migrations.AddField(
            model_name='products',
            name='dine_in_only',
            field=models.BooleanField(
                default=False,
                verbose_name='Только в заведении',
            ),
        ),
        migrations.AlterField(
            model_name='products',
            name='count',
            field=models.PositiveIntegerField(
                default=1,
                verbose_name='Количество товара / доступных мест',
            ),
        ),
    ]
