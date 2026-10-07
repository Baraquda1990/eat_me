import hashlib

from django.conf import settings
from django.db import models
from django.core.exceptions import ValidationError
from django.db.models import Q
from django.utils import timezone


def _legal_snapshot_path(instance, filename):
    safe_version = str(instance.version).replace('/', '-').strip()
    return f'legal/{instance.document_type}/v{safe_version}/{filename}'


def content_sha256(value: str) -> str:
    return hashlib.sha256((value or '').encode('utf-8')).hexdigest()


class LegalDocument(models.Model):
    class DocumentType(models.TextChoices):
        TERMS = 'terms', 'Условия использования'
        PRIVACY = 'privacy', 'Политика конфиденциальности'
        REFUND = 'refund', 'Политика возврата'
        FOOD_SAFETY = 'food_safety', 'Безопасность пищевых продуктов'
        CARD_SECURITY = 'card_security', 'Безопасность данных карты'

    class Placement(models.TextChoices):
        REGISTRATION = 'registration', 'Регистрация'
        CHECKOUT = 'checkout', 'Перед покупкой'
        INFORMATIONAL = 'informational', 'Информационный документ'

    document_type = models.CharField(
        max_length=40,
        choices=DocumentType.choices,
        db_index=True,
    )
    version = models.CharField(max_length=20)
    placement = models.CharField(
        max_length=20,
        choices=Placement.choices,
        default=Placement.INFORMATIONAL,
        db_index=True,
    )
    requires_acceptance = models.BooleanField(default=False)
    is_active = models.BooleanField(default=False, db_index=True)
    sort_order = models.PositiveSmallIntegerField(default=100)
    effective_at = models.DateTimeField(default=timezone.now)

    title_en = models.CharField(max_length=255)
    title_ru = models.CharField(max_length=255)
    title_hy = models.CharField(max_length=255)

    # The database copy is what the app renders. The R2 files below are
    # immutable/auditable snapshots of exactly the same version.
    content_en = models.TextField()
    content_ru = models.TextField()
    content_hy = models.TextField()

    hash_en = models.CharField(max_length=64, editable=False)
    hash_ru = models.CharField(max_length=64, editable=False)
    hash_hy = models.CharField(max_length=64, editable=False)

    snapshot_en = models.FileField(
        upload_to=_legal_snapshot_path,
        blank=True,
        max_length=500,
    )
    snapshot_ru = models.FileField(
        upload_to=_legal_snapshot_path,
        blank=True,
        max_length=500,
    )
    snapshot_hy = models.FileField(
        upload_to=_legal_snapshot_path,
        blank=True,
        max_length=500,
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ('sort_order', 'document_type', '-effective_at', '-id')
        constraints = [
            models.UniqueConstraint(
                fields=('document_type', 'version'),
                name='legal_unique_type_version',
            ),
            models.UniqueConstraint(
                fields=('document_type',),
                condition=Q(is_active=True),
                name='legal_one_active_version_per_type',
            ),
        ]

    def _assert_version_is_not_mutated_after_acceptance(self):
        if not self.pk:
            return
        if not self.consents.exists():
            return

        previous = type(self).objects.get(pk=self.pk)
        immutable_fields = (
            'document_type',
            'version',
            'title_en',
            'title_ru',
            'title_hy',
            'content_en',
            'content_ru',
            'content_hy',
        )
        changed = [
            field
            for field in immutable_fields
            if getattr(previous, field) != getattr(self, field)
        ]
        if changed:
            raise ValidationError(
                'A legal document version that already has user consent is '
                'immutable. Create a new version instead.'
            )

    def save(self, *args, **kwargs):
        self._assert_version_is_not_mutated_after_acceptance()
        self.hash_en = content_sha256(self.content_en)
        self.hash_ru = content_sha256(self.content_ru)
        self.hash_hy = content_sha256(self.content_hy)
        super().save(*args, **kwargs)

    @staticmethod
    def normalize_language(language):
        code = str(language or '').strip().lower().split('-')[0]
        return code if code in {'en', 'ru', 'hy'} else 'en'

    def title_for(self, language):
        code = self.normalize_language(language)
        return getattr(self, f'title_{code}')

    def content_for(self, language):
        code = self.normalize_language(language)
        return getattr(self, f'content_{code}')

    def hash_for(self, language):
        code = self.normalize_language(language)
        return getattr(self, f'hash_{code}')

    def snapshot_for(self, language):
        code = self.normalize_language(language)
        return getattr(self, f'snapshot_{code}')

    def __str__(self):
        suffix = 'active' if self.is_active else 'inactive'
        return f'{self.document_type} v{self.version} ({suffix})'


class LegalConsent(models.Model):
    class Source(models.TextChoices):
        REGISTRATION = 'registration', 'Регистрация'
        ACCOUNT_GATE = 'account_gate', 'Обязательное согласие после входа'
        CHECKOUT = 'checkout', 'Перед покупкой'
        OTHER = 'other', 'Другое'

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='legal_consents',
    )
    document = models.ForeignKey(
        LegalDocument,
        on_delete=models.PROTECT,
        related_name='consents',
    )

    document_type = models.CharField(max_length=40)
    document_version = models.CharField(max_length=20)
    language = models.CharField(max_length=5)
    document_hash = models.CharField(max_length=64)

    source = models.CharField(
        max_length=30,
        choices=Source.choices,
        default=Source.OTHER,
    )
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True, default='')
    accepted_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ('-accepted_at', '-id')
        constraints = [
            models.UniqueConstraint(
                fields=('user', 'document'),
                name='legal_unique_user_document_consent',
            ),
        ]

    def __str__(self):
        return (
            f'{self.user_id}: {self.document_type} '
            f'v{self.document_version} ({self.language})'
        )
