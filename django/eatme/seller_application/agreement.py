from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
from io import BytesIO
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile
from xml.sax.saxutils import escape

from django.utils import timezone


AGREEMENT_VERSION = '1.0'
AGREEMENT_TEMPLATE_NAME = 'agency_agreement_v1.docx'
DOCX_CONTENT_TYPE = (
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
)


@dataclass(frozen=True)
class RenderedAgencyAgreement:
    content: bytes
    template_sha256: str
    document_sha256: str
    filename: str


def _template_path() -> Path:
    return Path(__file__).resolve().parent / 'agreements' / AGREEMENT_TEMPLATE_NAME


def _sha256(data: bytes) -> str:
    return sha256(data).hexdigest()


def _safe_xml_text(value: str) -> str:
    return escape(value or '')


def _agreement_date(value) -> str:
    if value is None:
        value = timezone.now()
    if timezone.is_aware(value):
        value = timezone.localtime(value)
    return value.strftime('%d.%m.%Y')


def render_agency_agreement(application, *, effective_at=None) -> RenderedAgencyAgreement:
    """
    Fill the DOCX without requiring python-docx on the production server.

    The bundled template contains ASCII markers in single Word runs, so
    replacing text in document.xml preserves the original formatting.
    """
    template_bytes = _template_path().read_bytes()
    date_text = _agreement_date(effective_at)
    vendor_name = _safe_xml_text(application.organization_name.strip())
    vendor_address = _safe_xml_text(application.address.strip())

    replacements = {
        '__AGREEMENT_DATE_HY__': date_text,
        '__AGREEMENT_DATE_RU__': date_text,
        '__AGREEMENT_DATE_EN__': date_text,
        '__VENDOR_NAME_HY__': vendor_name,
        '__VENDOR_NAME_RU__': vendor_name,
        '__VENDOR_NAME_EN__': vendor_name,
        '__VENDOR_ADDRESS_HY__': vendor_address,
        '__VENDOR_ADDRESS_RU__': vendor_address,
        '__VENDOR_ADDRESS_EN__': vendor_address,
    }

    source = BytesIO(template_bytes)
    output = BytesIO()

    with ZipFile(source, 'r') as zin, ZipFile(output, 'w', ZIP_DEFLATED) as zout:
        for info in zin.infolist():
            data = zin.read(info.filename)
            if info.filename == 'word/document.xml':
                xml = data.decode('utf-8')
                for marker, value in replacements.items():
                    if marker not in xml:
                        raise ValueError(
                            f'Agency agreement template marker is missing: {marker}'
                        )
                    xml = xml.replace(marker, value)
                data = xml.encode('utf-8')
            zout.writestr(info, data)

    document_bytes = output.getvalue()
    return RenderedAgencyAgreement(
        content=document_bytes,
        template_sha256=_sha256(template_bytes),
        document_sha256=_sha256(document_bytes),
        filename=f'Appsosa_Agency_Agreement_{application.pk}.docx',
    )
