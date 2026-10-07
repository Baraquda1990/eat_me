from django.db import models
from django.conf import settings
from company.models import Company
from django.core.validators import MinValueValidator, MaxValueValidator
from django.utils import timezone
from tag.models import Tag
from core.utils import unique_slugify
from core.image_processing import product_variant_name


class Products(models.Model):
    company = models.ForeignKey(
        Company,
        on_delete=models.CASCADE,
        null=False,
        blank=False,
        related_name='products',
        verbose_name='Компания'
    )
    tag = models.ManyToManyField(
        Tag,
        related_name='products',
        verbose_name='Тег',
        blank=True
    )

    name = models.CharField(max_length=100, verbose_name="Название продукта")
    slug = models.SlugField(
        verbose_name='URL',
        max_length=255,
        blank=True,
        unique=True,
        null=True
    )
    image = models.ImageField(upload_to="uploads/products")
    description = models.TextField(verbose_name="Описание")

    price = models.DecimalField(
        verbose_name="Цена",
        max_digits=10,
        decimal_places=2,
        blank=True,
        null=True
    )

    created = models.DateTimeField(
        auto_now_add=True,
        verbose_name="Дата создания"
    )

    class PublicationStatus(models.TextChoices):
        DRAFT = 'draft', 'Черновик'
        SCHEDULED = 'scheduled', 'Запланирован'
        PUBLISHED = 'published', 'Опубликован'

    publication_status = models.CharField(
        max_length=20,
        choices=PublicationStatus.choices,
        default=PublicationStatus.PUBLISHED,
        db_index=True,
        verbose_name='Статус публикации'
    )

    publish_at = models.DateTimeField(
        null=True,
        blank=True,
        db_index=True,
        verbose_name='Опубликовать в'
    )

    published_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Фактически опубликован'
    )

    discount = models.PositiveSmallIntegerField(
        default=0,
        verbose_name='Процент скидки',
        validators=[MinValueValidator(0), MaxValueValidator(100)]
    )

    count = models.PositiveIntegerField(
        default=1,
        verbose_name='Количество товара / доступных мест'
    )

    dine_in_only = models.BooleanField(
        default=False,
        verbose_name='Только в заведении'
    )

    views_count = models.PositiveIntegerField(
        default=0,
        verbose_name='Количество просмотров'
    )

    shares_count = models.PositiveIntegerField(
        default=0,
        verbose_name='Количество поделившихся'
    )

    class InactiveReason(models.TextChoices):
        MANUAL = 'manual', 'Остановлен продавцом'
        SCHEDULED = 'scheduled', 'Ожидает публикации'
        PICKUP_EXPIRED = 'pickup_expired', 'Время получения истекло'
        EXPIRATION_EXPIRED = 'expiration_expired', 'Срок годности истёк'

    is_active = models.BooleanField(
        default=True,
        verbose_name='Активен в продаже'
    )

    inactive_reason = models.CharField(
        max_length=30,
        choices=InactiveReason.choices,
        blank=True,
        default='',
        verbose_name='Причина неактивности'
    )

    active_until = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Активен до'
    )

    pickup_from = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Получение с'
    )

    pickup_until = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Получение до'
    )

    package_quantity = models.CharField(
        max_length=120,
        blank=True,
        default='',
        verbose_name='Количество в упаковке'
    )

    weight = models.CharField(
        max_length=50,
        blank=True,
        default='',
        verbose_name='Вес / объём'
    )

    class DeliveryType(models.TextChoices):
        PICKUP = 'pickup', 'Самовывоз'
        DELIVERY = 'delivery', 'Доставка'
        BOTH = 'both', 'Самовывоз и доставка'

    delivery_type = models.CharField(
        max_length=20,
        choices=DeliveryType.choices,
        default=DeliveryType.PICKUP,
        verbose_name='Тип получения'
    )

    delivery_days = models.PositiveSmallIntegerField(
        null=True,
        blank=True,
        verbose_name='Доставка в течение дней'
    )

    delivery_radius_km = models.PositiveSmallIntegerField(
        null=True,
        blank=True,
        validators=[
            MinValueValidator(1),
            MaxValueValidator(100),
        ],
        verbose_name='Радиус доставки, км'
    )

    # Product-specific map point. For HOT this is the pickup point;
    # for Deals this is the center of the delivery radius. Keeping it on the
    # product allows the seller to choose a point independently of the company.
    location_address = models.CharField(
        max_length=500,
        blank=True,
        default='',
        verbose_name='Адрес точки товара'
    )

    location_latitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        null=True,
        blank=True,
        verbose_name='Широта точки товара'
    )

    location_longitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        null=True,
        blank=True,
        verbose_name='Долгота точки товара'
    )

    expiration_date = models.DateField(
        null=True,
        blank=True,
        verbose_name='Срок годности'
    )

    can_use_until = models.DateField(
        null=True,
        blank=True,
        verbose_name='Можно использовать до'
    )

    class Type(models.TextChoices):
        HOT = 'hot', 'горячая'
        LONG = 'long', 'долгосрочная'

    type = models.CharField(
        verbose_name='Тип продукта',
        max_length=20,
        choices=Type.choices,
        default=Type.HOT
    )

    # Поля для продвижения товаров
    is_promoted = models.BooleanField(
        default=False,
        verbose_name='Продвигаемый товар'
    )

    promotion_until = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Продвижение до'
    )


    def is_available_for_sale(self):
        now = timezone.now()

        if self.publication_status != self.PublicationStatus.PUBLISHED:
            return False

        if self.publish_at is not None and self.publish_at > now:
            return False

        if not self.is_active or self.count <= 0:
            return False

        if self.type == self.Type.HOT:
            deadline = self.pickup_until or self.active_until
            if deadline is None or deadline <= now:
                return False

        if (
            self.type == self.Type.LONG
            and self.expiration_date is not None
            and self.expiration_date < timezone.localdate()
        ):
            return False

        return True

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = unique_slugify(self, self.name.lower())
        super().save(*args, **kwargs)

    def image_url(self):
        if self.image:
            return self.image.url
        return ''

    def image_card_url(self):
        if not self.image:
           return ''

        name = product_variant_name(
            self.image.name,
            '640',
        )

        if not name:
            return self.image.url

        return self.image.storage.url(name)


    def image_thumb_url(self):
        if not self.image:
            return ''

        name = product_variant_name(
            self.image.name,
            '320',
        )

        if not name:
            return self.image.url

        return self.image.storage.url(name)
    

    @property
    def get_discount_price(self):
        if self.price is None:
            return 0
        return self.price - (self.price * self.discount / 100)

    class Meta:
        ordering = ('name',)
        verbose_name = 'Продукт'
        verbose_name_plural = 'Продукты'

    def __str__(self):
        return self.name
