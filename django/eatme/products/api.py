from rest_framework.generics import ListAPIView,RetrieveAPIView
from rest_framework.permissions import AllowAny
from .models import Products
from .serializers import ProductsDetailSerializer,ProductsListSerializer

class ProductsList(ListAPIView):
    serializer_class=ProductsListSerializer
    permission_classes=[AllowAny]
    def get_queryset(self):
        queryset=Products.objects.all().order_by('created')
        return queryset

class ProductsDetail(RetrieveAPIView):
    queryset=Products.objects.all().select_related('company')
    permission_classes=[AllowAny]
    serializer_class=ProductsDetailSerializer
    lookup_field='slug'