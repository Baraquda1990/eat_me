from uuid import uuid4
from pytils.translit import slugify


def unique_slugify(instance, value):
    """
    Генерирует уникальный slug для модели.
    """
    model = instance.__class__

    base_slug = slugify(value)
    unique_slug = base_slug

    queryset = model.objects.all()

    if instance.pk:
        queryset = queryset.exclude(pk=instance.pk)

    while queryset.filter(slug=unique_slug).exists():
        unique_slug = f'{base_slug}-{uuid4().hex[:8]}'

    return unique_slug