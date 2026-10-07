import logging

from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.mail import send_mail
from django.core.validators import validate_email
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Feedback
from core.phone import is_valid_armenian_phone

logger = logging.getLogger(__name__)


@extend_schema(description="Форма обратной связи / запрос в службу поддержки")
class FeedbackApi(APIView):
    # Support is intentionally available before login/registration.
    permission_classes = [AllowAny]

    def post(self, request):
        text = str(request.data.get('text') or '').strip()
        phone = str(request.data.get('phone') or '').strip()
        email = str(request.data.get('email') or '').strip()

        if not text:
            return Response(
                {'detail': 'Message is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if len(text) > 1000:
            return Response(
                {'detail': 'Message must be 1000 characters or less.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not email:
            return Response(
                {'detail': 'Email is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if phone and not is_valid_armenian_phone(phone, allow_blank=False):
            return Response(
                {
                    'phone': (
                        'Phone must be in Armenian format: +374XXXXXXXX.'
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            validate_email(email)
        except ValidationError:
            return Response(
                {'detail': 'Enter a valid email address.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        feedback = Feedback.objects.create(
            text=text,
            phone=phone,
            email=email,
        )

        # The database record is the source of truth. If email delivery is
        # temporarily unavailable, the user's request must not be lost.
        try:
            send_mail(
                'Обратная связь',
                f'Текст: {text},\nМаил: {email},\nТелефон: {phone}',
                settings.DEFAULT_FROM_EMAIL,
                ['damir.gilmanov2015@yandex.ru'],
            )
        except Exception:
            logger.exception(
                'Failed to email support notification for feedback id=%s',
                feedback.pk,
            )

        return Response(
            {'detail': 'Your inquiry has been sent to the administrator.'},
            status=status.HTTP_201_CREATED,
        )
