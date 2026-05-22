from rest_framework.generics import RetrieveAPIView,ListAPIView
from rest_framework.permissions import AllowAny
from .models import Company
from .serializers import CompanySerializer
from drf_spectacular.utils import extend_schema
from math import radians
from django.db.models import (
    F, Value, FloatField, ExpressionWrapper
)
from django.db.models.functions import ACos, Cos, Sin, Radians

@extend_schema(
    description="Детальная информация о компании."
)
class CompanyDetail(RetrieveAPIView):
    queryset=Company.objects.all()
    permission_classes=[AllowAny]
    serializer_class=CompanySerializer
    lookup_field='slug'

@extend_schema(
    description="Список компаний. GET /company/?latitude=50.283&longitude=57.167 - сортировка по расстоянию"
)
class CompanyList(ListAPIView):
    serializer_class = CompanySerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        qs = Company.objects.all()
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