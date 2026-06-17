from rest_framework.generics import (
    ListAPIView,
    RetrieveAPIView,
    CreateAPIView,
    RetrieveUpdateAPIView,
    DestroyAPIView,
)
from rest_framework.permissions import AllowAny, BasePermission
from rest_framework.exceptions import PermissionDenied
from rest_framework.pagination import LimitOffsetPagination
from rest_framework import filters
from drf_spectacular.utils import extend_schema
from django.db.models import F, DecimalField, ExpressionWrapper
from notifications.tasks import check_product_alarm_matches
from .models import Products
from .serializers import ProductsDetailSerializer, ProductsListSerializer, ProductsSerializer
from profiles.models import OrgProf
from django.db.models import Q
from card.models import Card_item


class ProductsPagination(LimitOffsetPagination):
    default_limit = 10
    max_limit = 100


@extend_schema(
    description=(
        "Получить список товаров. Можно использовать: limit=1&offset=0 — для догрузки содержимого "
        "с помощью LimitOffsetPagination. Также можно добавить: &tag=НазваниеТега — фильтрация товаров "
        "по тегам, &company=НазваниеКомпании — фильтрация товаров по компании, &type=hot/long — фильтрация "
        "по типу товара (горячие/акции), &search=СловаДляПоиска - поиск продуктов по названию и описанию, "
        "&ordering=price - сортировка по возрастанию цены, &ordering=-price - сортировка по убыванию цены, "
        "&ordering=-created - сортировка от новых к старым, "
        "&ordering=discount_price - сортировка по возрастанию цены со скидкой, "
        "&ordering=-discount_price - сортировка по убыванию цены со скидкой"
    )
)
class ProductsList(ListAPIView):
    serializer_class = ProductsListSerializer
    permission_classes = [AllowAny]
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name', 'description']
    ordering_fields = ['price', 'discount_price', 'created']
    ordering = ['discount_price']
    pagination_class = ProductsPagination

    def get_queryset(self):
        queryset = Products.objects.all().select_related('company').prefetch_related('tag').annotate(
            discount_price=ExpressionWrapper(
                F('price') - (F('price') * F('discount') / 100.0),
                output_field=DecimalField(max_digits=10, decimal_places=2),
            )
        )
        queryset = queryset.filter(count__gt=0)

        tag = self.request.GET.get('tag')
        if tag:
            queryset = queryset.filter(tag__slug=tag)

        company = self.request.GET.get('company')
        if company:
            queryset = queryset.filter(company__slug=company)

        product_type = self.request.GET.get('type')
        if product_type:
            queryset = queryset.filter(type__iexact=product_type)

        return queryset


@extend_schema(description="Рекомендованные товары для пользователя")
class RecommendedProductsList(ListAPIView):
    serializer_class = ProductsListSerializer
    permission_classes = [AllowAny]
    pagination_class = ProductsPagination

    def get_queryset(self):
        queryset = Products.objects.all().select_related(
            'company'
        ).prefetch_related(
            'tag'
        ).annotate(
            discount_price=ExpressionWrapper(
                F('price') - (F('price') * F('discount') / 100.0),
                output_field=DecimalField(max_digits=10, decimal_places=2),
            )
        ).filter(
            count__gt=0,
            type__iexact='hot'
        )

        user = self.request.user

        if user.is_authenticated:
            purchased_items = Card_item.objects.filter(
                card__user=user,
                card__status='paided',
                product__isnull=False,
            ).select_related('product').prefetch_related('product__tag')

            tag_slugs = set()

            for item in purchased_items[:50]:
                if not item.product:
                    continue

                for tag in item.product.tag.all():
                    tag_slugs.add(tag.slug)

            if tag_slugs:
                recommended = queryset.filter(
                    tag__slug__in=tag_slugs
                ).distinct().order_by(
                    '-company__company_score',
                    '-company__rating',
                    'discount_price'
                )

                if recommended.exists():
                    return recommended

        return queryset.order_by(
            '-company__company_score',
            '-company__rating',
            'discount_price'
        )


@extend_schema(description="Детальная информация о продукте.")
class ProductsDetail(RetrieveAPIView):
    queryset = Products.objects.all().select_related('company')
    permission_classes = [AllowAny]
    serializer_class = ProductsDetailSerializer
    lookup_field = 'slug'


class IsSeller(BasePermission):
    def has_permission(self, request, view):
        return (
            request.user.is_authenticated
            and hasattr(request.user, 'profile')
            and request.user.profile.type_user == 'seller'
        )


@extend_schema(description="Создание продукта")
class ProductsCreate(CreateAPIView):
    serializer_class = ProductsSerializer
    permission_classes = [IsSeller]

    def perform_create(self, serializer):
        user = self.request.user
        company = serializer.validated_data['company']

        if not OrgProf.objects.filter(user=user, company=company).exists():
            raise PermissionDenied("Вы не владелец этой компании")

        product = serializer.save()
        check_product_alarm_matches.delay(product.id)


@extend_schema(description="Список продуктов созданных компанией")
class MyProductsList(ListAPIView):
    serializer_class = ProductsListSerializer
    permission_classes = [IsSeller]

    def get_queryset(self):
        return Products.objects.filter(
            company__orgprof__user=self.request.user
        ).select_related('company').prefetch_related('tag').order_by('-created')


@extend_schema(description="Изменение продукта")
class MyProductUpdate(RetrieveUpdateAPIView):
    serializer_class = ProductsSerializer
    permission_classes = [IsSeller]
    lookup_field = 'slug'

    def get_queryset(self):
        # Важно: здесь уже проверяется владелец товара.
        # Если товар не принадлежит продавцу, Django просто не найдёт объект.
        return Products.objects.filter(
            company__orgprof__user=self.request.user
        )

    def perform_update(self, serializer):
        company = serializer.validated_data.get('company')

        # Если при редактировании продавец меняет компанию,
        # проверяем, что новая компания тоже принадлежит ему.
        if company and not OrgProf.objects.filter(user=self.request.user, company=company).exists():
            raise PermissionDenied("Вы не владелец этой компании")

        serializer.save()


@extend_schema(description="Удаление продукта")
class MyProductDelete(DestroyAPIView):
    serializer_class = ProductsSerializer
    permission_classes = [IsSeller]
    lookup_field = 'slug'

    def get_queryset(self):
        return Products.objects.filter(
            company__orgprof__user=self.request.user
        )
