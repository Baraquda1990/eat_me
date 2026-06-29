from rest_framework.generics import CreateAPIView, UpdateAPIView, RetrieveAPIView, DestroyAPIView, ListAPIView
from rest_framework.permissions import IsAuthenticated
from .models import Card, Card_item
from .serializers import CardSerializer, AddToCartSerializer, UpdateQuantitySerializer
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

        # Проверка для Deals
        has_deals = cart.card_item.filter(
            product__type='long'
        ).exists()

        if has_deals:
            profile = getattr(request.user, 'profile', None)

            phone = profile.phone.strip() if profile and profile.phone else ''
            address = profile.address.strip() if profile and profile.address else ''

            if not phone or not address:
                return Response(
                    {
                        "error": "Для заказа Deals нужно указать телефон и адрес доставки",
                        "required_fields": {
                            "phone": not bool(phone),
                            "address": not bool(address),
                        }
                    },
                    status=400
                )

        for item in cart.card_item.all():
            if item.quantity > item.product.count:
                return Response(
                    {
                        "error": f"Недостаточно товара: {item.product.name}",
                        "available": item.product.count
                    },
                    status=400
                )

        buyer_profile = getattr(request.user, 'profile', None)
        buyer_phone = buyer_profile.phone if buyer_profile else ''
        buyer_address = buyer_profile.address if buyer_profile else ''

        # 👇 ИЗМЕНЕННЫЙ БЛОК: группировка по компаниям
        items_by_company = {}

        for item in cart.card_item.all():
            product = item.product
            product.count -= item.quantity
            product.save()

            company = product.company

            if company.id not in items_by_company:
                items_by_company[company.id] = {
                    'company': company,
                    'items': [],
                }

            items_by_company[company.id]['items'].append(item)

        for company_data in items_by_company.values():
            company = company_data['company']
            items = company_data['items']

            sellers = OrgProf.objects.filter(company=company)

            total_quantity = sum(item.quantity for item in items)
            total_sum = sum(item.price_by_quantity for item in items)

            product_names = ', '.join(
                item.product.name for item in items[:3]
            )

            if len(items) > 3:
                product_names += f' и ещё {len(items) - 3}'

            for seller in sellers:
                Notification.objects.create(
                    user=seller.user,
                    type='order_created',
                    title='Новый заказ',
                    body=(
                        f'{request.user.username} купил товаров: {total_quantity}. '
                        f'{product_names}. '
                        f'Тел: {buyer_phone or "не указан"}'
                    ),
                    data={
                        'card_id': cart.id,
                        'company_id': company.id,
                        'company_name': company.name,
                        'items_count': len(items),
                        'total_quantity': total_quantity,
                        'total': float(total_sum),
                        'buyer_id': request.user.id,
                        'buyer_username': request.user.username,
                        'buyer_phone': buyer_phone,
                        'buyer_address': buyer_address,
                    },
                )

                send_push_to_user(
                    user=seller.user,
                    title='Новый заказ',
                    body=(
                        f'{request.user.username} купил товаров: {total_quantity}. '
                        f'{product_names}. '
                        f'Тел: {buyer_phone or "не указан"}'
                    ),
                    data={
                        'type': 'order_created',
                        'card_id': str(cart.id),
                        'company_id': str(company.id),
                        'company_name': company.name,
                        'items_count': str(len(items)),
                        'total_quantity': str(total_quantity),
                        'total': str(float(total_sum)),
                        'buyer_username': request.user.username,
                        'buyer_phone': buyer_phone,
                        'buyer_address': buyer_address,
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
            'card__user__profile',
            'product',
            'product__company',
        ).order_by('-card__created')

        grouped = {}

        for item in items:
            card = item.card
            product = item.product
            company = product.company

            key = f'{card.id}_{company.id}'

            buyer_profile = getattr(card.user, 'profile', None)

            if key not in grouped:
                grouped[key] = {
                    'id': key,
                    'card_id': card.id,
                    'company_id': company.id,
                    'company_name': company.name,
                    'created': card.created,
                    'buyer': card.user.username if card.user else '',
                    'buyer_phone': buyer_profile.phone if buyer_profile else '',
                    'buyer_address': buyer_profile.address if buyer_profile else '',
                    'items_count': 0,
                    'total_quantity': 0,
                    'total': 0,
                    'products': [],
                    'products_text': '',
                }

            item_total = item.price_by_quantity

            grouped[key]['items_count'] += 1
            grouped[key]['total_quantity'] += item.quantity
            grouped[key]['total'] += float(item_total)

            grouped[key]['products'].append({
                'id': item.id,
                'product_name': product.name,
                'product_slug': product.slug,
                'quantity': item.quantity,
                'price': float(product.get_discount_price),
                'total': float(item_total),
            })

        result = []

        for sale in grouped.values():
            product_names = [
                product['product_name']
                for product in sale['products']
            ]

            sale['products_text'] = ', '.join(product_names[:3])

            if len(product_names) > 3:
                sale['products_text'] += f' и ещё {len(product_names) - 3}'

            result.append(sale)

        result.sort(
            key=lambda sale: sale['created'],
            reverse=True,
        )

        return Response(result)


@extend_schema(description="Детали заказа продавца по корзине и компании")
class SellerOrderDetailApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, card_id, company_id):
        seller_has_company = OrgProf.objects.filter(
            user=request.user,
            company_id=company_id,
        ).exists()

        if not seller_has_company:
            return Response(
                {"error": "Нет доступа к этому заказу"},
                status=403
            )

        items = Card_item.objects.filter(
            card_id=card_id,
            card__status='paided',
            product__company_id=company_id,
            product__isnull=False,
        ).select_related(
            'card',
            'card__user',
            'card__user__profile',
            'product',
            'product__company',
        )

        if not items.exists():
            return Response(
                {"error": "Заказ не найден"},
                status=404
            )

        first_item = items.first()
        buyer = first_item.card.user
        buyer_profile = getattr(buyer, 'profile', None)

        order_items = []
        total = 0

        for item in items:
            item_total = item.price_by_quantity
            total += item_total

            order_items.append({
                'id': item.id,
                'product_name': item.product.name,
                'product_slug': item.product.slug,
                'quantity': item.quantity,
                'price': float(item.product.get_discount_price),
                'total': float(item_total),
            })

        return Response({
            'card_id': first_item.card.id,
            'company_id': company_id,
            'company_name': first_item.product.company.name,
            'created': first_item.card.created,
            'buyer': buyer.username,
            'buyer_phone': buyer_profile.phone if buyer_profile else '',
            'buyer_address': buyer_profile.address if buyer_profile else '',
            'items': order_items,
            'total': float(total),
        })