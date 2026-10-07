import hashlib
import logging
from decimal import Decimal
from pathlib import PurePosixPath
from urllib.parse import urlparse

from django.conf import settings
from django.core.files.base import File
from django.core.files.storage import default_storage
from django.utils import timezone

try:
    from core.image_processing import product_variant_name
except Exception:
    product_variant_name = None


logger = logging.getLogger(__name__)

SNAPSHOT_VERSION = 2
ARCHIVE_ROOT = 'order_snapshots'


def _string(value):
    if value is None:
        return ''
    return str(value)


def _iso(value):
    if value is None:
        return None
    isoformat = getattr(value, 'isoformat', None)
    if callable(isoformat):
        return isoformat()
    return str(value)


def _decimal_value(value):
    if callable(value):
        value = value()
    if value is None:
        return Decimal('0')
    try:
        return Decimal(str(value))
    except Exception:
        return Decimal('0')


def _json_decimal(value):
    return str(_decimal_value(value))


def _image_value(obj, attr_name):
    value = getattr(obj, attr_name, '')
    if callable(value):
        try:
            value = value()
        except Exception:
            value = ''
    return _string(value)


def _company_snapshot(company):
    if company is None:
        return {}

    return {
        'id': getattr(company, 'id', 0) or 0,
        'name': _string(getattr(company, 'name', '')),
        'slug': _string(getattr(company, 'slug', '')),
        'image_url': _image_value(company, 'image_url'),
        'address': _string(getattr(company, 'address', '')),
        'phone': _string(getattr(company, 'phone', '')),
        'description': _string(getattr(company, 'description', '')),
        'latitude': _string(getattr(company, 'latitude', '')),
        'longitude': _string(getattr(company, 'longitude', '')),
        'open_time': _string(getattr(company, 'open_time', '')),
        'close_time': _string(getattr(company, 'close_time', '')),
        'rating': _string(getattr(company, 'rating', 0) or 0),
        'reviews_count': int(getattr(company, 'reviews_count', 0) or 0),
        'successful_orders': int(getattr(company, 'successful_orders', 0) or 0),
        'company_score': int(getattr(company, 'company_score', 0) or 0),
        'avg_quality': _string(getattr(company, 'avg_quality', 0) or 0),
        'avg_value': _string(getattr(company, 'avg_value', 0) or 0),
        'avg_description_match': _string(
            getattr(company, 'avg_description_match', 0) or 0
        ),
        'avg_service': _string(getattr(company, 'avg_service', 0) or 0),
        'instagram': _string(getattr(company, 'instagram', '')),
        'facebook': _string(getattr(company, 'facebook', '')),
    }


def _tag_snapshots(product):
    manager = getattr(product, 'tag', None)
    if manager is None:
        return []

    try:
        tags = manager.all()
    except Exception:
        return []

    result = []
    for tag in tags:
        result.append({
            'id': getattr(tag, 'id', 0) or 0,
            'name': _string(getattr(tag, 'name', '')),
            'slug': _string(getattr(tag, 'slug', '')),
            'image_url': _image_value(tag, 'image_url'),
        })
    return result


def _safe_extension(name):
    suffix = PurePosixPath(str(name or '')).suffix.lower()
    if suffix in {'.jpg', '.jpeg', '.png', '.webp'}:
        return suffix
    return '.webp'


def _hash_storage_file(storage, source_name):
    digest = hashlib.sha256()

    with storage.open(source_name, 'rb') as source:
        while True:
            chunk = source.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)

    return digest.hexdigest()


def _archive_storage_file(storage, source_name):
    """
    Copy one image into immutable order_snapshots storage.

    The filename is content-addressed (SHA-256), so the same source image bought
    many times is physically stored only once. This avoids one copy per order.
    """
    if not source_name:
        return ''

    source_name = str(source_name).lstrip('/')

    if source_name.startswith(f'{ARCHIVE_ROOT}/'):
        try:
            return storage.url(source_name)
        except Exception:
            return ''

    digest = _hash_storage_file(storage, source_name)
    ext = _safe_extension(source_name)
    now = timezone.now()

    archive_name = (
        f'{ARCHIVE_ROOT}/{now.year:04d}/{now.month:02d}/'
        f'{digest[:2]}/{digest}{ext}'
    )

    if not storage.exists(archive_name):
        with storage.open(source_name, 'rb') as source:
            saved_name = storage.save(
                archive_name,
                File(source, name=PurePosixPath(source_name).name),
            )
    else:
        saved_name = archive_name

    return storage.url(saved_name)


def _preferred_product_image_source(product):
    """
    Prefer the 640px product variant for historical order screens.
    Fall back to the original ImageField file when the variant is unavailable.
    """
    image = getattr(product, 'image', None)
    image_name = _string(getattr(image, 'name', '')).lstrip('/')

    if not image or not image_name:
        return None, ''

    storage = getattr(image, 'storage', None) or default_storage
    candidates = []

    if product_variant_name is not None:
        try:
            card_name = product_variant_name(image_name, '640')
            if card_name:
                candidates.append(str(card_name).lstrip('/'))
        except Exception:
            pass

    candidates.append(image_name)

    for candidate in candidates:
        try:
            if storage.exists(candidate):
                return storage, candidate
        except Exception:
            # Some custom storages have an unreliable exists() implementation.
            try:
                with storage.open(candidate, 'rb'):
                    pass
                return storage, candidate
            except Exception:
                continue

    return storage, ''


def archive_product_image(product):
    """
    Archive the current product image and return its permanent URL.

    Image snapshot failure never blocks checkout. The textual/product snapshot
    is still saved, while image_url falls back to the current product URL.
    """
    try:
        storage, source_name = _preferred_product_image_source(product)
        if storage is None or not source_name:
            return ''

        return _archive_storage_file(storage, source_name)
    except Exception:
        logger.exception(
            'Could not archive image snapshot for product id=%s slug=%s',
            getattr(product, 'id', None),
            getattr(product, 'slug', ''),
        )
        return ''


def _storage_name_candidates_from_url(url):
    """
    Convert public URLs such as:
      https://media.appsosa.am/uploads/products/file_640.webp
      /media/uploads/products/file_640.webp
    into plausible Django storage names.
    """
    value = _string(url).strip()
    if not value:
        return []

    parsed = urlparse(value)
    path = (parsed.path if parsed.scheme or parsed.netloc else value).split('?', 1)[0]
    path = path.lstrip('/')

    candidates = []

    def add(candidate):
        candidate = _string(candidate).strip().lstrip('/')
        if candidate and candidate not in candidates:
            candidates.append(candidate)

    add(path)

    media_url = _string(getattr(settings, 'MEDIA_URL', '')).strip()
    if media_url:
        media_path = urlparse(media_url).path.lstrip('/')
        if media_path and path.startswith(media_path):
            add(path[len(media_path):].lstrip('/'))

    if path.startswith('media/'):
        add(path[len('media/'):])

    marker = 'uploads/'
    if marker in path:
        add(path[path.index(marker):])

    return candidates


def _storage_for_item(item):
    product = getattr(item, 'product', None)
    image = getattr(product, 'image', None) if product is not None else None
    return getattr(image, 'storage', None) or default_storage


def archive_existing_item_snapshot_image(item):
    """
    Archive the image referenced by an ALREADY EXISTING product_snapshot.

    Important: this intentionally does not silently replace a historical image
    with the current live product image. If the old URL cannot be resolved in
    storage, the existing URL is left unchanged.

    Returns one of:
      archived, already_archived, no_snapshot, no_image, source_missing, failed
    """
    snapshot = dict(item.product_snapshot or {})
    if not snapshot:
        return 'no_snapshot'

    image_urls = [
        _string(snapshot.get('image_card_url')).strip(),
        _string(snapshot.get('image_url')).strip(),
        _string(snapshot.get('image_thumb_url')).strip(),
    ]
    image_urls = [value for value in image_urls if value]

    if not image_urls:
        return 'no_image'

    for value in image_urls:
        if f'/{ARCHIVE_ROOT}/' in value or value.startswith(f'{ARCHIVE_ROOT}/'):
            snapshot['_snapshot_version'] = SNAPSHOT_VERSION
            snapshot['_image_snapshot_archived'] = True
            if snapshot != item.product_snapshot:
                item.product_snapshot = snapshot
                item.save(update_fields=['product_snapshot'])
            return 'already_archived'

    storage = _storage_for_item(item)

    try:
        source_name = ''
        source_url = ''

        for image_url in image_urls:
            for candidate in _storage_name_candidates_from_url(image_url):
                try:
                    exists = storage.exists(candidate)
                except Exception:
                    exists = False

                if exists:
                    source_name = candidate
                    source_url = image_url
                    break

            if source_name:
                break

        if not source_name:
            return 'source_missing'

        archive_url = _archive_storage_file(storage, source_name)
        if not archive_url:
            return 'failed'

        snapshot.setdefault('_image_source_url', source_url)
        snapshot['image_url'] = archive_url
        snapshot['image_card_url'] = archive_url
        snapshot['image_thumb_url'] = archive_url
        snapshot['_snapshot_version'] = SNAPSHOT_VERSION
        snapshot['_image_snapshot_archived'] = True

        item.product_snapshot = snapshot
        item.save(update_fields=['product_snapshot'])
        return 'archived'

    except Exception:
        logger.exception(
            'Could not archive existing order image for Card_item id=%s',
            getattr(item, 'id', None),
        )
        return 'failed'


def build_product_snapshot(product):
    """
    Build an immutable JSON-safe representation of the product at purchase time.

    Field names intentionally match ProductsListSerializer / Flutter Product.fromJson,
    so past-orders can keep using the existing Product model.

    Snapshot v2 additionally archives ONE immutable 640px-ish product image.
    """
    company = getattr(product, 'company', None)
    discounted = _decimal_value(getattr(product, 'get_discount_price', 0))

    live_image_url = _image_value(product, 'image_url')
    live_card_url = _image_value(product, 'image_card_url')
    live_thumb_url = _image_value(product, 'image_thumb_url')

    archived_image_url = archive_product_image(product)

    display_image_url = archived_image_url or live_image_url
    display_card_url = archived_image_url or live_card_url or live_image_url
    display_thumb_url = archived_image_url or live_thumb_url or live_image_url

    return {
        '_snapshot_version': SNAPSHOT_VERSION,
        '_image_snapshot_archived': bool(archived_image_url),
        '_image_source_url': live_card_url or live_image_url or live_thumb_url,
        'name': _string(getattr(product, 'name', '')),
        'image_url': display_image_url,
        'image_card_url': display_card_url,
        'image_thumb_url': display_thumb_url,
        'slug': _string(getattr(product, 'slug', '')),
        'description': _string(getattr(product, 'description', '')),
        'price': _json_decimal(getattr(product, 'price', 0)),
        'get_discount_price': str(discounted),
        'discount': int(getattr(product, 'discount', 0) or 0),
        'type': _string(getattr(product, 'type', '')),
        'company': _company_snapshot(company),
        'tag': _tag_snapshots(product),
        # Raw stock at the instant of purchase. CardItemSerializer returns a
        # read-only display copy with count=0 to avoid re-buying from history.
        'count': int(getattr(product, 'count', 0) or 0),
        'sold_count': int(getattr(product, 'sold_count', 0) or 0),
        'views_count': int(getattr(product, 'views_count', 0) or 0),
        'shares_count': int(getattr(product, 'shares_count', 0) or 0),
        'pickup_deadline': _iso(
            getattr(product, 'pickup_deadline', None)
            or getattr(product, 'pickup_until', None)
            or getattr(product, 'active_until', None)
        ),
        'pickup_from': _iso(getattr(product, 'pickup_from', None)),
        'pickup_until': _iso(getattr(product, 'pickup_until', None)),
        'is_active': bool(getattr(product, 'is_active', False)),
        'inactive_reason': _string(getattr(product, 'inactive_reason', '')),
        'active_until': _iso(getattr(product, 'active_until', None)),
        'package_quantity': _string(getattr(product, 'package_quantity', '')),
        'weight': _string(getattr(product, 'weight', '')),
        'delivery_type': _string(getattr(product, 'delivery_type', '')),
        'delivery_days': getattr(product, 'delivery_days', None),
        'delivery_radius_km': getattr(product, 'delivery_radius_km', None),
        'expiration_date': _iso(getattr(product, 'expiration_date', None)),
        'can_use_until': _iso(getattr(product, 'can_use_until', None)),
        'is_promoted': bool(getattr(product, 'is_promoted', False)),
        'promotion_until': _iso(getattr(product, 'promotion_until', None)),
    }


def capture_item_snapshot(item, *, force=False):
    product = item.product
    if product is None:
        return False

    if item.product_snapshot and not force:
        return False

    snapshot = build_product_snapshot(product)
    unit_price = _decimal_value(getattr(product, 'get_discount_price', 0))
    company = getattr(product, 'company', None)

    item.product_snapshot = snapshot
    item.unit_price_snapshot = unit_price
    item.company_id_snapshot = getattr(company, 'id', None)
    item.product_slug_snapshot = _string(getattr(product, 'slug', ''))
    item.product_type_snapshot = _string(getattr(product, 'type', ''))
    item.save(update_fields=[
        'product_snapshot',
        'unit_price_snapshot',
        'company_id_snapshot',
        'product_slug_snapshot',
        'product_type_snapshot',
    ])
    return True


def capture_card_snapshot(card, *, user=None, force=False):
    """Capture buyer contact + all product snapshots before the order is finalized."""
    buyer = user or getattr(card, 'user', None)

    if buyer is not None and (force or not card.buyer_username_snapshot):
        profile = getattr(buyer, 'profile', None)
        card.buyer_username_snapshot = _string(getattr(buyer, 'username', ''))
        card.buyer_phone_snapshot = _string(
            getattr(profile, 'phone', '') if profile else ''
        )
        card.buyer_address_snapshot = _string(
            getattr(profile, 'address', '') if profile else ''
        )
        card.buyer_house_number_snapshot = _string(
            getattr(profile, 'house_number', '') if profile else ''
        )
        card.buyer_floor_snapshot = _string(
            getattr(profile, 'floor', '') if profile else ''
        )
        card.buyer_delivery_latitude_snapshot = (
            getattr(profile, 'delivery_latitude', None)
            if profile else None
        )
        card.buyer_delivery_longitude_snapshot = (
            getattr(profile, 'delivery_longitude', None)
            if profile else None
        )
        card.buyer_delivery_additional_info_snapshot = _string(
            getattr(profile, 'delivery_additional_info', '')
            if profile else ''
        )
        card.save(update_fields=[
            'buyer_username_snapshot',
            'buyer_phone_snapshot',
            'buyer_address_snapshot',
            'buyer_house_number_snapshot',
            'buyer_floor_snapshot',
            'buyer_delivery_latitude_snapshot',
            'buyer_delivery_longitude_snapshot',
            'buyer_delivery_additional_info_snapshot',
        ])

    changed = 0
    items = card.card_item.select_related('product', 'product__company').prefetch_related(
        'product__tag'
    )
    for item in items:
        if capture_item_snapshot(item, force=force):
            changed += 1
    return changed
