
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from products.models import Products
from profiles.models import OrgProf

from .models import Card_item


class SellerDeliveriesApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        company_ids = OrgProf.objects.filter(
            user=request.user,
        ).values_list('company_id', flat=True)

        if not company_ids:
            return Response([])

        items = (
            Card_item.objects.filter(
                card__status='paided',
                product__isnull=False,
                product__company_id__in=company_ids,
                product__type=Products.Type.LONG,
            )
            .exclude(
                delivery_status=Card_item.DeliveryStatus.DELIVERED,
            )
            .select_related(
                'card',
                'card__user',
                'card__user__profile',
                'product',
                'product__company',
            )
            .order_by('-card__paid_at', '-card__id', '-id')
        )

        result = []

        for item in items:
            product = item.product
            card = item.card
            buyer = card.user
            buyer_profile = getattr(buyer, 'profile', None)

            buyer_phone = (
                card.buyer_phone_snapshot
                or (
                    buyer_profile.phone
                    if buyer_profile and buyer_profile.phone
                    else ''
                )
            )
            buyer_address = (
                card.buyer_address_snapshot
                or (
                    buyer_profile.address
                    if buyer_profile and buyer_profile.address
                    else ''
                )
            )

            image_url = ''
            try:
                if product.image:
                    image_url = product.image.url
            except Exception:
                image_url = ''

            result.append({
                'id': item.id,
                'card_id': card.id,
                'order_number': card.order_number,
                'company_id': product.company_id,
                'company_name': product.company.name,
                'created': card.paid_at or card.created,
                'buyer': buyer.username if buyer else '',
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
                'product_name': product.name,
                'product_slug': product.slug,
                'product_image_url': image_url,
                'product_type': product.type,
                'package_quantity': product.package_quantity,
                'delivery_days': product.delivery_days,
                'quantity': item.quantity,
                'price': float(product.get_discount_price),
                'full_price': float(product.price or 0),
                'total': float(item.price_by_quantity),
                'delivery_status': item.delivery_status,
            })

        return Response(result)


class SellerDeliveryStatusApi(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, item_id):
        value = (
            request.data.get('delivery_status')
            or request.data.get('status')
            or ''
        ).strip().lower()

        valid_statuses = {
            Card_item.DeliveryStatus.PROCESSING,
            Card_item.DeliveryStatus.DELIVERING,
            Card_item.DeliveryStatus.DELIVERED,
        }

        if value not in valid_statuses:
            return Response(
                {
                    'error': 'Недопустимый статус доставки.',
                    'allowed': sorted(valid_statuses),
                },
                status=400,
            )

        try:
            item = Card_item.objects.select_related(
                'card',
                'product',
                'product__company',
            ).get(
                id=item_id,
                card__status='paided',
                product__isnull=False,
                product__type=Products.Type.LONG,
            )
        except Card_item.DoesNotExist:
            return Response(
                {'error': 'Заказ доставки не найден.'},
                status=404,
            )

        seller_has_company = OrgProf.objects.filter(
            user=request.user,
            company_id=item.product.company_id,
        ).exists()

        if not seller_has_company:
            return Response(
                {'error': 'Нет доступа к этому заказу.'},
                status=403,
            )

        update_fields = ['delivery_status']
        item.delivery_status = value

        # Reviews are HOT-only. Delivery state for Deals no longer creates,
        # opens, revokes, or schedules any review window.
        item.save(update_fields=update_fields)

        return Response({
            'id': item.id,
            'delivery_status': item.delivery_status,
            'review_available_at': (
                item.review_available_at.isoformat()
                if item.review_available_at
                else None
            ),
        })
