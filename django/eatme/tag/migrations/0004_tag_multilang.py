from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('tag', '0003_alter_tag_image'),
    ]

    operations = [
        migrations.AlterField(
            model_name='tag',
            name='name',
            field=models.CharField(max_length=100, verbose_name='Название (RU)'),
        ),
        migrations.AddField(
            model_name='tag',
            name='name_en',
            field=models.CharField(
                blank=True,
                default='',
                max_length=100,
                verbose_name='Название (EN)',
            ),
        ),
        migrations.AddField(
            model_name='tag',
            name='name_hy',
            field=models.CharField(
                blank=True,
                default='',
                max_length=100,
                verbose_name='Название (HY)',
            ),
        ),
    ]
