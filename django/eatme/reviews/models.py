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

    comment = models.TextField(blank=True)

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
