from django.urls import path
from .api import CompanyDetail,CompanyList,CompanyCreate,MyCompanyList,MyCompanyDetailUpdate
'''
Эндпоинт предоставления списка Каталога
'''
urlpatterns = [
    path('company/', CompanyList.as_view()),

    path('company/my/', MyCompanyList.as_view()),
    path('company/add/', CompanyCreate.as_view()),

    path(
        'company/<slug:slug>/update/',
        MyCompanyDetailUpdate.as_view()
    ),

    path(
        'company/<slug:slug>/',
        CompanyDetail.as_view()
    ),
]
