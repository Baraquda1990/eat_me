from django.urls import path
from .api import AddToCartApi, CartRetrieveApi, CartUpdateApi, CheckoutApi, RemoveCartItemApi, UpdateQuantityApi, PastOrdersApi, SellerStatsApi,SellerSalesApi,SellerOrderDetailApi

urlpatterns = [
    path('cart/', CartRetrieveApi.as_view(), name='cart'),
    path('cart/add/', AddToCartApi.as_view(), name='cart-add'),
    path('cart/update/', CartUpdateApi.as_view(), name='cart-update'),
    path('cart/checkout/', CheckoutApi.as_view(), name='cart-checkout'),
    path('cart/item/<slug:slug>/', RemoveCartItemApi.as_view(), name='cart-item-delete'),
    path('cart/item/<slug:slug>/update/', UpdateQuantityApi.as_view()),
    path('cart/past-orders/', PastOrdersApi.as_view(), name='past-orders'),
    path('seller/stats/', SellerStatsApi.as_view(), name='seller-stats'),
    path('seller/sales/', SellerSalesApi.as_view(), name='seller-sales'),
    path('seller/orders/<int:card_id>/<int:company_id>/',SellerOrderDetailApi.as_view(),name='seller-order-detail'),
]
