from google.oauth2 import id_token
from google.auth.transport import requests
from django.contrib.auth import get_user_model

User = get_user_model()

GOOGLE_CLIENT_ID = "701891817101-7l1bdih2eveqi7cv2ico4cb751nr1qru.apps.googleusercontent.com"

def authenticate_google_token(token):
    payload = id_token.verify_oauth2_token(
        token,
        requests.Request(),
        GOOGLE_CLIENT_ID,
    )

    email = payload.get("email")

    if not email:
        raise ValueError("Email not found")

    user, _ = User.objects.get_or_create(
        email=email,
        defaults={
            "username": email,
        },
    )

    return user