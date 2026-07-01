from django.urls import path
from . import views

urlpatterns = [
    path('', views.home, name='home'),
    path('token/', views.get_jwt_token, name='get_token'),
    path('projects/', views.projects, name='projects'),
]