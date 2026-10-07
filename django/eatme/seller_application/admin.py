from django.contrib import admin
from django.contrib import messages
from django.utils.html import format_html
from django.http import HttpResponseRedirect

from .services import (
    approve_application,
    reject_application,
    request_changes_application,
)

from .models import (
    BusinessCategory,
    CompanyChannel,
    SellerAgencyAgreementAcceptance,
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


class SellerAgencyAgreementAcceptanceInline(admin.StackedInline):
    model = SellerAgencyAgreementAcceptance
    extra = 0
    can_delete = False

    fields = (
        'version',
        'language',
        'accepted_at',
        'snapshot',
        'template_sha256',
        'document_sha256',
        'ip_address',
        'user_agent',
        'created',
        'updated',
    )
    readonly_fields = fields


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
    change_form_template = 'admin/seller_application/sellerapplication/change_form.html'

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
        'status',
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
        SellerAgencyAgreementAcceptanceInline,
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

    def response_change(self, request, obj):
        # ==========================
        # ОДОБРИТЬ
        # ==========================
        if '_approve_application' in request.POST:
            try:
                company = approve_application(
                    obj,
                    request.user,
                )

                self.message_user(
                    request,
                    (
                        f'Заявка #{obj.id} одобрена. '
                        f'Компания "{company.name}" создана/обновлена, '
                        f'пользователь привязан к компании.'
                    ),
                    level=messages.SUCCESS,
                )

            except Exception as exc:
                self.message_user(
                    request,
                    f'Ошибка при одобрении заявки: {exc}',
                    level=messages.ERROR,
                )

            return HttpResponseRedirect(request.path)

        # ==========================
        # ВЕРНУТЬ НА ИСПРАВЛЕНИЕ
        # ==========================
        if '_request_changes' in request.POST:
            try:
                request_changes_application(
                    obj,
                    request.user,
                    obj.admin_comment,
                )

                self.message_user(
                    request,
                    f'Заявка #{obj.id} возвращена пользователю на исправление.',
                    level=messages.SUCCESS,
                )

            except Exception as exc:
                self.message_user(
                    request,
                    f'Ошибка: {exc}',
                    level=messages.ERROR,
                )

            return HttpResponseRedirect(request.path)

        # ==========================
        # ОТКЛОНИТЬ
        # ==========================
        if '_reject_application' in request.POST:
            try:
                reject_application(
                    obj,
                    request.user,
                    obj.admin_comment,
                )

                self.message_user(
                    request,
                    f'Заявка #{obj.id} отклонена.',
                    level=messages.SUCCESS,
                )

            except Exception as exc:
                self.message_user(
                    request,
                    f'Ошибка при отклонении заявки: {exc}',
                    level=messages.ERROR,
                )

            return HttpResponseRedirect(request.path)

        return super().response_change(request, obj)


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

@admin.register(SellerAgencyAgreementAcceptance)
class SellerAgencyAgreementAcceptanceAdmin(admin.ModelAdmin):
    list_display = (
        'application',
        'version',
        'language',
        'accepted_at',
        'ip_address',
    )
    list_filter = ('version', 'language', 'accepted_at')
    search_fields = (
        'application__organization_name',
        'application__user__username',
        'document_sha256',
    )
    readonly_fields = (
        'application',
        'version',
        'language',
        'template_sha256',
        'document_sha256',
        'snapshot',
        'accepted_at',
        'ip_address',
        'user_agent',
        'created',
        'updated',
    )
