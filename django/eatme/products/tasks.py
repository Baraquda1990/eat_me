from datetime import datetime, time, timedelta
from zoneinfo import ZoneInfo

from celery import shared_task
from django.db import transaction
from django.utils import timezone

from notifications.tasks import check_product_alarm_matches

from .models import Products
from .services import activate_product


def _deals_expiration_eta(expiration_date):
    """Hide a Deals product at 00:00 on the day after expiration_date."""
    tz = ZoneInfo('Asia/Yerevan')
    return datetime.combine(
        expiration_date + timedelta(days=1),
        time.min,
        tzinfo=tz,
    )


def schedule_deals_expiration(product):
    """
    Schedule exact expiration for a Deals product.

    Stale ETA tasks are safe because expire_deals_product checks the date that
    was current when the task was scheduled.
    """
    if product.type != Products.Type.LONG or product.expiration_date is None:
        return

    expire_deals_product.apply_async(
        args=[product.id, product.expiration_date.isoformat()],
        eta=_deals_expiration_eta(product.expiration_date),
    )


@shared_task
def expire_deals_product(product_id, expected_expiration_date_iso):
    try:
        product = Products.objects.get(id=product_id)
    except Products.DoesNotExist:
        return {'status': 'missing'}

    if product.type != Products.Type.LONG or product.expiration_date is None:
        return {'status': 'not_deals_or_no_date'}

    if product.expiration_date.isoformat() != expected_expiration_date_iso:
        return {'status': 'stale_task'}

    # The product is valid through the expiration date itself.
    if timezone.localdate() <= product.expiration_date:
        expire_deals_product.apply_async(
            args=[product.id, expected_expiration_date_iso],
            eta=_deals_expiration_eta(product.expiration_date),
        )
        return {'status': 'rescheduled'}

    update_fields = []

    if product.is_active:
        product.is_active = False
        update_fields.append('is_active')

    if product.inactive_reason != Products.InactiveReason.EXPIRATION_EXPIRED:
        product.inactive_reason = Products.InactiveReason.EXPIRATION_EXPIRED
        update_fields.append('inactive_reason')

    if product.publication_status == Products.PublicationStatus.SCHEDULED:
        # Prevent a stale scheduled-publication task from resurrecting an
        # already expired product later.
        product.publication_status = Products.PublicationStatus.DRAFT
        update_fields.append('publication_status')

    if update_fields:
        product.save(update_fields=update_fields)

    return {'status': 'expired', 'product_id': product.id}


@shared_task
def expire_due_deals_products():
    """Fallback scan. Run periodically from Celery Beat (for example hourly)."""
    today = timezone.localdate()
    product_ids = list(
        Products.objects.filter(
            type=Products.Type.LONG,
            expiration_date__isnull=False,
            expiration_date__lt=today,
        ).exclude(
            inactive_reason=Products.InactiveReason.EXPIRATION_EXPIRED,
        ).values_list('id', flat=True)[:1000]
    )

    for product_id in product_ids:
        product = Products.objects.filter(id=product_id).only(
            'id', 'expiration_date'
        ).first()
        if product is not None and product.expiration_date is not None:
            expire_deals_product.delay(
                product.id,
                product.expiration_date.isoformat(),
            )

    return {'queued': len(product_ids)}


@shared_task
def publish_scheduled_product(product_id):
    """
    Publish one scheduled product when its publish_at moment is reached.

    The task is idempotent: duplicate Celery delivery is safe.
    """
    with transaction.atomic():
        try:
            product = (
                Products.objects
                .select_for_update()
                .select_related('company')
                .get(id=product_id)
            )
        except Products.DoesNotExist:
            return {'status': 'missing'}

        if product.publication_status != Products.PublicationStatus.SCHEDULED:
            return {'status': 'already_processed'}

        now = timezone.now()

        if product.publish_at is None:
            return {'status': 'no_publish_at'}

        if product.publish_at > now:
            # Can happen if the task was delivered early.
            publish_scheduled_product.apply_async(
                args=[product.id],
                eta=product.publish_at,
            )
            return {'status': 'rescheduled'}

        # HOT must still have a valid pickup window when publication happens.
        if (
            product.type == Products.Type.HOT
            and (
                product.pickup_until is None
                or product.pickup_until <= now
            )
        ):
            product.publication_status = Products.PublicationStatus.DRAFT
            product.is_active = False
            product.inactive_reason = Products.InactiveReason.PICKUP_EXPIRED
            product.save(
                update_fields=[
                    'publication_status',
                    'is_active',
                    'inactive_reason',
                ]
            )
            return {'status': 'pickup_expired'}

        product.publication_status = Products.PublicationStatus.PUBLISHED
        product.published_at = now
        product.inactive_reason = ''
        product.save(
            update_fields=[
                'publication_status',
                'published_at',
                'inactive_reason',
            ]
        )

        # Existing activation logic remains the single source of truth
        # for is_active / HOT expiration scheduling.
        activate_product(product)
        schedule_deals_expiration(product)

        transaction.on_commit(
            lambda: check_product_alarm_matches.delay(product.id)
        )

    return {'status': 'published', 'product_id': product_id}


@shared_task
def publish_due_products():
    """
    Fallback scanner for scheduled products.

    Run from Celery Beat every minute. This guarantees publication even if an
    ETA task was lost because of worker restart or a long Redis visibility
    timeout.
    """
    now = timezone.now()

    product_ids = list(
        Products.objects.filter(
            publication_status=Products.PublicationStatus.SCHEDULED,
            publish_at__isnull=False,
            publish_at__lte=now,
        ).values_list('id', flat=True)[:500]
    )

    for product_id in product_ids:
        publish_scheduled_product.delay(product_id)

    return {'queued': len(product_ids)}
