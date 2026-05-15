from rest_framework.generics import ListAPIView
from rest_framework.permissions import AllowAny
from products.models import Products
from products.serializers import ProductsListSerializer
from rest_framework import filters
from rest_framework.pagination import LimitOffsetPagination
from drf_spectacular.utils import extend_schema

class ProductsPagination(LimitOffsetPagination):
    default_limit=10
    max_limit=100

@extend_schema(
    description="Поиск продуктов по названию и описанию. Можно использовать: limit=1&offset=0 — для догрузки содержимого с помощью LimitOffsetPagination. Запрос по роуту /search?search=СловаДляПоиска"
)

class SearchApi(ListAPIView):
    queryset=Products.objects.all()
    permission_classes=[AllowAny]
    serializer_class=ProductsListSerializer
    filter_backends=[filters.SearchFilter]
    search_fields=['name','description']
    pagination_class = ProductsPagination