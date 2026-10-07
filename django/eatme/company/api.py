from rest_framework.generics import (
    RetrieveAPIView,
    ListAPIView,
    CreateAPIView,
    RetrieveUpdateAPIView,
)
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.exceptions import PermissionDenied
from django.db.models import (
    F, Value, FloatField, ExpressionWrapper, Count, Q
)
from django.db.models.functions import ACos, Cos, Sin, Radians
from drf_spectacular.utils import extend_schema

from .models import Company
from .serializers import CompanySerializer, CompanyCreateSerializer
from profiles.models import OrgProf


def company_queryset():
    """Company queryset with HOT-product presence precomputed.

    A mixed HOT + Deals company has hot_products_count > 0 and therefore keeps
    its rating block. A Deals-only company receives has_hot_products=false.
    """
    return Company.objects.annotate(
        hot_products_count=Count(
            'products',
            filter=Q(products__type='hot'),
            distinct=True,
        ),
    )


@extend_schema(
    description="Детальная информация о компании."
)
class CompanyDetail(RetrieveAPIView):
    queryset = company_queryset()
    permission_classes = [AllowAny]
    serializer_class = CompanySerializer
    lookup_field = 'slug'


@extend_schema(
    description="Список компаний. GET /company/?latitude=50.283&longitude=57.167 - сортировка по расстоянию"
)
class CompanyList(ListAPIView):
    serializer_class = CompanySerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        qs = company_queryset()
        
        # Фильтрация по типу продукта
        product_type = self.request.query_params.get('type')
        
        if product_type in ['hot', 'long']:
            qs = qs.filter(products__type=product_type).distinct()
        
        lat = self.request.query_params.get('latitude')
        lon = self.request.query_params.get('longitude')
        if not lat or not lon:
            return qs
        try:
            lat = float(lat)
            lon = float(lon)
        except ValueError:
            return qs
        distance = 6371 * ACos(
            Cos(Radians(Value(lat))) *
            Cos(Radians(F('latitude'))) *
            Cos(Radians(F('longitude')) - Radians(Value(lon))) +
            Sin(Radians(Value(lat))) *
            Sin(Radians(F('latitude')))
        )
        return qs.annotate(
            distance=ExpressionWrapper(distance, output_field=FloatField())
        ).order_by('distance')


@extend_schema(
    description="Создание компании"
)
class CompanyCreate(CreateAPIView):
    serializer_class = CompanyCreateSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]
    
    def perform_create(self, serializer):
        if not hasattr(self.request.user, 'profile'):
            raise PermissionDenied('Профиль не найден')
        if self.request.user.profile.type_user != 'seller':
            raise PermissionDenied(
                'Создавать компании могут только продавцы'
            )
        company = serializer.save()
        OrgProf.objects.create(
            user=self.request.user,
            company=company
        )


@extend_schema(
    description="Список созданных компаний продавцом"
)
class MyCompanyList(ListAPIView):
    serializer_class = CompanySerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user

        if not hasattr(user, 'profile'):
            raise PermissionDenied('Профиль не найден')

        if user.profile.type_user != 'seller':
            raise PermissionDenied('Только продавцы имеют доступ')

        return company_queryset().filter(orgprof__user=user)


@extend_schema(
    description="Детальная информация о компании и изменение компании"
)
class MyCompanyDetailUpdate(RetrieveUpdateAPIView):
    serializer_class = CompanySerializer
    permission_classes = [IsAuthenticated]
    lookup_field = 'slug'
    parser_classes = [MultiPartParser, FormParser]

    def get_queryset(self):
        user = self.request.user

        if not hasattr(user, 'profile'):
            raise PermissionDenied('Профиль не найден')

        if user.profile.type_user != 'seller':
            raise PermissionDenied('Только продавцы имеют доступ')

        return Company.objects.filter(orgprof__user=user)