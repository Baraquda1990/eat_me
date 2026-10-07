from django.utils import timezone

from notifications.tasks import expire_hot_product

from .models import Products


def _pickup_deadline(product):
    if product.type != Products.Type.HOT:
        return None

    # pickup_until is the source of truth.
    # active_until is kept only for backward compatibility.
    return product.pickup_until or product.active_until


def schedule_product_expiration(product):
    deadline = _pickup_deadline(product)

    if (
        product.type != Products.Type.HOT
        or not product.is_active
        or deadline is None
    ):
        return

    expire_hot_product.apply_async(
        args=[product.id, deadline.isoformat()],
        eta=deadline,
    )


def activate_product(product):
    if product.count <= 0:
        if product.dine_in_only:
            raise ValueError(
                'Нельзя вернуть в продажу предложение с нулевым остатком '
                'доступных мест.'
            )
        raise ValueError(
            'Нельзя вернуть в продажу товар с нулевым остатком.'
        )

    if product.type == Products.Type.HOT:
        if product.pickup_from is None or product.pickup_until is None:
            raise ValueError(
                'Укажите время получения Hot-товара.'
            )

        if product.pickup_until <= timezone.now():
            raise ValueError(
                'Время получения истекло. '
                'Укажите новое время получения товара.'
            )

        product.active_until = product.pickup_until
    else:
        product.active_until = None
        product.pickup_from = None
        product.pickup_until = None

    product.is_active = True
    product.inactive_reason = ''

    product.save(
        update_fields=[
            'is_active',
            'inactive_reason',
            'active_until',
            'pickup_from',
            'pickup_until',
        ]
    )

    schedule_product_expiration(product)
    return product


def pause_product(product):
    product.is_active = False
    product.inactive_reason = Products.InactiveReason.MANUAL

    # Pickup window must stay unchanged while the product is paused.
    product.save(
        update_fields=[
            'is_active',
            'inactive_reason',
        ]
    )
    return product


def ensure_product_expiration_schedule(product):
    """Synchronize Celery expiration with pickup_until."""

    if not product.is_active:
        return product

    if product.type != Products.Type.HOT:
        changed_fields = []

        if product.active_until is not None:
            product.active_until = None
            changed_fields.append('active_until')

        if product.pickup_from is not None:
            product.pickup_from = None
            changed_fields.append('pickup_from')

        if product.pickup_until is not None:
            product.pickup_until = None
            changed_fields.append('pickup_until')

        if changed_fields:
            product.save(update_fields=changed_fields)

        return product

    deadline = product.pickup_until or product.active_until

    if deadline is None:
        return product

    if product.active_until != deadline:
        product.active_until = deadline
        product.save(update_fields=['active_until'])

    if deadline <= timezone.now():
        expire_hot_product.delay(
            product.id,
            deadline.isoformat(),
        )
        return product

    schedule_product_expiration(product)
    return product
