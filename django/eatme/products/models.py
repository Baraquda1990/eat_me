from django.db import models
from django.conf import settings
from company.models import Company

class Products(models.Model):
    company=models.ForeignKey(
        Company,
        on_delete=models.CASCADE,
        null=False,
        blank=False,
        related_name='products',
        verbose_name='Компания' 
        )
    name=models.CharField(max_length=100,verbose_name="Название продукта")
    slug=models.SlugField(verbose_name='URL',max_length=255,blank=True,unique=True,null=True)
    image=models.ImageField(upload_to="uploads/products")
    description = models.TextField(verbose_name="Описание")
    price=models.DecimalField(verbose_name="Цена",max_digits=10, decimal_places=2,blank=True,null=True)
    created=models.DateTimeField(auto_now_add=True,verbose_name="Дата создания")
    def image_url(self):
        if self.image:
            return f'{settings.WEBSITE_URL}{self.image.url}'
        else:
            return ''
    class Meta:
        ordering=('name',)
        verbose_name='Продукт'
        verbose_name_plural='Продукты'
    def __str__(self):
        return self.name
