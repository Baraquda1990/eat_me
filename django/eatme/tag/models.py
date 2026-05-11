from django.db import models

class Tag(models.Model):
    name=models.CharField(max_length=100,verbose_name="Имя тега")
    slug=models.SlugField(unique=True)
    def __str__(self):
        return self.name
