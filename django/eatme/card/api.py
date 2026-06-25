from rest_framework.generics import CreateAPIView,UpdateAPIView,RetrieveAPIView,DestroyAPIView,ListAPIView
from rest_framework.permissions import IsAuthenticated
from .models import Card,Card_item
from .serializers import CardSerializer,AddToCartSerializer,UpdateQuantitySerializer
from rest_framework.response import Response
from rest_framework import status
from products.models import Products
from rest_framework.exceptions import ValidationError
from drf_spectacular.utils import extend_schema
from profiles.models import OrgProf
from notifications.models import Notification
from notifications.services import send_push_to_user
from notifications.tasks import create_review_reminder
from django.db.models import Sum
from rest_framework.views import APIView
from reviews.models import Review


@extend_schema(
    description="AddToCartApi - для добавления товара в корзину"
)
class AddToCartApi(CreateAPIView):
    serializer_class = AddToCartSerializer
    permission_classes = [IsAuthenticated]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user = request.user
        product_slug = serializer.validated_data['product_slug']
        quantity = serializer.validated_data.get('quantity', 1)

        if quantity <= 0:
            return Response(
                {"error": "Количество должно быть больше 0"},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            product = Products.objects.get(slug=product_slug)
        except Products.DoesNotExist:
            return Response(
                {"error": "Продукт не найден"},
                status=status.HTTP_404_NOT_FOUND
            )

        if product.count <= 0:
            return Response(
                {
                    "error": f"Товар закончился: {product.name}",
                    "available": 0
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        cart, _ = Card.objects.get_or_create(
            user=user,
            status='pending'
        )

        item = Card_item.objects.filter(
            card=cart,
            product=product
        ).first()

        current_quantity = item.quantity if item else 0
        new_quantity = current_quantity + quantity

        if new_quantity > product.count:
            return Response(
                {
                    "error": f"Недостаточно товара: {product.name}",
                    "available": product.count,
                    "in_cart": current_quantity,
                    "can_add": max(product.count - current_quantity, 0)
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if item:
            item.quantity = new_quantity
            item.save(update_fields=['quantity'])
        else:
            item = Card_item.objects.create(
                card=cart,
                product=product,
                quantity=quantity
            )

        return Response(
            {
                "message": "Товар добавлен в корзину",
                "product": product.name,
                "quantity": item.quantity,
                "available": product.count
            },
            status=status.HTTP_201_CREATED
        )


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

        for item in cart.card_item.all():
            if item.quantity > item.product.count:
                return Response(
                    {
                        "error": f"Недостаточно товара: {item.product.name}",
                        "available": item.product.count
                    },
                    status=400
                )

        for item in cart.card_item.all():
            product = item.product
            product.count -= item.quantity
            product.save()

            sellers = OrgProf.objects.filter(company=product.company)

            for seller in sellers:
                # Создаём уведомление в БД
                Notification.objects.create(
                    user=seller.user,
                    type='order_created',
                    title='Новый заказ',
                    body=f'Купили товар: {product.name}. Количество: {item.quantity}',
                    data={
                        'product_slug': product.slug,
                        'product_name': product.name,
                        'quantity': item.quantity,
                        'buyer_id': request.user.id,
                        'buyer_username': request.user.username,
                    },
                )

                # Отправляем push-уведомление продавцу
                send_push_to_user(
                    user=seller.user,
                    title='Новый заказ',
                    body=f'Купили товар: {product.name}. Количество: {item.quantity}',
                    data={
                        'type': 'order_created',
                        'product_slug': product.slug,
                    },
                )

        cart.status = 'paided'
        cart.save()

        # Создаем напоминание об оценке после оформления заказа
        create_review_reminder(cart)

        companies = set()
        for item in cart.card_item.all():
            if item.product and item.product.company:
                companies.add(item.product.company)

        for company in companies:
            company.successful_orders += 1
            company.save(update_fields=['successful_orders'])

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


@extend_schema(description="Статистика продавца")
class SellerStatsApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        companies = OrgProf.objects.filter(
            user=request.user
        ).values_list('company_id', flat=True)

        if not companies:
            return Response({
                "total_sales": 0,
                "orders_count": 0,
                "sold_items": 0,
                "rating": 0,
                "reviews_count": 0,
            })

        items = Card_item.objects.filter(
            card__status='paided',
            product__company_id__in=companies,
            product__isnull=False,
        ).select_related('product', 'card')

        total_sales = sum(item.price_by_quantity for item in items)
        sold_items = items.aggregate(total=Sum('quantity'))['total'] or 0

        orders_count = Card.objects.filter(
            status='paided',
            card_item__product__company_id__in=companies,
        ).distinct().count()

        reviews = Review.objects.filter(
            company_id__in=companies,
        )

        rating_sum = sum(review.rating for review in reviews)
        reviews_count = reviews.count()
        rating = round(rating_sum / reviews_count, 1) if reviews_count else 0

        return Response({
            "total_sales": float(total_sales),
            "orders_count": orders_count,
            "sold_items": sold_items,
            "rating": rating,
            "reviews_count": reviews_count,
        })


@extend_schema(description="Продажи продавца")
class SellerSalesApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        companies = OrgProf.objects.filter(
            user=request.user
        ).values_list('company_id', flat=True)

        if not companies:
            return Response([])

        items = Card_item.objects.filter(
            card__status='paided',
            product__company_id__in=companies,
            product__isnull=False,
        ).select_related(
            'card',
            'card__user',
            'product',
            'product__company',
            'card__user__profile'
        ).order_by('-card__created')

        result = []

        for item in items:
            result.append({
                'id': item.id,
                'card_id': item.card.id,
                'created': item.card.created,
                'buyer': item.card.user.username if item.card.user else '',
                'product_name': item.product.name,
                'product_slug': item.product.slug,
                'company_name': item.product.company.name,
                'quantity': item.quantity,
                'price': float(item.product.get_discount_price),
                'total': float(item.price_by_quantity),
                'phone': item.card.user.profile.phone,
                'address': item.card.user.profile.address
            })

        return Response(result)
