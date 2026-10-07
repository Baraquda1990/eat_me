from math import radians, sin, cos, sqrt, atan2

from celery import shared_task
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from django.contrib.auth import get_user_model
from django.db.models import Q

from products.models import Products
from notifications.models import Notification, NotificationAlarm, NotificationBroadcast
from notifications.services import send_push_to_user, get_broadcast_recipient_queryset
from notifications.i18n import tr
from card.models import Card, Card_item
from profiles.models import OrgProf

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


def _review_reminder_exists(card):
    return Notification.objects.filter(
        user=card.user,
        type='review_reminder',
        data__card_id=card.id,
    ).exists()


def _review_states(card, company_id=None):
    # Reviews/reminders are HOT-only.
    # Local import avoids a module-level card -> notifications -> card cycle.
    from card.review_eligibility import (
        hot_company_ids_for_card,
        get_company_review_availability,
    )

    hot_company_ids = set(hot_company_ids_for_card(card))

    if company_id is not None:
        requested_company_id = int(company_id)
        if requested_company_id not in hot_company_ids:
            return []
        company_ids = [requested_company_id]
    else:
        company_ids = sorted(hot_company_ids)

    return [
        get_company_review_availability(card, current_company_id)
        for current_company_id in company_ids
    ]


def _next_review_reminder_eta(states, now=None):
    now = now or timezone.now()
    future_times = []

    for state in states:
        if state.get('can_review'):
            return now

        available_at = state.get('available_at')
        if available_at is not None and available_at > now:
            future_times.append(available_at)

    return min(future_times) if future_times else None


def _send_review_reminder_now(card, company_id=None):
    if not card.user or _review_reminder_exists(card):
        return False

    title = tr(card.user, 'review_reminder_title')
    body = tr(card.user, 'review_reminder_body')

    data = {
        'card_id': card.id,
    }
    if company_id is not None:
        data['company_id'] = int(company_id)

    Notification.objects.create(
        user=card.user,
        type='review_reminder',
        title=title,
        body=body,
        data=data,
    )

    send_push_to_user(
        user=card.user,
        title=title,
        body=body,
        data={
            'type': 'review_reminder',
            **data,
        },
    )
    return True


@shared_task
def send_review_reminder_when_available(card_id, company_id=None):
    card = (
        Card.objects
        .select_related('user')
        .filter(id=card_id, status='paided')
        .first()
    )
    if card is None or card.user is None or _review_reminder_exists(card):
        return

    states = _review_states(card, company_id=company_id)
    if not states:
        return

    now = timezone.now()

    if any(state.get('can_review') for state in states):
        _send_review_reminder_now(card, company_id=company_id)
        return

    eta = _next_review_reminder_eta(states, now=now)
    if eta is not None and eta > now:
        send_review_reminder_when_available.apply_async(
            args=[card.id, company_id],
            eta=eta,
        )


def create_review_reminder(card, company_id=None):
    """Send now or schedule a review reminder for a HOT purchase only.

    HOT: paid_at + 2 hours.
    Deals: no review and no review reminder.
    """
    if not card.user or _review_reminder_exists(card):
        return

    states = _review_states(card, company_id=company_id)
    if not states:
        return

    now = timezone.now()

    if any(state.get('can_review') for state in states):
        _send_review_reminder_now(card, company_id=company_id)
        return

    eta = _next_review_reminder_eta(states, now=now)
    if eta is None:
        # No HOT review window exists for this order/company.
        return

    if eta <= now:
        _send_review_reminder_now(card, company_id=company_id)
        return

    send_review_reminder_when_available.apply_async(
        args=[card.id, company_id],
        eta=eta,
    )


@shared_task
def check_product_alarm_matches(product_id):
    try:
        product = Products.objects.prefetch_related('tag').get(id=product_id)
    except Products.DoesNotExist:
        return

    if not product.is_available_for_sale():
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
            title=tr(user, 'favorite_store_title'),
            body=tr(
                user,
                'favorite_store_body',
                company=product.company.name,
                product=product.name,
            ),
            data={
                'product_slug': product.slug,
                'product_name': product.name,
                'company_slug': product.company.slug,
                'company_name': product.company.name,
            },
        )

    product_tag_ids = set(product.tag.values_list('id', flat=True))

    now = timezone.now()

    # Safety cleanup in addition to the exact ETA task: an expired alarm
    # must never keep matching products if a worker was restarted around
    # its deadline.
    NotificationAlarm.objects.filter(
        is_active=True,
    ).filter(
        Q(notify_until__lte=now)
        | Q(notify_until__isnull=True, notify_at__lte=now)
    ).update(is_active=False)

    alarms = NotificationAlarm.objects.filter(
        is_active=True,
        product_type=product.type,
        notify_at__lte=now,
        notify_until__gt=now,
    ).prefetch_related('tags', 'user')

    for alarm in alarms:
        alarm_tag_ids = set(alarm.tags.values_list('id', flat=True))

        if alarm_tag_ids and not product_tag_ids.intersection(alarm_tag_ids):
            continue

        if alarm.latitude is not None and alarm.longitude is not None:
            # Product publications may have their own map point (HOT pickup
            # point or Deals delivery-area center). Fall back to the company
            # coordinates for older products created before that feature.
            product_lat = product.location_latitude
            product_lng = product.location_longitude

            if product_lat is None or product_lng is None:
                product_lat = product.company.latitude
                product_lng = product.company.longitude

            if product_lat is None or product_lng is None:
                continue

            distance = distance_km(
                alarm.latitude,
                alarm.longitude,
                product_lat,
                product_lng,
            )

            if distance > float(alarm.radius_km):
                continue

            # Новое предложение рядом
            create_notification_once(
                user=alarm.user,
                type_='new_nearby_product',
                title=tr(alarm.user, 'nearby_title'),
                body=tr(
                    alarm.user,
                    'nearby_body',
                    product=product.name,
                ),
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

        alarm_title = tr(alarm.user, 'alarm_match_title')
        alarm_body = tr(
            alarm.user,
            'alarm_match_body',
            company=product.company.name,
            product=product.name,
        )

        Notification.objects.create(
            user=alarm.user,
            type='alarm_match',
            title=alarm_title,
            body=alarm_body,
            data={
                'product_slug': product.slug,
                'product_name': product.name,
                'company_slug': product.company.slug,
                'company_name': product.company.name,
            },
        )

        send_push_to_user(
            user=alarm.user,
            title=alarm_title,
            body=alarm_body,
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
            is_active=True,
        ).filter(
            Q(type=Products.Type.LONG)
            | Q(type=Products.Type.HOT, pickup_until__gt=timezone.now())
            | Q(
                type=Products.Type.HOT,
                pickup_until__isnull=True,
                active_until__gt=timezone.now(),
            )
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

        title = tr(user, 'recommendation_title')
        body = tr(
            user,
            'recommendation_body',
            product=product.name,
        )

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


@shared_task
def expire_hot_product(product_id, expected_deadline_iso):
    """
    Automatically remove a HOT product from sale at product.pickup_until.

    expected_deadline_iso protects against stale Celery ETA tasks after
    editing the pickup window.
    """
    try:
        product = Products.objects.select_related('company').get(id=product_id)
    except Products.DoesNotExist:
        return

    if product.type != Products.Type.HOT or not product.is_active:
        return

    deadline = product.pickup_until or product.active_until
    if deadline is None:
        return

    expected_deadline = parse_datetime(expected_deadline_iso)
    if expected_deadline is None:
        return

    if timezone.is_naive(expected_deadline):
        expected_deadline = timezone.make_aware(expected_deadline)

    # Ignore an old scheduled task after changing pickup_until.
    if abs((deadline - expected_deadline).total_seconds()) > 1:
        return

    if timezone.now() < deadline:
        return

    product.is_active = False
    product.inactive_reason = Products.InactiveReason.PICKUP_EXPIRED
    product.active_until = deadline
    product.save(
        update_fields=[
            'is_active',
            'inactive_reason',
            'active_until',
        ]
    )

    deadline_iso = deadline.isoformat()

    seller_links = OrgProf.objects.filter(
        company=product.company
    ).select_related('user')

    for seller_link in seller_links:
        user = seller_link.user
        title = tr(user, 'product_expired_title')
        body = tr(user, 'product_expired_body', product=product.name)

        already_exists = Notification.objects.filter(
            user=user,
            type='product_expired',
            data__product_slug=product.slug,
            data__pickup_until=deadline_iso,
        ).exists()

        if already_exists:
            continue

        Notification.objects.create(
            user=user,
            type='product_expired',
            title=title,
            body=body,
            data={
                'product_slug': product.slug,
                'product_name': product.name,
                'company_slug': product.company.slug,
                'company_name': product.company.name,
                'pickup_until': deadline_iso,
                # Compatibility for the current notification client.
                'pickup_deadline': deadline_iso,
                'reason': 'pickup_expired',
            },
        )

        send_push_to_user(
            user=user,
            title=title,
            body=body,
            data={
                'type': 'product_expired',
                'product_slug': product.slug,
                'company_slug': product.company.slug,
                'pickup_until': deadline_iso,
                'pickup_deadline': deadline_iso,
            },
        )

@shared_task
def expire_notification_alarm(alarm_id, expected_deadline_iso):
    """Deactivate one notification alarm at the end of its time window."""
    try:
        alarm = NotificationAlarm.objects.get(id=alarm_id)
    except NotificationAlarm.DoesNotExist:
        return

    if not alarm.is_active:
        return

    expected_deadline = parse_datetime(expected_deadline_iso)
    if expected_deadline is None:
        return
    if timezone.is_naive(expected_deadline):
        expected_deadline = timezone.make_aware(expected_deadline)

    deadline = alarm.notify_until or alarm.notify_at

    # Ignore a stale scheduled task if the stored deadline has changed.
    if abs((deadline - expected_deadline).total_seconds()) > 1:
        return

    if timezone.now() < deadline:
        expire_notification_alarm.apply_async(
            args=[alarm.id, deadline.isoformat()],
            eta=deadline,
        )
        return

    alarm.is_active = False
    alarm.save(update_fields=['is_active'])




@shared_task
def send_notification_broadcast(broadcast_id):
    """Fan out one admin campaign to its selected audience.

    The task is intentionally idempotent at the Notification-row level:
    rerunning a failed/pending campaign will not create duplicate in-app
    notifications for users that were already processed.
    """
    from django.db import transaction

    try:
        with transaction.atomic():
            broadcast = NotificationBroadcast.objects.select_for_update().get(
                id=broadcast_id
            )

            if broadcast.status == NotificationBroadcast.Status.COMPLETED:
                return {
                    'status': 'already_completed',
                    'broadcast_id': broadcast_id,
                }

            if broadcast.status == NotificationBroadcast.Status.SENDING:
                return {
                    'status': 'already_sending',
                    'broadcast_id': broadcast_id,
                }

            broadcast.status = NotificationBroadcast.Status.SENDING
            broadcast.error_message = ''
            broadcast.sent_at = None
            broadcast.save(
                update_fields=['status', 'error_message', 'sent_at']
            )

        recipients = get_broadcast_recipient_queryset(broadcast).order_by('id')
        recipients_count = recipients.count()
        NotificationBroadcast.objects.filter(id=broadcast_id).update(
            recipients_count=recipients_count
        )

        # The id is stored as a string so FCM data and JSON data use the same
        # representation on every platform.
        broadcast_key = str(broadcast_id)
        existing_user_ids = set(
            Notification.objects.filter(
                data__broadcast_id=broadcast_key,
            ).values_list('user_id', flat=True)
        )

        batch_size = 500
        pending_ids = []

        def process_batch(user_ids):
            if not user_ids:
                return

            users = list(User.objects.filter(id__in=user_ids).order_by('id'))
            notification_data = {
                **(broadcast.data or {}),
                'broadcast_id': broadcast_key,
                'broadcast_audience': broadcast.audience,
            }

            Notification.objects.bulk_create([
                Notification(
                    user=user,
                    type=broadcast.type,
                    title=broadcast.title,
                    body=broadcast.body,
                    data=dict(notification_data),
                    is_read=False,
                )
                for user in users
            ], batch_size=batch_size)

            push_data = {
                **notification_data,
                'type': broadcast.type,
            }

            for user in users:
                send_push_to_user(
                    user=user,
                    title=broadcast.title,
                    body=broadcast.body,
                    data=push_data,
                )

        for user_id in recipients.values_list('id', flat=True).iterator(
            chunk_size=batch_size
        ):
            if user_id in existing_user_ids:
                continue
            pending_ids.append(user_id)
            if len(pending_ids) >= batch_size:
                process_batch(pending_ids)
                pending_ids = []

        process_batch(pending_ids)

        created_count = Notification.objects.filter(
            data__broadcast_id=broadcast_key,
        ).count()

        NotificationBroadcast.objects.filter(id=broadcast_id).update(
            status=NotificationBroadcast.Status.COMPLETED,
            notifications_created=created_count,
            sent_at=timezone.now(),
            error_message='',
        )

        return {
            'status': 'completed',
            'broadcast_id': broadcast_id,
            'recipients_count': recipients_count,
            'notifications_created': created_count,
        }

    except NotificationBroadcast.DoesNotExist:
        return {
            'status': 'not_found',
            'broadcast_id': broadcast_id,
        }
    except Exception as exc:
        NotificationBroadcast.objects.filter(id=broadcast_id).update(
            status=NotificationBroadcast.Status.FAILED,
            error_message=str(exc)[:4000],
        )
        raise
