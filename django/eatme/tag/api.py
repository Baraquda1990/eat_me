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
        product_type = self.request.query_params.get('type')

        qs = Tag.objects.all()

        if product_type in ['hot', 'long']:
            qs = qs.filter(products__type=product_type)

        return (
            qs.annotate(
                products_count=Count('products', distinct=True)
            )
            .filter(products_count__gt=0)
            .order_by('-products_count')
            .distinct()
        )