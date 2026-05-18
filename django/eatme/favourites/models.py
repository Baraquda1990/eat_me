from django.db import models
from products.models import Products
from django.contrib.auth import get_user_model
User=get_user_model()

class Favourites(models.Model):
    products=models.ForeignKey(
        Products,
        on_delete=models.CASCADE,
        null=False,
        blank=False,
        related_name='favourites',
        verbose_name='Продукты'
    )
    user=models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        null=False,
        blank=False,
        related_name='favourites',
        verbose_name='Пользователь'
    )
    created=models.DateTimeField(auto_now_add=True)
    class Meta:
        ordering=('created',)
        verbose_name='Избранное'
        verbose_name_plural='Избранное'
        unique_together = ('user', 'products')
