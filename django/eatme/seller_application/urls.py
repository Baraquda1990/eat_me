from django.urls import path

from .views import (
    BusinessCategoryListApi,
    CompanyChannelListApi,
    MySellerApplicationApi,
    SellerApplicationDetailApi,
    SellerApplicationDocumentCreateApi,
    SellerApplicationDocumentDeleteApi,
    SellerApplicationSubmitApi,
)


urlpatterns = [
    path(
        'seller-applications/channels/',
        CompanyChannelListApi.as_view(),
        name='seller-application-channels',
    ),
    path(
        'seller-applications/categories/',
        BusinessCategoryListApi.as_view(),
        name='seller-application-categories',
    ),
    path(
        'seller-applications/my/',
        MySellerApplicationApi.as_view(),
        name='my-seller-application',
    ),
    path(
        'seller-applications/<int:pk>/',
        SellerApplicationDetailApi.as_view(),
        name='seller-application-detail',
    ),
    path(
        'seller-applications/<int:pk>/documents/',
        SellerApplicationDocumentCreateApi.as_view(),
        name='seller-application-document-create',
    ),
    path(
        'seller-applications/documents/<int:pk>/',
        SellerApplicationDocumentDeleteApi.as_view(),
        name='seller-application-document-delete',
    ),
    path(
        'seller-applications/<int:pk>/submit/',
        SellerApplicationSubmitApi.as_view(),
        name='seller-application-submit',
    ),
]