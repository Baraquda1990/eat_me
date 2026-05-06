from rest_framework.generics import RetrieveAPIView
from rest_framework.permissions import AllowAny

from .models import Company
from .serializers import CompanySerializer

class CompanyDetail(RetrieveAPIView):
    queryset=Company.objects.all()
    permission_classes=[AllowAny]
    serializer_class=CompanySerializer
    lookup_field='slug'