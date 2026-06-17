from django.contrib import admin
from django.contrib.auth import get_user_model

from .models import DeviceToken, Notification, NotificationAlarm
from .services import send_push_to_user

User = get_user_model()


@admin.register(DeviceToken)
class DeviceTokenAdmin(admin.ModelAdmin):
    list_display = ('user', 'device_type', 'is_active', 'created')
    search_fields = ('user__username', 'token')
    list_filter = ('device_type', 'is_active')


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = (
        'user',
        'type',
        'title',
        'is_read',
        'created',
    )

    search_fields = (
        'user__username',
        'title',
        'body',
    )

    list_filter = (
        'type',
        'is_read',
        'created',
    )

    actions = ['send_to_all_users']

    @admin.action(description='📢 Разослать всем пользователям')
    def send_to_all_users(self, request, queryset):

        for notification in queryset:

            users = User.objects.all()

            for user in users:

                Notification.objects.create(
                    user=user,
                    type='admin_news',
                    title=notification.title,
                    body=notification.body,
                    data=notification.data,
                )

                send_push_to_user(
                    user=user,
                    title=notification.title,
                    body=notification.body,
                    data={
                        'type': 'admin_news',
                    },
                )

        self.message_user(
            request,
            'Рассылка успешно отправлена'
        )


@admin.register(NotificationAlarm)
class NotificationAlarmAdmin(admin.ModelAdmin):
    list_display = (
        'user',
        'product_type',
        'notify_at',
        'is_active',
        'created',
    )

    search_fields = (
        'user__username',
    )

    list_filter = (
        'product_type',
        'is_active',
        'created',
    )

    filter_horizontal = (
        'tags',
    )
