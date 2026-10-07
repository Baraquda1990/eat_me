# card/hot_reservation_api.py

from django.db import transaction
from django.db.models import F
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from notifications.models import Notification
from notifications.services import send_push_to_user
from notifications.tasks import create_review_reminder
from products.models import Products
from profiles.models import OrgProf
from core.phone import is_valid_armenian_phone
from legal.services import (
    missing_required_documents,
    preferred_language_for_request,
    serialize_documents,
)

from .models import Card, Card_item
from .review_eligibility import hot_product_review_available_at


class HotReserveApi(APIView):
    """
    Direct reservation for a HOT product.

    Important:
    - does NOT checkout the user's shared pending cart;
    - requires a buyer phone number;
    - does NOT require a delivery address;
    - creates a separate paid order for this HOT reservation;
    - leaves Deals in the pending cart untouched;
    - removes a stale copy of the same HOT product from the pending cart,
      which can remain there after the old checkout flow failed.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
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

        product_slug = str(request.data.get('product_slug') or '').strip()

        try:
            quantity = int(request.data.get('quantity', 1))
        except (TypeError, ValueError):
            quantity = 0

        if not product_slug:
            return Response(
                {
                    'code': 'hot_not_found',
                    'error': 'Товар не найден',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if quantity <= 0:
            return Response(
                {
                    'code': 'invalid_quantity',
                    'error': 'Количество должно быть больше 0',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        buyer_profile = getattr(request.user, 'profile', None)
        buyer_phone = (
            buyer_profile.phone.strip()
            if buyer_profile and buyer_profile.phone
            else ''
        )
        buyer_address = (
            buyer_profile.address.strip()
            if buyer_profile and buyer_profile.address
            else ''
        )

        if not is_valid_armenian_phone(buyer_phone, allow_blank=False):
            return Response(
                {
                    'code': 'phone_required',
                    'error': (
                        'Для оформления заказа укажите корректный армянский '
                        'номер телефона в формате +374XXXXXXXX'
                    ),
                    'required_fields': {
                        'phone': True,
                        'address': False,
                    },
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        with transaction.atomic():
            product = (
                Products.objects
                .select_for_update()
                .select_related('company')
                .filter(slug=product_slug)
                .first()
            )

            if product is None:
                return Response(
                    {
                        'code': 'hot_not_found',
                        'error': 'Товар не найден',
                    },
                    status=status.HTTP_404_NOT_FOUND,
                )

            if product.type != Products.Type.HOT:
                return Response(
                    {
                        'code': 'not_hot',
                        'error': 'Этот способ покупки доступен только для HOT-товаров',
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            if not product.is_available_for_sale():
                return Response(
                    {
                        'code': 'hot_unavailable',
                        'error': 'HOT-предложение больше недоступно',
                        'available': max(int(product.count or 0), 0),
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            available = max(int(product.count or 0), 0)

            if available <= 0:
                return Response(
                    {
                        'code': 'hot_out_of_stock',
                        'error': 'Товар закончился',
                        'available': 0,
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            if quantity > available:
                return Response(
                    {
                        'code': 'hot_out_of_stock',
                        'error': f'Доступно только {available} шт.',
                        'available': available,
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # Remove only a stale copy of THIS HOT item from pending carts.
            # Deals and other items remain untouched.
            pending_carts = Card.objects.filter(
                user=request.user,
                status='pending',
            )
            Card_item.objects.filter(
                card__in=pending_carts,
                product=product,
            ).delete()

            # A HOT reservation is its own completed order.
            order = Card.objects.create(
                user=request.user,
                status='paided',
            )

            item = Card_item.objects.create(
                card=order,
                product=product,
                quantity=quantity,
                review_available_at=hot_product_review_available_at(
                    product,
                    order,
                ),
            )

            product.count = available - quantity
            product.save(update_fields=['count'])

            company = product.company
            company.__class__.objects.filter(pk=company.pk).update(
                successful_orders=F('successful_orders') + 1,
            )

            notification_body = (
                f'Заказ №{order.order_number}. '
                f'{request.user.username} оформил заказ: {product.name}. '
                f'Кол-во: {quantity}. '
                f'Тел: {buyer_phone}'
            )

            sellers = list(
                OrgProf.objects
                .filter(company=company)
                .select_related('user')
            )

            for seller in sellers:
                Notification.objects.create(
                    user=seller.user,
                    type='order_created',
                    title='Новый заказ',
                    body=notification_body,
                    data={
                        'card_id': order.id,
                        'order_number': order.order_number,
                        'company_id': company.id,
                        'company_name': company.name,
                        'product_slug': product.slug,
                        'product_name': product.name,
                        'quantity': quantity,
                        'buyer_id': request.user.id,
                        'buyer_username': request.user.username,
                        'buyer_phone': buyer_phone,
                        'buyer_address': buyer_address,
                    },
                )

                push_data = {
                    'type': 'order_created',
                    'card_id': str(order.id),
                    'order_number': str(order.order_number),
                    'company_id': str(company.id),
                    'company_name': company.name,
                    'product_slug': product.slug,
                    'product_name': product.name,
                    'quantity': str(quantity),
                    'buyer_username': request.user.username,
                    'buyer_phone': buyer_phone,
                    'buyer_address': buyer_address,
                }

                transaction.on_commit(
                    lambda user=seller.user,
                           body=notification_body,
                           data=push_data: send_push_to_user(
                        user=user,
                        title='Новый заказ',
                        body=body,
                        data=data,
                    )
                )

            # HOT: review access and the reminder are scheduled for
            # exactly 2 hours after the paid order was created.
            transaction.on_commit(
                lambda created_order=order: create_review_reminder(
                    created_order
                )
            )

            remaining = product.count

        return Response(
            {
                'code': 'hot_reserved',
                'message': 'Товар успешно забронирован',
                'order_id': order.id,
                'order_number': order.order_number,
                'item_id': item.id,
                'product_slug': product.slug,
                'quantity': quantity,
                'remaining': remaining,
            },
            status=status.HTTP_201_CREATED,
        )
