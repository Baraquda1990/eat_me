import hashlib

from django.core.files.base import ContentFile
from django.core.management.base import BaseCommand
from django.db import transaction

from legal.models import LegalDocument


TERMS_EN = """Terms and Conditions of Use

1. Acceptance of Terms
By accessing or using Appsosa LLC, you agree to be bound by these Terms and Conditions. If you do not agree to these terms, you may not use the platform.

2. Marketplace Role
Appsosa LLC acts as a digital intermediary connecting users with vendors for the purpose of purchasing surplus food products. Appsosa LLC does not own, manufacture, package, or store the food items sold through the platform.

3. Product Safety and Quality
Products are provided by third-party vendors. Users acknowledge that these items are sold as described by the vendor. While Appsosa encourages high standards, the vendor is responsible for food safety, hygiene, product quality, and the accuracy of allergen information.

4. User Conduct
Users agree to use the platform only for lawful purposes. Prohibited activities include fraudulent transactions, spam, unauthorized scraping, and attempts to compromise platform security.

5. Payments and Refunds
Payments and refund requests are handled according to the payment flow and the current Appsosa Refund Policy. Eligibility for a refund depends on the circumstances described in that policy and applicable law.

6. Limitation of Liability
To the maximum extent permitted by applicable law, Appsosa LLC is not responsible for losses caused by acts or omissions of independent vendors, including issues related to the preparation, storage, description, allergens, or quality of products supplied by those vendors.

7. Governing Law
These Terms are governed by the laws of the Republic of Armenia.
"""

TERMS_RU = """Условия использования

1. Принятие условий
Получая доступ к Appsosa ООО или используя платформу, вы соглашаетесь соблюдать настоящие Условия. Если вы не согласны с ними, вы не можете использовать функции платформы, требующие принятия этих условий.

2. Роль торговой площадки
Appsosa ООО выступает цифровым посредником, связывающим пользователей с продавцами для приобретения излишков продуктов питания. Appsosa ООО не является владельцем, производителем, упаковщиком или хранителем товаров, продаваемых продавцами через платформу.

3. Безопасность и качество продукции
Товары предоставляются сторонними продавцами. Пользователь получает товары в соответствии с описанием продавца. Appsosa поддерживает высокие стандарты, однако продавец отвечает за безопасность пищевых продуктов, гигиену, качество продукции и точность информации об аллергенах.

4. Поведение пользователя
Пользователь обязуется использовать платформу только в законных целях. Запрещаются мошеннические операции, спам, несанкционированный сбор данных и попытки нарушить безопасность платформы.

5. Платежи и возвраты
Платежи и запросы на возврат обрабатываются в соответствии с используемым платежным процессом и актуальной Политикой возврата Appsosa. Право на возврат зависит от обстоятельств, указанных в этой политике, и требований применимого законодательства.

6. Ограничение ответственности
В максимально допустимой законом степени Appsosa ООО не отвечает за убытки, вызванные действиями или бездействием независимых продавцов, включая вопросы приготовления, хранения, описания, аллергенов или качества продуктов, предоставляемых продавцами.

7. Применимое право
Настоящие Условия регулируются законодательством Республики Армения.
"""

TERMS_HY = """Օգտագործման պայմաններ

1. Պայմանների ընդունում
Մուտք գործելով կամ օգտագործելով Appsosa ՍՊԸ հարթակը՝ դուք համաձայնում եք պահպանել սույն Պայմանները։ Եթե համաձայն չեք դրանց հետ, չեք կարող օգտվել այն գործառույթներից, որոնց համար պահանջվում է այս պայմանների ընդունումը։

2. Հարթակի դերը
Appsosa ՍՊԸ-ն հանդես է գալիս որպես թվային միջնորդ՝ կապելով օգտատերերին վաճառողների հետ ավելցուկային սննդամթերք ձեռք բերելու նպատակով։ Appsosa ՍՊԸ-ն չի հանդիսանում վաճառողների կողմից հարթակի միջոցով վաճառվող ապրանքների սեփականատերը, արտադրողը, փաթեթավորողը կամ պահեստավորողը։

3. Ապրանքի անվտանգություն և որակ
Ապրանքները տրամադրվում են երրորդ կողմ հանդիսացող վաճառողների կողմից։ Օգտատերը ստանում է ապրանքը վաճառողի նկարագրությանը համապատասխան։ Appsosa-ն խրախուսում է բարձր չափանիշներ, սակայն սննդամթերքի անվտանգության, հիգիենայի, որակի և ալերգենների վերաբերյալ տեղեկատվության ճշգրտության համար պատասխանատու է վաճառողը։

4. Օգտատիրոջ վարքագիծ
Օգտատերը պարտավորվում է հարթակն օգտագործել միայն օրինական նպատակներով։ Արգելվում են խարդախ գործարքները, սպամը, չարտոնված տվյալների հավաքագրումը և հարթակի անվտանգությունը խախտելու փորձերը։

5. Վճարումներ և վերադարձներ
Վճարումները և վերադարձի հարցումները մշակվում են կիրառվող վճարային գործընթացի և Appsosa-ի գործող Վերադարձի քաղաքականության համաձայն։ Վերադարձի իրավունքը կախված է այդ քաղաքականությամբ նկարագրված հանգամանքներից և կիրառելի օրենսդրության պահանջներից։

6. Պատասխանատվության սահմանափակում
Կիրառելի օրենքով թույլատրելի առավելագույն չափով Appsosa ՍՊԸ-ն պատասխանատվություն չի կրում անկախ վաճառողների գործողությունների կամ անգործության հետևանքով առաջացած վնասների համար, ներառյալ վաճառողների կողմից տրամադրվող ապրանքների պատրաստման, պահպանման, նկարագրության, ալերգենների կամ որակի հետ կապված հարցերը։

7. Կիրառելի իրավունք
Սույն Պայմանները կարգավորվում են Հայաստանի Հանրապետության օրենսդրությամբ։
"""

PRIVACY_EN = """Privacy Policy

1. Data Collection
We collect personal information needed to provide Appsosa services, including information such as your name or username, email address, phone number, delivery or profile address, and location data when you allow location access.

2. Usage of Data
We use this information to operate accounts, facilitate orders, show relevant nearby offers, improve application performance, provide customer support, prevent abuse, and send service-related updates and notifications.

3. Order, Service and Consent Data
When you use Appsosa, the service may also process order history, favorites, reviews, notification preferences and device tokens, and technical information required for operation and security. When you accept a legal document, Appsosa may record the document type and version, language, content hash, date and time of acceptance, IP address and user-agent information for audit purposes.

4. Data Protection
We use organizational and technical measures designed to protect personal information from unauthorized access, alteration, disclosure, or loss.

5. Third-Party Sharing
We do not sell your personal data. We may share information that is necessary to provide the service, for example with a vendor to fulfill an order or with service providers that process infrastructure, notifications, storage, analytics, or payments on our behalf.

6. Payment Data
Where payments are handled by an external payment provider, payment-card data is processed according to that provider's integration. Appsosa should not store full card numbers when the selected payment integration sends card data directly to the payment processor.

7. Updates
We may update this Privacy Policy when the service or legal requirements change. When a new version requires renewed consent, the application will ask you to review and accept it.
"""

PRIVACY_RU = """Политика конфиденциальности

1. Сбор данных
Мы собираем персональную информацию, необходимую для предоставления сервисов Appsosa, включая имя или логин, адрес электронной почты, номер телефона, адрес профиля или доставки, а также данные о местоположении, если пользователь разрешил доступ к геолокации.

2. Использование данных
Мы используем эти данные для работы аккаунта, оформления и выполнения заказов, показа ближайших предложений, улучшения приложения, поддержки пользователей, предотвращения злоупотреблений и отправки сервисных уведомлений.

3. Данные об использовании сервиса и согласиях
При использовании Appsosa также могут обрабатываться история заказов, избранное, отзывы, настройки уведомлений и токены устройств, а также техническая информация, необходимая для работы и безопасности сервиса. При принятии юридического документа Appsosa может сохранять тип и версию документа, язык, хеш содержимого, дату и время принятия, IP-адрес и сведения user-agent в целях аудита.

4. Защита данных
Мы применяем организационные и технические меры, предназначенные для защиты персональной информации от несанкционированного доступа, изменения, раскрытия или утраты.

5. Передача третьим лицам
Мы не продаём персональные данные. Информация может передаваться в объёме, необходимом для оказания сервиса, например продавцу для выполнения заказа или поставщикам инфраструктуры, уведомлений, хранения, аналитики и платежных услуг, действующим от нашего имени.

6. Платёжные данные
Если платежи обрабатывает внешний платежный провайдер, данные карты обрабатываются в соответствии с выбранной интеграцией этого провайдера. Appsosa не должна хранить полный номер карты, если выбранная платежная интеграция передаёт данные карты непосредственно платежному процессору.

7. Обновления
Политика конфиденциальности может обновляться при изменении сервиса или требований законодательства. Если новая версия требует повторного согласия, приложение предложит ознакомиться с ней и принять её.
"""

PRIVACY_HY = """Գաղտնիության քաղաքականություն

1. Տվյալների հավաքագրում
Մենք հավաքում ենք Appsosa ծառայությունների մատուցման համար անհրաժեշտ անձնական տվյալներ, ներառյալ անունը կամ օգտանունը, էլեկտրոնային փոստի հասցեն, հեռախոսահամարը, պրոֆիլի կամ առաքման հասցեն, ինչպես նաև գտնվելու վայրի տվյալները, եթե օգտատերը թույլատրել է տեղադրության հասանելիությունը։

2. Տվյալների օգտագործում
Տվյալներն օգտագործվում են հաշվի աշխատանքի, պատվերների ձևակերպման և կատարման, մոտակա առաջարկների ցուցադրման, հավելվածի աշխատանքի բարելավման, օգտատերերի աջակցության, չարաշահումների կանխարգելման և ծառայողական ծանուցումների ուղարկման համար։

3. Ծառայության օգտագործման և համաձայնությունների տվյալներ
Appsosa-ն օգտագործելիս կարող են մշակվել նաև պատվերների պատմությունը, ընտրյալները, կարծիքները, ծանուցումների կարգավորումները և սարքի թոքենները, ինչպես նաև ծառայության աշխատանքի և անվտանգության համար անհրաժեշտ տեխնիկական տեղեկությունները։ Իրավական փաստաթուղթ ընդունելիս Appsosa-ն աուդիտի նպատակով կարող է պահպանել փաստաթղթի տեսակը և տարբերակը, լեզուն, բովանդակության հեշը, ընդունման ամսաթիվն ու ժամը, IP հասցեն և user-agent տեղեկությունները։

4. Տվյալների պաշտպանություն
Մենք կիրառում ենք կազմակերպական և տեխնիկական միջոցներ՝ անձնական տվյալները չարտոնված հասանելիությունից, փոփոխումից, բացահայտումից կամ կորստից պաշտպանելու նպատակով։

5. Երրորդ կողմերի հետ տվյալների փոխանցում
Մենք չենք վաճառում անձնական տվյալները։ Տվյալները կարող են փոխանցվել միայն ծառայությունը մատուցելու համար անհրաժեշտ ծավալով, օրինակ՝ վաճառողին՝ պատվերը կատարելու համար, կամ մեր անունից ենթակառուցվածք, ծանուցումներ, պահպանում, վերլուծություն կամ վճարային ծառայություններ տրամադրող մատակարարներին։

6. Վճարային տվյալներ
Եթե վճարումները մշակվում են արտաքին վճարային մատակարարի կողմից, քարտային տվյալները մշակվում են տվյալ մատակարարի ընտրված ինտեգրման համաձայն։ Appsosa-ն չպետք է պահպանի քարտի ամբողջական համարը, եթե ընտրված ինտեգրումը քարտային տվյալներն անմիջապես փոխանցում է վճարային մշակողին։

7. Թարմացումներ
Գաղտնիության քաղաքականությունը կարող է թարմացվել ծառայության կամ իրավական պահանջների փոփոխության դեպքում։ Եթե նոր տարբերակը պահանջում է կրկին համաձայնություն, հավելվածը կառաջարկի ծանոթանալ և ընդունել այն։
"""

REFUND_EN = """Refund Policy

Refunds may be provided if a vendor is unexpectedly closed, if the food is spoiled, or if the order was not fulfilled as described. Refund requests should be submitted within 24 hours of the scheduled pickup or delivery time through the Appsosa Support section. Each request is reviewed according to the circumstances of the order, the current payment method, and applicable law.
"""

REFUND_RU = """Политика возврата средств

Возврат средств может быть предоставлен, если продавец неожиданно закрыт, еда испорчена или заказ не был выполнен в соответствии с описанием. Запрос на возврат следует подать в течение 24 часов после запланированного времени получения или доставки через раздел «Поддержка» в Appsosa. Каждый запрос рассматривается с учётом обстоятельств заказа, используемого способа оплаты и требований применимого законодательства.
"""

REFUND_HY = """Վերադարձի քաղաքականություն

Գումարի վերադարձ կարող է տրամադրվել, եթե վաճառողը անսպասելիորեն փակ է, սնունդը փչացած է կամ պատվերը չի կատարվել նկարագրությանը համապատասխան։ Վերադարձի հարցումը պետք է ներկայացնել նախատեսված ստացման կամ առաքման ժամից հետո 24 ժամվա ընթացքում՝ Appsosa-ի «Աջակցություն» բաժնի միջոցով։ Յուրաքանչյուր հարցում դիտարկվում է՝ հաշվի առնելով պատվերի հանգամանքները, կիրառվող վճարման եղանակը և կիրառելի օրենսդրությունը։
"""

FOOD_EN = """Food Safety Disclaimer

By making a purchase, you acknowledge that products are provided directly by the vendor. Appsosa acts only as a digital intermediary and is not the producer or preparer of the food. The vendor is responsible for food safety, quality, hygiene, and the accuracy of allergen information relating to the products it supplies.

If you have allergies, dietary restrictions, or other specific dietary concerns, please contact the vendor directly before completing or collecting the order.
"""

FOOD_RU = """Отказ от ответственности за безопасность пищевых продуктов

Совершая покупку, вы подтверждаете, что товары предоставляются непосредственно продавцом. Appsosa выступает только в качестве цифрового посредника и не является производителем или изготовителем продуктов. Продавец отвечает за безопасность пищевых продуктов, качество, гигиену и точность информации об аллергенах в отношении предоставляемых им товаров.

Если у вас есть аллергии, ограничения в питании или иные специальные требования к рациону, пожалуйста, заранее свяжитесь непосредственно с продавцом до завершения или получения заказа.
"""

FOOD_HY = """Սննդի անվտանգության վերաբերյալ պատասխանատվության սահմանափակում

Գնում կատարելով՝ դուք հաստատում եք, որ ապրանքները տրամադրվում են անմիջապես վաճառողի կողմից։ Appsosa-ն հանդես է գալիս միայն որպես թվային միջնորդ և չի հանդիսանում սննդամթերքի արտադրող կամ պատրաստող։ Վաճառողը պատասխանատու է իր կողմից տրամադրվող սննդամթերքի անվտանգության, որակի, հիգիենայի և ալերգենների վերաբերյալ տեղեկատվության ճշգրտության համար։

Եթե ունեք ալերգիաներ, սննդակարգային սահմանափակումներ կամ այլ հատուկ պահանջներ, խնդրում ենք նախապես՝ մինչև պատվերի վերջնական ձևակերպումը կամ ստացումը, անմիջապես կապվել վաճառողի հետ։
"""

CARD_EN = """Card Information Security

Appsosa prioritizes the security of payment data. When the selected payment integration sends card data directly to a PCI-DSS compliant payment provider, Appsosa does not store full credit or debit card numbers on its servers and should not receive raw card details. Sensitive payment information is handled according to the payment provider's secure integration.
"""

CARD_RU = """Безопасность данных карты

Appsosa уделяет приоритетное внимание безопасности платёжных данных. Если выбранная платежная интеграция передаёт данные карты непосредственно платежному провайдеру, соответствующему PCI-DSS, Appsosa не хранит полные номера кредитных или дебетовых карт на своих серверах и не должна получать необработанные реквизиты карты. Конфиденциальная платежная информация обрабатывается в соответствии с защищённой интеграцией платежного провайдера.
"""

CARD_HY = """Քարտային տվյալների անվտանգություն

Appsosa-ն առաջնահերթություն է տալիս վճարային տվյալների անվտանգությանը։ Եթե ընտրված վճարային ինտեգրումը քարտային տվյալներն անմիջապես փոխանցում է PCI-DSS պահանջներին համապատասխանող վճարային մատակարարին, Appsosa-ն իր սերվերներում չի պահպանում վարկային կամ դեբետային քարտերի ամբողջական համարները և չպետք է ստանա քարտի չմշակված տվյալները։ Զգայուն վճարային տեղեկատվությունը մշակվում է վճարային մատակարարի անվտանգ ինտեգրման համաձայն։
"""


DOCUMENTS = [
    {
        'document_type': 'terms',
        'version': '1.0',
        'placement': 'registration',
        'requires_acceptance': True,
        'sort_order': 10,
        'title_en': 'Terms of Use',
        'title_ru': 'Условия использования',
        'title_hy': 'Օգտագործման պայմաններ',
        'content_en': TERMS_EN,
        'content_ru': TERMS_RU,
        'content_hy': TERMS_HY,
    },
    {
        'document_type': 'privacy',
        'version': '1.0',
        'placement': 'registration',
        'requires_acceptance': True,
        'sort_order': 20,
        'title_en': 'Privacy Policy',
        'title_ru': 'Политика конфиденциальности',
        'title_hy': 'Գաղտնիության քաղաքականություն',
        'content_en': PRIVACY_EN,
        'content_ru': PRIVACY_RU,
        'content_hy': PRIVACY_HY,
    },
    {
        'document_type': 'refund',
        'version': '1.0',
        'placement': 'informational',
        'requires_acceptance': False,
        'sort_order': 30,
        'title_en': 'Refund Policy',
        'title_ru': 'Политика возврата средств',
        'title_hy': 'Վերադարձի քաղաքականություն',
        'content_en': REFUND_EN,
        'content_ru': REFUND_RU,
        'content_hy': REFUND_HY,
    },
    {
        'document_type': 'food_safety',
        'version': '1.0',
        'placement': 'checkout',
        'requires_acceptance': True,
        'sort_order': 40,
        'title_en': 'Food Safety Disclaimer',
        'title_ru': 'Безопасность пищевых продуктов',
        'title_hy': 'Սննդի անվտանգության վերաբերյալ պատասխանատվության սահմանափակում',
        'content_en': FOOD_EN,
        'content_ru': FOOD_RU,
        'content_hy': FOOD_HY,
    },
    {
        'document_type': 'card_security',
        'version': '1.0',
        'placement': 'informational',
        'requires_acceptance': False,
        'sort_order': 50,
        'title_en': 'Card Information Security',
        'title_ru': 'Безопасность данных карты',
        'title_hy': 'Քարտային տվյալների անվտանգություն',
        'content_en': CARD_EN,
        'content_ru': CARD_RU,
        'content_hy': CARD_HY,
    },
]


def _hash(text):
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


class Command(BaseCommand):
    help = 'Create Appsosa legal document v1.0 and archive immutable snapshots in default R2 storage.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--activate',
            action='store_true',
            help='Activate reviewed v1.0 Terms, Privacy, Refund and Food Safety documents.',
        )
        parser.add_argument(
            '--activate-card-security',
            action='store_true',
            help='Also activate Card Security after the final payment integration has been verified.',
        )

    @transaction.atomic
    def handle(self, *args, **options):
        activate = bool(options['activate'])
        activate_card_security = bool(options['activate_card_security'])

        for payload in DOCUMENTS:
            document_type = payload['document_type']
            version = payload['version']

            should_activate = (
                activate
                and document_type != 'card_security'
            ) or (
                activate_card_security
                and document_type == 'card_security'
            )

            if should_activate:
                LegalDocument.objects.filter(
                    document_type=document_type,
                    is_active=True,
                ).exclude(version=version).update(is_active=False)

            document, _ = LegalDocument.objects.get_or_create(
                document_type=document_type,
                version=version,
                defaults={**payload, 'is_active': False},
            )

            old_hashes = {
                code: getattr(document, f'hash_{code}', '')
                for code in ('en', 'ru', 'hy')
            }

            for key, value in payload.items():
                setattr(document, key, value)

            # A plain seed/update never disables an already active version.
            # Activation is an explicit deployment step.
            if should_activate:
                document.is_active = True
            document.save()

            for code in ('en', 'ru', 'hy'):
                content = getattr(document, f'content_{code}')
                new_hash = _hash(content)
                field = getattr(document, f'snapshot_{code}')

                if field and old_hashes.get(code) == new_hash:
                    continue

                filename = f'{code}-{new_hash[:16]}.txt'
                field.save(
                    filename,
                    ContentFile(content.encode('utf-8')),
                    save=False,
                )

            document.save()
            self.stdout.write(
                self.style.SUCCESS(
                    f'{document.document_type} v{document.version}: '
                    f'{"ACTIVE" if document.is_active else "inactive"}'
                )
            )

        if not activate:
            self.stdout.write(
                self.style.WARNING(
                    'Documents were seeded but left inactive. Review them, then run '
                    '`python manage.py seed_legal_documents --activate`.'
                )
            )
