from django.core.management.base import BaseCommand

from seller_application.models import (
    BusinessCategory,
    CompanyChannel,
)


class Command(BaseCommand):
    help = 'Создаёт направления HOT/DEALS и категории бизнеса'

    def handle(self, *args, **options):
        hot, _ = CompanyChannel.objects.update_or_create(
            code=CompanyChannel.Code.HOT,
            defaults={
                'is_active': True,
            },
        )

        deals, _ = CompanyChannel.objects.update_or_create(
            code=CompanyChannel.Code.DEALS,
            defaults={
                'is_active': True,
            },
        )

        categories = [
            {
                'code': 'cafe',
                'name_en': 'Cafe',
                'name_ru': 'Кафе',
                'name_hy': 'Սրճարան',
                'channels': [hot],
                'sort_order': 10,
            },
            {
                'code': 'restaurant',
                'name_en': 'Restaurant',
                'name_ru': 'Ресторан',
                'name_hy': 'Ռեստորան',
                'channels': [hot],
                'sort_order': 20,
            },
            {
                'code': 'bakery',
                'name_en': 'Bakery',
                'name_ru': 'Пекарня',
                'name_hy': 'Հացաբուլկեղեն',
                'channels': [hot],
                'sort_order': 30,
            },
            {
                'code': 'confectionery',
                'name_en': 'Confectionery',
                'name_ru': 'Кондитерская',
                'name_hy': 'Հրուշակեղեն',
                'channels': [hot],
                'sort_order': 40,
            },
            {
                'code': 'coffee-shop',
                'name_en': 'Coffee shop',
                'name_ru': 'Кофейня',
                'name_hy': 'Սրճարան',
                'channels': [hot],
                'sort_order': 50,
            },
            {
                'code': 'grocery-store',
                'name_en': 'Grocery store',
                'name_ru': 'Продуктовый магазин',
                'name_hy': 'Մթերային խանութ',
                'channels': [deals],
                'sort_order': 60,
            },
            {
                'code': 'manufacturer',
                'name_en': 'Manufacturer',
                'name_ru': 'Производитель',
                'name_hy': 'Արտադրող',
                'channels': [deals],
                'sort_order': 70,
            },
            {
                'code': 'warehouse',
                'name_en': 'Warehouse',
                'name_ru': 'Склад',
                'name_hy': 'Պահեստ',
                'channels': [deals],
                'sort_order': 80,
            },
            {
                'code': 'distributor',
                'name_en': 'Distributor',
                'name_ru': 'Дистрибьютор',
                'name_hy': 'Դիստրիբյուտոր',
                'channels': [deals],
                'sort_order': 90,
            },
            {
                'code': 'electronics',
                'name_en': 'Electronics',
                'name_ru': 'Электроника',
                'name_hy': 'Էլեկտրոնիկա',
                'channels': [deals],
                'sort_order': 100,
            },
            {
                'code': 'other',
                'name_en': 'Other',
                'name_ru': 'Другое',
                'name_hy': 'Այլ',
                'channels': [hot, deals],
                'sort_order': 200,
            },
        ]

        for item in categories:
            channels = item.pop('channels')

            category, _ = BusinessCategory.objects.update_or_create(
                code=item['code'],
                defaults=item,
            )

            category.allowed_channels.set(channels)

            self.stdout.write(
                self.style.SUCCESS(
                    f'Создана/обновлена категория: {category.code}'
                )
            )

        self.stdout.write(
            self.style.SUCCESS(
                'Направления и категории успешно созданы.'
            )
        )
