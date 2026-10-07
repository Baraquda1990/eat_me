from drf_spectacular.utils import extend_schema
from rest_framework.generics import RetrieveUpdateAPIView
from .serializers import ProfileSerializer
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import JSONParser, FormParser, MultiPartParser
from .models import Profile
from rest_framework.views import APIView
import secrets
from django.core.mail import send_mail
from django.conf import settings
from rest_framework.response import Response

@extend_schema(description="Изменение и просмотр своего профиля")
class ProfileUpdateRetrieve(RetrieveUpdateAPIView):
    serializer_class = ProfileSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = [JSONParser, FormParser, MultiPartParser]

    def get_object(self):
        return Profile.objects.get(user=self.request.user)
    
@extend_schema(description="Сброс пароля")
class ResetPassword(APIView):
    def post(self,request):
        email=request.data.get("email")
        profile=Profile.objects.filter(user__email=email).first()
        if profile:
            new_password=secrets.token_urlsafe(4)
            profile.user.set_password(new_password)
            profile.user.save()
            send_mail(
                "Password reset",
                f"Your new temporary password: {new_password},\nYour login: {profile.user.username}",
                settings.DEFAULT_FROM_EMAIL,
                [profile.user.email],
            )
        return Response({
            "detail": "If the email exists, a new password has been sent."
        })

