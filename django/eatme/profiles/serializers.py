from rest_framework import serializers
from djoser.serializers import UserCreatePasswordRetypeSerializer
from django.contrib.auth import get_user_model
from .models import Profile
User = get_user_model()

class CustomUserCreateSerializer(UserCreatePasswordRetypeSerializer):
    phone = serializers.CharField(
        required=False,
        allow_blank=True,
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
        )

    def validate(self, attrs):
        self._phone = attrs.pop('phone', '')
        return super().validate(attrs)

    def create(self, validated_data):
        user = super().create(validated_data)

        if hasattr(user, 'profile'):
            user.profile.phone = getattr(self, '_phone', '')
            user.profile.phone_verified = False
            user.profile.save(update_fields=['phone', 'phone_verified'])

        return user
    
class ProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model=Profile
        fields=[
            'bio',
            'birth_date',
            'phone',
            'address'
        ]