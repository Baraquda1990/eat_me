from decimal import Decimal

from django.db import models
from django.contrib.auth import get_user_model
from django.core.validators import MinValueValidator, MaxValueValidator

from company.models import Company
from card.models import Card

User = get_user_model()


class Review(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='reviews'
    )

    company = models.ForeignKey(
        Company,
        on_delete=models.CASCADE,
        related_name='reviews'
    )

    card = models.ForeignKey(
        Card,
        on_delete=models.CASCADE,
        related_name='reviews'
    )

    quality = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)]
    )

    value = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)]
    )

    description_match = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)]
    )

    service = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)]
    )

    comment = models.TextField(blank=True,max_length=400)

    rating = models.DecimalField(
        max_digits=3,
        decimal_places=2,
        default=0
    )

    created = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ('-created',)
        unique_together = ('user', 'company', 'card')
        verbose_name = 'Отзыв'
        verbose_name_plural = 'Отзывы'

    def calculate_rating(self):
        return (
            Decimal('0.4') * Decimal(self.quality) +
            Decimal('0.3') * Decimal(self.value) +
            Decimal('0.2') * Decimal(self.description_match) +
            Decimal('0.1') * Decimal(self.service)
        )

    def save(self, *args, **kwargs):
        self.rating = self.calculate_rating()
        super().save(*args, **kwargs)

    def __str__(self):
        return f'{self.company.name} - {self.rating}'


class ReviewEditRequest(models.Model):
    class Status(models.TextChoices):
        PENDING = 'pending', 'Ожидает решения'
        APPROVED = 'approved', 'Разрешено'
        REJECTED = 'rejected', 'Запрещено'
        USED = 'used', 'Использовано'

    review = models.ForeignKey(
        Review,
        on_delete=models.CASCADE,
        related_name='edit_requests',
        verbose_name='Отзыв',
    )
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='review_edit_requests',
        verbose_name='Пользователь',
    )
    status = models.CharField(
        max_length=16,
        choices=Status.choices,
        default=Status.PENDING,
        db_index=True,
        verbose_name='Статус',
    )
    admin_comment = models.CharField(
        max_length=500,
        blank=True,
        verbose_name='Комментарий администратора',
    )
    created = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Создан',
    )
    decided_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Решение принято',
    )
    decided_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='review_edit_requests_decided',
        verbose_name='Решил',
    )
    used_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Редактирование использовано',
    )

    class Meta:
        ordering = ('-created', '-id')
        verbose_name = 'Запрос на редактирование отзыва'
        verbose_name_plural = 'Запросы на редактирование отзывов'

    def __str__(self):
        return f'#{self.pk} {self.review_id} {self.user} — {self.status}'
