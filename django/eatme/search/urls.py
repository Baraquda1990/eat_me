from django.urls import path
from .api import SearchApi

urlpatterns = [
    path('search',SearchApi.as_view())
]