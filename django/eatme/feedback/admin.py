from django.contrib import admin

from .models import Feedback


@admin.register(Feedback)
class FeedbackAdmin(admin.ModelAdmin):
    list_display = (
        'phone',
        'email',
        'timedate',
    )

    list_display_links = (
        'email',
    )

    list_filter = (
        'timedate',
    )

    search_fields = (
        'phone',
        'email',
    )


