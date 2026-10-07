from rest_framework.generics import ListAPIView
from .serializers import TagSerializer
from .models import Tag
from django.db.models import Count
from drf_spectacular.utils import extend_schema


@extend_schema(
    description=(
        "Получить список тегов. По умолчанию возвращаются только теги, "
        "которые уже используются товарами. Для формы продавца используйте "
        "?include_empty=1, чтобы получить весь справочник тегов."
    )
)
class TagsList(ListAPIView):
    serializer_class = TagSerializer

    def get_queryset(self):
        product_type = self.request.query_params.get('type')
        include_empty = (
            str(self.request.query_params.get('include_empty', ''))
            .strip()
            .lower()
            in {'1', 'true', 'yes'}
        )

        qs = Tag.objects.all()

        # В обычном каталоге/будильнике с type оставляем только теги,
        # которые реально используются товарами выбранного типа.
        if product_type in ['hot', 'long']:
            qs = qs.filter(products__type=product_type)

        qs = qs.annotate(
            products_count=Count('products', distinct=True)
        )

        # В форме создания/редактирования товара продавцу нужен ВЕСЬ
        # справочник, включая новые теги, которые пока не привязаны ни к
        # одному товару. Иначе после добавления нового тега в админке он
        # никогда не появится в форме продавца.
        if not include_empty:
            qs = qs.filter(products_count__gt=0)

        return qs.order_by('-products_count', 'name').distinct()
