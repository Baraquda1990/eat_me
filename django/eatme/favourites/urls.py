from django.urls import path
from .api import CreateFavourites,ListFavorites,DestroyFavorites,ListFavouritesDetail

urlpatterns = [
    path('favourites/create/',CreateFavourites.as_view()),
    path('favourites/list/',ListFavorites.as_view()),
    path('favourites/destroy/<slug:slug>',DestroyFavorites.as_view()),
    path('favourites/detail/',ListFavouritesDetail.as_view()),
]