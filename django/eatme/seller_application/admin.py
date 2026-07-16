from django.contrib import admin
from django.contrib import messages
from django.utils.html import format_html

from .services import (
    approve_application,
    reject_application,
    request_changes_application,
)

from .models import (
    BusinessCategory,
    CompanyChannel,
    SellerApplication,
    SellerApplicationDocument,
)


class SellerApplicationDocumentInline(admin.TabularInline):
    model = SellerApplicationDocument
    extra = 0

    fields = (
        'document_type',
        'file',
        'original_name',
        'description',
        'uploaded_by',
        'created',
    )

    readonly_fields = (
        'original_name',
        'uploaded_by',
        'created',
    )


@admin.register(CompanyChannel)
class CompanyChannelAdmin(admin.ModelAdmin):
    list_display = (
        'code',
        'is_active',
        'created',
    )

    list_filter = (
        'is_active',
    )

    ordering = (
        'code',
    )


@admin.register(BusinessCategory)
class BusinessCategoryAdmin(admin.ModelAdmin):
    list_display = (
        'name_en',
        'name_ru',
        'name_hy',
        'code',
        'is_active',
        'sort_order',
    )

    list_filter = (
        'is_active',
        'allowed_channels',
    )

    search_fields = (
        'name_en',
        'name_ru',
        'name_hy',
        'code',
    )

    filter_horizontal = (
        'allowed_channels',
    )

    prepopulated_fields = {
        'code': ('name_en',),
    }

    ordering = (
        'sort_order',
        'name_en',
    )


@admin.action(
    description='Одобрить выбранные заявки'
)
def approve_selected(
    modeladmin,
    request,
    queryset,
):
    approved = 0

    for application in queryset:
        try:
            approve_application(
                application,
                request.user,
            )
            approved += 1

        except Exception as exc:
            modeladmin.message_user(
                request,
                f'Ошибка заявки #{application.id}: {exc}',
                level=messages.ERROR,
            )

    modeladmin.message_user(
        request,
        f'Одобрено заявок: {approved}',
        level=messages.SUCCESS,
    )


@admin.action(
    description='Отклонить выбранные заявки'
)
def reject_selected(
    modeladmin,
    request,
    queryset,
):
    rejected = 0

    for application in queryset:
        try:
            reject_application(
                application,
                request.user,
            )
            rejected += 1

        except Exception as exc:
            modeladmin.message_user(
                request,
                f'Ошибка заявки #{application.id}: {exc}',
                level=messages.ERROR,
            )

    modeladmin.message_user(
        request,
        f'Отклонено заявок: {rejected}',
        level=messages.SUCCESS,
    )


@admin.action(description='Вернуть выбранные заявки на исправление')
def request_changes_selected(modeladmin, request, queryset):
    changed = 0
    for application in queryset:
        try:
            request_changes_application(
                application,
                request.user,
                application.admin_comment,
            )
            changed += 1
        except Exception as exc:
            modeladmin.message_user(
                request,
                f'Ошибка заявки #{application.id}: {exc}',
                level=messages.ERROR,
            )

    if changed:
        modeladmin.message_user(
            request,
            f'Возвращено на исправление: {changed}',
            level=messages.SUCCESS,
        )


@admin.register(SellerApplication)
class SellerApplicationAdmin(admin.ModelAdmin):
    actions = (
        approve_selected,
        reject_selected,
        request_changes_selected,
    )

    list_display = (
        'id',
        'organization_name',
        'user',
        'colored_status',
        'display_channels',
        'business_category',
        'current_step',
        'submitted_at',
        'created',
    )

    list_display_links = (
        'id',
        'organization_name',
    )

    list_filter = (
        'status',
        'requested_channels',
        'business_category',
        'created',
    )

    search_fields = (
        'organization_name',
        'tax_number',
        'business_email',
        'business_phone',
        'contact_name',
        'contact_phone',
        'user__username',
        'user__email',
    )

    filter_horizontal = (
        'requested_channels',
    )

    readonly_fields = (
        'created',
        'updated',
        'submitted_at',
        'reviewed_at',
        'reviewed_by',
        'company',
    )

    fieldsets = (
        (
            'Состояние заявки',
            {
                'fields': (
                    'user',
                    'status',
                    'current_step',
                    'requested_channels',
                    'admin_comment',
                ),
            },
        ),
        (
            'Организация',
            {
                'fields': (
                    'organization_name',
                    'tax_number',
                    'business_category',
                    'address',
                    'latitude',
                    'longitude',
                    'business_phone',
                    'business_email',
                ),
            },
        ),
        (
            'Контактное лицо',
            {
                'fields': (
                    'contact_name',
                    'contact_phone',
                    'contact_email',
                ),
            },
        ),
        (
            'Банковские реквизиты',
            {
                'fields': (
                    'bank_name',
                    'iban',
                    'account_holder_name',
                ),
            },
        ),
        (
            'Публичное оформление',
            {
                'fields': (
                    'logo',
                    'public_description',
                ),
            },
        ),
        (
            'Проверка',
            {
                'fields': (
                    'submitted_at',
                    'reviewed_at',
                    'reviewed_by',
                    'company',
                    'created',
                    'updated',
                ),
            },
        ),
    )

    inlines = [
        SellerApplicationDocumentInline,
    ]

    @admin.display(description='Направления')
    def display_channels(self, obj):
        return ', '.join(
            obj.requested_channels.values_list(
                'code',
                flat=True,
            )
        ) or '—'

    @admin.display(description='Статус')
    def colored_status(self, obj):
        colors = {
            'draft': '#808080',
            'pending': '#d1bc00',
            'approved': '#00a651',
            'rejected': '#dc3545',
            'changes_requested': '#fd7e14',
        }

        color = colors.get(
            obj.status,
            '#808080',
        )

        return format_html(
            '<b style="color:{};">{}</b>',
            color,
            obj.get_status_display(),
        )


@admin.register(SellerApplicationDocument)
class SellerApplicationDocumentAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'application',
        'document_type',
        'original_name',
        'uploaded_by',
        'created',
    )

    list_filter = (
        'document_type',
        'created',
    )

    search_fields = (
        'application__organization_name',
        'application__tax_number',
        'original_name',
        'uploaded_by__username',
    )

    readonly_fields = (
        'original_name',
        'created',
    )