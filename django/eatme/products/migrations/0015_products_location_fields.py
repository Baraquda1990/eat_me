from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('products', '0014_alter_products_inactive_reason'),
    ]

    operations = [
        migrations.AddField(
            model_name='products',
            name='location_address',
            field=models.CharField(blank=True, default='', max_length=500, verbose_name='Адрес точки товара'),
        ),
        migrations.AddField(
            model_name='products',
            name='location_latitude',
            field=models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True, verbose_name='Широта точки товара'),
        ),
        migrations.AddField(
            model_name='products',
            name='location_longitude',
            field=models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True, verbose_name='Долгота точки товара'),
        ),
    ]
