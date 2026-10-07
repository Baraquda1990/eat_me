from rest_framework import serializers
from .models import Review, ReviewEditRequest


class ReviewSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(
        source='company.name',
        read_only=True
    )

    username = serializers.CharField(
        source='user.username',
        read_only=True
    )

    edit_request_status = serializers.SerializerMethodField()
    can_edit = serializers.SerializerMethodField()

    def _latest_edit_request(self, obj):
        cached = list(obj.edit_requests.all())
        if cached:
            return cached[0]
        return None

    def get_edit_request_status(self, obj):
        request = self._latest_edit_request(obj)
        return request.status if request is not None else None

    def get_can_edit(self, obj):
        request = self._latest_edit_request(obj)
        return (
            request is not None
            and request.status == ReviewEditRequest.Status.APPROVED
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
            'edit_request_status',
            'can_edit',
        ]

        read_only_fields = [
            'id',
            'company',
            'company_name',
            'card',
            'username',
            'rating',
            'created',
            'edit_request_status',
            'can_edit',
        ]
