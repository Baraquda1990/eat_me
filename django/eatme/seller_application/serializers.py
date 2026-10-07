import re

from rest_framework import serializers

from core.phone import validate_armenian_phone

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

    agreement_accepted = serializers.SerializerMethodField()
    agreement_version = serializers.SerializerMethodField()
    agreement_accepted_at = serializers.SerializerMethodField()

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

            'agreement_accepted',
            'agreement_version',
            'agreement_accepted_at',

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
            'agreement_accepted',
            'agreement_version',
            'agreement_accepted_at',
            'submitted_at',
            'reviewed_at',
            'created',
            'updated',
        )


    def _agreement_acceptance(self, obj):
        return obj.agency_agreement_acceptances.order_by(
            '-accepted_at', '-id'
        ).first()

    def get_agreement_accepted(self, obj):
        return self._agreement_acceptance(obj) is not None and not obj.is_editable

    def get_agreement_version(self, obj):
        acceptance = self._agreement_acceptance(obj)
        return acceptance.version if acceptance else None

    def get_agreement_accepted_at(self, obj):
        acceptance = self._agreement_acceptance(obj)
        return acceptance.accepted_at if acceptance else None

    def validate_tax_number(self, value):
        tax_number = (value or '').strip()

        # Drafts may still be partially filled. Final submission checks
        # that the field is present, while any non-empty value must already
        # be a valid Armenian 8-digit TIN.
        if not tax_number:
            return ''

        if re.fullmatch(r'[0-9]{8}', tax_number) is None:
            raise serializers.ValidationError(
                'ИНН должен содержать ровно 8 цифр.'
            )

        return tax_number

    def validate_business_phone(self, value):
        return validate_armenian_phone(value, allow_blank=True)

    def validate_contact_phone(self, value):
        return validate_armenian_phone(value, allow_blank=True)

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
