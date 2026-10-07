# Generated manually for Appsosa legal consent v1.
from django.conf import settings
from django.db import migrations, models
from django.db.models import Q
import django.db.models.deletion
import django.utils.timezone
import legal.models


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='LegalDocument',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('document_type', models.CharField(choices=[('terms', 'Условия использования'), ('privacy', 'Политика конфиденциальности'), ('refund', 'Политика возврата'), ('food_safety', 'Безопасность пищевых продуктов'), ('card_security', 'Безопасность данных карты')], db_index=True, max_length=40)),
                ('version', models.CharField(max_length=20)),
                ('placement', models.CharField(choices=[('registration', 'Регистрация'), ('checkout', 'Перед покупкой'), ('informational', 'Информационный документ')], db_index=True, default='informational', max_length=20)),
                ('requires_acceptance', models.BooleanField(default=False)),
                ('is_active', models.BooleanField(db_index=True, default=False)),
                ('sort_order', models.PositiveSmallIntegerField(default=100)),
                ('effective_at', models.DateTimeField(default=django.utils.timezone.now)),
                ('title_en', models.CharField(max_length=255)),
                ('title_ru', models.CharField(max_length=255)),
                ('title_hy', models.CharField(max_length=255)),
                ('content_en', models.TextField()),
                ('content_ru', models.TextField()),
                ('content_hy', models.TextField()),
                ('hash_en', models.CharField(editable=False, max_length=64)),
                ('hash_ru', models.CharField(editable=False, max_length=64)),
                ('hash_hy', models.CharField(editable=False, max_length=64)),
                ('snapshot_en', models.FileField(blank=True, max_length=500, upload_to=legal.models._legal_snapshot_path)),
                ('snapshot_ru', models.FileField(blank=True, max_length=500, upload_to=legal.models._legal_snapshot_path)),
                ('snapshot_hy', models.FileField(blank=True, max_length=500, upload_to=legal.models._legal_snapshot_path)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'ordering': ('sort_order', 'document_type', '-effective_at', '-id'),
            },
        ),
        migrations.CreateModel(
            name='LegalConsent',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('document_type', models.CharField(max_length=40)),
                ('document_version', models.CharField(max_length=20)),
                ('language', models.CharField(max_length=5)),
                ('document_hash', models.CharField(max_length=64)),
                ('source', models.CharField(choices=[('registration', 'Регистрация'), ('account_gate', 'Обязательное согласие после входа'), ('checkout', 'Перед покупкой'), ('other', 'Другое')], default='other', max_length=30)),
                ('ip_address', models.GenericIPAddressField(blank=True, null=True)),
                ('user_agent', models.TextField(blank=True, default='')),
                ('accepted_at', models.DateTimeField(auto_now_add=True, db_index=True)),
                ('document', models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name='consents', to='legal.legaldocument')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='legal_consents', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ('-accepted_at', '-id'),
            },
        ),
        migrations.AddConstraint(
            model_name='legaldocument',
            constraint=models.UniqueConstraint(fields=('document_type', 'version'), name='legal_unique_type_version'),
        ),
        migrations.AddConstraint(
            model_name='legaldocument',
            constraint=models.UniqueConstraint(condition=Q(is_active=True), fields=('document_type',), name='legal_one_active_version_per_type'),
        ),
        migrations.AddConstraint(
            model_name='legalconsent',
            constraint=models.UniqueConstraint(fields=('user', 'document'), name='legal_unique_user_document_consent'),
        ),
    ]
