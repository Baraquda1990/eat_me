from products.serializers import ProductsListSerializer
from .models import Favourites
from products.models import Products
from rest_framework.generics import ListAPIView,CreateAPIView,DestroyAPIView
from rest_framework.permissions import IsAuthenticated
from .serializers import FavouritesSerializer,FavouritesList
from drf_spectacular.utils import extend_schema
@extend_schema(
        description="Добавление товара в избранное. Требует Авторизации.",
    )
class CreateFavourites(CreateAPIView):
    queryset = Favourites.objects.all()
    serializer_class = FavouritesSerializer
    permission_classes = [IsAuthenticated]
    def perform_create(self, serializer):
        serializer.save(user=self.request.user)
@extend_schema(
        description="Список избранных товаров. Требует Авторизации.",
    )
class ListFavorites(ListAPIView):
    serializer_class=FavouritesList
    permission_classes=[IsAuthenticated]
    def get_queryset(self):
        user=self.request.user
        queryset=Favourites.objects.filter(user=user)
        return queryset
@extend_schema(
        description="Удаление из избранного. Требует Авторизации.",
    )
class DestroyFavorites(DestroyAPIView):
    permission_classes=[IsAuthenticated]
    lookup_field = 'products__slug'
    lookup_url_kwarg = 'slug'
    def get_queryset(self):
        return Favourites.objects.filter(user=self.request.user)
@extend_schema(
        description="Список избранных товаров с детальной информацией о продукте. Требует Авторизации.",
    )
class ListFavouritesDetail(ListAPIView):
    permission_classes=[IsAuthenticated]
    serializer_class=ProductsListSerializer
    def get_queryset(self):
        user=self.request.user
        queryset = Products.objects.filter(favourites__user=user).order_by('created')
        return queryset