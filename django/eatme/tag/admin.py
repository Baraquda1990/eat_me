from django.contrib import admin

from .models import Tag


@admin.register(Tag)
class TagAdmin(admin.ModelAdmin):
    list_display = ('name', 'name_en', 'name_hy', 'slug')
    list_display_links = ('name',)
    search_fields = ('name', 'name_en', 'name_hy', 'slug')
    prepopulated_fields = {'slug': ('name',)}

    fieldsets = (
        (
            'Названия',
            {
                'fields': (
                    'name',
                    'name_en',
                    'name_hy',
                ),
            },
        ),
        (
            'Технические данные',
            {
                'fields': (
                    'slug',
                    'image',
                ),
            },
        ),
    )
