from django.contrib.auth import get_user_model
from django.test import TestCase

from company.models import Company
from profiles.models import OrgProf, Profile

from .models import SellerApplication
from .services import approve_application, request_changes_application


User = get_user_model()


class SellerApplicationApprovalTests(TestCase):
    def setUp(self):
        self.admin = User.objects.create_superuser(
            username='admin',
            email='admin@example.com',
            password='test-password',
        )
        self.user = User.objects.create_user(
            username='seller',
            email='seller@example.com',
            password='test-password',
        )
        self.application = SellerApplication.objects.create(
            user=self.user,
            organization_name='Первая компания',
            address='Первый адрес',
            business_phone='+100000000',
            public_description='Первое описание',
            status=SellerApplication.Status.PENDING,
        )

    def test_reapproval_updates_existing_company_without_duplicates(self):
        first_company = approve_application(
            self.application,
            self.admin,
        )

        self.application.refresh_from_db()
        self.user.profile.refresh_from_db()

        self.assertEqual(
            self.user.profile.type_user,
            Profile.TypeUser.SELLER,
        )
        self.assertEqual(self.application.company_id, first_company.id)
        self.assertEqual(Company.objects.count(), 1)
        self.assertEqual(OrgProf.objects.count(), 1)

        request_changes_application(
            self.application,
            self.admin,
            'Добавьте новые сведения.',
        )

        self.application.refresh_from_db()
        self.assertEqual(
            self.application.status,
            SellerApplication.Status.CHANGES_REQUESTED,
        )
        self.assertEqual(self.application.company_id, first_company.id)

        self.application.organization_name = 'Обновлённая компания'
        self.application.address = 'Новый адрес'
        self.application.status = SellerApplication.Status.PENDING
        self.application.save(
            update_fields=[
                'organization_name',
                'address',
                'status',
                'updated',
            ]
        )

        second_company = approve_application(
            self.application,
            self.admin,
        )

        self.application.refresh_from_db()
        first_company.refresh_from_db()

        self.assertEqual(second_company.id, first_company.id)
        self.assertEqual(self.application.company_id, first_company.id)
        self.assertEqual(first_company.name, 'Обновлённая компания')
        self.assertEqual(first_company.address, 'Новый адрес')
        self.assertEqual(Company.objects.count(), 1)
        self.assertEqual(OrgProf.objects.count(), 1)
