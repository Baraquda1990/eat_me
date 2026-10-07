from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import LegalConsent, LegalDocument
from .services import (
    ACTION_PLACEMENTS,
    LegalAcceptanceError,
    all_active_documents,
    create_consents,
    missing_required_documents,
    preferred_language_for_request,
    serialize_document,
    serialize_documents,
    validate_acceptance_items,
)


class LegalDocumentsApi(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        language = preferred_language_for_request(request)
        action = str(request.query_params.get('action') or 'all').strip().lower()
        document_type = str(request.query_params.get('type') or '').strip()

        documents = all_active_documents()
        if document_type:
            documents = documents.filter(document_type=document_type)
        elif action in ACTION_PLACEMENTS:
            documents = documents.filter(
                requires_acceptance=True,
                placement__in=ACTION_PLACEMENTS[action],
            )

        documents = list(documents)
        user = request.user if getattr(request.user, 'is_authenticated', False) else None

        return Response({
            'language': language,
            'documents': serialize_documents(
                documents,
                language=language,
                request=request,
                user=user,
            ),
        })


class LegalStatusApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        action = str(request.query_params.get('action') or 'registration').strip().lower()
        if action not in ACTION_PLACEMENTS:
            return Response(
                {'detail': 'Unsupported legal action.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        language = preferred_language_for_request(request)
        missing = missing_required_documents(request.user, action=action)

        return Response({
            'action': action,
            'ready': not missing,
            'language': language,
            'missing': serialize_documents(
                missing,
                language=language,
                request=request,
                user=request.user,
            ),
        })


class LegalAcceptApi(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        action = str(request.data.get('action') or 'other').strip().lower()
        raw_acceptances = request.data.get('acceptances')

        try:
            validated = validate_acceptance_items(raw_acceptances)
        except LegalAcceptanceError as error:
            return Response(
                {'detail': str(error), 'code': 'legal_acceptance_invalid'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        source = {
            'registration': LegalConsent.Source.ACCOUNT_GATE,
            'checkout': LegalConsent.Source.CHECKOUT,
        }.get(action, LegalConsent.Source.OTHER)

        create_consents(
            request.user,
            validated,
            request=request,
            source=source,
        )

        if action in ACTION_PLACEMENTS:
            language = preferred_language_for_request(request)
            missing = missing_required_documents(request.user, action=action)
            return Response({
                'action': action,
                'ready': not missing,
                'missing': serialize_documents(
                    missing,
                    language=language,
                    request=request,
                    user=request.user,
                ),
            })

        return Response({'accepted': True})


class LegalDocumentDetailApi(APIView):
    permission_classes = [AllowAny]

    def get(self, request, document_type):
        language = preferred_language_for_request(request)
        document = LegalDocument.objects.filter(
            document_type=document_type,
            is_active=True,
        ).first()

        if document is None:
            return Response(
                {'detail': 'Legal document not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        accepted = None
        if getattr(request.user, 'is_authenticated', False):
            accepted = LegalConsent.objects.filter(
                user=request.user,
                document=document,
            ).exists()

        return Response(
            serialize_document(
                document,
                language=language,
                request=request,
                accepted=accepted,
            )
        )
