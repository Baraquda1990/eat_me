from rest_framework.generics import ListAPIView
from .serializers import TagSerializer
from .models import Tag
from django.db.models import Count
from drf_spectacular.utils import extend_schema
@extend_schema(
        description="Получить список всех тегов. Возвращает отсортированные теги от большего к меньшему с полем products_count - количество товаров с данным тегом.",
    )
class TagsList(ListAPIView):
    serializer_class=TagSerializer
    def get_queryset(self):
        return (
            Tag.objects.annotate(products_count=Count('products'))
            .filter(products_count__gt=0)
            .order_by('-products_count')
        )