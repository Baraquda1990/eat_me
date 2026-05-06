from django.urls import path
from .api import ProductsList,ProductsDetail
'''
Эндпоинт предоставления списка Каталога
'''
urlpatterns = [
    path('products/',ProductsList.as_view()),
    path('products/<slug:slug>/',ProductsDetail.as_view()),
]