from django.urls import path

from .api import (
    LegalAcceptApi,
    LegalDocumentDetailApi,
    LegalDocumentsApi,
    LegalStatusApi,
)

urlpatterns = [
    path('legal/documents/', LegalDocumentsApi.as_view(), name='legal-documents'),
    path('legal/status/', LegalStatusApi.as_view(), name='legal-status'),
    path('legal/accept/', LegalAcceptApi.as_view(), name='legal-accept'),
    path(
        'legal/documents/<str:document_type>/',
        LegalDocumentDetailApi.as_view(),
        name='legal-document-detail',
    ),
]
