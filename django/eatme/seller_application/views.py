from django.db import transaction
from django.utils import timezone

from rest_framework import generics, status
from rest_framework.exceptions import ValidationError
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import (
    BusinessCategory,
    CompanyChannel,
    SellerApplication,
    SellerApplicationDocument,
)
from .serializers import (
    BusinessCategorySerializer,
    CompanyChannelSerializer,
    SellerApplicationDocumentSerializer,
    SellerApplicationSerializer,
)


class CompanyChannelListApi(generics.ListAPIView):
    serializer_class = CompanyChannelSerializer

    def get_queryset(self):
        return CompanyChannel.objects.filter(
            is_active=True,
        ).order_by('code')


class BusinessCategoryListApi(generics.ListAPIView):
    serializer_class = BusinessCategorySerializer

    def get_queryset(self):
        queryset = (
            BusinessCategory.objects
            .filter(is_active=True)
            .prefetch_related('allowed_channels')
            .order_by('sort_order', 'name_en')
        )

        channel = self.request.query_params.get('channel')

        if channel:
            queryset = queryset.filter(
                allowed_channels__code=channel,
                allowed_channels__is_active=True,
            ).distinct()

        return queryset


class MySellerApplicationApi(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, user):
        return (
            SellerApplication.objects
            .filter(user=user)
            .exclude(
                status=SellerApplication.Status.CANCELLED,
            )
            .prefetch_related(
                'requested_channels',
                'documents',
            )
            .order_by('-created')
            .first()
        )

    def get(self, request):
        application = self.get_object(request.user)

        if not application:
            return Response(
                {
                    'detail': 'Заявка ещё не создана.',
                    'application': None,
                },
                status=status.HTTP_200_OK,
            )

        serializer = SellerApplicationSerializer(
            application,
            context={'request': request},
        )

        return Response(serializer.data)

    def post(self, request):
        existing = self.get_object(request.user)

        if existing:
            serializer = SellerApplicationSerializer(
                existing,
                data=request.data,
                partial=True,
                context={'request': request},
            )
        else:
            serializer = SellerApplicationSerializer(
                data=request.data,
                context={'request': request},
            )

        serializer.is_valid(raise_exception=True)

        if existing:
            application = serializer.save()
        else:
            application = serializer.save(
                user=request.user,
            )

        return Response(
            SellerApplicationSerializer(
                application,
                context={'request': request},
            ).data,
            status=(
                status.HTTP_200_OK
                if existing
                else status.HTTP_201_CREATED
            ),
        )


class SellerApplicationDetailApi(
    generics.RetrieveUpdateAPIView
):
    serializer_class = SellerApplicationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return (
            SellerApplication.objects
            .filter(user=self.request.user)
            .prefetch_related(
                'requested_channels',
                'documents',
            )
        )

    def perform_update(self, serializer):
        application = self.get_object()

        if not application.is_editable:
            raise ValidationError(
                'Заявку нельзя редактировать в текущем статусе.'
            )

        serializer.save()


class SellerApplicationDocumentCreateApi(
    generics.CreateAPIView
):
    serializer_class = SellerApplicationDocumentSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = [
        MultiPartParser,
        FormParser,
    ]

    def perform_create(self, serializer):
        application_id = self.kwargs['pk']

        try:
            application = SellerApplication.objects.get(
                pk=application_id,
                user=self.request.user,
            )
        except SellerApplication.DoesNotExist:
            raise ValidationError(
                'Заявка не найдена.'
            )

        if not application.is_editable:
            raise ValidationError(
                'В эту заявку нельзя добавлять документы.'
            )

        serializer.save(
            application=application,
            uploaded_by=self.request.user,
        )


class SellerApplicationDocumentDeleteApi(
    generics.DestroyAPIView
):
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return SellerApplicationDocument.objects.filter(
            application__user=self.request.user,
            application__status__in=[
                SellerApplication.Status.DRAFT,
                SellerApplication.Status.CHANGES_REQUESTED,
            ],
        )


class SellerApplicationSubmitApi(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request, pk):
        try:
            application = (
                SellerApplication.objects
                .select_for_update()
                .prefetch_related(
                    'requested_channels',
                    'documents',
                )
                .get(
                    pk=pk,
                    user=request.user,
                )
            )
        except SellerApplication.DoesNotExist:
            return Response(
                {
                    'detail': 'Заявка не найдена.',
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        if not application.is_editable:
            return Response(
                {
                    'detail': (
                        'Заявку нельзя отправить '
                        'в текущем статусе.'
                    ),
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        errors = {}

        if not application.requested_channels.exists():
            errors['requested_channels'] = (
                'Выберите хотя бы одно направление.'
            )

        required_fields = {
            'organization_name': 'Укажите название организации.',
            'tax_number': 'Укажите ИНН.',
            'address': 'Укажите адрес.',
            'latitude': 'Укажите местоположение на карте.',
            'longitude': 'Укажите местоположение на карте.',
            'business_phone': 'Укажите телефон организации.',
            'contact_name': 'Укажите контактное лицо.',
            'contact_phone': 'Укажите контактный телефон.',
            'business_category': 'Выберите категорию бизнеса.',
            'bank_name': 'Укажите название банка.',
            'iban': 'Укажите IBAN.',
            'account_holder_name': (
                'Укажите владельца банковского счёта.'
            ),
        }

        for field_name, message in required_fields.items():
            value = getattr(application, field_name)

            if value is None or value == '':
                errors[field_name] = message

        if not application.documents.exists():
            errors['documents'] = (
                'Загрузите хотя бы один документ.'
            )

        if errors:
            return Response(
                errors,
                status=status.HTTP_400_BAD_REQUEST,
            )

        selected_channels = set(
            application.requested_channels.values_list(
                'id',
                flat=True,
            )
        )

        allowed_channels = set(
            application.business_category.allowed_channels.values_list(
                'id',
                flat=True,
            )
        )

        if not selected_channels.issubset(allowed_channels):
            return Response(
                {
                    'business_category': (
                        'Выбранная категория не поддерживает '
                        'одно из указанных направлений.'
                    ),
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        application.status = SellerApplication.Status.PENDING
        application.current_step = 5
        application.submitted_at = timezone.now()
        application.admin_comment = ''

        application.save(
            update_fields=[
                'status',
                'current_step',
                'submitted_at',
                'admin_comment',
                'updated',
            ]
        )

        return Response(
            SellerApplicationSerializer(
                application,
                context={'request': request},
            ).data,
            status=status.HTTP_200_OK,
        )