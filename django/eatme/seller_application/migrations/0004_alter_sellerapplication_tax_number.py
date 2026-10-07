from django.core.validators import RegexValidator
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('seller_application', '0003_selleragencyagreementacceptance'),
    ]

    operations = [
        migrations.AlterField(
            model_name='sellerapplication',
            name='tax_number',
            field=models.CharField(
                blank=True,
                max_length=8,
                validators=[
                    RegexValidator(
                        regex='^[0-9]{8}$',
                        message='ИНН должен содержать ровно 8 цифр.',
                        code='invalid_tax_number',
                    ),
                ],
                verbose_name='ИНН',
            ),
        ),
    ]
