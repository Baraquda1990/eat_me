from django.db.models import Avg
from rest_framework import serializers

from .models import Company


class CompanySerializer(serializers.ModelSerializer):
    avg_quality = serializers.SerializerMethodField()
    avg_value = serializers.SerializerMethodField()
    avg_description_match = serializers.SerializerMethodField()
    avg_service = serializers.SerializerMethodField()

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
        ]

        read_only_fields = [
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
