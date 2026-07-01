from django.shortcuts import render
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework.authentication import SessionAuthentication
from rest_framework.decorators import authentication_classes

def home(request):
    return render(request, 'google_core/home.html')

@api_view(['GET'])
@authentication_classes([SessionAuthentication])
def get_jwt_token(request):
    if not request.user.is_authenticated:
        return Response({"error": "Please sign in first"}, status=401)
    refresh = RefreshToken.for_user(request.user)
    return Response({
        'refresh': str(refresh),
        'access': str(refresh.access_token),
    })

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def projects(request):
    data = {
        "message": "Welcome to the project collaboration API!",
        "user": request.user.email,
        "projects": ["Sample Project 1", "Sample Project 2"]
    }
    return Response(data)

