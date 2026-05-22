from django.urls import path
from .api import CompanyDetail,CompanyList
'''
Эндпоинт предоставления списка Каталога
'''
urlpatterns = [
    path('company/', CompanyList.as_view()),
    path('company/<slug:slug>/',CompanyDetail.as_view())
]