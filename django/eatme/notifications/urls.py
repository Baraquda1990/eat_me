from django.urls import path

from .api import (
    NotificationsList,
    NotificationsUnreadCount,
    NotificationRead,
    DeviceTokenCreate,
    NotificationAlarmListCreate,
    NotificationAlarmDelete,
)

urlpatterns = [
    path('notifications/', NotificationsList.as_view()),
    path('notifications/unread-count/', NotificationsUnreadCount.as_view()),
    path('notifications/<int:pk>/read/', NotificationRead.as_view()),
    path('notifications/device/', DeviceTokenCreate.as_view()),
    path('notifications/alarms/', NotificationAlarmListCreate.as_view()),
    path('notifications/alarms/<int:id>/', NotificationAlarmDelete.as_view()),
]
