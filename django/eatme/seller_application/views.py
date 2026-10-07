import re
from io import BytesIO
from zipfile import ZipFile
from xml.etree import ElementTree

from django.core.files.base import ContentFile
from django.db import transaction
from django.http import FileResponse, HttpResponse
from django.utils import timezone

from rest_framework import generics, status
from rest_framework.exceptions import ValidationError
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from core.phone import is_valid_armenian_phone

from .agreement import (
    AGREEMENT_VERSION,
    DOCX_CONTENT_TYPE,
    render_agency_agreement,
)
from .models import (
    BusinessCategory,
    CompanyChannel,
    SellerAgencyAgreementAcceptance,
    SellerApplication,
    SellerApplicationDocument,
)
from .serializers import (
    BusinessCategorySerializer,
    CompanyChannelSerializer,
    SellerApplicationDocumentSerializer,
    SellerApplicationSerializer,
)


def _client_ip(request):
    forwarded = request.META.get('HTTP_X_FORWARDED_FOR', '')
    if forwarded:
        return forwarded.split(',')[0].strip() or None
    return request.META.get('REMOTE_ADDR') or None


def _agreement_language(value):
    code = (value or '').strip().lower().split('-')[0]
    return code if code in {'hy', 'ru', 'en'} else 'en'


_WORD_NS = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'


def _docx_bytes_to_text(data):
    """Extract readable paragraph text from an accepted DOCX snapshot."""
    with ZipFile(BytesIO(data)) as archive:
        document_xml = archive.read('word/document.xml')

    root = ElementTree.fromstring(document_xml)
    paragraphs = []

    for paragraph in root.iter(f'{{{_WORD_NS}}}p'):
        parts = []

        for node in paragraph.iter():
            if node.tag == f'{{{_WORD_NS}}}t':
                parts.append(node.text or '')
            elif node.tag == f'{{{_WORD_NS}}}tab':
                parts.append('\t')
            elif node.tag == f'{{{_WORD_NS}}}br':
                parts.append('\n')

        value = ''.join(parts).strip()
        if value:
            paragraphs.append(value)

    return '\n\n'.join(paragraphs)


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


class SellerApplicationAgreementDownloadApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        try:
            application = SellerApplication.objects.get(
                pk=pk,
                user=request.user,
            )
        except SellerApplication.DoesNotExist:
            return Response(
                {'detail': 'Заявка не найдена.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        # During editing always generate a fresh preview from current values.
        # After submit return the immutable accepted snapshot.
        if not application.is_editable:
            acceptance = application.agency_agreement_acceptances.order_by(
                '-accepted_at', '-id'
            ).first()

            if acceptance and acceptance.snapshot:
                return FileResponse(
                    acceptance.snapshot.open('rb'),
                    as_attachment=True,
                    filename=f'Appsosa_Agency_Agreement_{application.pk}.docx',
                    content_type=DOCX_CONTENT_TYPE,
                )

        if not application.organization_name.strip() or not application.address.strip():
            return Response(
                {
                    'detail': (
                        'Для формирования договора заполните название '
                        'организации и адрес.'
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        rendered = render_agency_agreement(application)
        response = HttpResponse(rendered.content, content_type=DOCX_CONTENT_TYPE)
        response['Content-Disposition'] = (
            f'attachment; filename="{rendered.filename}"'
        )
        response['X-Agreement-Version'] = AGREEMENT_VERSION
        response['X-Agreement-SHA256'] = rendered.document_sha256
        return response


class SellerApplicationAgreementPreviewApi(APIView):
    """
    Returns agreement text for in-app viewing.

    While the application is editable, the endpoint renders the current
    agreement from the application's saved data so the seller can read it
    before accepting it.

    After submit, it returns ONLY the immutable accepted snapshot.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        try:
            application = SellerApplication.objects.get(
                pk=pk,
                user=request.user,
            )
        except SellerApplication.DoesNotExist:
            return Response(
                {'detail': 'Заявка не найдена.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        language = _agreement_language(
            request.query_params.get('language')
        )

        if application.is_editable:
            if (
                not application.organization_name.strip()
                or not application.address.strip()
            ):
                return Response(
                    {
                        'detail': (
                            'Для просмотра договора заполните название '
                            'организации и адрес.'
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            try:
                rendered = render_agency_agreement(application)
                text = _docx_bytes_to_text(rendered.content)
            except Exception:
                return Response(
                    {'detail': 'Не удалось сформировать агентский договор.'},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR,
                )

            if not text.strip():
                return Response(
                    {'detail': 'Агентский договор пуст.'},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR,
                )

            return Response(
                {
                    'application_id': application.pk,
                    'version': AGREEMENT_VERSION,
                    'language': language,
                    'accepted_at': None,
                    'is_accepted': False,
                    'text': text,
                },
                status=status.HTTP_200_OK,
            )

        acceptance = application.agency_agreement_acceptances.order_by(
            '-accepted_at',
            '-id',
        ).first()

        if not acceptance or not acceptance.snapshot:
            return Response(
                {
                    'detail': (
                        'Принятый агентский договор для этой заявки '
                        'ещё не сформирован.'
                    )
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        try:
            acceptance.snapshot.open('rb')
            try:
                content = acceptance.snapshot.read()
            finally:
                acceptance.snapshot.close()

            text = _docx_bytes_to_text(content)
        except Exception:
            return Response(
                {'detail': 'Не удалось прочитать агентский договор.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        if not text.strip():
            return Response(
                {'detail': 'Агентский договор пуст.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        return Response(
            {
                'application_id': application.pk,
                'version': acceptance.version,
                'language': acceptance.language,
                'accepted_at': acceptance.accepted_at,
                'is_accepted': True,
                'text': text,
            },
            status=status.HTTP_200_OK,
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

        if request.data.get('agreement_accepted') is not True:
            return Response(
                {
                    'agreement_accepted': (
                        'Необходимо принять агентский договор и '
                        'Условия предоставления услуг.'
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        agreement_language = _agreement_language(
            request.data.get('agreement_language')
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

        # Legacy drafts created before TIN validation must not be submitted
        # until the Armenian tax number is corrected.
        if application.tax_number and re.fullmatch(
            r'[0-9]{8}',
            application.tax_number.strip(),
        ) is None:
            errors['tax_number'] = (
                'ИНН должен содержать ровно 8 цифр.'
            )

        # A legacy draft created before Armenian phone validation must not
        # be submitted until both numbers are corrected.
        if application.business_phone and not is_valid_armenian_phone(
            application.business_phone,
            allow_blank=False,
        ):
            errors['business_phone'] = (
                'Телефон организации должен быть в формате +374XXXXXXXX.'
            )

        if application.contact_phone and not is_valid_armenian_phone(
            application.contact_phone,
            allow_blank=False,
        ):
            errors['contact_phone'] = (
                'Контактный телефон должен быть в формате +374XXXXXXXX.'
            )

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

        accepted_at = timezone.now()
        rendered_agreement = render_agency_agreement(
            application,
            effective_at=accepted_at,
        )

        acceptance = SellerAgencyAgreementAcceptance(
            application=application,
            version=AGREEMENT_VERSION,
            language=agreement_language,
            template_sha256=rendered_agreement.template_sha256,
            document_sha256=rendered_agreement.document_sha256,
            accepted_at=accepted_at,
            ip_address=_client_ip(request),
            user_agent=request.META.get('HTTP_USER_AGENT', '')[:2000],
        )
        acceptance.snapshot.save(
            rendered_agreement.filename,
            ContentFile(rendered_agreement.content),
            save=False,
        )
        acceptance.save()

        application.status = SellerApplication.Status.PENDING
        application.current_step = 5
        application.submitted_at = accepted_at
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