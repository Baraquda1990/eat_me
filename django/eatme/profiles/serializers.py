from djoser.serializers import UserCreatePasswordRetypeSerializer
from django.contrib.auth import get_user_model

User = get_user_model()


class CustomUserCreateSerializer(UserCreatePasswordRetypeSerializer):
    class Meta(UserCreatePasswordRetypeSerializer.Meta):
        model = User
        fields = (
            'id',
            'username',
            'email',
            'password',
            're_password',
            'phone',
        )

    def create(self, validated_data):
        phone = validated_data.pop('phone', '')
        user = super().create(validated_data)

        if hasattr(user, 'profile'):
            user.profile.phone = phone
            user.profile.save(update_fields=['phone'])

        return user
