from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('reviews', '0002_alter_review_comment'),
    ]

    operations = [
        migrations.CreateModel(
            name='ReviewEditRequest',
            fields=[
                (
                    'id',
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name='ID',
                    ),
                ),
                (
                    'status',
                    models.CharField(
                        choices=[
                            ('pending', 'Ожидает решения'),
                            ('approved', 'Разрешено'),
                            ('rejected', 'Запрещено'),
                            ('used', 'Использовано'),
                        ],
                        db_index=True,
                        default='pending',
                        max_length=16,
                        verbose_name='Статус',
                    ),
                ),
                (
                    'admin_comment',
                    models.CharField(
                        blank=True,
                        max_length=500,
                        verbose_name='Комментарий администратора',
                    ),
                ),
                (
                    'created',
                    models.DateTimeField(
                        auto_now_add=True,
                        verbose_name='Создан',
                    ),
                ),
                (
                    'decided_at',
                    models.DateTimeField(
                        blank=True,
                        null=True,
                        verbose_name='Решение принято',
                    ),
                ),
                (
                    'used_at',
                    models.DateTimeField(
                        blank=True,
                        null=True,
                        verbose_name='Редактирование использовано',
                    ),
                ),
                (
                    'decided_by',
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name='review_edit_requests_decided',
                        to=settings.AUTH_USER_MODEL,
                        verbose_name='Решил',
                    ),
                ),
                (
                    'review',
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name='edit_requests',
                        to='reviews.review',
                        verbose_name='Отзыв',
                    ),
                ),
                (
                    'user',
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name='review_edit_requests',
                        to=settings.AUTH_USER_MODEL,
                        verbose_name='Пользователь',
                    ),
                ),
            ],
            options={
                'verbose_name': 'Запрос на редактирование отзыва',
                'verbose_name_plural': 'Запросы на редактирование отзывов',
                'ordering': ('-created', '-id'),
            },
        ),
    ]
