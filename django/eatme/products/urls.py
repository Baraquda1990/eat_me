from django.urls import path
from .api import ProductsList,ProductsDetail,MyProductsList,ProductsCreate,MyProductUpdate,MyProductDelete,RecommendedProductsList
'''
Эндпоинт предоставления списка Каталога
'''
urlpatterns = [
    path('products/', ProductsList.as_view()),
    path('products/recommended/', RecommendedProductsList.as_view()),
    path('products/my/', MyProductsList.as_view()),
    path('products/create/', ProductsCreate.as_view()),
    path('products/<slug:slug>/', ProductsDetail.as_view()),
    path('products/<slug:slug>/update/', MyProductUpdate.as_view()),
    path('products/<slug:slug>/delete/', MyProductDelete.as_view()),
]
