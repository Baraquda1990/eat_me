from django.contrib import admin
from django.utils import timezone

from .models import Review, ReviewEditRequest


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'user',
        'company',
        'rating',
        'created',
    )
    list_filter = (
        'created',
        'company',
    )
    search_fields = (
        'user__username',
        'company__name',
        'comment',
    )
    readonly_fields = (
        'rating',
        'created',
    )


@admin.action(description='Разрешить редактирование выбранных отзывов')
def approve_review_edit(modeladmin, request, queryset):
    now = timezone.now()
    updated = queryset.filter(
        status=ReviewEditRequest.Status.PENDING,
    ).update(
        status=ReviewEditRequest.Status.APPROVED,
        decided_at=now,
        decided_by=request.user,
    )
    modeladmin.message_user(
        request,
        f'Разрешено запросов: {updated}',
    )


@admin.action(description='Запретить редактирование выбранных отзывов')
def reject_review_edit(modeladmin, request, queryset):
    now = timezone.now()
    updated = queryset.filter(
        status=ReviewEditRequest.Status.PENDING,
    ).update(
        status=ReviewEditRequest.Status.REJECTED,
        decided_at=now,
        decided_by=request.user,
    )
    modeladmin.message_user(
        request,
        f'Отклонено запросов: {updated}',
    )


@admin.register(ReviewEditRequest)
class ReviewEditRequestAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'review',
        'user',
        'status',
        'created',
        'decided_at',
        'decided_by',
        'used_at',
    )
    list_filter = (
        'status',
        'created',
        'decided_at',
    )
    search_fields = (
        'user__username',
        'review__company__name',
        'review__comment',
    )
    readonly_fields = (
        'review',
        'user',
        'created',
        'used_at',
    )
    actions = (
        approve_review_edit,
        reject_review_edit,
    )
