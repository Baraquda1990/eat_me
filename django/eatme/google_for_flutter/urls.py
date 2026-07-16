from django.urls import path
from .api import GoogleLoginApi

urlpatterns = [
    path(
        'google-login/',
        GoogleLoginApi.as_view(),
        name='google-login',
    ),
]