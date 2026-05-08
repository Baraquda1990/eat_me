from rest_framework import serializers
from .models import Company
class CompanySerializer(serializers.ModelSerializer):
    class Meta:
        model=Company
        fields=['name','slug','latitude','longitude','address','image_url','description']