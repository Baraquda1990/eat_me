from rest_framework import serializers

from .models import Tag


class TagSerializer(serializers.ModelSerializer):
    # `name` stays compatible with the existing Flutter/API contract, but now
    # contains the translation matching the requested language.
    name = serializers.SerializerMethodField()
    name_ru = serializers.CharField(source='name', read_only=True)
    products_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = Tag
        fields = [
            'name',
            'name_ru',
            'name_en',
            'name_hy',
            'slug',
            'products_count',
            'image_url',
        ]

    def _language_code(self):
        request = self.context.get('request')
        if request is None:
            return 'ru'

        # Optional ?lang= is handy for API/manual tests. Flutter normally sends
        # Accept-Language globally.
        raw = (
            request.query_params.get('lang')
            or request.headers.get('Accept-Language')
            or 'ru'
        )

        # Handles values such as "en-US,en;q=0.9".
        primary = str(raw).split(',')[0].strip().lower()
        return primary.split('-')[0]

    def get_name(self, obj):
        return obj.get_localized_name(self._language_code())
