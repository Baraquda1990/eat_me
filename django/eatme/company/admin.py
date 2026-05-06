from django.contrib import admin
from .models import Company

@admin.register(Company)
class Company_admin(admin.ModelAdmin):
    list_display=('name','address')
    list_display_links=('name',)
    prepopulated_fields={'slug':('name',)}
