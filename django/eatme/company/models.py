from django.db import models, transaction
from django.conf import settings
from django.contrib.auth import get_user_model

User = get_user_model()
from core.utils import unique_slugify


class Company(models.Model):
    name = models.CharField(max_length=100, verbose_name="Название организации")
    slug = models.SlugField(
        verbose_name='URL',
        max_length=255,
        blank=True,
        unique=True,
        # null=True убран
    )
    image = models.ImageField(upload_to="uploads/company", blank=True, null=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, verbose_name="Широта", blank=True, null=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, verbose_name="Долгота", blank=True, null=True)
    address = models.CharField(max_length=255, verbose_name="Адрес", blank=True, null=True)
    phone = models.CharField(max_length=30, blank=True, null=True, verbose_name='Телефон')
    created = models.DateTimeField(auto_now_add=True, verbose_name="Дата создания")
    description = models.TextField(verbose_name="Описание компании", null=True, blank=True)
    open_time = models.TimeField(null=True, blank=True, verbose_name="Время открытия")
    close_time = models.TimeField(null=True, blank=True, verbose_name="Время закрытия")
    instagram = models.URLField(max_length=300, blank=True, null=True, verbose_name='Instagram')
    facebook = models.URLField(max_length=300, blank=True, null=True, verbose_name='Facebook')
    
    
    # === ДОБАВЛЕННЫЕ ПОЛЯ ДЛЯ РЕЙТИНГА ===
    rating = models.DecimalField(
        max_digits=3,
        decimal_places=2,
        default=0,
        verbose_name='Рейтинг'
    )
    
    reviews_count = models.PositiveIntegerField(
        default=0,
        verbose_name='Количество отзывов'
    )
    
    successful_orders = models.PositiveIntegerField(
        default=0,
        verbose_name='Успешные заказы'
    )
    
    complaints_count = models.PositiveIntegerField(
        default=0,
        verbose_name='Количество жалоб'
    )
    
    company_score = models.PositiveIntegerField(
        default=0,
        verbose_name='Внутренний рейтинг'
    )
    

    def image_url(self):
        if self.image:
            return self.image.url
        return ''

    def save(self, *args, **kwargs):
        # Remember the file currently stored for this company before updating
        # the DB row. If a new logo replaces it, the old physical file should
        # not remain orphaned in MEDIA/storage.
        old_image_name = None

        if self.pk:
            previous = (
                type(self)
                .objects
                .filter(pk=self.pk)
                .only('image')
                .first()
            )
            if previous is not None and previous.image:
                old_image_name = previous.image.name

        if not self.slug:
            self.slug = unique_slugify(self, self.name)

        super().save(*args, **kwargs)

        new_image_name = self.image.name if self.image else None

        if old_image_name and old_image_name != new_image_name:
            storage = self._meta.get_field('image').storage

            # Delete only after the DB transaction has successfully committed.
            # In normal autocommit mode this runs immediately after save().
            transaction.on_commit(
                lambda name=old_image_name, file_storage=storage:
                    file_storage.delete(name),
            )

    class Meta:
        ordering = ('name',)
        verbose_name = 'Компания'
        verbose_name_plural = 'Компании'

    def __str__(self):
        return self.name