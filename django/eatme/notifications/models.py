from django.conf import settings
from django.db import models

from tag.models import Tag


class DeviceToken(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='device_tokens',
        verbose_name='Пользователь'
    )
    token = models.TextField(
        unique=True,
        verbose_name='FCM токен'
    )
    device_type = models.CharField(
        max_length=20,
        blank=True,
        default='android',
        verbose_name='Тип устройства'
    )
    is_active = models.BooleanField(
        default=True,
        verbose_name='Активен'
    )
    created = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Создан'
    )

    def __str__(self):
        return f'{self.user} - {self.device_type}'


class Notification(models.Model):
    class Type(models.TextChoices):
        ADMIN_NEWS = 'admin_news', 'Новость от администрации'
        NEW_PRODUCT = 'new_product', 'Новый товар'
        ORDER_CREATED = 'order_created', 'Новый заказ'
        ORDER_RESERVED = 'order_reserved', 'Товар зарезервирован'
        ORDER_CANCELLED = 'order_cancelled', 'Заказ отменён'
        LOW_STOCK = 'low_stock', 'Мало товара'
        ALARM_MATCH = 'alarm_match', 'Найдено предложение'
        FAVORITE_STORE = 'favorite_store', 'Любимый магазин'
        REVIEW_REMINDER = 'review_reminder', 'Напоминание об оценке'
        NEW_NEARBY_PRODUCT = 'new_nearby_product', 'Новое предложение рядом'

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications',
        verbose_name='Пользователь'
    )
    type = models.CharField(
        max_length=30,
        choices=Type.choices,
        verbose_name='Тип'
    )
    title = models.CharField(
        max_length=255,
        verbose_name='Заголовок'
    )
    body = models.TextField(
        verbose_name='Текст'
    )
    data = models.JSONField(
        blank=True,
        null=True,
        verbose_name='Доп. данные'
    )
    is_read = models.BooleanField(
        default=False,
        verbose_name='Прочитано'
    )
    created = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Создано'
    )

    class Meta:
        ordering = ['-created']

    def __str__(self):
        return self.title


class NotificationAlarm(models.Model):
    class ProductType(models.TextChoices):
        HOT = 'hot', 'Горячее'
        LONG = 'long', 'Акции'

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notification_alarms',
        verbose_name='Пользователь'
    )
    product_type = models.CharField(
        max_length=20,
        choices=ProductType.choices,
        default=ProductType.HOT,
        verbose_name='Тип товара'
    )
    tags = models.ManyToManyField(
        Tag,
        blank=True,
        related_name='notification_alarms',
        verbose_name='Теги'
    )
    notify_at = models.DateTimeField(
        verbose_name='Когда уведомить'
    )
    radius_km = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=3,
        verbose_name='Радиус, км'
    )
    latitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        null=True,
        blank=True,
        verbose_name='Широта пользователя'
    )
    longitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        null=True,
        blank=True,
        verbose_name='Долгота пользователя'
    )
    is_active = models.BooleanField(
        default=True,
        verbose_name='Активен'
    )
    created = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Создан'
    )

    class Meta:
        ordering = ['-created']

    def __str__(self):
        return f'{self.user} - {self.product_type} - {self.notify_at}'
