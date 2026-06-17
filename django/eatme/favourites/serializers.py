from rest_framework.exceptions import ValidationError
from rest_framework import serializers
from .models import Favourites
from products.models import Products

class FavouritesSerializer(serializers.ModelSerializer):
    products = serializers.SlugRelatedField(
        queryset=Products.objects.all(),
        slug_field='slug'
    )
    class Meta:
        model = Favourites
        fields = ['products']
    def validate(self, data):
        user = self.context['request'].user
        products = data['products']
        if Favourites.objects.filter(user=user, products=products).exists():
            raise ValidationError("Уже в избранном")
        return data

class FavouritesList(serializers.ModelSerializer):
    products = serializers.SlugRelatedField(
        read_only=True,
        slug_field='slug'
    )
    class Meta:
        model=Favourites
        fields=['products']