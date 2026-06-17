from rest_framework import serializers
from .models import Card, Card_item
from products.serializers import ProductsListSerializer

class CardItemSerializer(serializers.ModelSerializer):
    product = ProductsListSerializer(read_only=True)
    class Meta:
        model = Card_item
        fields = ['id', 'product', 'quantity', 'price_by_quantity']

class CardSerializer(serializers.ModelSerializer):
    items = CardItemSerializer(source='card_item', many=True, read_only=True)
    total_price = serializers.SerializerMethodField()
    class Meta:
        model = Card
        fields = [
            'id',
            'status',
            'items',
            'created',
            'total_price'
        ]
    def get_total_price(self, obj):
        return sum(item.price_by_quantity for item in obj.card_item.all())

class AddToCartSerializer(serializers.Serializer):
    product_slug = serializers.SlugField()
    quantity = serializers.IntegerField(default=1)

class UpdateQuantitySerializer(serializers.ModelSerializer):
    class Meta:
        model = Card_item
        fields = ['quantity']

    def validate_quantity(self, value):
        if value < 0:
            raise serializers.ValidationError("Количество не может быть меньше 0")
        return value