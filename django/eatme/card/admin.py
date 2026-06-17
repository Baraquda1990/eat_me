from django.contrib import admin
from .models import Card,Card_item

@admin.register(Card)
class CardAdmin(admin.ModelAdmin):
    list_display=('user','created','status')
    list_display_links=('user',)

@admin.register(Card_item)
class Card_itemAdmin(admin.ModelAdmin):
    list_display=('card','product','added','quantity','price_by_quantity')
    list_display_links=('card',)
