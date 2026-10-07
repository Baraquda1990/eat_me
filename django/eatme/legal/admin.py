from django.contrib import admin

from .models import LegalConsent, LegalDocument


@admin.register(LegalDocument)
class LegalDocumentAdmin(admin.ModelAdmin):
    list_display = (
        'document_type',
        'version',
        'placement',
        'requires_acceptance',
        'is_active',
        'effective_at',
    )
    list_filter = ('document_type', 'placement', 'requires_acceptance', 'is_active')
    search_fields = ('document_type', 'version', 'title_en', 'title_ru', 'title_hy')
    readonly_fields = ('hash_en', 'hash_ru', 'hash_hy', 'created_at', 'updated_at')


@admin.register(LegalConsent)
class LegalConsentAdmin(admin.ModelAdmin):
    list_display = (
        'user',
        'document_type',
        'document_version',
        'language',
        'source',
        'accepted_at',
    )
    list_filter = ('document_type', 'document_version', 'language', 'source')
    search_fields = ('user__username', 'user__email', 'document_hash')
    readonly_fields = (
        'user',
        'document',
        'document_type',
        'document_version',
        'language',
        'document_hash',
        'source',
        'ip_address',
        'user_agent',
        'accepted_at',
    )

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
