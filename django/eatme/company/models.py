from django.db import models
from django.conf import settings

class Company(models.Model):
    name=models.CharField(max_length=100,verbose_name="Название организации")
    slug=models.SlugField(verbose_name='URL',max_length=255,blank=True,unique=True,null=True)
    image=models.ImageField(upload_to="uploads/company")
    latitude = models.DecimalField(max_digits=9, decimal_places=6, verbose_name="Широта")
    longitude = models.DecimalField(max_digits=9, decimal_places=6, verbose_name="Долгота")
    address = models.CharField(max_length=255, verbose_name="Адрес")
    created=models.DateTimeField(auto_now_add=True,verbose_name="Дата создания")
    def image_url(self):
        if self.image:
            return f'{settings.WEBSITE_URL}{self.image.url}'
        else:
            return ''
    class Meta:
        ordering=('name',)
        verbose_name='Компания'
        verbose_name_plural='Компании'
    def __str__(self):
        return self.name
    

