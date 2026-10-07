from dataclasses import dataclass

from django.db import transaction

from .models import LegalConsent, LegalDocument


ACTION_PLACEMENTS = {
    'registration': {LegalDocument.Placement.REGISTRATION},
    # Checkout also protects legacy/social-login users that may not yet have
    # accepted the registration documents.
    'checkout': {
        LegalDocument.Placement.REGISTRATION,
        LegalDocument.Placement.CHECKOUT,
    },
}


class LegalAcceptanceError(ValueError):
    pass


@dataclass(frozen=True)
class ValidatedAcceptance:
    document: LegalDocument
    language: str
    document_hash: str


def normalize_language(language):
    return LegalDocument.normalize_language(language)


def client_ip(request):
    if request is None:
        return None

    cloudflare_ip = str(request.META.get('HTTP_CF_CONNECTING_IP') or '').strip()
    if cloudflare_ip:
        return cloudflare_ip

    forwarded = request.META.get('HTTP_X_FORWARDED_FOR', '')
    if forwarded:
        return forwarded.split(',')[0].strip() or None

    value = request.META.get('REMOTE_ADDR')
    return value.strip() if isinstance(value, str) and value.strip() else None


def preferred_language_for_request(request, fallback='en'):
    query_language = None
    if request is not None:
        query_language = request.query_params.get('lang')
        if not query_language and isinstance(getattr(request, 'data', None), dict):
            query_language = request.data.get('language')

    if query_language:
        return normalize_language(query_language)

    user = getattr(request, 'user', None) if request is not None else None
    profile = getattr(user, 'profile', None) if user and getattr(user, 'is_authenticated', False) else None
    if profile is not None and getattr(profile, 'language', None):
        return normalize_language(profile.language)

    return normalize_language(fallback)


def active_documents(*, action=None, include_informational=False):
    queryset = LegalDocument.objects.filter(is_active=True)

    if action in ACTION_PLACEMENTS:
        queryset = queryset.filter(
            requires_acceptance=True,
            placement__in=ACTION_PLACEMENTS[action],
        )
    elif not include_informational:
        queryset = queryset.filter(requires_acceptance=True)

    return queryset.order_by('sort_order', 'document_type', 'id')


def all_active_documents():
    return LegalDocument.objects.filter(is_active=True).order_by(
        'sort_order', 'document_type', 'id'
    )


def missing_required_documents(user, *, action):
    required = active_documents(action=action)
    if not getattr(user, 'is_authenticated', False):
        return list(required)

    consents = LegalConsent.objects.filter(
        user=user,
        document__in=required,
    ).select_related('document')

    accepted_ids = set()
    for consent in consents:
        document = consent.document
        if consent.document_version != document.version:
            continue
        if consent.document_hash != document.hash_for(consent.language):
            continue
        accepted_ids.add(document.id)

    return [document for document in required if document.id not in accepted_ids]


def _snapshot_url(document, language, request=None):
    field = document.snapshot_for(language)
    if not field:
        return None

    try:
        url = field.url
    except (ValueError, NotImplementedError):
        return None

    if request is not None and url.startswith('/'):
        return request.build_absolute_uri(url)
    return url


def serialize_document(document, *, language, request=None, accepted=None):
    language = normalize_language(language)
    data = {
        'id': document.id,
        'type': document.document_type,
        'version': document.version,
        'placement': document.placement,
        'requires_acceptance': document.requires_acceptance,
        'title': document.title_for(language),
        'content': document.content_for(language),
        'hash': document.hash_for(language),
        'language': language,
        'snapshot_url': _snapshot_url(document, language, request=request),
        'effective_at': document.effective_at.isoformat(),
    }
    if accepted is not None:
        data['accepted'] = bool(accepted)
    return data


def serialize_documents(documents, *, language, request=None, user=None):
    accepted_ids = set()
    if user is not None and getattr(user, 'is_authenticated', False):
        accepted_ids = set(
            LegalConsent.objects.filter(
                user=user,
                document__in=documents,
            ).values_list('document_id', flat=True)
        )

    return [
        serialize_document(
            document,
            language=language,
            request=request,
            accepted=(document.id in accepted_ids) if user is not None else None,
        )
        for document in documents
    ]


def _acceptance_map(raw_acceptances):
    if not isinstance(raw_acceptances, list):
        raise LegalAcceptanceError('legal_acceptances must be a list.')

    result = {}
    for item in raw_acceptances:
        if not isinstance(item, dict):
            raise LegalAcceptanceError('Invalid legal acceptance item.')
        document_type = str(item.get('type') or '').strip()
        if not document_type:
            raise LegalAcceptanceError('Legal document type is required.')
        result[document_type] = item
    return result


def validate_required_acceptances(raw_acceptances, *, action):
    expected_documents = list(active_documents(action=action))
    supplied = _acceptance_map(raw_acceptances)
    validated = []

    for document in expected_documents:
        item = supplied.get(document.document_type)
        if item is None:
            raise LegalAcceptanceError(
                f'Acceptance is required for {document.document_type}.'
            )

        version = str(item.get('version') or '').strip()
        language = normalize_language(item.get('language'))
        document_hash = str(item.get('hash') or '').strip().lower()

        if version != document.version:
            raise LegalAcceptanceError(
                f'{document.document_type} version has changed. Refresh the document.'
            )

        expected_hash = document.hash_for(language)
        if document_hash != expected_hash:
            raise LegalAcceptanceError(
                f'{document.document_type} content has changed. Refresh the document.'
            )

        validated.append(
            ValidatedAcceptance(
                document=document,
                language=language,
                document_hash=expected_hash,
            )
        )

    return validated


def validate_acceptance_items(raw_acceptances):
    supplied = _acceptance_map(raw_acceptances)
    validated = []

    for document_type, item in supplied.items():
        document = LegalDocument.objects.filter(
            document_type=document_type,
            is_active=True,
        ).first()
        if document is None:
            raise LegalAcceptanceError(
                f'Active legal document {document_type} was not found.'
            )

        version = str(item.get('version') or '').strip()
        language = normalize_language(item.get('language'))
        document_hash = str(item.get('hash') or '').strip().lower()

        if version != document.version:
            raise LegalAcceptanceError(
                f'{document_type} version has changed. Refresh the document.'
            )

        expected_hash = document.hash_for(language)
        if document_hash != expected_hash:
            raise LegalAcceptanceError(
                f'{document_type} content has changed. Refresh the document.'
            )

        validated.append(
            ValidatedAcceptance(
                document=document,
                language=language,
                document_hash=expected_hash,
            )
        )

    return validated


def create_consents(
    user,
    validated_acceptances,
    *,
    request=None,
    source=LegalConsent.Source.OTHER,
):
    ip = client_ip(request)
    user_agent = ''
    if request is not None:
        user_agent = str(request.META.get('HTTP_USER_AGENT') or '')[:2000]

    created = []
    with transaction.atomic():
        for acceptance in validated_acceptances:
            consent, _ = LegalConsent.objects.get_or_create(
                user=user,
                document=acceptance.document,
                defaults={
                    'document_type': acceptance.document.document_type,
                    'document_version': acceptance.document.version,
                    'language': acceptance.language,
                    'document_hash': acceptance.document_hash,
                    'source': source,
                    'ip_address': ip,
                    'user_agent': user_agent,
                },
            )
            created.append(consent)
    return created
