from rest_framework import serializers
from .models import Review


class ReviewSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(
        source='company.name',
        read_only=True
    )

    username = serializers.CharField(
        source='user.username',
        read_only=True
    )

    class Meta:
        model = Review
        fields = [
            'id',
            'company',
            'company_name',
            'card',
            'username',
            'quality',
            'value',
            'description_match',
            'service',
            'comment',
            'rating',
            'created',
        ]

        read_only_fields = [
            'id',
            'company_name',
            'username',
            'rating',
            'created',
        ]
