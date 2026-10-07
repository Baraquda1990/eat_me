from django.urls import path

from .api import ProfileUpdateRetrieve,ResetPassword

urlpatterns = [
    path('profile/', ProfileUpdateRetrieve.as_view()),
    path('reset_password/',ResetPassword.as_view())
]
