from rest_framework import serializers
from .models import Company
class CompanySerializer(serializers.ModelSerializer):
    class Meta:
        model=Company
        fields=['name','slug','latitude','longitude','address','image_url','description','open_time','close_time']

class CompanyCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Company
        fields = (
            'name',
            'slug',
            'image',
            'latitude',
            'longitude',
            'address',
            'description',
            'open_time',
            'close_time',
        )