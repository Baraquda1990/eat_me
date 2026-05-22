from django.db import models
from django.conf import settings

class Tag(models.Model):
    name=models.CharField(max_length=100,verbose_name="Имя тега")
    slug=models.SlugField(unique=True)
    image=models.ImageField(upload_to='uploads/tag',verbose_name='Иконка тега', blank=True,null=True)
    def image_url(self):
        if self.image:
            return f'{settings.WEBSITE_URL}{self.image.url}'
        else:
            return ''
    def __str__(self):
        return self.name
