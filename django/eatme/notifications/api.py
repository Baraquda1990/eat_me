from datetime import timedelta

from django.db.models import Q
from django.utils import timezone

from rest_framework.generics import (
    ListAPIView,
    ListCreateAPIView,
    DestroyAPIView,
)
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import DeviceToken, Notification, NotificationAlarm
from .serializers import (
    DeviceTokenSerializer,
    NotificationSerializer,
    NotificationAlarmSerializer,
)
from .services import send_push_to_user
from notifications.i18n import tr


class NotificationsList(ListAPIView):
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(
            user=self.request.user
        )


class NotificationsUnreadCount(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        count = Notification.objects.filter(
            user=request.user,
            is_read=False,
        ).count()
        return Response({'count': count})


class NotificationRead(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        notification = Notification.objects.filter(
            id=pk,
            user=request.user,
        ).first()

        if notification is None:
            return Response(
                {'detail': 'Уведомление не найдено'},
                status=404,
            )

        notification.is_read = True
        notification.save(update_fields=['is_read'])

        return Response({'status': 'ok'})


class DeviceTokenCreate(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = DeviceTokenSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        DeviceToken.objects.update_or_create(
            token=serializer.validated_data['token'],
            defaults={
                'user': request.user,
                'device_type': serializer.validated_data.get(
                    'device_type',
                    'android',
                ),
                'is_active': True,
            },
        )

        return Response({'status': 'ok'})


class NotificationAlarmListCreate(ListCreateAPIView):
    serializer_class = NotificationAlarmSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        now = timezone.now()

        # Expired alarms must not remain active forever. For old rows without
        # notify_until, notify_at is treated as their deadline.
        NotificationAlarm.objects.filter(
            user=self.request.user,
            is_active=True,
        ).filter(
            Q(notify_until__lte=now)
            | Q(notify_until__isnull=True, notify_at__lte=now)
        ).update(is_active=False)

        return NotificationAlarm.objects.filter(
            user=self.request.user
        )

    def perform_create(self, serializer):
        alarm = serializer.save()

        # Schedule exact automatic deactivation at the end of the selected
        # alarm window. The UI replaces an edited alarm by delete + create,
        # so stale ETA tasks are harmless and additionally protected by the
        # expected deadline argument inside the task.
        deadline = alarm.notify_until or alarm.notify_at
        from .tasks import expire_notification_alarm
        expire_notification_alarm.apply_async(
            args=[alarm.id, deadline.isoformat()],
            eta=deadline,
        )

        # notify_at хранится в UTC, а offset приходит с телефона пользователя.
        # Так текст уведомления показывает именно выбранное пользователем
        # локальное время независимо от страны.
        notify_local = alarm.notify_at + timedelta(
            minutes=alarm.timezone_offset_minutes
        )
        notify_at_iso = alarm.notify_at.isoformat()
        notify_text = notify_local.strftime('%d.%m.%Y %H:%M')

        already_exists = Notification.objects.filter(
            user=self.request.user,
            type='alarm_match',
            data__notify_at=notify_at_iso,
        ).exists()

        if already_exists:
            return

        title = tr(self.request.user, 'alarm_saved_title')
        body = tr(
            self.request.user,
            'alarm_saved_body',
            date=notify_text,
        )

        Notification.objects.create(
            user=self.request.user,
            type='alarm_match',
            title=title,
            body=body,
            data={
                'alarm_id': alarm.id,
                'product_type': alarm.product_type,
                'notify_at': notify_at_iso,
                'timezone_offset_minutes': alarm.timezone_offset_minutes,
                'notify_text': notify_text,
            },
        )

        send_push_to_user(
            user=self.request.user,
            title=title,
            body=body,
            data={
                'type': 'alarm_created',
                'alarm_id': alarm.id,
                'product_type': alarm.product_type,
                'notify_at': notify_at_iso,
                'timezone_offset_minutes': alarm.timezone_offset_minutes,
                'notify_text': notify_text,
            },
        )


class NotificationAlarmDelete(DestroyAPIView):
    serializer_class = NotificationAlarmSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = 'id'

    def get_queryset(self):
        return NotificationAlarm.objects.filter(
            user=self.request.user
        )