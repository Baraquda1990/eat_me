from rest_framework import serializers
from djoser.serializers import UserCreatePasswordRetypeSerializer
from django.contrib.auth import get_user_model
from django.db import transaction
from .models import Profile
from core.phone import validate_armenian_phone
from legal.models import LegalConsent
from legal.services import (
    LegalAcceptanceError,
    create_consents,
    validate_required_acceptances,
)
User = get_user_model()

class CustomUserCreateSerializer(UserCreatePasswordRetypeSerializer):
    phone = serializers.CharField(
        required=False,
        allow_blank=True,
        write_only=True,
    )
    legal_acceptances = serializers.ListField(
        child=serializers.DictField(),
        required=False,
        default=list,
        write_only=True,
    )

    class Meta(UserCreatePasswordRetypeSerializer.Meta):
        model = User
        fields = (
            'id',
            'username',
            'email',
            'password',
            'phone',
            'legal_acceptances',
        )

    def validate_phone(self, value):
        return validate_armenian_phone(value, allow_blank=True)

    def validate(self, attrs):
        self._phone = attrs.pop('phone', '')
        raw_acceptances = attrs.pop('legal_acceptances', [])

        try:
            self._legal_acceptances = validate_required_acceptances(
                raw_acceptances,
                action='registration',
            )
        except LegalAcceptanceError as error:
            raise serializers.ValidationError({
                'legal_acceptances': str(error),
            }) from error

        return super().validate(attrs)

    @transaction.atomic
    def create(self, validated_data):
        user = super().create(validated_data)

        if hasattr(user, 'profile'):
            user.profile.phone = getattr(self, '_phone', '')
            user.profile.phone_verified = False
            user.profile.save(update_fields=['phone', 'phone_verified'])

        create_consents(
            user,
            getattr(self, '_legal_acceptances', []),
            request=self.context.get('request'),
            source=LegalConsent.Source.REGISTRATION,
        )

        return user
    
class ProfileSerializer(serializers.ModelSerializer):
    avatar_url = serializers.SerializerMethodField()

    class Meta:
        model = Profile
        fields = [
            'bio',
            'birth_date',
            'phone',
            'address',
            'house_number',
            'floor',
            'delivery_latitude',
            'delivery_longitude',
            'delivery_additional_info',
            'avatar',
            'avatar_url',
            'type_user',
            'language',
        ]
        read_only_fields = ['avatar_url', 'type_user']
        extra_kwargs = {
            'avatar': {
                'required': False,
                'allow_null': True,
            },
        }

    def get_avatar_url(self, obj):
        if not obj.avatar:
            return None

        request = self.context.get('request')
        url = obj.avatar.url

        if request is not None:
            return request.build_absolute_uri(url)

        return url

    def validate_phone(self, value):
        return validate_armenian_phone(value, allow_blank=True)

    def validate(self, attrs):
        attrs = super().validate(attrs)

        instance = self.instance

        latitude = attrs.get(
            'delivery_latitude',
            getattr(instance, 'delivery_latitude', None),
        )
        longitude = attrs.get(
            'delivery_longitude',
            getattr(instance, 'delivery_longitude', None),
        )

        if (latitude is None) != (longitude is None):
            raise serializers.ValidationError({
                'delivery_location': (
                    'Широта и долгота должны быть указаны вместе.'
                ),
            })

        if latitude is not None and not (-90 <= latitude <= 90):
            raise serializers.ValidationError({
                'delivery_latitude': 'Недопустимая широта.',
            })

        if longitude is not None and not (-180 <= longitude <= 180):
            raise serializers.ValidationError({
                'delivery_longitude': 'Недопустимая долгота.',
            })

        return attrs

    def validate_avatar(self, avatar):
        if avatar is None:
            return avatar

        max_size = 5 * 1024 * 1024
        if avatar.size > max_size:
            raise serializers.ValidationError(
                'Размер аватарки не должен превышать 5 МБ.'
            )

        return avatar

