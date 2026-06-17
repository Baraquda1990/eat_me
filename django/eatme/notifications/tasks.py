from math import radians, sin, cos, sqrt, atan2

from celery import shared_task
from django.utils import timezone

from products.models import Products
from notifications.models import Notification, NotificationAlarm
from notifications.services import send_push_to_user


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


@shared_task
def check_product_alarm_matches(product_id):
    try:
        product = Products.objects.prefetch_related('tag').get(id=product_id)
    except Products.DoesNotExist:
        return

    if product.count <= 0:
        return

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
