from rest_framework import serializers

from .models import (
    BusinessCategory,
    CompanyChannel,
    SellerApplication,
    SellerApplicationDocument,
)


class CompanyChannelSerializer(serializers.ModelSerializer):
    name = serializers.CharField(
        source='get_code_display',
        read_only=True,
    )

    class Meta:
        model = CompanyChannel
        fields = (
            'id',
            'code',
            'name',
        )


class BusinessCategorySerializer(serializers.ModelSerializer):
    allowed_channels = CompanyChannelSerializer(
        many=True,
        read_only=True,
    )

    class Meta:
        model = BusinessCategory
        fields = (
            'id',
            'code',
            'name_en',
            'name_ru',
            'name_hy',
            'allowed_channels',
        )


class SellerApplicationDocumentSerializer(serializers.ModelSerializer):
    file_url = serializers.SerializerMethodField()

    class Meta:
        model = SellerApplicationDocument
        fields = (
            'id',
            'document_type',
            'file',
            'file_url',
            'original_name',
            'description',
            'created',
        )

        read_only_fields = (
            'id',
            'file_url',
            'original_name',
            'created',
        )

    def get_file_url(self, obj):
        if not obj.file:
            return None

        request = self.context.get('request')

        if request:
            return request.build_absolute_uri(obj.file.url)

        return obj.file.url


class SellerApplicationSerializer(serializers.ModelSerializer):
    requested_channels = serializers.PrimaryKeyRelatedField(
        queryset=CompanyChannel.objects.filter(is_active=True),
        many=True,
        required=False,
    )

    documents = SellerApplicationDocumentSerializer(
        many=True,
        read_only=True,
    )

    status_display = serializers.CharField(
        source='get_status_display',
        read_only=True,
    )

    is_editable = serializers.BooleanField(
        read_only=True,
    )

    class Meta:
        model = SellerApplication
        fields = (
            'id',
            'requested_channels',

            'organization_name',
            'tax_number',
            'address',
            'latitude',
            'longitude',
            'business_phone',
            'business_email',

            'contact_name',
            'contact_phone',
            'contact_email',

            'business_category',

            'bank_name',
            'iban',
            'account_holder_name',

            'logo',
            'public_description',

            'status',
            'status_display',
            'current_step',
            'admin_comment',

            'documents',
            'is_editable',

            'submitted_at',
            'reviewed_at',
            'created',
            'updated',
        )

        read_only_fields = (
            'id',
            'status',
            'status_display',
            'admin_comment',
            'documents',
            'is_editable',
            'submitted_at',
            'reviewed_at',
            'created',
            'updated',
        )

    def validate_current_step(self, value):
        if value < 1 or value > 5:
            raise serializers.ValidationError(
                'Шаг должен быть от 1 до 5.'
            )

        return value

    def validate(self, attrs):
        instance = self.instance

        if instance and not instance.is_editable:
            raise serializers.ValidationError(
                'Эту заявку больше нельзя редактировать.'
            )

        return attrs
