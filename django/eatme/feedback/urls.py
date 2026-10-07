from django.urls import path
from .api import FeedbackApi

urlpatterns = [
    path('feedback/', FeedbackApi.as_view())
]