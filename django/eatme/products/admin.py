from django.contrib import admin

from .models import Products


@admin.register(Products)
class ProductsAdmin(admin.ModelAdmin):
    list_display = (
        'name',
        'company',
        'type',
        'price',
        'discount',
        'count',
        'delivery_type',
        'is_promoted',
        'promotion_until',
    )

    list_display_links = (
        'name',
    )

    list_filter = (
        'type',
        'delivery_type',
        'is_promoted',
        'company',
    )

    search_fields = (
        'name',
        'company__name',
    )

    prepopulated_fields = {
        'slug': ('name',)
    }

    filter_horizontal = (
        'tag',
    )

    fieldsets = (
        (
            'Основная информация',
            {
                'fields': (
                    'company',
                    'name',
                    'slug',
                    'image',
                    'description',
                    'tag',
                )
            }
        ),
        (
            'Цена',
            {
                'fields': (
                    'price',
                    'discount',
                    'count',
                )
            }
        ),
        (
            'Тип предложения',
            {
                'fields': (
                    'type',
                )
            }
        ),
        (
            'Упаковка и доставка',
            {
                'fields': (
                    'package_quantity',
                    'weight',
                    'delivery_type',
                    'delivery_days',
                )
            }
        ),
        (
            'Сроки',
            {
                'fields': (
                    'expiration_date',
                    'can_use_until',
                )
            }
        ),
        (
            'Продвижение',
            {
                'fields': (
                    'is_promoted',
                    'promotion_until',
                )
            }
        ),
    )
