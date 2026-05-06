from django.urls import path
from .api import CompanyDetail
'''
Эндпоинт предоставления списка Каталога
'''
urlpatterns = [
    path('company/<slug:slug>/',CompanyDetail.as_view())
]