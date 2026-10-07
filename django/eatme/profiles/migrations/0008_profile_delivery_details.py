from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('profiles', '0007_profile_avatar'),
    ]

    operations = [
        migrations.AddField(
            model_name='profile',
            name='house_number',
            field=models.CharField(
                blank=True,
                default='',
                max_length=50,
                verbose_name='Номер дома',
            ),
        ),
        migrations.AddField(
            model_name='profile',
            name='floor',
            field=models.CharField(
                blank=True,
                default='',
                max_length=20,
                verbose_name='Этаж',
            ),
        ),
        migrations.AddField(
            model_name='profile',
            name='delivery_latitude',
            field=models.FloatField(
                blank=True,
                null=True,
                verbose_name='Широта доставки',
            ),
        ),
        migrations.AddField(
            model_name='profile',
            name='delivery_longitude',
            field=models.FloatField(
                blank=True,
                null=True,
                verbose_name='Долгота доставки',
            ),
        ),
        migrations.AddField(
            model_name='profile',
            name='delivery_additional_info',
            field=models.TextField(
                blank=True,
                default='',
                max_length=500,
                verbose_name='Дополнительная информация для доставки',
            ),
        ),
    ]
