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
