from rest_framework.generics import ListAPIView,RetrieveAPIView
from rest_framework.permissions import AllowAny
from .models import Products
from .serializers import ProductsDetailSerializer,ProductsListSerializer
from rest_framework.pagination import LimitOffsetPagination
from drf_spectacular.utils import extend_schema

class ProductsPagination(LimitOffsetPagination):
    default_limit=10
    max_limit=100

@extend_schema(
    description="""
    <h3>Получить список товаров</h3>

    Можно использовать:

    <ul>
    <li>?limit=1&offset=0 — для догрузки содержимого с помощью LimitOffsetPagination</li>
    </ul>

    Также можно добавить:

    <ul>
    <li><span style="color:blue">?tag=Название_тега</span> — фильтрация товаров по тегам</li>
    <li><span style="color:blue">?company=Название_компании</span> — фильтрация товаров по компании</li>
    </ul>
"""
)
class ProductsList(ListAPIView):
    serializer_class=ProductsListSerializer
    permission_classes=[AllowAny]
    def get_queryset(self):
        queryset=Products.objects.all().select_related('company').prefetch_related('tag')
        tag=self.request.GET.get('tag')
        if tag:
            queryset=queryset.filter(tag__slug=tag)
        company=self.request.GET.get('company')
        if company:
            queryset=queryset.filter(company__slug=company)
        return queryset
    pagination_class=ProductsPagination
    
@extend_schema(
    description="Детальная информация о продукте."
)
class ProductsDetail(RetrieveAPIView):
    queryset=Products.objects.all().select_related('company')
    permission_classes=[AllowAny]
    serializer_class=ProductsDetailSerializer
    lookup_field='slug'