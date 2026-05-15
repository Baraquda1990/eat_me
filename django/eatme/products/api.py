from rest_framework.generics import ListAPIView,RetrieveAPIView
from rest_framework.permissions import AllowAny
from .models import Products
from .serializers import ProductsDetailSerializer,ProductsListSerializer
from rest_framework.pagination import LimitOffsetPagination
from drf_spectacular.utils import extend_schema
from rest_framework import filters

class ProductsPagination(LimitOffsetPagination):
    default_limit=10
    max_limit=100

@extend_schema(
    description="Получить список товаров. Можно использовать: limit=1&offset=0 — для догрузки содержимого с помощью LimitOffsetPagination. Также можно добавить: &tag=НазваниеТега — фильтрация товаров по тегам, &company=НазваниеКомпании — фильтрация товаров по компании, &search=СловаДляПоиска - поиск продуктов по названию и описанию, &ordering=price - сортировка по возрастанию цены, &ordering=-price - сортировка по убыванию цены, &ordering=-created - сортировка от новых к старым, &ordering=-created - сортировка от старых к новым"
)
class ProductsList(ListAPIView):
    serializer_class=ProductsListSerializer
    permission_classes=[AllowAny]
    filter_backends=[filters.SearchFilter, filters.OrderingFilter]
    search_fields=['name','description']
    ordering_fields=['price', 'created']
    ordering=['price']
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