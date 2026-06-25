from drf_spectacular.utils import extend_schema
from rest_framework.generics import RetrieveUpdateAPIView
from .serializers import ProfileSerializer
from rest_framework.permissions import IsAuthenticated
from .models import Profile

@extend_schema(description="Изменение и просмотр своего профиля")
class ProfileUpdateRetrieve(RetrieveUpdateAPIView):
    serializer_class=ProfileSerializer
    permission_classes=[IsAuthenticated]
    def get_object(self):
        return Profile.objects.get(user=self.request.user)