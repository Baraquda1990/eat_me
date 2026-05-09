from rest_framework import serializers
from .models import Products
from company.models import Company

class CompanyFromProductsListSerializer(serializers.ModelSerializer):
    class Meta:
        model=Company
        fields=['name','image_url','address','slug','open_time','close_time']

class ProductsListSerializer(serializers.ModelSerializer):
    company=CompanyFromProductsListSerializer(many=False,read_only=True)
    class Meta:
        model=Products
        fields=['name','image_url','slug','description','price','discount_price','type','company']

class ProductsDetailSerializer(serializers.ModelSerializer):
    '''company = serializers.SlugRelatedField(
        read_only=True,
        slug_field='slug'
    )'''
    company=CompanyFromProductsListSerializer(many=False,read_only=True)
    class Meta:
        model=Products
        #fields='__all__'
        fields=['company','name','slug','description','price','discount_price','image_url','type']