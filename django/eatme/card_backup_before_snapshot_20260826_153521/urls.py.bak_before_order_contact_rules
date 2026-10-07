from django.urls import path
from .hot_reservation_api import HotReserveApi
from .delivery_api import SellerDeliveriesApi, SellerDeliveryStatusApi
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

    path(
        'seller/deliveries/',
        SellerDeliveriesApi.as_view(),
        name='seller-deliveries',
    ),
    path(
        'seller/deliveries/<int:item_id>/status/',
        SellerDeliveryStatusApi.as_view(),
        name='seller-delivery-status',
    ),
    path('cart/reserve-hot/', HotReserveApi.as_view(), name='cart-reserve-hot'),
]
