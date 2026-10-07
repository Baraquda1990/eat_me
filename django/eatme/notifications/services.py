import firebase_admin
from firebase_admin import credentials
from firebase_admin import messaging

from django.conf import settings

from .models import DeviceToken


def init_firebase():
    if firebase_admin._apps:
        return

    cred = credentials.Certificate(
        settings.FIREBASE_CREDENTIALS_PATH
    )

    firebase_admin.initialize_app(cred)


def send_push_to_user(
    user,
    title,
    body,
    data=None,
):
    init_firebase()

    tokens = DeviceToken.objects.filter(
        user=user,
        is_active=True,
    )

    for device in tokens:
        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data={
                    str(k): str(v)
                    for k, v in (data or {}).items()
                },
                token=device.token,
            )

            messaging.send(message)

        except Exception as e:
            print("FCM SEND ERROR:", e)

            device.is_active = False
            device.save(
               update_fields=["is_active"]
            )



def get_broadcast_recipient_queryset(broadcast):
    """Return active users matching the selected broadcast audience.

    Buyer/seller membership is derived from Profile.type_user. Sellers are
    additionally recognised through OrgProf so an existing seller mapping is
    not missed if a legacy profile value is stale.
    """
    from django.contrib.auth import get_user_model
    from django.db.models import Q
    from profiles.models import Profile, OrgProf

    User = get_user_model()
    base = User.objects.filter(is_active=True)

    if broadcast.audience == broadcast.Audience.SPECIFIC:
        if not broadcast.user_id:
            return base.none()
        return base.filter(pk=broadcast.user_id)

    if broadcast.audience == broadcast.Audience.BUYERS:
        buyer_ids = Profile.objects.filter(
            type_user='buyer',
        ).values_list('user_id', flat=True)
        return base.filter(id__in=buyer_ids).distinct()

    if broadcast.audience == broadcast.Audience.SELLERS:
        seller_profile_ids = Profile.objects.filter(
            type_user='seller',
        ).values_list('user_id', flat=True)
        seller_org_ids = OrgProf.objects.values_list('user_id', flat=True)
        return base.filter(
            Q(id__in=seller_profile_ids) | Q(id__in=seller_org_ids)
        ).distinct()

    # «Все пользователи» means every active account. Superusers without an
    # active FCM token simply receive an in-app Notification row like any other
    # account; this keeps the meaning of «Все» exact and predictable.
    return base.order_by('id')
