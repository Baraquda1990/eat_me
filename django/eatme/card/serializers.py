from copy import deepcopy

from rest_framework import serializers

from products.serializers import ProductsListSerializer

from .models import Card, Card_item
from .review_eligibility import serialize_review_availability


class CardItemSerializer(serializers.ModelSerializer):
    product = serializers.SerializerMethodField()
    product_snapshot = serializers.JSONField(read_only=True)
    unit_price_snapshot = serializers.DecimalField(
        max_digits=12,
        decimal_places=2,
        read_only=True,
        allow_null=True,
    )

    class Meta:
        model = Card_item
        fields = [
            'id',
            'product',
            'product_snapshot',
            'quantity',
            'price_by_quantity',
            'unit_price_snapshot',
            'delivery_status',
            'review_available_at',
        ]

    def get_product(self, obj):
        # Completed orders always prefer the immutable purchase-time snapshot.
        # Return a read-only display copy so a historical HOT item cannot look
        # purchasable again just because its old snapshot had stock > 0.
        if obj.card.status == 'paided' and obj.product_snapshot:
            data = deepcopy(obj.product_snapshot)
            data['count'] = 0
            data['is_active'] = False
            data['inactive_reason'] = 'purchase_snapshot'
            return data

        if obj.product is None:
            return obj.product_snapshot or None

        return ProductsListSerializer(
            obj.product,
            context=self.context,
        ).data


class CardSerializer(serializers.ModelSerializer):
    items = CardItemSerializer(source='card_item', many=True, read_only=True)
    total_price = serializers.SerializerMethodField()
    reviewed_company_ids = serializers.SerializerMethodField()
    review_availability = serializers.SerializerMethodField()
    created = serializers.SerializerMethodField()

    class Meta:
        model = Card
        fields = [
            'id',
            'order_number',
            'status',
            'items',
            'created',
            'paid_at',
            'total_price',
            'reviewed_company_ids',
            'review_availability',
        ]

    def get_created(self, obj):
        # Backward compatibility for existing Flutter code:
        # paid orders expose their real checkout time as "created".
        value = obj.paid_at or obj.created
        return value.isoformat() if value else None

    def get_total_price(self, obj):
        return sum(item.price_by_quantity for item in obj.card_item.all())

    def get_reviewed_company_ids(self, obj):
        from reviews.models import Review

        return list(
            Review.objects.filter(
                card=obj,
                user=obj.user,
            ).values_list('company_id', flat=True)
        )

    def get_review_availability(self, obj):
        return serialize_review_availability(obj)


class AddToCartSerializer(serializers.Serializer):
    product_slug = serializers.SlugField()
    quantity = serializers.IntegerField(default=1)


class UpdateQuantitySerializer(serializers.ModelSerializer):
    class Meta:
        model = Card_item
        fields = ['quantity']

    def validate_quantity(self, value):
        if value < 0:
            raise serializers.ValidationError(
                'Количество не может быть меньше 0'
            )
        return value
