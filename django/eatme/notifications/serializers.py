from rest_framework import serializers

from tag.models import Tag
from tag.serializers import TagSerializer
from .models import DeviceToken, Notification, NotificationAlarm


class DeviceTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeviceToken
        fields = ['token', 'device_type']


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = [
            'id',
            'type',
            'title',
            'body',
            'data',
            'is_read',
            'created',
        ]


class NotificationAlarmSerializer(serializers.ModelSerializer):
    tags = serializers.SlugRelatedField(
        slug_field='slug',
        queryset=Tag.objects.all(),
        many=True,
        required=False
    )

    tags_detail = TagSerializer(
        source='tags',
        many=True,
        read_only=True
    )

    class Meta:
        model = NotificationAlarm
        fields = [
            'id',
            'product_type',
            'tags',
            'tags_detail',
            'notify_at',
            'radius_km',
            'latitude',
            'longitude',
            'is_active',
            'created',
        ]
        read_only_fields = ['id', 'created']

    def create(self, validated_data):
        tags = validated_data.pop('tags', [])
        alarm = NotificationAlarm.objects.create(
            user=self.context['request'].user,
            **validated_data
        )
        alarm.tags.set(tags)
        return alarm

    def update(self, instance, validated_data):
        tags = validated_data.pop('tags', None)

        for attr, value in validated_data.items():
            setattr(instance, attr, value)

        instance.save()

        if tags is not None:
            instance.tags.set(tags)

        return instance
