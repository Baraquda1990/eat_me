from rest_framework import serializers
from .models import Products
class ProductsListSerializer(serializers.ModelSerializer):
    class Meta:
        model=Products
        fields=['name','image_url','slug']

class ProductsDetailSerializer(serializers.ModelSerializer):
    company = serializers.SlugRelatedField(
        read_only=True,
        slug_field='slug'
    )
    class Meta:
        model=Products
        fields='__all__'