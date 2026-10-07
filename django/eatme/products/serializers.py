from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from rest_framework import serializers
from django.db.models import Avg, Sum
from django.db.models.functions import Coalesce
from django.utils import timezone
from django.conf import settings
from django.utils.dateparse import parse_datetime
from zoneinfo import ZoneInfo
from .models import Products
from company.models import Company
from tag.models import Tag
from tag.serializers import TagSerializer
from django.db import transaction

from core.image_processing import (
    save_product_image_variants,
    delete_product_image_variants,
)


MAX_HOT_PRODUCT_TAGS = 3
MAX_DEALS_PRODUCT_TAGS = 3
MAX_DELIVERY_RADIUS_KM = 100


class CompanyFromProductsListSerializer(serializers.ModelSerializer):
    avg_quality = serializers.SerializerMethodField()
    avg_value = serializers.SerializerMethodField()
    avg_description_match = serializers.SerializerMethodField()
    avg_service = serializers.SerializerMethodField()

    class Meta:
        model = Company
        fields = [
            'id',
            'name',
            'image_url',
            'address',
            'phone',
            'slug',
            'open_time',
            'close_time',
            'latitude',
            'longitude',
            'description',
            'rating',
            'reviews_count',
            'successful_orders',
            'company_score',
            'avg_quality',
            'avg_value',
            'avg_description_match',
            'avg_service',
        ]

    def _avg(self, obj, field):
        value = obj.reviews.aggregate(avg=Avg(field))['avg']
        return round(value, 2) if value else 0

    def get_avg_quality(self, obj):
        return self._avg(obj, 'quality')

    def get_avg_value(self, obj):
        return self._avg(obj, 'value')

    def get_avg_description_match(self, obj):
        return self._avg(obj, 'description_match')

    def get_avg_service(self, obj):
        return self._avg(obj, 'service')


class ProductStatsMixin:
    def get_sold_count(self, obj):
        annotated_value = getattr(obj, 'sold_count', None)
        if annotated_value is not None:
            return annotated_value

        return obj.card_item.filter(
            card__status='paided'
        ).aggregate(
            total=Coalesce(Sum('quantity'), 0)
        )['total']

    def get_pickup_deadline(self, obj):
        if obj.type != Products.Type.HOT:
            return None

        # pickup_deadline remains as a compatibility alias for older Flutter code.
        deadline = obj.pickup_until or obj.active_until
        return deadline.isoformat() if deadline is not None else None


class ProductsListSerializer(ProductStatsMixin, serializers.ModelSerializer):
    sold_count = serializers.SerializerMethodField()
    pickup_deadline = serializers.SerializerMethodField()
    company = CompanyFromProductsListSerializer(
        many=False,
        read_only=True
    )
    tag = TagSerializer(
        many=True,
        read_only=True
    )

    class Meta:
        model = Products
        fields = [
            'name',
            'image_url',
            'image_card_url',
            'image_thumb_url',
            'slug',
            'description',
            'price',
            'get_discount_price',
            'type',
            'company',
            'tag',
            'count',
            'dine_in_only',
            'sold_count',
            'views_count',
            'shares_count',
            'pickup_deadline',
            'pickup_from',
            'pickup_until',
            'is_active',
            'inactive_reason',
            'active_until',
            'package_quantity',
            'weight',
            'delivery_type',
            'delivery_days',
            'delivery_radius_km',
            'location_address',
            'location_latitude',
            'location_longitude',
            'expiration_date',
            'can_use_until',
            'is_promoted',
            'promotion_until',
            'publication_status',
            'publish_at',
            'published_at',
        ]


class ProductsDetailSerializer(ProductStatsMixin, serializers.ModelSerializer):
    sold_count = serializers.SerializerMethodField()
    pickup_deadline = serializers.SerializerMethodField()
    company = CompanyFromProductsListSerializer(
        many=False,
        read_only=True
    )
    tag = TagSerializer(
        many=True,
        read_only=True
    )

    class Meta:
        model = Products
        fields = [
            'company',
            'name',
            'slug',
            'description',
            'price',
            'get_discount_price',
            'image_url',
            'image_card_url',
            'image_thumb_url',
            'type',
            'tag',
            'count',
            'dine_in_only',
            'sold_count',
            'views_count',
            'shares_count',
            'pickup_deadline',
            'pickup_from',
            'pickup_until',
            'is_active',
            'inactive_reason',
            'active_until',
            'package_quantity',
            'weight',
            'delivery_type',
            'delivery_days',
            'delivery_radius_km',
            'location_address',
            'location_latitude',
            'location_longitude',
            'expiration_date',
            'can_use_until',
            'is_promoted',
            'promotion_until',
            'publication_status',
            'publish_at',
            'published_at',
        ]


class ProductCoordinateField(serializers.Field):
    """Normalize product coordinates to the six decimals used by the model."""

    default_error_messages = {
        'invalid': 'Введите корректные координаты.',
    }

    def __init__(self, *, minimum, maximum, **kwargs):
        self.minimum = Decimal(str(minimum))
        self.maximum = Decimal(str(maximum))
        super().__init__(**kwargs)

    def to_internal_value(self, data):
        if data in (None, ''):
            return None

        try:
            value = Decimal(str(data))
        except (InvalidOperation, TypeError, ValueError):
            self.fail('invalid')

        if value < self.minimum or value > self.maximum:
            self.fail('invalid')

        return value.quantize(
            Decimal('0.000001'),
            rounding=ROUND_HALF_UP,
        )

    def to_representation(self, value):
        if value is None:
            return None
        return f'{Decimal(str(value)):.6f}'


class ProductsSerializer(serializers.ModelSerializer):
    location_latitude = ProductCoordinateField(
        minimum=-90,
        maximum=90,
        required=False,
        allow_null=True,
    )
    location_longitude = ProductCoordinateField(
        minimum=-180,
        maximum=180,
        required=False,
        allow_null=True,
    )

    publish_at_local = serializers.CharField(
        write_only=True,
        required=False,
        allow_blank=True,
        help_text=(
            'Локальное время публикации магазина по Еревану. '
            'Формат: YYYY-MM-DDTHH:MM[:SS]'
        ),
    )

    company = serializers.SlugRelatedField(
        slug_field='slug',
        queryset=Company.objects.all()
    )

    tag = serializers.SlugRelatedField(
        slug_field='slug',
        queryset=Tag.objects.all(),
        many=True,
        required=False
    )


    def validate_image(self, image):
        allowed_types = {
            'image/jpeg',
            'image/png',
            'image/webp',
        }

        content_type = getattr(
            image,
            'content_type',
            None,
        )

        if content_type and content_type not in allowed_types:
            raise serializers.ValidationError(
                'Supported formats: JPG, PNG, WEBP.'
            )

        if image.size > 20 * 1024 * 1024:
            raise serializers.ValidationError(
                'Maximum image size is 20 MB.'
            )

        return image

    class Meta:
        model = Products
        fields = [
            'company',
            'name',
            'slug',
            'image',
            'description',
            'price',
            'discount',
            'count',
            'dine_in_only',
            'views_count',
            'shares_count',
            'is_active',
            'inactive_reason',
            'active_until',
            'pickup_from',
            'pickup_until',
            'type',
            'tag',
            'package_quantity',
            'weight',
            'delivery_type',
            'delivery_days',
            'delivery_radius_km',
            'location_address',
            'location_latitude',
            'location_longitude',
            'expiration_date',
            'can_use_until',
            'is_promoted',
            'promotion_until',
            'publication_status',
            'publish_at',
            'published_at',
            'publish_at_local',
        ]

        read_only_fields = [
            'views_count',
            'shares_count',
            'is_active',
            'inactive_reason',
            'active_until',
            'publication_status',
            'publish_at',
            'published_at',
        ]

    def validate(self, attrs):
        instance = self.instance

        publish_at_local = attrs.pop('publish_at_local', None)

        if publish_at_local is not None:
            text = publish_at_local.strip()

            if text:
                parsed = parse_datetime(text)
                if parsed is None:
                    raise serializers.ValidationError({
                        'publish_at_local': (
                            'Неверный формат времени. '
                            'Используйте YYYY-MM-DDTHH:MM.'
                        )
                    })

                yerevan_tz = ZoneInfo(
                    getattr(settings, 'SELLER_TIME_ZONE', 'Asia/Yerevan')
                )

                # Seller chooses a wall-clock time in Yerevan.
                # Even if the seller's phone is in another country,
                # the publication schedule belongs to the Armenian shop.
                if timezone.is_naive(parsed):
                    parsed = parsed.replace(tzinfo=yerevan_tz)
                else:
                    parsed = parsed.astimezone(yerevan_tz)

                attrs['publish_at'] = parsed
            else:
                attrs['publish_at'] = None

        product_type = attrs.get(
            'type',
            getattr(instance, 'type', Products.Type.HOT),
        )

        dine_in_only = attrs.get(
            'dine_in_only',
            getattr(instance, 'dine_in_only', False),
        )

        # "Только в заведении" applies only to HOT products.
        if product_type != Products.Type.HOT:
            attrs['dine_in_only'] = False
            dine_in_only = False

        if product_type == Products.Type.HOT and dine_in_only:
            count = attrs.get(
                'count',
                getattr(instance, 'count', 0),
            )
            if count is None or count < 1:
                raise serializers.ValidationError({
                    'count': 'Укажите хотя бы 1 доступное место.'
                })

        submitted_tags = attrs.get('tag', None)

        if submitted_tags is not None:
            unique_tag_ids = {tag.pk for tag in submitted_tags}

            if product_type == Products.Type.LONG:
                if not 1 <= len(unique_tag_ids) <= MAX_DEALS_PRODUCT_TAGS:
                    raise serializers.ValidationError({
                        'tag': (
                            f'Для Deals выберите от 1 до '
                            f'{MAX_DEALS_PRODUCT_TAGS} тегов.'
                        )
                    })
            elif len(unique_tag_ids) > MAX_HOT_PRODUCT_TAGS:
                raise serializers.ValidationError({
                    'tag': (
                        f'Для HOT можно выбрать не более '
                        f'{MAX_HOT_PRODUCT_TAGS} тегов.'
                    )
                })
        elif product_type == Products.Type.LONG:
            existing_tag_count = (
                instance.tag.count() if instance is not None else 0
            )
            if not 1 <= existing_tag_count <= MAX_DEALS_PRODUCT_TAGS:
                raise serializers.ValidationError({
                    'tag': (
                        f'Для Deals выберите от 1 до '
                        f'{MAX_DEALS_PRODUCT_TAGS} тегов.'
                    )
                })

        if product_type == Products.Type.HOT:
            pickup_from = attrs.get(
                'pickup_from',
                getattr(instance, 'pickup_from', None),
            )
            pickup_until = attrs.get(
                'pickup_until',
                getattr(instance, 'pickup_until', None),
            )

            errors = {}

            if pickup_from is None:
                errors['pickup_from'] = 'Укажите время начала получения товара.'

            if pickup_until is None:
                errors['pickup_until'] = 'Укажите время окончания получения товара.'

            if pickup_from is not None and pickup_until is not None:
                if pickup_until <= pickup_from:
                    errors['pickup_until'] = (
                        'Время окончания получения должно быть позже времени начала.'
                    )

                if pickup_until <= timezone.now():
                    errors['pickup_until'] = (
                        'Время окончания получения должно быть в будущем.'
                    )

            if errors:
                raise serializers.ValidationError(errors)
        else:
            # Deals are delivered by the seller. There is no pickup map/window.
            attrs['pickup_from'] = None
            attrs['pickup_until'] = None
            attrs['delivery_type'] = Products.DeliveryType.DELIVERY

            delivery_days = attrs.get(
                'delivery_days',
                getattr(instance, 'delivery_days', None),
            )
            delivery_radius_km = attrs.get(
                'delivery_radius_km',
                getattr(instance, 'delivery_radius_km', None),
            )

            delivery_errors = {}

            if delivery_days is None or not 1 <= delivery_days <= 60:
                delivery_errors['delivery_days'] = (
                    'Укажите срок доставки от 1 до 60 дней.'
                )

            if (
                delivery_radius_km is None
                or not 1 <= delivery_radius_km <= MAX_DELIVERY_RADIUS_KM
            ):
                delivery_errors['delivery_radius_km'] = (
                    f'Укажите радиус доставки от 1 до '
                    f'{MAX_DELIVERY_RADIUS_KM} км.'
                )

            if delivery_errors:
                raise serializers.ValidationError(delivery_errors)

        location_latitude = attrs.get(
            'location_latitude',
            getattr(instance, 'location_latitude', None),
        )
        location_longitude = attrs.get(
            'location_longitude',
            getattr(instance, 'location_longitude', None),
        )

        location_errors = {}
        if (location_latitude is None) != (location_longitude is None):
            location_errors['location'] = (
                'Широта и долгота точки товара должны быть указаны вместе.'
            )

        if location_latitude is not None and not -90 <= location_latitude <= 90:
            location_errors['location_latitude'] = 'Широта должна быть от -90 до 90.'

        if location_longitude is not None and not -180 <= location_longitude <= 180:
            location_errors['location_longitude'] = 'Долгота должна быть от -180 до 180.'

        if location_errors:
            raise serializers.ValidationError(location_errors)

        expiration_date = attrs.get(
            'expiration_date',
            getattr(instance, 'expiration_date', None),
        )
        can_use_until = attrs.get(
            'can_use_until',
            getattr(instance, 'can_use_until', None),
        )

        date_errors = {}
        today = timezone.localdate()

        if expiration_date is not None and expiration_date < today:
            # A product that has already expired remains in the seller cabinet.
            # The seller may edit its other fields without being forced to change
            # the old expiration date immediately. A NEW past date is still
            # rejected, and creation with a past date is rejected as before.
            existing_expiration_date = (
                getattr(instance, 'expiration_date', None)
                if instance is not None
                else None
            )
            unchanged_expired_date = (
                instance is not None
                and existing_expiration_date == expiration_date
            )

            if not unchanged_expired_date:
                date_errors['expiration_date'] = (
                    'Нельзя указывать новый срок годности в прошлом.'
                )

        if (
            expiration_date is not None
            and can_use_until is not None
            and can_use_until > expiration_date
        ):
            date_errors['can_use_until'] = (
                'Дата «Лучше употребить до» не может быть позже '
                'срока годности.'
            )

        if date_errors:
            raise serializers.ValidationError(date_errors)

        publish_at = attrs.get(
            'publish_at',
            getattr(instance, 'publish_at', None),
        )

        if expiration_date is not None and publish_at is not None:
            yerevan_tz = ZoneInfo(
                getattr(settings, 'SELLER_TIME_ZONE', 'Asia/Yerevan')
            )
            publish_date = timezone.localtime(
                publish_at,
                timezone=yerevan_tz,
            ).date()
            if publish_date > expiration_date:
                raise serializers.ValidationError({
                    'publish_at_local': (
                        'Дата публикации не может быть позже срока годности.'
                    )
                })

        # A seller may reschedule an already published product after editing.
        # ProductsUpdate.perform_update() will switch it to SCHEDULED, hide it
        # from sale, clear the previous active window, and publish it again at
        # the requested future moment.

        if publish_at is not None and publish_at > timezone.now():
            if product_type == Products.Type.HOT:
                pickup_until = attrs.get(
                    'pickup_until',
                    getattr(instance, 'pickup_until', None),
                )
                if pickup_until is not None and pickup_until <= publish_at:
                    raise serializers.ValidationError({
                        'pickup_until': (
                            'Окончание получения должно быть позже '
                            'времени публикации товара.'
                        )
                    })

        return attrs

    @transaction.atomic
    def create(self, validated_data):
        tag_instances = validated_data.pop('tag', [])
        product = Products.objects.create(**validated_data)

        if tag_instances:
            product.tag.set(tag_instances)

        uploaded_image = validated_data.get('image')

        if uploaded_image:
            storage = product._meta.get_field('image').storage

            try:
                variants = save_product_image_variants(
                    uploaded_image,
                    storage,
                )

                product.image.name = variants['image']

                product.save(
                    update_fields=['image'],
                )

            except Exception as exc:
                product.delete()

                raise serializers.ValidationError({
                    'image': (
                        'Could not process the image: '
                        f'{exc}'
                    )
                })

        return product

    @transaction.atomic
    def update(self, instance, validated_data):
        uploaded_image = validated_data.pop(
            'image',
            None,
        )

        old_image_name = (
            instance.image.name
            if instance.image
            else ''
        )

        instance = super().update(
            instance,
            validated_data,
        )

        # Normal edit: price/count/etc.
        # Do NOT recompress existing photo.
        if uploaded_image is None:
            return instance

        storage = instance._meta.get_field(
            'image'
        ).storage

        try:
            variants = save_product_image_variants(
                uploaded_image,
                storage,
            )

            instance.image.name = variants['image']

            instance.save(
                update_fields=['image'],
            )

        except Exception as exc:
            raise serializers.ValidationError({
                'image': (
                    'Could not process the image: '
                    f'{exc}'
                )
            })

        # Delete previous image only AFTER
        # the new image was successfully stored.
        if old_image_name:
            old_field = instance._meta.get_field(
                'image'
            )

            old_field_file = old_field.attr_class(
                instance,
                old_field,
                old_image_name,
            )

            delete_product_image_variants(
                old_field_file,
            )

        return instance