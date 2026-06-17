from django.contrib import admin

from .models import Profile,OrgProf

@admin.register(Profile)
class Profile_admin(admin.ModelAdmin):
    list_display=('user','type_user')
    list_display_links=('user',)

@admin.register(OrgProf)
class OrgProf_admin(admin.ModelAdmin):
    list_display=('user','company')
    list_display_links=('user','company')