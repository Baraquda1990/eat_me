from django.db import models
from django.contrib.auth import get_user_model
from products.models import Products

User=get_user_model()
class Card(models.Model):
    user=models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        null=False,
        blank=False,
        related_name='card',
        verbose_name='Корзина'
    )
    created=models.DateTimeField(auto_now_add=True,verbose_name='Дата создания')
    STATUS_CARD=(
        ('pending','Ожидает'),
        ('paided','Оплачен')
    )
    status=models.CharField(max_length=20,default='pending',verbose_name='Статус',choices=STATUS_CARD)
    def __str__(self):
        return f"Корзина {self.id} - {self.user}"

class Card_item(models.Model):
    card=models.ForeignKey(
        Card,
        on_delete=models.CASCADE,
        null=False,
        blank=False,
        related_name='card_item',
        verbose_name='Корзина'
    )
    product=models.ForeignKey(
        Products,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='card_item',
        verbose_name='Продукт в корзине'
    )
    added=models.DateTimeField(auto_now_add=True,verbose_name='Дата добавления')
    quantity=models.PositiveIntegerField(default=1,verbose_name='Количество')
    @property
    def price_by_quantity(self):
        if not self.product:
            return 0
        return self.quantity * self.product.get_discount_price
    class Meta:
        ordering=('added',)
        verbose_name='Товар в корзине'
        verbose_name_plural='Товары в корзине'
    def __str__(self):
        return f"{self.product.name} x {self.quantity}"