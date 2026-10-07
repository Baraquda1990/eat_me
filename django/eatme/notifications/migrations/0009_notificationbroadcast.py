# Generated manually for Appsosa notification audience broadcasts.

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('notifications', '0008_notificationalarm_notify_until_and_more'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='NotificationBroadcast',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('audience', models.CharField(choices=[('all', 'Все пользователи'), ('buyers', 'Покупатели'), ('sellers', 'Продавцы'), ('specific', 'Конкретный пользователь')], default='specific', max_length=20, verbose_name='Получатели')),
                ('type', models.CharField(choices=[('admin_news', 'Новость от администрации'), ('new_product', 'Новый товар'), ('order_created', 'Новый заказ'), ('order_reserved', 'Товар зарезервирован'), ('order_cancelled', 'Заказ отменён'), ('low_stock', 'Мало товара'), ('alarm_match', 'Найдено предложение'), ('favorite_store', 'Любимый магазин'), ('review_reminder', 'Напоминание об оценке'), ('new_nearby_product', 'Новое предложение рядом'), ('recommendation', 'Персональная рекомендация')], default='admin_news', max_length=30, verbose_name='Тип')),
                ('title', models.CharField(max_length=255, verbose_name='Заголовок')),
                ('body', models.TextField(verbose_name='Текст')),
                ('data', models.JSONField(blank=True, null=True, verbose_name='Доп. данные')),
                ('status', models.CharField(choices=[('pending', 'В очереди'), ('sending', 'Отправляется'), ('completed', 'Отправлено'), ('failed', 'Ошибка')], db_index=True, default='pending', max_length=20, verbose_name='Статус')),
                ('recipients_count', models.PositiveIntegerField(default=0, verbose_name='Получателей')),
                ('notifications_created', models.PositiveIntegerField(default=0, verbose_name='Создано уведомлений')),
                ('error_message', models.TextField(blank=True, default='', verbose_name='Ошибка')),
                ('created', models.DateTimeField(auto_now_add=True, verbose_name='Создано')),
                ('sent_at', models.DateTimeField(blank=True, null=True, verbose_name='Завершено')),
                ('created_by', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='created_notification_broadcasts', to=settings.AUTH_USER_MODEL, verbose_name='Создал')),
                ('user', models.ForeignKey(blank=True, help_text='Используется только если выбран получатель «Конкретный пользователь».', null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='targeted_notification_broadcasts', to=settings.AUTH_USER_MODEL, verbose_name='Конкретный пользователь')),
            ],
            options={
                'verbose_name': 'Рассылка уведомления',
                'verbose_name_plural': 'Рассылки уведомлений',
                'ordering': ['-created'],
            },
        ),
    ]
