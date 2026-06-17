from rest_framework.generics import ListAPIView,RetrieveAPIView,CreateAPIView,RetrieveUpdateAPIView,DestroyAPIView
from rest_framework.permissions import AllowAny
from .models import Products
from .serializers import ProductsDetailSerializer,ProductsListSerializer,ProductsSerializer
from rest_framework.pagination import LimitOffsetPagination
from drf_spectacular.utils import extend_schema
from rest_framework import filters
from django.db.models import F, DecimalField, ExpressionWrapper
from rest_framework.permissions import BasePermission
from rest_framework.exceptions import PermissionDenied
from profiles.models import OrgProf

class ProductsPagination(LimitOffsetPagination):
    default_limit=10
    max_limit=100

@extend_schema(
    description="Получить список товаров. Можно использовать: limit=1&offset=0 — для догрузки содержимого с помощью LimitOffsetPagination. Также можно добавить: &tag=НазваниеТега — фильтрация товаров по тегам, &company=НазваниеКомпании — фильтрация товаров по компании, &search=СловаДляПоиска - поиск продуктов по названию и описанию, &ordering=price - сортировка по возрастанию цены, &ordering=-price - сортировка по убыванию цены, &ordering=-created - сортировка от новых к старым, &ordering=-created - сортировка от старых к новым, &ordering=discount_price - сортировка по возрастанию цены со скидкой, &ordering=-discount_price - сортировка по убыванию цены со скидкой"
)
class ProductsList(ListAPIView):
    serializer_class=ProductsListSerializer
    permission_classes=[AllowAny]
    filter_backends=[filters.SearchFilter, filters.OrderingFilter]
    search_fields=['name','description']
    ordering_fields=['price', 'discount_price', 'created']
    ordering=['discount_price']
    def get_queryset(self):
        queryset=Products.objects.all().select_related('company').prefetch_related('tag').annotate(
            discount_price=ExpressionWrapper(
                F('price') - (F('price') * F('discount') / 100.0),
                output_field=DecimalField(max_digits=10, decimal_places=2)
            )
        )
        queryset=queryset.filter(count__gt=0)
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

class IsSeller(BasePermission):
    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and
            hasattr(request.user, 'profile') and
            request.user.profile.type_user == 'seller'
        )
@extend_schema(
    description="Создание продукта"
)
class ProductsCreate(CreateAPIView):
    serializer_class = ProductsSerializer
    permission_classes = [IsSeller]

    def perform_create(self, serializer):
        user = self.request.user

        company = serializer.validated_data['company']

        # 🔒 проверка: принадлежит ли компания этому продавцу
        if not OrgProf.objects.filter(user=user, company=company).exists():
            raise PermissionDenied("Вы не владелец этой компании")

        serializer.save()

@extend_schema(
    description="Список продуктов созданных компанией"
)
class MyProductsList(ListAPIView):
    serializer_class = ProductsListSerializer
    permission_classes = [IsSeller]

    def get_queryset(self):
        user = self.request.user

        return Products.objects.filter(
            company__orgprof__user=user
        ).select_related('company').prefetch_related('tag')
@extend_schema(
    description="Изменение продукта"
)
class MyProductUpdate(RetrieveUpdateAPIView):
    serializer_class = ProductsSerializer
    permission_classes = [IsSeller]
    lookup_field = 'slug'

    def get_queryset(self):
        return Products.objects.filter(
            company__orgprof__user=self.request.user
        )

    def perform_update(self, serializer):
        obj = self.get_object()

        if obj.company.orgprof.user != self.request.user:
            raise PermissionDenied("Нет доступа")

        serializer.save()
@extend_schema(
    description="Удаление продукта"
)
class MyProductDelete(DestroyAPIView):
    serializer_class = ProductsSerializer
    permission_classes = [IsSeller]
    lookup_field = 'slug'

    def get_queryset(self):
        return Products.objects.filter(
            company__orgprof__user=self.request.user
        )