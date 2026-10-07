import re

from django.core.exceptions import ValidationError


ARMENIAN_PHONE_PATTERN = re.compile(r'^\+374\d{8}$')
ARMENIAN_PHONE_ERROR = (
    'Номер телефона должен быть в формате +374XXXXXXXX '
    '(код Армении +374 и 8 цифр номера).'
)


def is_valid_armenian_phone(value, *, allow_blank=True):
    phone = str(value or '').strip()

    if not phone:
        return allow_blank

    return ARMENIAN_PHONE_PATTERN.fullmatch(phone) is not None


def validate_armenian_phone(value, *, allow_blank=True):
    phone = str(value or '').strip()

    if not phone:
        if allow_blank:
            return ''
        raise ValidationError(
            ARMENIAN_PHONE_ERROR,
            code='invalid_armenian_phone',
        )

    if ARMENIAN_PHONE_PATTERN.fullmatch(phone) is None:
        raise ValidationError(
            ARMENIAN_PHONE_ERROR,
            code='invalid_armenian_phone',
        )

    return phone
