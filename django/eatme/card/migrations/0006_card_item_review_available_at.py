from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('card', '0005_true_order_number'),
    ]

    operations = [
        migrations.AddField(
            model_name='card_item',
            name='review_available_at',
            field=models.DateTimeField(
                blank=True,
                db_index=True,
                null=True,
                verbose_name='Отзыв доступен с',
            ),
        ),
    ]
