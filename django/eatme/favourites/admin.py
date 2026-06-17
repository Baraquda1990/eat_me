from django.contrib import admin
from .models import Favourites

@admin.register(Favourites)
class FavouritesAdmin(admin.ModelAdmin):
    list_display=('products','user','created')
    list_display_links=('products',)