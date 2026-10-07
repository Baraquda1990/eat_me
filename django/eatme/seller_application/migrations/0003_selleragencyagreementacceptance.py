# Generated for Appsosa seller agency agreement acceptance

import core.storage_backends
import django.db.models.deletion
import seller_application.models
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('seller_application', '0002_alter_sellerapplicationdocument_file'),
    ]

    operations = [
        migrations.CreateModel(
            name='SellerAgencyAgreementAcceptance',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('version', models.CharField(max_length=30, verbose_name='Версия договора')),
                ('language', models.CharField(choices=[('hy', 'Հայերեն'), ('ru', 'Русский'), ('en', 'English')], default='en', max_length=5, verbose_name='Язык интерфейса при принятии')),
                ('template_sha256', models.CharField(max_length=64, verbose_name='SHA-256 шаблона')),
                ('document_sha256', models.CharField(max_length=64, verbose_name='SHA-256 принятого документа')),
                ('snapshot', models.FileField(storage=core.storage_backends.get_private_storage, upload_to=seller_application.models.seller_agreement_snapshot_upload_path, verbose_name='Snapshot договора')),
                ('accepted_at', models.DateTimeField(verbose_name='Дата и время принятия')),
                ('ip_address', models.GenericIPAddressField(blank=True, null=True, verbose_name='IP-адрес')),
                ('user_agent', models.TextField(blank=True, verbose_name='User-Agent')),
                ('created', models.DateTimeField(auto_now_add=True, verbose_name='Создано')),
                ('updated', models.DateTimeField(auto_now=True, verbose_name='Изменено')),
                ('application', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='agency_agreement_acceptances', to='seller_application.sellerapplication', verbose_name='Заявка')),
            ],
            options={
                'ordering': ('-accepted_at', '-id'),
                'verbose_name': 'Принятие агентского договора',
                'verbose_name_plural': 'Принятия агентских договоров',
            },
        ),
    ]
