from django.urls import path
from .api import ProfileUpdateRetrieve

urlpatterns=[
    path('profile/', ProfileUpdateRetrieve.as_view()),
]