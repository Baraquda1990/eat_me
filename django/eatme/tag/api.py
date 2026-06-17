from rest_framework.generics import ListAPIView
from .serializers import TagSerializer
from .models import Tag
from django.db.models import Count
from drf_spectacular.utils import extend_schema

@extend_schema(
    description="Получить список всех тегов."
)
class TagsList(ListAPIView):
    serializer_class = TagSerializer

    def get_queryset(self):
        return (
            Tag.objects.annotate(
                products_count=Count('products')
            ).order_by('-products_count')
        )
