from django.db import models

class Feedback(models.Model):
    text=models.TextField(max_length=1000,verbose_name="Текст сообщения")
    phone=models.CharField(max_length=20, null=True,blank=True,verbose_name="Телефон отправителя")
    email=models.EmailField(verbose_name="Email отправителя")
    timedate=models.DateTimeField(auto_now_add=True)

