from rest_framework.generics import CreateAPIView,UpdateAPIView,RetrieveAPIView,DestroyAPIView,ListAPIView
from rest_framework.permissions import IsAuthenticated
from .models import Card,Card_item
from .serializers import CardSerializer,AddToCartSerializer,UpdateQuantitySerializer
from rest_framework.response import Response
from rest_framework import status
from products.models import Products
from rest_framework.exceptions import ValidationError
from drf_spectacular.utils import extend_schema

@extend_schema(
    description="AddToCartApi - для добавления товара в корзину"
)
class AddToCartApi(CreateAPIView):
    serializer_class = AddToCartSerializer
    permission_classes = [IsAuthenticated]
    def perform_create(self, serializer):
        user = self.request.user
        cart, _ = Card.objects.get_or_create(
            user=user,
            status='pending'
        )
        product_slug = serializer.validated_data['product_slug']
        try:
            product = Products.objects.get(slug=product_slug)
        except Products.DoesNotExist:
            raise ValidationError("Продукт не найден")
        quantity = serializer.validated_data['quantity']
        item, created = Card_item.objects.get_or_create(
            card=cart,
            product=product,
            defaults={'quantity': quantity}
        )
        if not created:
            item.quantity += quantity
            item.save()

@extend_schema(
    description="CartUpdateApi - изменения элементов корзины"
)
class CartUpdateApi(UpdateAPIView):
    serializer_class = CardSerializer
    permission_classes = [IsAuthenticated]
    def get_object(self):
        return Card.objects.get(
            user=self.request.user,
            status='pending'
        )
@extend_schema(
    description="CartRetrieveApi - предоставление корзины для пользователя"
)
class CartRetrieveApi(RetrieveAPIView):
    serializer_class = CardSerializer
    permission_classes = [IsAuthenticated]
    def get_object(self):
        cart, _ = Card.objects.get_or_create(
            user=self.request.user,
            status='pending'
        )
        return cart
@extend_schema(
    description="CheckoutApi - для проверки наличия необходимых полей и затем изменение статуса корзины"
)
class CheckoutApi(UpdateAPIView):
    serializer_class = CardSerializer
    permission_classes = [IsAuthenticated]
    def get_object(self):
        return Card.objects.get(
            user=self.request.user,
            status='pending'
        )

    def update(self, request, *args, **kwargs):
        cart = self.get_object()
        cart.status = 'paided'
        cart.save()
        Card.objects.create(user=request.user, status='pending')
        return Response({"message": "Заказ оформлен"})
@extend_schema(
    description="RemoveCartItemApi - удаление товара из корзины"
)
class RemoveCartItemApi(DestroyAPIView):
    permission_classes = [IsAuthenticated]
    def get_object(self):
        return Card_item.objects.get(
            card__user=self.request.user,
            card__status='pending',
            product__slug=self.kwargs['slug']
        )
@extend_schema(
    description="UpdateQuantityApi - изменение количества товара в корзине"
)
class UpdateQuantityApi(UpdateAPIView):
    serializer_class = UpdateQuantitySerializer
    permission_classes = [IsAuthenticated]
    def update(self, request, *args, **kwargs):
        user = request.user
        product_slug = kwargs.get('slug')
        try:
            item = Card_item.objects.get(
                card__user=user,
                card__status='pending',
                product__slug=product_slug
            )
        except Card_item.DoesNotExist:
            return Response(
                {"error": "Товар не найден в корзине"},
                status=404
            )
        quantity = request.data.get('quantity')
        if quantity is None:
            return Response(
                {"error": "quantity обязателен"},
                status=400
            )
        quantity = int(quantity)
        if quantity <= 0:
            item.delete()
            return Response(
                {"message": "Товар удалён"}
            )
        product = item.product
        if quantity > product.count:
            return Response(
                {
                    "error": "Недостаточно товара на складе",
                    "available": product.count
                },
                status=400
            )
        item.quantity = quantity
        item.save()

        return Response(
            {"message": "Количество обновлено"}
        )
@extend_schema(
    description="PastOrdersApi - предоставление предыдущих заказов (корзины со статусом 'Оплачен')"
)
class PastOrdersApi(ListAPIView):
    serializer_class = CardSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Card.objects.filter(
            user=self.request.user,
            status='paided'
        ).order_by('-created')