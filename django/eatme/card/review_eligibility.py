from datetime import timedelta

from django.utils import timezone
from django.utils.dateparse import parse_datetime

from .models import Card_item


# Reviews are a HOT-only feature.
HOT_REVIEW_DELAY = timedelta(hours=2)


def _aware_datetime(value):
    if value is None:
        return None

    if hasattr(value, 'tzinfo'):
        result = value
    else:
        raw = str(value).strip()
        if not raw:
            return None
        result = parse_datetime(raw)
        if result is None:
            return None

    if timezone.is_naive(result):
        result = timezone.make_aware(result, timezone.get_current_timezone())

    return result


def company_id_for_item(item):
    company_id = getattr(item, 'company_id_snapshot', None)
    if company_id:
        return int(company_id)

    product = getattr(item, 'product', None)
    if product is not None and getattr(product, 'company_id', None):
        return int(product.company_id)

    return None


def _product_type_for_item(item):
    return str(
        getattr(item, 'snapshot_product_type', '') or ''
    ).strip().lower()


def _is_hot_item(item):
    return _product_type_for_item(item) == 'hot'


def company_ids_for_card(card):
    """All companies in the order.

    Kept for order/business logic that is not related to reviews.
    """
    result = set()
    items = card.card_item.select_related('product', 'product__company').all()

    for item in items:
        company_id = company_id_for_item(item)
        if company_id:
            result.add(company_id)

    return sorted(result)


def hot_company_ids_for_card(card):
    """Companies that have at least one purchased HOT item in this order."""
    result = set()
    items = card.card_item.select_related('product', 'product__company').all()

    for item in items:
        if not _is_hot_item(item):
            continue

        company_id = company_id_for_item(item)
        if company_id:
            result.add(company_id)

    return sorted(result)


def company_name_for_card(card, company_id):
    items = card.card_item.select_related('product', 'product__company').all()

    for item in items:
        if company_id_for_item(item) != int(company_id):
            continue

        name = str(getattr(item, 'snapshot_company_name', '') or '').strip()
        if name:
            return name

    return ''


def hot_product_review_available_at(product, card):
    # The HOT review delay starts from the real purchase/payment time.
    order_time = _aware_datetime(getattr(card, 'paid_at', None))
    if order_time is None:
        order_time = _aware_datetime(getattr(card, 'order_datetime', None))
    if order_time is None:
        order_time = timezone.now()

    return order_time + HOT_REVIEW_DELAY


def review_available_at_for_item(item):
    # Deals/long products never become reviewable.
    if not _is_hot_item(item):
        return None

    stored = _aware_datetime(getattr(item, 'review_available_at', None))
    if stored is not None:
        return stored

    return hot_product_review_available_at(
        getattr(item, 'product', None),
        item.card,
    )


def get_company_review_availability(card, company_id, now=None):
    company_id = int(company_id)
    now = _aware_datetime(now) or timezone.now()

    all_company_items = [
        item
        for item in card.card_item.select_related(
            'product',
            'product__company',
        ).all()
        if company_id_for_item(item) == company_id
    ]

    if not all_company_items:
        return {
            'company_id': company_id,
            'can_review': False,
            'available_at': None,
            'reason': 'not_in_order',
        }

    hot_items = [
        item for item in all_company_items
        if _is_hot_item(item)
    ]

    if not hot_items:
        return {
            'company_id': company_id,
            'can_review': False,
            'available_at': None,
            'reason': 'hot_only',
        }

    available_times = [
        review_available_at_for_item(item)
        for item in hot_items
    ]
    available_times = [
        value for value in available_times
        if value is not None
    ]

    if not available_times:
        return {
            'company_id': company_id,
            'can_review': False,
            'available_at': None,
            'reason': 'waiting_delay',
        }

    # One company receives one review per order. If an order contains several
    # HOT items from the same company, wait until all of their review windows
    # are open (normally the same paid_at + 2h moment).
    available_at = max(available_times)
    can_review = now >= available_at

    return {
        'company_id': company_id,
        'can_review': can_review,
        'available_at': available_at,
        'reason': 'available' if can_review else 'waiting_delay',
    }


def serialize_review_availability(card):
    """Expose review availability only for HOT companies.

    Deals companies are intentionally absent from this list, so clients must
    not render them in the "Rate" flow.
    """
    result = []

    for company_id in hot_company_ids_for_card(card):
        state = get_company_review_availability(card, company_id)
        available_at = state.get('available_at')

        result.append({
            'company_id': company_id,
            'can_review': bool(state.get('can_review')),
            'available_at': (
                available_at.isoformat()
                if available_at
                else None
            ),
            'reason': state.get('reason') or '',
        })

    return result
