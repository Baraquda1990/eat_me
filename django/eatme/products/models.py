from django.db import models
from django.conf import settings
from company.models import Company
from django.core.validators import MinValueValidator, MaxValueValidator
from tag.models import Tag
from core.utils import unique_slugify


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

    discount = models.PositiveSmallIntegerField(
        default=0,
        verbose_name='Процент скидки',
        validators=[MinValueValidator(0), MaxValueValidator(100)]
    )

    count = models.PositiveIntegerField(
        default=1,
        verbose_name='Количество товара'
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

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = unique_slugify(self, self.name.lower())
        super().save(*args, **kwargs)

    def image_url(self):
        if self.image:
            return f'{settings.WEBSITE_URL}{self.image.url}'
        return ''

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
