from rest_framework import serializers
from django.db.models import Avg
from .models import Products
from company.models import Company
from tag.models import Tag
from tag.serializers import TagSerializer


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


class ProductsListSerializer(serializers.ModelSerializer):
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
            'slug',
            'description',
            'price',
            'get_discount_price',
            'type',
            'company',
            'tag',
            'count',
            'package_quantity',
            'weight',
            'delivery_type',
            'delivery_days',
            'expiration_date',
            'can_use_until',
            'is_promoted',
            'promotion_until',
        ]


class ProductsDetailSerializer(serializers.ModelSerializer):
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
            'type',
            'tag',
            'count',
            'package_quantity',
            'weight',
            'delivery_type',
            'delivery_days',
            'expiration_date',
            'can_use_until',
            'is_promoted',
            'promotion_until',
        ]


class ProductsSerializer(serializers.ModelSerializer):
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
            'type',
            'tag',
            'package_quantity',
            'weight',
            'delivery_type',
            'delivery_days',
            'expiration_date',
            'can_use_until',
            'is_promoted',
            'promotion_until',
        ]
