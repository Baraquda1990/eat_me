from rest_framework import serializers
from .models import Tag

class TagSerializer(serializers.ModelSerializer):
    products_count=serializers.IntegerField(read_only=True)
    class Meta:
        model=Tag
        fields=['name','slug','products_count']