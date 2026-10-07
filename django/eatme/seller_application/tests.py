from django.contrib.auth import get_user_model
from django.test import TestCase

from company.models import Company
from profiles.models import OrgProf, Profile

from .models import SellerApplication
from .serializers import SellerApplicationSerializer
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


class SellerAgencyAgreementTemplateTests(TestCase):
    def test_template_is_filled_without_placeholders(self):
        from io import BytesIO
        from types import SimpleNamespace
        from zipfile import ZipFile

        from .agreement import render_agency_agreement

        application = SimpleNamespace(
            pk=99,
            organization_name='Demo Vendor LLC',
            address='10 Test Street, Yerevan',
        )
        rendered = render_agency_agreement(application)

        with ZipFile(BytesIO(rendered.content)) as archive:
            xml = archive.read('word/document.xml').decode('utf-8')

        self.assertIn('Demo Vendor LLC', xml)
        self.assertIn('10 Test Street, Yerevan', xml)
        self.assertNotIn('__VENDOR_', xml)
        self.assertNotIn('__AGREEMENT_DATE_', xml)
        self.assertEqual(len(rendered.document_sha256), 64)
        self.assertEqual(len(rendered.template_sha256), 64)

class SellerApplicationTaxNumberValidationTests(TestCase):
    def test_accepts_exactly_eight_digits(self):
        serializer = SellerApplicationSerializer(
            data={'tax_number': '01234567'},
            partial=True,
        )
        self.assertTrue(serializer.is_valid(), serializer.errors)
        self.assertEqual(
            serializer.validated_data['tax_number'],
            '01234567',
        )

    def test_rejects_short_tax_number(self):
        serializer = SellerApplicationSerializer(
            data={'tax_number': '1234567'},
            partial=True,
        )
        self.assertFalse(serializer.is_valid())
        self.assertIn('tax_number', serializer.errors)

    def test_rejects_long_tax_number(self):
        serializer = SellerApplicationSerializer(
            data={'tax_number': '123456789'},
            partial=True,
        )
        self.assertFalse(serializer.is_valid())
        self.assertIn('tax_number', serializer.errors)

    def test_rejects_non_digit_tax_number(self):
        serializer = SellerApplicationSerializer(
            data={'tax_number': '1234A678'},
            partial=True,
        )
        self.assertFalse(serializer.is_valid())
        self.assertIn('tax_number', serializer.errors)

    def test_blank_tax_number_is_allowed_while_draft_is_incomplete(self):
        serializer = SellerApplicationSerializer(
            data={'tax_number': ''},
            partial=True,
        )
        self.assertTrue(serializer.is_valid(), serializer.errors)

