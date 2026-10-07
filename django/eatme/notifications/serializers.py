from datetime import timedelta
from django.utils import timezone
from rest_framework import serializers

from tag.models import Tag
from tag.serializers import TagSerializer
from .models import DeviceToken, Notification, NotificationAlarm
from .i18n import localize_notification
from company.models import Company  # 👈 ДОБАВЛЕН ИМПОРТ
from company.serializers import CompanySerializer  # 👈 ДОБАВЛЕН ИМПОРТ


class DeviceTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeviceToken
        fields = ['token', 'device_type']


class NotificationSerializer(serializers.ModelSerializer):
    title = serializers.SerializerMethodField()
    body = serializers.SerializerMethodField()

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

    def _localized_text(self, obj):
        request = self.context.get('request')
        user = request.user if request is not None and request.user.is_authenticated else obj.user
        return localize_notification(
            user=user,
            type_=obj.type,
            data=obj.data or {},
            fallback_title=obj.title,
            fallback_body=obj.body,
        )

    def get_title(self, obj):
        return self._localized_text(obj)[0]

    def get_body(self, obj):
        return self._localized_text(obj)[1]


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

    # 👇 ДОБАВЛЕНЫ ПОЛЯ ДЛЯ КОМПАНИЙ
    companies = serializers.SlugRelatedField(
        slug_field='slug',
        queryset=Company.objects.all(),
        many=True,
        required=False
    )

    companies_detail = CompanySerializer(
        source='companies',
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
            'notify_until',
            'timezone_offset_minutes',
            'radius_km',
            'latitude',
            'longitude',
            'is_active',
            'created',
            'companies',           # 👈 ДОБАВЛЕНО
            'companies_detail',    # 👈 ДОБАВЛЕНО
        ]

        read_only_fields = ['id', 'created']


    def validate_notify_at(self, value):
        minimum_allowed = timezone.now() + timedelta(minutes=5)

        if value <= minimum_allowed:
            raise serializers.ValidationError(
                'Выберите время минимум на 5 минут позже текущего.'
            )

        return value

    def validate(self, attrs):
        attrs = super().validate(attrs)

        notify_at = attrs.get(
            'notify_at',
            getattr(self.instance, 'notify_at', None),
        )
        notify_until = attrs.get(
            'notify_until',
            getattr(self.instance, 'notify_until', None),
        )

        if notify_at is not None and notify_until is not None:
            if notify_until <= notify_at:
                raise serializers.ValidationError({
                    'notify_until': 'Время окончания должно быть позже времени начала.'
                })

        return attrs

    def create(self, validated_data):
        tags = validated_data.pop('tags', [])
        companies = validated_data.pop('companies', [])  # 👈 ДОБАВЛЕНО

        alarm = NotificationAlarm.objects.create(
            user=self.context['request'].user,
            **validated_data
        )

        alarm.tags.set(tags)
        alarm.companies.set(companies)  # 👈 ДОБАВЛЕНО

        return alarm

    def update(self, instance, validated_data):
        tags = validated_data.pop('tags', None)
        companies = validated_data.pop('companies', None)  # 👈 ДОБАВЛЕНО

        for attr, value in validated_data.items():
            setattr(instance, attr, value)

        instance.save()

        if tags is not None:
            instance.tags.set(tags)

        if companies is not None:  # 👈 ДОБАВЛЕНО
            instance.companies.set(companies)

        return instance