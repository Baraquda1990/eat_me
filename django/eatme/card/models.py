from django.db import models, transaction
from django.utils import timezone
from django.contrib.auth import get_user_model
from products.models import Products

User = get_user_model()


class OrderNumberCounter(models.Model):
    """
    Single locked counter used to issue human-facing order numbers.

    Card.id remains the internal database key and can be created while a cart
    is still pending. order_number is assigned only when the Card is paid.
    """

    key = models.CharField(
        max_length=32,
        primary_key=True,
        default='orders',
        editable=False,
    )
    last_value = models.PositiveBigIntegerField(default=0)

    class Meta:
        verbose_name = 'Счётчик номеров заказов'
        verbose_name_plural = 'Счётчики номеров заказов'

    def __str__(self):
        return f'{self.key}: {self.last_value}'


class Card(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        null=False,
        blank=False,
        related_name='card',
        verbose_name='Корзина'
    )
    created = models.DateTimeField(auto_now_add=True, verbose_name='Дата создания')
    paid_at = models.DateTimeField(
        null=True,
        blank=True,
        db_index=True,
        verbose_name='Дата оплаты',
    )
    order_number = models.PositiveBigIntegerField(
        null=True,
        blank=True,
        unique=True,
        verbose_name='Номер заказа',
    )

    STATUS_CARD = (
        ('pending', 'Ожидает'),
        ('paided', 'Оплачен')
    )
    status = models.CharField(max_length=20, default='pending', verbose_name='Статус', choices=STATUS_CARD)

    # Immutable buyer data captured when the order is finalized.
    buyer_username_snapshot = models.CharField(
        max_length=150,
        blank=True,
        default='',
        verbose_name='Логин покупателя на момент заказа',
    )
    buyer_phone_snapshot = models.CharField(
        max_length=50,
        blank=True,
        default='',
        verbose_name='Телефон покупателя на момент заказа',
    )
    buyer_address_snapshot = models.TextField(
        blank=True,
        default='',
        verbose_name='Адрес покупателя на момент заказа',
    )
    buyer_house_number_snapshot = models.CharField(
        max_length=50,
        blank=True,
        default='',
        verbose_name='Номер дома покупателя на момент заказа',
    )
    buyer_floor_snapshot = models.CharField(
        max_length=20,
        blank=True,
        default='',
        verbose_name='Этаж покупателя на момент заказа',
    )
    buyer_delivery_latitude_snapshot = models.FloatField(
        null=True,
        blank=True,
        verbose_name='Широта доставки на момент заказа',
    )
    buyer_delivery_longitude_snapshot = models.FloatField(
        null=True,
        blank=True,
        verbose_name='Долгота доставки на момент заказа',
    )
    buyer_delivery_additional_info_snapshot = models.TextField(
        blank=True,
        default='',
        verbose_name='Доп. информация доставки на момент заказа',
    )

    def save(self, *args, **kwargs):
        # A real order number must be created only when the order becomes paid.
        # Both paid_at and order_number are assigned under DB locks, so two
        # simultaneous purchases cannot receive the same number.
        needs_paid_identity = (
            self.status == 'paided'
            and (self.paid_at is None or self.order_number is None)
        )

        if needs_paid_identity:
            with transaction.atomic():
                # If two processes try to finalize the same Card at once,
                # lock the existing row and reuse the already assigned values.
                if self.pk:
                    current = (
                        type(self)
                        .objects
                        .select_for_update()
                        .only('paid_at', 'order_number')
                        .filter(pk=self.pk)
                        .first()
                    )
                    if current is not None:
                        if self.paid_at is None and current.paid_at is not None:
                            self.paid_at = current.paid_at
                        if (
                            self.order_number is None
                            and current.order_number is not None
                        ):
                            self.order_number = current.order_number

                if self.paid_at is None:
                    self.paid_at = timezone.now()

                if self.order_number is None:
                    counter, _ = (
                        OrderNumberCounter.objects
                        .select_for_update()
                        .get_or_create(
                            key='orders',
                            defaults={'last_value': 0},
                        )
                    )
                    counter.last_value += 1
                    counter.save(update_fields=['last_value'])
                    self.order_number = counter.last_value

                # Keep both values persisted even when a caller saves only
                # update_fields=['status'].
                update_fields = kwargs.get('update_fields')
                if update_fields is not None:
                    kwargs['update_fields'] = list(
                        set(update_fields)
                        | {'paid_at', 'order_number'}
                    )

                super().save(*args, **kwargs)
            return

        super().save(*args, **kwargs)

    @property
    def order_datetime(self):
        return self.paid_at or self.created

    def __str__(self):
        return f"Корзина {self.id} - {self.user}"


class Card_item(models.Model):
    card = models.ForeignKey(
        Card,
        on_delete=models.CASCADE,
        null=False,
        blank=False,
        related_name='card_item',
        verbose_name='Корзина'
    )
    product = models.ForeignKey(
        Products,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='card_item',
        verbose_name='Продукт в корзине'
    )
    added = models.DateTimeField(auto_now_add=True, verbose_name='Дата добавления')
    quantity = models.PositiveIntegerField(default=1, verbose_name='Количество')

    # Immutable product/order snapshot captured at checkout.
    product_snapshot = models.JSONField(
        default=dict,
        blank=True,
        verbose_name='Снимок товара на момент покупки',
    )
    unit_price_snapshot = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        verbose_name='Цена за единицу на момент покупки',
    )
    company_id_snapshot = models.PositiveBigIntegerField(
        null=True,
        blank=True,
        db_index=True,
        verbose_name='ID компании на момент покупки',
    )
    product_slug_snapshot = models.CharField(
        max_length=255,
        blank=True,
        default='',
        db_index=True,
        verbose_name='Slug товара на момент покупки',
    )
    product_type_snapshot = models.CharField(
        max_length=20,
        blank=True,
        default='',
        db_index=True,
        verbose_name='Тип товара на момент покупки',
    )

    class DeliveryStatus(models.TextChoices):
        PROCESSING = 'processing', 'В обработке'
        DELIVERING = 'delivering', 'Доставляется'
        DELIVERED = 'delivered', 'Доставлено'

    delivery_status = models.CharField(
        max_length=20,
        choices=DeliveryStatus.choices,
        default=DeliveryStatus.PROCESSING,
        db_index=True,
        verbose_name='Статус доставки',
    )

    review_available_at = models.DateTimeField(
        null=True,
        blank=True,
        db_index=True,
        verbose_name='Отзыв доступен с',
    )

    @property
    def unit_price(self):
        if self.unit_price_snapshot is not None:
            return self.unit_price_snapshot
        if not self.product:
            return 0
        value = self.product.get_discount_price
        return value() if callable(value) else value

    @property
    def price_by_quantity(self):
        return self.quantity * self.unit_price

    @property
    def snapshot_company_id(self):
        if self.company_id_snapshot:
            return self.company_id_snapshot
        if self.product and self.product.company_id:
            return self.product.company_id
        return None

    @property
    def snapshot_company_name(self):
        company = (self.product_snapshot or {}).get('company') or {}
        name = str(company.get('name') or '').strip()
        if name:
            return name
        if self.product and self.product.company:
            return self.product.company.name
        return ''

    @property
    def snapshot_product_name(self):
        name = str((self.product_snapshot or {}).get('name') or '').strip()
        if name:
            return name
        return self.product.name if self.product else 'Удалённый товар'

    @property
    def snapshot_product_slug(self):
        if self.product_slug_snapshot:
            return self.product_slug_snapshot
        return self.product.slug if self.product else ''

    @property
    def snapshot_product_type(self):
        if self.product_type_snapshot:
            return self.product_type_snapshot
        return self.product.type if self.product else ''

    class Meta:
        ordering = ('added',)
        verbose_name = 'Товар в корзине'
        verbose_name_plural = 'Товары в корзине'

    def __str__(self):
        if self.product:
            return f"{self.product.name} x {self.quantity}"
        return f"Удалённый товар x {self.quantity}"
