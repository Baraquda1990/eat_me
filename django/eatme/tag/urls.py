from django.urls import path
from .api import TagsList

urlpatterns = [
    path('tag/',TagsList.as_view())
]
