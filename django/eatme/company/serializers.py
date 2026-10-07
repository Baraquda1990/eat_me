from django.db.models import Avg, Exists, OuterRef, Q
from rest_framework import serializers

from .models import Company
from card.models import Card_item
from core.phone import validate_armenian_phone


class CompanySerializer(serializers.ModelSerializer):
    image = serializers.ImageField(
        required=False,
        allow_null=True,
        write_only=True,
    )

    rating = serializers.SerializerMethodField()
    reviews_count = serializers.SerializerMethodField()
    avg_quality = serializers.SerializerMethodField()
    avg_value = serializers.SerializerMethodField()
    avg_description_match = serializers.SerializerMethodField()
    avg_service = serializers.SerializerMethodField()
    has_hot_products = serializers.SerializerMethodField()

    class Meta:
        model = Company
        fields = [
            'id',
            'name',
            'slug',
            'latitude',
            'longitude',
            'address',
            'phone',

            'image',
            'image_url',

            'description',
            'open_time',
            'close_time',
            'rating',
            'reviews_count',
            'successful_orders',
            'company_score',
            'instagram',
            'facebook',

            'avg_quality',
            'avg_value',
            'avg_description_match',
            'avg_service',
            'has_hot_products',
        ]

        read_only_fields = [
            'id',
            'slug',
            'image_url',
            'rating',
            'reviews_count',
            'successful_orders',
            'company_score',
            'avg_quality',
            'avg_value',
            'avg_description_match',
            'avg_service',
            'has_hot_products',
        ]

    def validate_phone(self, value):
        if value is None:
            return None
        return validate_armenian_phone(value, allow_blank=True)

    def _hot_review_stats(self, obj):
        cached = getattr(obj, '_hot_review_stats_cache', None)
        if cached is not None:
            return cached

        matching_hot_item = (
            Card_item.objects
            .filter(card_id=OuterRef('card_id'))
            .filter(
                Q(company_id_snapshot=OuterRef('company_id'))
                | Q(
                    company_id_snapshot__isnull=True,
                    product__company_id=OuterRef('company_id'),
                )
            )
            .filter(
                Q(product_type_snapshot__iexact='hot')
                | Q(
                    product_type_snapshot='',
                    product__type__iexact='hot',
                )
            )
        )

        hot_reviews = (
            obj.reviews
            .annotate(_has_hot_purchase=Exists(matching_hot_item))
            .filter(_has_hot_purchase=True)
        )

        values = hot_reviews.aggregate(
            rating=Avg('rating'),
            quality=Avg('quality'),
            value=Avg('value'),
            description_match=Avg('description_match'),
            service=Avg('service'),
        )
        values['reviews_count'] = hot_reviews.count()

        setattr(obj, '_hot_review_stats_cache', values)
        return values

    def get_rating(self, obj):
        value = self._hot_review_stats(obj).get('rating')
        return round(value, 2) if value else 0

    def get_reviews_count(self, obj):
        return int(self._hot_review_stats(obj).get('reviews_count') or 0)

    def get_avg_quality(self, obj):
        value = self._hot_review_stats(obj).get('quality')
        return round(value, 2) if value else 0

    def get_avg_value(self, obj):
        value = self._hot_review_stats(obj).get('value')
        return round(value, 2) if value else 0

    def get_avg_description_match(self, obj):
        value = self._hot_review_stats(obj).get('description_match')
        return round(value, 2) if value else 0

    def get_avg_service(self, obj):
        value = self._hot_review_stats(obj).get('service')
        return round(value, 2) if value else 0

    def get_has_hot_products(self, obj):
        annotated = getattr(obj, 'hot_products_count', None)
        if annotated is not None:
            return int(annotated) > 0

        return obj.products.filter(type='hot').exists()

class CompanyCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Company
        fields = (
            'id',
            'name',
            'slug',
            'image',
            'latitude',
            'longitude',
            'address',
            'phone',
            'instagram',
            'facebook',
            'description',
            'open_time',
            'close_time',
        )
        read_only_fields = ('id',)

    def validate_phone(self, value):
        if value is None:
            return None
        return validate_armenian_phone(value, allow_blank=True)
