from django.db import transaction
from django.utils import timezone

from company.models import Company
from profiles.models import OrgProf, Profile

from .models import SellerApplication


@transaction.atomic
def approve_application(application, admin_user):
    """Одобряет заявку продавца и создаёт компанию."""

    if application.status != SellerApplication.Status.PENDING:
        raise ValueError(
            'Можно одобрять только заявки со статусом PENDING.'
        )

    company = Company.objects.create(
        name=application.organization_name,
        address=application.address,
        phone=application.business_phone,
        latitude=application.latitude,
        longitude=application.longitude,
        description=application.public_description,
        image=application.logo if application.logo else None,
    )

    OrgProf.objects.create(
        user=application.user,
        company=company,
    )

    profile = application.user.profile
    profile.type_user = Profile.TypeUser.SELLER
    profile.save(
        update_fields=[
            'type_user',
        ]
    )

    application.status = SellerApplication.Status.APPROVED
    application.reviewed_at = timezone.now()
    application.reviewed_by = admin_user
    application.company = company

    application.save(
        update_fields=[
            'status',
            'reviewed_at',
            'reviewed_by',
            'company',
            'updated',
        ]
    )

    return company


@transaction.atomic
def reject_application(
    application,
    admin_user,
    comment='',
):
    """Отклоняет заявку продавца."""

    if application.status != SellerApplication.Status.PENDING:
        raise ValueError(
            'Можно отклонять только заявки со статусом PENDING.'
        )

    application.status = SellerApplication.Status.REJECTED
    application.reviewed_at = timezone.now()
    application.reviewed_by = admin_user
    application.admin_comment = (comment or '').strip()

    application.save(
        update_fields=[
            'status',
            'reviewed_at',
            'reviewed_by',
            'admin_comment',
            'updated',
        ]
    )

    return application


@transaction.atomic
def request_changes_application(
    application,
    admin_user,
    comment,
):
    """Возвращает отправленную заявку пользователю на исправление."""

    if application.status != SellerApplication.Status.PENDING:
        raise ValueError(
            'Запрашивать исправления можно только для заявки PENDING.'
        )

    comment = (comment or '').strip()
    if not comment:
        raise ValueError(
            'Перед возвратом заявки укажите комментарий администратора.'
        )

    application.status = SellerApplication.Status.CHANGES_REQUESTED
    application.reviewed_at = timezone.now()
    application.reviewed_by = admin_user
    application.admin_comment = comment

    application.save(
        update_fields=[
            'status',
            'reviewed_at',
            'reviewed_by',
            'admin_comment',
            'updated',
        ]
    )

    return application
