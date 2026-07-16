from pathlib import Path

from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import FileExtensionValidator
from django.db import models


def validate_document_size(file):
    """
    Максимальный размер одного загружаемого документа — 20 МБ.
    """
    max_size = 20 * 1024 * 1024

    if file.size > max_size:
        raise ValidationError(
            'Размер файла не должен превышать 20 МБ.'
        )


def seller_document_upload_path(instance, filename):
    """
    Пример:
    uploads/seller_applications/15/registration/document.pdf
    """
    extension = Path(filename).suffix.lower()
    document_type = instance.document_type or 'other'

    return (
        f'uploads/seller_applications/'
        f'{instance.application_id}/'
        f'{document_type}/'
        f'{instance.application_id}_{document_type}_{instance.pk or "new"}'
        f'{extension}'
    )


def seller_logo_upload_path(instance, filename):
    extension = Path(filename).suffix.lower()

    return (
        f'uploads/seller_applications/'
        f'{instance.user_id}/'
        f'logo_{instance.user_id}{extension}'
    )


class CompanyChannel(models.Model):
    """
    Разделы приложения, в которых организация может размещать товары.

    HOT   -> Products.type = hot -> Home
    DEALS -> Products.type = long -> Deals
    """

    class Code(models.TextChoices):
        HOT = 'hot', 'Home / HOT'
        DEALS = 'deals', 'Deals'

    code = models.CharField(
        max_length=20,
        choices=Code.choices,
        unique=True,
        verbose_name='Код направления',
    )

    is_active = models.BooleanField(
        default=True,
        verbose_name='Активно',
    )

    created = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Дата создания',
    )

    class Meta:
        ordering = ('code',)
        verbose_name = 'Направление организации'
        verbose_name_plural = 'Направления организаций'

    def __str__(self):
        return self.get_code_display()


class BusinessCategory(models.Model):
    """
    Категория бизнеса:
    кафе, ресторан, кондитерская, магазин, производитель и т. д.
    """

    code = models.SlugField(
        max_length=100,
        unique=True,
        verbose_name='Код',
        help_text='Например: cafe, bakery, grocery-store',
    )

    name_en = models.CharField(
        max_length=150,
        verbose_name='Название на английском',
    )

    name_ru = models.CharField(
        max_length=150,
        blank=True,
        verbose_name='Название на русском',
    )

    name_hy = models.CharField(
        max_length=150,
        blank=True,
        verbose_name='Название на армянском',
    )

    allowed_channels = models.ManyToManyField(
        CompanyChannel,
        blank=True,
        related_name='business_categories',
        verbose_name='Доступные направления',
        help_text=(
            'Например, кафе может быть доступно для HOT, '
            'а производитель — для DEALS.'
        ),
    )

    is_active = models.BooleanField(
        default=True,
        verbose_name='Активна',
    )

    sort_order = models.PositiveIntegerField(
        default=0,
        verbose_name='Порядок сортировки',
    )

    created = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Дата создания',
    )

    class Meta:
        ordering = ('sort_order', 'name_en')
        verbose_name = 'Категория бизнеса'
        verbose_name_plural = 'Категории бизнеса'

    def __str__(self):
        return self.name_ru or self.name_en


class SellerApplication(models.Model):
    """
    Заявка на регистрацию организации.

    До одобрения администратором:
    - Profile.type_user остаётся buyer;
    - Company не создаётся;
    - OrgProf не создаётся;
    - продавец не получает доступ к панели.
    """

    class Status(models.TextChoices):
        DRAFT = 'draft', 'Черновик'
        PENDING = 'pending', 'На проверке'
        CHANGES_REQUESTED = (
            'changes_requested',
            'Требуются исправления',
        )
        APPROVED = 'approved', 'Одобрена'
        REJECTED = 'rejected', 'Отклонена'
        CANCELLED = 'cancelled', 'Отменена пользователем'

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='seller_applications',
        verbose_name='Пользователь',
    )

    requested_channels = models.ManyToManyField(
        CompanyChannel,
        related_name='seller_applications',
        verbose_name='Запрашиваемые направления',
    )

    # Шаг 2: данные организации

    organization_name = models.CharField(
        max_length=200,
        blank=True,
        verbose_name='Название организации',
    )

    tax_number = models.CharField(
        max_length=50,
        blank=True,
        verbose_name='ИНН',
    )

    address = models.CharField(
        max_length=300,
        blank=True,
        verbose_name='Адрес',
    )

    latitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        null=True,
        blank=True,
        verbose_name='Широта',
    )

    longitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        null=True,
        blank=True,
        verbose_name='Долгота',
    )

    business_phone = models.CharField(
        max_length=30,
        blank=True,
        verbose_name='Телефон организации',
    )

    business_email = models.EmailField(
        blank=True,
        verbose_name='Email организации',
    )

    contact_name = models.CharField(
        max_length=150,
        blank=True,
        verbose_name='Контактное лицо',
    )

    contact_phone = models.CharField(
        max_length=30,
        blank=True,
        verbose_name='Телефон контактного лица',
    )

    contact_email = models.EmailField(
        blank=True,
        verbose_name='Email контактного лица',
    )

    # Шаг 3: категория

    business_category = models.ForeignKey(
        BusinessCategory,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name='seller_applications',
        verbose_name='Категория бизнеса',
    )

    # Шаг 4: документы хранятся в SellerApplicationDocument

    # Шаг 5: банковские реквизиты и оформление

    bank_name = models.CharField(
        max_length=150,
        blank=True,
        verbose_name='Название банка',
    )

    iban = models.CharField(
        max_length=100,
        blank=True,
        verbose_name='IBAN / банковский счёт',
    )

    account_holder_name = models.CharField(
        max_length=200,
        blank=True,
        verbose_name='Владелец банковского счёта',
    )

    logo = models.ImageField(
        upload_to=seller_logo_upload_path,
        null=True,
        blank=True,
        validators=[
            FileExtensionValidator(
                allowed_extensions=[
                    'jpg',
                    'jpeg',
                    'png',
                    'webp',
                ]
            ),
            validate_document_size,
        ],
        verbose_name='Логотип организации',
    )

    public_description = models.TextField(
        blank=True,
        verbose_name='Описание организации',
    )

    # Управление заявкой

    status = models.CharField(
        max_length=30,
        choices=Status.choices,
        default=Status.DRAFT,
        db_index=True,
        verbose_name='Статус',
    )

    current_step = models.PositiveSmallIntegerField(
        default=1,
        verbose_name='Текущий шаг регистрации',
    )

    admin_comment = models.TextField(
        blank=True,
        verbose_name='Комментарий администратора',
        help_text=(
            'Причина отклонения или описание необходимых исправлений.'
        ),
    )

    submitted_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Дата отправки на проверку',
    )

    reviewed_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Дата проверки',
    )

    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='reviewed_seller_applications',
        verbose_name='Проверил',
    )

    company = models.OneToOneField(
        'company.Company',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='source_seller_application',
        verbose_name='Созданная компания',
        help_text='Заполняется после одобрения заявки.',
    )

    created = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Дата создания',
    )

    updated = models.DateTimeField(
        auto_now=True,
        verbose_name='Дата изменения',
    )

    class Meta:
        ordering = ('-created',)
        verbose_name = 'Заявка продавца'
        verbose_name_plural = 'Заявки продавцов'
        indexes = [
            models.Index(
                fields=['user', 'status'],
                name='seller_app_user_status_idx',
            ),
            models.Index(
                fields=['status', 'created'],
                name='seller_app_status_date_idx',
            ),
        ]

    def __str__(self):
        name = self.organization_name or 'Без названия'
        return f'#{self.pk} — {name} — {self.get_status_display()}'

    @property
    def is_editable(self):
        return self.status in {
            self.Status.DRAFT,
            self.Status.CHANGES_REQUESTED,
        }

    @property
    def is_submitted(self):
        return self.status in {
            self.Status.PENDING,
            self.Status.APPROVED,
            self.Status.REJECTED,
        }


class SellerApplicationDocument(models.Model):
    class DocumentType(models.TextChoices):
        REGISTRATION = (
            'registration',
            'Учредительный документ',
        )
        TAX = (
            'tax',
            'Налоговый документ',
        )
        LICENSE = (
            'license',
            'Лицензия',
        )
        FOOD_SAFETY = (
            'food_safety',
            'Документ пищевой безопасности',
        )
        CERTIFICATE = (
            'certificate',
            'Сертификат',
        )
        IDENTITY = (
            'identity',
            'Документ ответственного лица',
        )
        BANK = (
            'bank',
            'Банковский документ',
        )
        OTHER = (
            'other',
            'Другой документ',
        )

    application = models.ForeignKey(
        SellerApplication,
        on_delete=models.CASCADE,
        related_name='documents',
        verbose_name='Заявка',
    )

    document_type = models.CharField(
        max_length=30,
        choices=DocumentType.choices,
        default=DocumentType.OTHER,
        verbose_name='Тип документа',
    )

    file = models.FileField(
        upload_to=seller_document_upload_path,
        validators=[
            FileExtensionValidator(
                allowed_extensions=[
                    'pdf',
                    'jpg',
                    'jpeg',
                    'png',
                    'webp',
                    'doc',
                    'docx',
                ]
            ),
            validate_document_size,
        ],
        verbose_name='Файл',
    )

    original_name = models.CharField(
        max_length=255,
        blank=True,
        verbose_name='Исходное имя файла',
    )

    description = models.CharField(
        max_length=300,
        blank=True,
        verbose_name='Описание',
    )

    uploaded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='uploaded_seller_documents',
        verbose_name='Загрузил',
    )

    created = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Дата загрузки',
    )

    class Meta:
        ordering = ('created',)
        verbose_name = 'Документ заявки продавца'
        verbose_name_plural = 'Документы заявок продавцов'

    def save(self, *args, **kwargs):
        if self.file and not self.original_name:
            self.original_name = Path(self.file.name).name

        super().save(*args, **kwargs)

    def __str__(self):
        return (
            f'{self.get_document_type_display()} — '
            f'заявка #{self.application_id}'
        )