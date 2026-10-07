from django.db import migrations, models


WELCOME_CHOICES = [
    ('welcome', 'Добро пожаловать в Appsosa'),
    ('admin_news', 'Новость от администрации'),
    ('new_product', 'Новый товар'),
    ('order_created', 'Новый заказ'),
    ('order_reserved', 'Товар зарезервирован'),
    ('order_cancelled', 'Заказ отменён'),
    ('low_stock', 'Мало товара'),
    ('alarm_match', 'Найдено предложение'),
    ('favorite_store', 'Любимый магазин'),
    ('review_reminder', 'Напоминание об оценке'),
    ('new_nearby_product', 'Новое предложение рядом'),
    ('recommendation', 'Персональная рекомендация'),
]


class Migration(migrations.Migration):

    dependencies = [
        ('notifications', '0009_notificationbroadcast'),
    ]

    operations = [
        migrations.AlterField(
            model_name='notification',
            name='type',
            field=models.CharField(
                choices=WELCOME_CHOICES,
                max_length=30,
                verbose_name='Тип',
            ),
        ),
        migrations.AlterField(
            model_name='notificationbroadcast',
            name='type',
            field=models.CharField(
                choices=WELCOME_CHOICES,
                default='admin_news',
                max_length=30,
                verbose_name='Тип',
            ),
        ),
    ]
