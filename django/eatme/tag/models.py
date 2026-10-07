from django.db import models


class Tag(models.Model):
    # Legacy field `name` is kept as the Russian name so existing backend code,
    # relations and migrations continue to work without changes.
    name = models.CharField(
        max_length=100,
        verbose_name='Название (RU)',
    )
    name_en = models.CharField(
        max_length=100,
        blank=True,
        default='',
        verbose_name='Название (EN)',
    )
    name_hy = models.CharField(
        max_length=100,
        blank=True,
        default='',
        verbose_name='Название (HY)',
    )
    slug = models.SlugField(unique=True)
    image = models.ImageField(
        upload_to='uploads/tag',
        verbose_name='Иконка тега',
        blank=True,
        null=True,
    )

    def image_url(self):
        if self.image:
            return self.image.url
        return ''

    def get_localized_name(self, language_code='ru'):
        code = (language_code or 'ru').strip().lower().split('-')[0]

        if code == 'en':
            return self.name_en.strip() or self.name.strip() or self.name_hy.strip()

        if code == 'hy':
            return self.name_hy.strip() or self.name.strip() or self.name_en.strip()

        return self.name.strip() or self.name_en.strip() or self.name_hy.strip()

    def __str__(self):
        return self.name
