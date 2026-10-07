from rest_framework.generics import CreateAPIView, UpdateAPIView, RetrieveAPIView, DestroyAPIView, ListAPIView
from rest_framework.permissions import IsAuthenticated
from .models import Card, Card_item
from .stock_out_notifications import notify_product_out_of_stock
from .snapshots import capture_card_snapshot
from .review_eligibility import hot_product_review_available_at
from .serializers import CardSerializer, AddToCartSerializer, UpdateQuantitySerializer
from rest_framework.response import Response
from rest_framework import status
from products.models import Products
from rest_framework.exceptions import ValidationError
from drf_spectacular.utils import extend_schema
from profiles.models import OrgProf
from legal.services import (
    missing_required_documents,
    preferred_language_for_request,
    serialize_documents,
)
from notifications.models import Notification
from notifications.services import send_push_to_user
from notifications.tasks import create_review_reminder
from django.db.models import Q, Sum
from rest_framework.views import APIView
from reviews.models import Review
from django.utils import timezone
from core.phone import is_valid_armenian_phone


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

        if not product.is_available_for_sale():
            return Response(
                {
                    "error": f"Товар сейчас недоступен для продажи: {product.name}",
                    "available": product.count,
                    "is_active": product.is_active,
                },
                status=status.HTTP_400_BAD_REQUEST
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

        missing_legal = missing_required_documents(
            request.user,
            action='checkout',
        )
        if missing_legal:
            language = preferred_language_for_request(request)
            return Response(
                {
                    'code': 'legal_consent_required',
                    'error': 'Required legal consent is missing.',
                    'documents': serialize_documents(
                        missing_legal,
                        language=language,
                        request=request,
                        user=request.user,
                    ),
                },
                status=428,
            )

        # Универсальные контактные данные заказа
        # Телефон обязателен для любого заказа.
        # Адрес обязателен только если в корзине есть Deals с доставкой.
        profile = getattr(request.user, 'profile', None)

        phone = profile.phone.strip() if profile and profile.phone else ''
        address = profile.address.strip() if profile and profile.address else ''
        house_number = (
            profile.house_number.strip()
            if profile and profile.house_number
            else ''
        )
        floor = (
            profile.floor.strip()
            if profile and profile.floor
            else ''
        )
        delivery_latitude = (
            profile.delivery_latitude
            if profile
            else None
        )
        delivery_longitude = (
            profile.delivery_longitude
            if profile
            else None
        )

        requires_delivery_address = cart.card_item.filter(
            product__type=Products.Type.LONG,
            product__delivery_type__in=[
                Products.DeliveryType.DELIVERY,
                Products.DeliveryType.BOTH,
            ],
        ).exists()

        missing_phone = not is_valid_armenian_phone(phone, allow_blank=False)
        missing_address = requires_delivery_address and not bool(address)
        missing_house_number = (
            requires_delivery_address and not bool(house_number)
        )
        missing_floor = (
            requires_delivery_address and not bool(floor)
        )
        missing_location = (
            requires_delivery_address
            and (
                delivery_latitude is None
                or delivery_longitude is None
            )
        )

        if (
            missing_phone
            or missing_address
            or missing_house_number
            or missing_floor
            or missing_location
        ):
            if requires_delivery_address:
                error_message = (
                    'Заполните личные данные для доставки: телефон, адрес, '
                    'номер дома, этаж и точку на карте'
                )
            else:
                error_message = (
                    'Укажите корректный армянский номер телефона '
                    'в формате +374XXXXXXXX'
                )

            return Response(
                {
                    'code': 'contact_data_required',
                    'error': error_message,
                    'required_fields': {
                        'phone': missing_phone,
                        'address': missing_address,
                        'house_number': missing_house_number,
                        'floor': missing_floor,
                        'location': missing_location,
                    },
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        for item in cart.card_item.select_related('product').all():
            if not item.product.is_available_for_sale():
                return Response(
                    {
                        "error": f"Товар снят с продажи: {item.product.name}",
                        "product_slug": item.product.slug,
                    },
                    status=400
                )

            if item.quantity > item.product.count:
                return Response(
                    {
                        "error": f"Недостаточно товара: {item.product.name}",
                        "available": item.product.count
                    },
                    status=400
                )

        # Freeze buyer + product data BEFORE stock, price or seller data can change.
        capture_card_snapshot(cart, user=request.user)

        buyer_phone = cart.buyer_phone_snapshot
        buyer_address = cart.buyer_address_snapshot
        buyer_house_number = cart.buyer_house_number_snapshot
        buyer_floor = cart.buyer_floor_snapshot
        buyer_delivery_latitude = cart.buyer_delivery_latitude_snapshot
        buyer_delivery_longitude = cart.buyer_delivery_longitude_snapshot
        buyer_delivery_additional_info = (
            cart.buyer_delivery_additional_info_snapshot
        )

        # 👇 ИЗМЕНЕННЫЙ БЛОК: группировка по компаниям
        items_by_company = {}

        for item in cart.card_item.all():
            product = item.product
            product.count -= item.quantity
            product.save()

            # Appsosa: notify seller when Deals stock reaches zero
            if str(product.type).lower() in ('long', 'deals') and product.count <= 0:
                notify_product_out_of_stock(product.id)
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
                item.snapshot_product_name for item in items[:3]
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
                        'buyer_house_number': buyer_house_number,
                        'buyer_floor': buyer_floor,
                        'buyer_delivery_latitude': buyer_delivery_latitude,
                        'buyer_delivery_longitude': buyer_delivery_longitude,
                        'buyer_delivery_additional_info': (
                            buyer_delivery_additional_info
                        ),
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
                        'buyer_house_number': buyer_house_number,
                        'buyer_floor': buyer_floor,
                        'buyer_delivery_latitude': (
                            '' if buyer_delivery_latitude is None
                            else str(buyer_delivery_latitude)
                        ),
                        'buyer_delivery_longitude': (
                            '' if buyer_delivery_longitude is None
                            else str(buyer_delivery_longitude)
                        ),
                        'buyer_delivery_additional_info': (
                            buyer_delivery_additional_info
                        ),
                    },
                )

        cart.status = 'paided'
        cart.save()

        # Reviews are HOT-only. Persist paid_at + 2h only for HOT items and
        # never schedule a review reminder for a Deals-only checkout.
        has_hot_review_item = False

        for item in cart.card_item.select_related('product').all():
            if str(item.snapshot_product_type or '').lower() != 'hot':
                continue

            has_hot_review_item = True
            item.review_available_at = hot_product_review_available_at(
                item.product,
                cart,
            )
            item.save(update_fields=['review_available_at'])

        if has_hot_review_item:
            create_review_reminder(cart)

        companies = set()
        for item in cart.card_item.all():
            if item.product and item.product.company:
                companies.add(item.product.company)

        for company in companies:
            company.successful_orders += 1
            company.save(update_fields=['successful_orders'])

        Card.objects.create(user=request.user, status='pending')

        return Response({
            "message": "Заказ оформлен",
            "card_id": cart.id,
            "order_number": cart.order_number,
        })


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

        if not product.is_available_for_sale():
            return Response(
                {
                    "error": f"Товар снят с продажи: {product.name}",
                    "product_slug": product.slug,
                },
                status=400
            )

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
        ).order_by('-paid_at', '-id')


@extend_schema(description="Статистика продавца")
class SellerStatsApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        companies = list(
            OrgProf.objects.filter(
                user=request.user
            ).values_list('company_id', flat=True)
        )

        if not companies:
            return Response({
                "total_sales": 0,
                "orders_count": 0,
                "sold_items": 0,
                "rating": 0,
                "reviews_count": 0,
            })

        item_company_filter = (
            Q(company_id_snapshot__in=companies)
            | Q(
                company_id_snapshot__isnull=True,
                product__company_id__in=companies,
            )
        )

        items = (
            Card_item.objects
            .filter(card__status='paided')
            .filter(item_company_filter)
            .select_related('product', 'card')
        )

        total_sales = sum(item.price_by_quantity for item in items)
        sold_items = items.aggregate(total=Sum('quantity'))['total'] or 0

        orders_count = (
            Card.objects
            .filter(status='paided')
            .filter(
                Q(card_item__company_id_snapshot__in=companies)
                | Q(
                    card_item__company_id_snapshot__isnull=True,
                    card_item__product__company_id__in=companies,
                )
            )
            .distinct()
            .count()
        )

        reviews = Review.objects.filter(company_id__in=companies)

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
        companies = list(
            OrgProf.objects.filter(
                user=request.user
            ).values_list('company_id', flat=True)
        )

        if not companies:
            return Response([])

        items = (
            Card_item.objects
            .filter(card__status='paided')
            .filter(
                Q(company_id_snapshot__in=companies)
                | Q(
                    company_id_snapshot__isnull=True,
                    product__company_id__in=companies,
                )
            )
            .select_related(
                'card',
                'card__user',
                'card__user__profile',
                'product',
                'product__company',
            )
            .order_by('-card__paid_at', '-card__id')
        )

        grouped = {}

        for item in items:
            card = item.card
            company_id = item.snapshot_company_id
            if company_id is None:
                continue

            company_name = item.snapshot_company_name
            key = f'{card.id}_{company_id}'

            buyer_profile = getattr(card.user, 'profile', None)
            buyer_username = (
                card.buyer_username_snapshot
                or (card.user.username if card.user else '')
            )
            buyer_phone = (
                card.buyer_phone_snapshot
                or (buyer_profile.phone if buyer_profile else '')
            )
            buyer_address = (
                card.buyer_address_snapshot
                or (buyer_profile.address if buyer_profile else '')
            )

            if key not in grouped:
                grouped[key] = {
                    'id': key,
                    'card_id': card.id,
                    'order_number': card.order_number,
                    'company_id': company_id,
                    'company_name': company_name,
                    'created': card.paid_at or card.created,
                    'buyer': buyer_username,
                    'buyer_phone': buyer_phone,
                    'buyer_address': buyer_address,
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
                'product_name': item.snapshot_product_name,
                'product_slug': item.snapshot_product_slug,
                'product_type': item.snapshot_product_type,
                'quantity': item.quantity,
                'price': float(item.unit_price),
                'total': float(item_total),
                'product_snapshot': item.product_snapshot or {},
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

        items = (
            Card_item.objects
            .filter(
                card_id=card_id,
                card__status='paided',
            )
            .filter(
                Q(company_id_snapshot=company_id)
                | Q(
                    company_id_snapshot__isnull=True,
                    product__company_id=company_id,
                )
            )
            .select_related(
                'card',
                'card__user',
                'card__user__profile',
                'product',
                'product__company',
            )
        )

        if not items.exists():
            return Response(
                {"error": "Заказ не найден"},
                status=404
            )

        first_item = items.first()
        card = first_item.card
        buyer = card.user
        buyer_profile = getattr(buyer, 'profile', None)

        buyer_username = (
            card.buyer_username_snapshot
            or (buyer.username if buyer else '')
        )
        buyer_phone = (
            card.buyer_phone_snapshot
            or (buyer_profile.phone if buyer_profile else '')
        )
        buyer_address = (
            card.buyer_address_snapshot
            or (buyer_profile.address if buyer_profile else '')
        )

        order_items = []
        total = 0

        for item in items:
            item_total = item.price_by_quantity
            total += item_total

            order_items.append({
                'id': item.id,
                'product_name': item.snapshot_product_name,
                'product_slug': item.snapshot_product_slug,
                'product_type': item.snapshot_product_type,
                'quantity': item.quantity,
                'price': float(item.unit_price),
                'total': float(item_total),
                'product_snapshot': item.product_snapshot or {},
            })

        return Response({
            'card_id': card.id,
            'order_number': card.order_number,
            'company_id': company_id,
            'company_name': first_item.snapshot_company_name,
            'created': card.paid_at or card.created,
            'buyer': buyer_username,
            'buyer_phone': buyer_phone,
            'buyer_address': buyer_address,
            'buyer_house_number': card.buyer_house_number_snapshot,
            'buyer_floor': card.buyer_floor_snapshot,
            'buyer_delivery_latitude': (
                card.buyer_delivery_latitude_snapshot
            ),
            'buyer_delivery_longitude': (
                card.buyer_delivery_longitude_snapshot
            ),
            'buyer_delivery_additional_info': (
                card.buyer_delivery_additional_info_snapshot
            ),
            'items': order_items,
            'total': float(total),
        })
