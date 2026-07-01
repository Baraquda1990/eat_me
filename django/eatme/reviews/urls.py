from django.urls import path
from .api import ReviewCreateApi, CompanyReviewsApi, MyReviewsApi, SellerReviewsApi, MyReviewDetailApi


urlpatterns = [
    path('reviews/add/', ReviewCreateApi.as_view(), name='review-add'),
    path('reviews/my/', MyReviewsApi.as_view(), name='my-reviews'),
    path('reviews/my/<int:pk>/', MyReviewDetailApi.as_view(), name='my-review-detail'),
    path('reviews/seller/', SellerReviewsApi.as_view()),
    path(
        'company/<slug:slug>/reviews/',
        CompanyReviewsApi.as_view(),
        name='company-reviews'
    ),
]
