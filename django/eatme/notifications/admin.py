from django import forms
from django.contrib import admin, messages
from django.contrib.auth import get_user_model
from django.db import transaction
from django.urls import reverse
from django.utils.html import format_html
from urllib.parse import urlencode

from .models import (
    DeviceToken,
    Notification,
    NotificationAlarm,
    NotificationBroadcast,
)
from .services import get_broadcast_recipient_queryset
from .tasks import send_notification_broadcast

User = get_user_model()


@admin.register(DeviceToken)
class DeviceTokenAdmin(admin.ModelAdmin):
    list_display = ('user', 'device_type', 'is_active', 'created')
    search_fields = ('user__username', 'token')
    list_filter = ('device_type', 'is_active')


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    """Per-user notifications.

    Mass/group sending lives in NotificationBroadcast so a large dispatch never
    blocks the Django admin HTTP request and every campaign has an audit trail.
    """

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

    def get_search_results(self, request, queryset, search_term):
        # Internal helper used by the broadcast detail page. A query such as
        # "broadcast:12" shows only Notification rows created by campaign 12.
        prefix = 'broadcast:'
        normalized = search_term.strip().lower()
        if normalized.startswith(prefix):
            broadcast_id = normalized[len(prefix):].strip()
            if broadcast_id.isdigit():
                return queryset.filter(data__broadcast_id=broadcast_id), False

        return super().get_search_results(request, queryset, search_term)


class NotificationBroadcastAdminForm(forms.ModelForm):
    class Meta:
        model = NotificationBroadcast
        fields = '__all__'

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        # On the change/view page NotificationBroadcastAdmin marks campaign
        # fields as readonly. Django then removes them from self.fields, so every
        # custom form tweak must tolerate the field being absent.
        if 'user' in self.fields:
            self.fields['user'].queryset = User.objects.filter(
                is_active=True,
            ).order_by('username')

        if 'audience' in self.fields:
            self.fields['audience'].help_text = (
                'Выберите: все пользователи, покупатели, продавцы или одного пользователя.'
            )

        if 'type' in self.fields:
            self.fields['type'].help_text = (
                'Для обычной ручной рассылки используйте «Новость от администрации».'
            )

    def clean(self):
        cleaned = super().clean()
        audience = cleaned.get('audience')

        # Existing campaigns are readonly in the admin change page, therefore
        # audience/user are intentionally absent from cleaned_data there.
        if audience is None:
            return cleaned

        user = cleaned.get('user')

        if audience == NotificationBroadcast.Audience.SPECIFIC and user is None:
            self.add_error(
                'user',
                'Выберите пользователя для точечной отправки.',
            )

        if audience != NotificationBroadcast.Audience.SPECIFIC:
            # Do not retain a stale dropdown value when the campaign targets a group.
            cleaned['user'] = None

        return cleaned


@admin.register(NotificationBroadcast)
class NotificationBroadcastAdmin(admin.ModelAdmin):
    form = NotificationBroadcastAdminForm

    list_display = (
        'title',
        'audience_label',
        'status',
        'recipients_count',
        'notifications_created',
        'created',
        'sent_at',
    )
    list_filter = (
        'audience',
        'status',
        'type',
        'created',
    )
    search_fields = (
        'title',
        'body',
        'user__username',
        'user__email',
    )
    autocomplete_fields = ('user',)
    actions = ('retry_broadcasts',)

    readonly_fields = (
        'status',
        'recipients_count',
        'notifications_created',
        'created_by',
        'recipient_notifications_link',
        'error_message',
        'created',
        'sent_at',
    )

    fieldsets = (
        ('Получатели', {
            'fields': ('audience', 'user'),
            'description': (
                'Если выбран «Конкретный пользователь», укажите его ниже. '
                'Для остальных вариантов поле пользователя игнорируется.'
            ),
        }),
        ('Уведомление', {
            'fields': ('type', 'title', 'body', 'data'),
        }),
        ('Состояние рассылки', {
            'fields': (
                'status',
                'recipients_count',
                'notifications_created',
                'created_by',
                'recipient_notifications_link',
                'created',
                'sent_at',
                'error_message',
            ),
        }),
    )

    @admin.display(description='Получатели')
    def audience_label(self, obj):
        if obj.audience == NotificationBroadcast.Audience.SPECIFIC:
            return f'Конкретный: {obj.user or "—"}'
        return obj.get_audience_display()

    @admin.display(description='Уведомления получателей')
    def recipient_notifications_link(self, obj):
        if obj is None or not obj.pk:
            return '—'

        url = reverse('admin:notifications_notification_changelist')
        query = urlencode({'q': f'broadcast:{obj.pk}'})
        count = Notification.objects.filter(
            data__broadcast_id=str(obj.pk),
        ).count()

        return format_html(
            '<a href="{}?{}">Открыть уведомления ({})</a>',
            url,
            query,
            count,
        )

    def get_readonly_fields(self, request, obj=None):
        readonly = list(super().get_readonly_fields(request, obj))
        if obj is not None:
            # A campaign is immutable once created. This prevents a completed
            # campaign from being silently edited into something its audit row
            # no longer represents.
            readonly.extend(['audience', 'user', 'type', 'title', 'body', 'data'])
        return tuple(dict.fromkeys(readonly))

    @admin.action(description='🔁 Повторить выбранные незавершённые рассылки')
    def retry_broadcasts(self, request, queryset):
        queued = 0
        skipped = 0

        for broadcast in queryset:
            if broadcast.status == NotificationBroadcast.Status.COMPLETED:
                skipped += 1
                continue

            NotificationBroadcast.objects.filter(pk=broadcast.pk).update(
                status=NotificationBroadcast.Status.PENDING,
                error_message='',
                sent_at=None,
            )
            transaction.on_commit(
                lambda broadcast_id=broadcast.pk: send_notification_broadcast.delay(broadcast_id)
            )
            queued += 1

        if queued:
            self.message_user(
                request,
                f'Повторно поставлено в очередь: {queued}.',
                level=messages.SUCCESS,
            )
        if skipped:
            self.message_user(
                request,
                f'Уже завершённые рассылки пропущены: {skipped}.',
                level=messages.WARNING,
            )

    def save_model(self, request, obj, form, change):
        if change:
            super().save_model(request, obj, form, change)
            return

        obj.created_by = request.user
        obj.status = NotificationBroadcast.Status.PENDING
        obj.error_message = ''
        super().save_model(request, obj, form, change)

        recipients_count = get_broadcast_recipient_queryset(obj).count()
        obj.recipients_count = recipients_count
        obj.save(update_fields=['recipients_count'])

        # Queue only after the DB transaction commits. If Celery/Redis is down,
        # the campaign stays visible as PENDING and can be retried after fixing it.
        transaction.on_commit(
            lambda broadcast_id=obj.pk: send_notification_broadcast.delay(broadcast_id)
        )

        self.message_user(
            request,
            f'Рассылка поставлена в очередь. Получателей: {recipients_count}.',
            level=messages.SUCCESS,
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
        'companies',
    )
