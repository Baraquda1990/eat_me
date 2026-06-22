from math import radians, sin, cos, sqrt, atan2

from celery import shared_task
from django.utils import timezone
from django.contrib.auth import get_user_model
from django.db.models import Q

from products.models import Products
from notifications.models import Notification, NotificationAlarm
from notifications.services import send_push_to_user
from card.models import Card, Card_item

User = get_user_model()


def distance_km(lat1, lon1, lat2, lon2):
    r = 6371

    lat1 = radians(float(lat1))
    lon1 = radians(float(lon1))
    lat2 = radians(float(lat2))
    lon2 = radians(float(lon2))

    dlat = lat2 - lat1
    dlon = lon2 - lon1

    a = (
        sin(dlat / 2) ** 2
        + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    )

    c = 2 * atan2(sqrt(a), sqrt(1 - a))

    return r * c


def create_notification_once(user, type_, title, body, data):
    exists = Notification.objects.filter(
        user=user,
        type=type_,
        data__product_slug=data.get('product_slug'),
    ).exists()

    if exists:
        return

    Notification.objects.create(
        user=user,
        type=type_,
        title=title,
        body=body,
        data=data,
    )

    send_push_to_user(
        user=user,
        title=title,
        body=body,
        data={
            'type': type_,
            **data,
        },
    )


def create_review_reminder(card):
    if not card.user:
        return

    exists = Notification.objects.filter(
        user=card.user,
        type='review_reminder',
        data__card_id=card.id,
    ).exists()

    if exists:
        return

    Notification.objects.create(
        user=card.user,
        type='review_reminder',
        title='Оцените заказ',
        body='Поделитесь впечатлениями о покупке',
        data={
            'card_id': card.id,
        },
    )

    send_push_to_user(
        user=card.user,
        title='Оцените заказ',
        body='Поделитесь впечатлениями о покупке',
        data={
            'type': 'review_reminder',
            'card_id': card.id,
        },
    )


@shared_task
def check_product_alarm_matches(product_id):
    try:
        product = Products.objects.prefetch_related('tag').get(id=product_id)
    except Products.DoesNotExist:
        return

    if product.count <= 0:
        return

    # ❤️ Любимый магазин: если пользователь уже покупал в этой компании
    favorite_user_ids = Card_item.objects.filter(
        card__status__in=['paid', 'paided', 'completed'],
        product__company=product.company,
        card__user__isnull=False,
    ).values_list('card__user_id', flat=True).distinct()

    for user_id in favorite_user_ids:
        user = User.objects.filter(id=user_id).first()
        if not user:
            continue

        create_notification_once(
            user=user,
            type_='favorite_store',
            title='Любимый магазин',
            body=f'{product.company.name} добавил новое предложение: {product.name}',
            data={
                'product_slug': product.slug,
                'product_name': product.name,
                'company_slug': product.company.slug,
                'company_name': product.company.name,
            },
        )

    product_tag_ids = set(product.tag.values_list('id', flat=True))

    alarms = NotificationAlarm.objects.filter(
        is_active=True,
        product_type=product.type,
        notify_at__lte=timezone.now(),
    ).prefetch_related('tags', 'user')

    for alarm in alarms:
        alarm_tag_ids = set(alarm.tags.values_list('id', flat=True))

        if alarm_tag_ids and not product_tag_ids.intersection(alarm_tag_ids):
            continue

        if alarm.latitude is not None and alarm.longitude is not None:
            company_lat = product.company.latitude
            company_lng = product.company.longitude

            if company_lat is None or company_lng is None:
                continue

            distance = distance_km(
                alarm.latitude,
                alarm.longitude,
                company_lat,
                company_lng,
            )

            if distance > float(alarm.radius_km):
                continue

            # Новое предложение рядом
            create_notification_once(
                user=alarm.user,
                type_='new_nearby_product',
                title='Новое предложение рядом',
                body=f'Рядом появилось предложение: {product.name}',
                data={
                    'product_slug': product.slug,
                    'product_name': product.name,
                    'company_slug': product.company.slug,
                    'company_name': product.company.name,
                },
            )

        already_exists = Notification.objects.filter(
            user=alarm.user,
            type='alarm_match',
            data__product_slug=product.slug,
        ).exists()

        if already_exists:
            continue

        Notification.objects.create(
            user=alarm.user,
            type='alarm_match',
            title='Найдено предложение',
            body=f'{product.company.name} добавил товар "{product.name}"',
            data={
                'product_slug': product.slug,
                'product_name': product.name,
                'company_slug': product.company.slug,
                'company_name': product.company.name,
            },
        )

        send_push_to_user(
            user=alarm.user,
            title='Найдено предложение',
            body=f'{product.company.name} добавил товар "{product.name}"',
            data={
                'type': 'alarm_match',
                'product_slug': product.slug,
            },
        )


@shared_task
def create_recommendations_for_users():
    from django.contrib.auth import get_user_model
    from card.models import Card_item
    from products.models import Products

    User = get_user_model()

    users = User.objects.filter(
        card__status__in=['paid', 'paided', 'completed']
    ).distinct()

    for user in users:
        bought_items = Card_item.objects.filter(
            card__user=user,
            card__status__in=['paid', 'paided', 'completed'],
            product__isnull=False,
        ).select_related('product', 'product__company').prefetch_related('product__tag')

        tag_ids = set()
        company_ids = set()

        for item in bought_items:
            company_ids.add(item.product.company_id)
            tag_ids.update(item.product.tag.values_list('id', flat=True))

        if not tag_ids and not company_ids:
            continue

        recommendation_filter = Q()

        if tag_ids:
            recommendation_filter |= Q(tag__id__in=tag_ids)

        if company_ids:
            recommendation_filter |= Q(company_id__in=company_ids)

        if not recommendation_filter:
            continue

        products = Products.objects.filter(
            recommendation_filter,
            count__gt=0,
        ).exclude(
            card_item__card__user=user
        ).select_related(
            'company'
        ).prefetch_related(
            'tag'
        ).distinct()

        product = products.order_by('-created').first()

        if not product:
            continue

        already_exists = Notification.objects.filter(
            user=user,
            type='recommendation',
            data__product_slug=product.slug,
        ).exists()

        if already_exists:
            continue

        title = 'Рекомендация для вас'
        body = f'Мы нашли предложение, которое может вам понравиться: {product.name}'

        Notification.objects.create(
            user=user,
            type='recommendation',
            title=title,
            body=body,
            data={
                'product_slug': product.slug,
                'product_name': product.name,
                'company_slug': product.company.slug,
                'company_name': product.company.name,
            },
        )

        send_push_to_user(
            user=user,
            title=title,
            body=body,
            data={
                'type': 'recommendation',
                'product_slug': product.slug,
            },
        )
