from django.contrib.auth import get_user_model
from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import Notification


User = get_user_model()


@receiver(post_save, sender=User)
def create_welcome_notification(sender, instance, created, **kwargs):
    """Create one persistent in-app welcome notification for a new account."""
    if not created:
        return

    # Admin/service accounts do not need a customer welcome message.
    if instance.is_staff or instance.is_superuser:
        return

    Notification.objects.get_or_create(
        user=instance,
        type=Notification.Type.WELCOME,
        defaults={
            'title': 'Welcome to Appsosa!',
            'body': (
                'Great to have you here! Discover nearby deals, save your '
                'favorite places and get notified about new offers.'
            ),
            'data': {
                'system': 'welcome',
            },
        },
    )
