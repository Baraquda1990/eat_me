from django.contrib import admin

from .models import Card, Card_item


@admin.register(Card)
class CardAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'user',
        'created',
        'status',
        'buyer_phone_snapshot',
    )
    list_display_links = ('id', 'user')
    list_filter = ('status', 'created')
    search_fields = (
        'user__username',
        'buyer_username_snapshot',
        'buyer_phone_snapshot',
    )


@admin.register(Card_item)
class CardItemAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'card',
        'snapshot_product_name',
        'added',
        'quantity',
        'unit_price',
        'price_by_quantity',
        'delivery_status',
    )
    list_display_links = ('id', 'card')
    list_filter = ('delivery_status', 'product_type_snapshot')
    search_fields = (
        'product_slug_snapshot',
        'product__slug',
        'product__name',
    )
    readonly_fields = (
        'product_snapshot',
        'unit_price_snapshot',
        'company_id_snapshot',
        'product_slug_snapshot',
        'product_type_snapshot',
    )
