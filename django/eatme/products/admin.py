from django.contrib import admin

from .models import Products

@admin.register(Products)
class Company_admin(admin.ModelAdmin):
    list_display=('name','company')
    list_display_links=('name',)
    prepopulated_fields={'slug':('name',)}
