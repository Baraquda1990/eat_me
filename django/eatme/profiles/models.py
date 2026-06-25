from django.db import models
from django.dispatch import receiver
from django.db.models.signals import post_save
from django.contrib.auth import get_user_model
User = get_user_model()
from company.models import Company
from core.utils import unique_slugify


class Profile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    slug = models.SlugField(max_length=255, blank=True, unique=True, verbose_name='URL')
    bio = models.TextField(max_length=500, blank=True, verbose_name='Информация о себе')
    birth_date = models.DateField(null=True, blank=True, verbose_name='Дата рождения')
    phone = models.CharField(max_length=20, blank=True, verbose_name='Телефон')
    phone_verified = models.BooleanField(default=False, verbose_name='Телефон подтверждён')
    address=models.CharField(max_length=250,blank=True,verbose_name='Адрес')
    
    class TypeUser(models.TextChoices):
        BUYER = 'buyer', 'покупатель'
        SELLER = 'seller', 'продавец'
    
    type_user = models.CharField(
        verbose_name='Тип пользователя',
        max_length=20,
        choices=TypeUser.choices,
        default=TypeUser.BUYER
    )
    
    class Meta:
        ordering = ('user',)
        verbose_name = 'Профиль'
        verbose_name_plural = 'Профили'
    
    def save(self, *args, **kwargs):
        """
        Сохрание полей модели при их отсутствии заполнения
        """
        if not self.slug:
            self.slug = unique_slugify(self, self.user.username.lower())
        super().save(*args, **kwargs)
    
    def __str__(self):
        """
        Возвращение строки
        """
        return self.user.username


class OrgProf(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        null=False,
        blank=False,
        related_name='orgprof',
        verbose_name='Продавец'
    )
    company = models.ForeignKey(
        Company,
        on_delete=models.CASCADE,
        null=False,
        blank=False,
        related_name='orgprof',
        verbose_name='Компания'
    )


@receiver(post_save, sender=User)
def create_user_profile(sender, instance, created, **kwargs):
    if created:
        Profile.objects.create(user=instance)
