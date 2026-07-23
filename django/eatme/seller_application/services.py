from django.db import transaction
from django.utils import timezone

from company.models import Company
from profiles.models import OrgProf, Profile

from .models import SellerApplication


def _company_data_from_application(application):
    """Возвращает поля Company, которые заполняются из заявки."""
    return {
        'name': application.organization_name,
        'address': application.address,
        'phone': application.business_phone,
        'latitude': application.latitude,
        'longitude': application.longitude,
        'description': application.public_description,
    }


@transaction.atomic
def approve_application(application, admin_user):
    """
    Одобряет заявку продавца.

    При первом одобрении создаёт Company и OrgProf.
    При повторном одобрении обновляет уже связанную Company,
    не создавая новую компанию и новую дублирующую связь OrgProf.
    """

    if application.status != SellerApplication.Status.PENDING:
        raise ValueError(
            'Можно одобрять только заявки со статусом PENDING.'
        )

    company_data = _company_data_from_application(application)

    if application.company_id:
        company = application.company

        for field, value in company_data.items():
            setattr(company, field, value)

        # Если в заявке загружен новый логотип, заменяем логотип компании.
        # Если файл не передан, существующий логотип сохраняется.
        if application.logo:
            company.image = application.logo

        company.save()
    else:
        company = Company.objects.create(
            **company_data,
            image=application.logo if application.logo else None,
        )

        application.company = company

    # Не создаём повторную идентичную привязку при повторном одобрении.
    OrgProf.objects.get_or_create(
        user=application.user,
        company=company,
    )

    profile = application.user.profile
    if profile.type_user != Profile.TypeUser.SELLER:
        profile.type_user = Profile.TypeUser.SELLER
        profile.save(update_fields=['type_user'])

    application.status = SellerApplication.Status.APPROVED
    application.reviewed_at = timezone.now()
    application.reviewed_by = admin_user

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
    """
    Возвращает заявку пользователю на исправление.

    Разрешено возвращать как заявку на проверке, так и ранее
    одобренную заявку. Связанная Company при этом не удаляется
    и не отвязывается, чтобы после повторного одобрения она была
    обновлена, а не создана заново.
    """

    allowed_statuses = {
        SellerApplication.Status.PENDING,
        SellerApplication.Status.APPROVED,
    }

    if application.status not in allowed_statuses:
        raise ValueError(
            'Запрашивать исправления можно только для заявки '
            'PENDING или APPROVED.'
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
