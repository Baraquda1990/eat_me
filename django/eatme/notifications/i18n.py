# notifications/i18n.py
# Centralized localization for automatic notification texts.

SUPPORTED_LANGUAGES = {'ru', 'en', 'hy'}
DEFAULT_LANGUAGE = 'en'

TRANSLATIONS = {
    'ru': {
        'welcome_title': 'Добро пожаловать в Appsosa!',
        'welcome_body': 'Рады видеть вас! Находите выгодные предложения рядом, сохраняйте любимые места и получайте уведомления о новых товарах.',
        'alarm_saved_title': 'Уведомление сохранено',
        'alarm_saved_body': 'Уведомление сохранено на {date}. Мы уведомим вас о новых предложениях.',
        'favorite_store_title': 'Любимый магазин',
        'favorite_store_body': '{company} добавил новое предложение: {product}',
        'nearby_title': 'Новое предложение рядом',
        'nearby_body': 'Рядом появилось предложение: {product}',
        'alarm_match_title': 'Найдено предложение',
        'alarm_match_body': '{company} добавил товар «{product}»',
        'recommendation_title': 'Рекомендация для вас',
        'recommendation_body': 'Мы нашли предложение, которое может вам понравиться: {product}',
        'review_reminder_title': 'Оцените заказ',
        'review_reminder_body': 'Теперь можно оценить покупку и оставить отзыв',
        'product_expired_title': 'Время получения товара истекло',
        'product_expired_body': 'Товар «{product}» автоматически снят с продажи.',
        'low_stock_title': 'Товар закончился',
        'low_stock_body': 'Товар «{product}» полностью распродан. Остаток: 0.',
        'new_product_title': 'Новое предложение',
        'new_product_body': '{company} добавил новое предложение: {product}',
        'order_created_title': 'Новый заказ',
        'order_created_hot_body': 'Заказ №{order_number}. {buyer} оформил заказ: {product}. Кол-во: {quantity}. Тел: {phone}',
        'order_created_cart_body': '{buyer} оформил новый заказ. Кол-во товаров: {quantity}. Тел: {phone}',
        'order_reserved_title': 'Заказ зарезервирован',
        'order_reserved_body': 'Ваш заказ №{order_number} зарезервирован.',
    },
    'en': {
        'welcome_title': 'Welcome to Appsosa!',
        'welcome_body': 'Great to have you here! Discover nearby deals, save your favorite places and get notified about new offers.',
        'alarm_saved_title': 'Notification saved',
        'alarm_saved_body': 'Notification saved for {date}. We will notify you about new offers.',
        'favorite_store_title': 'Favorite store',
        'favorite_store_body': '{company} added a new offer: {product}',
        'nearby_title': 'New offer nearby',
        'nearby_body': 'A new offer appeared nearby: {product}',
        'alarm_match_title': 'Offer found',
        'alarm_match_body': '{company} added the item “{product}”',
        'recommendation_title': 'Recommended for you',
        'recommendation_body': 'We found an offer you may like: {product}',
        'review_reminder_title': 'Rate your order',
        'review_reminder_body': 'You can now rate your purchase and leave a review',
        'product_expired_title': 'Pickup time has expired',
        'product_expired_body': '“{product}” was automatically removed from sale.',
        'low_stock_title': 'Item sold out',
        'low_stock_body': '“{product}” is completely sold out. Remaining: 0.',
        'new_product_title': 'New offer',
        'new_product_body': '{company} added a new offer: {product}',
        'order_created_title': 'New order',
        'order_created_hot_body': 'Order #{order_number}. {buyer} placed an order: {product}. Qty: {quantity}. Phone: {phone}',
        'order_created_cart_body': '{buyer} placed a new order. Total quantity: {quantity}. Phone: {phone}',
        'order_reserved_title': 'Order reserved',
        'order_reserved_body': 'Your order #{order_number} has been reserved.',
    },
    'hy': {
        'welcome_title': 'Բարի գալուստ Appsosa!',
        'welcome_body': 'Ուրախ ենք տեսնել ձեզ։ Գտեք շահավետ առաջարկներ մոտակայքում, պահպանեք սիրելի վայրերը և ստացեք ծանուցումներ նոր առաջարկների մասին։',
        'alarm_saved_title': 'Ծանուցումը պահպանված է',
        'alarm_saved_body': 'Ծանուցումը պահպանված է {date}-ի համար։ Մենք կտեղեկացնենք նոր առաջարկների մասին։',
        'favorite_store_title': 'Սիրելի խանութ',
        'favorite_store_body': '{company}-ը ավելացրել է նոր առաջարկ՝ {product}',
        'nearby_title': 'Նոր առաջարկ մոտակայքում',
        'nearby_body': 'Մոտակայքում հայտնվել է նոր առաջարկ՝ {product}',
        'alarm_match_title': 'Առաջարկ է գտնվել',
        'alarm_match_body': '{company}-ը ավելացրել է «{product}» ապրանքը',
        'recommendation_title': 'Առաջարկ ձեզ համար',
        'recommendation_body': 'Մենք գտել ենք առաջարկ, որը կարող է ձեզ դուր գալ՝ {product}',
        'review_reminder_title': 'Գնահատեք պատվերը',
        'review_reminder_body': 'Այժմ կարող եք գնահատել գնումը և թողնել կարծիք',
        'product_expired_title': 'Ապրանքի ստացման ժամանակը լրացել է',
        'product_expired_body': '«{product}» ապրանքը ավտոմատ հանվել է վաճառքից։',
        'low_stock_title': 'Ապրանքը սպառվել է',
        'low_stock_body': '«{product}» ապրանքն ամբողջությամբ վաճառվել է։ Մնացորդ՝ 0։',
        'new_product_title': 'Նոր առաջարկ',
        'new_product_body': '{company}-ը ավելացրել է նոր առաջարկ՝ {product}',
        'order_created_title': 'Նոր պատվեր',
        'order_created_hot_body': 'Պատվեր №{order_number}։ {buyer}-ը պատվիրել է՝ {product}։ Քանակ՝ {quantity}։ Հեռ․՝ {phone}',
        'order_created_cart_body': '{buyer}-ը ձևակերպել է նոր պատվեր։ Ընդհանուր քանակ՝ {quantity}։ Հեռ․՝ {phone}',
        'order_reserved_title': 'Պատվերը ամրագրված է',
        'order_reserved_body': 'Ձեր №{order_number} պատվերն ամրագրված է։',
    },
}


def get_user_language(user):
    try:
        code = str(user.profile.language or '').strip().lower().split('-')[0]
    except Exception:
        code = DEFAULT_LANGUAGE
    return code if code in SUPPORTED_LANGUAGES else DEFAULT_LANGUAGE


def tr(user, key, **kwargs):
    language = get_user_language(user)
    template = TRANSLATIONS.get(language, TRANSLATIONS[DEFAULT_LANGUAGE]).get(key)
    if template is None:
        template = TRANSLATIONS[DEFAULT_LANGUAGE].get(key, key)
    try:
        return template.format(**kwargs)
    except (KeyError, IndexError, ValueError):
        return template


def localize_notification(user, type_, data=None, fallback_title='', fallback_body=''):
    """Return localized (title, body) for an automatic notification.

    This reconstructs text from language-neutral values in Notification.data,
    so old rows that were originally stored in Russian are displayed in the
    user's CURRENT selected language too.
    """
    data = data if isinstance(data, dict) else {}
    type_ = str(type_ or '')

    if type_ == 'welcome':
        return tr(user, 'welcome_title'), tr(user, 'welcome_body')

    company = str(data.get('company_name') or '').strip()
    product = str(data.get('product_name') or '').strip()
    buyer = str(data.get('buyer_username') or '').strip()
    phone = str(data.get('buyer_phone') or '').strip() or '—'
    order_number = str(data.get('order_number') or data.get('card_id') or '').strip()
    quantity = str(data.get('quantity') or data.get('total_quantity') or data.get('items_count') or '').strip()

    if type_ == 'favorite_store' and (company or product):
        return (
            tr(user, 'favorite_store_title'),
            tr(user, 'favorite_store_body', company=company, product=product),
        )

    if type_ == 'new_nearby_product' and product:
        return (
            tr(user, 'nearby_title'),
            tr(user, 'nearby_body', product=product),
        )

    if type_ == 'alarm_match':
        # Alarm-created confirmation uses the same historical type but has no product.
        if product:
            return (
                tr(user, 'alarm_match_title'),
                tr(user, 'alarm_match_body', company=company, product=product),
            )
        notify_text = str(data.get('notify_text') or '').strip()
        if notify_text:
            return (
                tr(user, 'alarm_saved_title'),
                tr(user, 'alarm_saved_body', date=notify_text),
            )

    if type_ == 'recommendation' and product:
        return (
            tr(user, 'recommendation_title'),
            tr(user, 'recommendation_body', product=product),
        )

    if type_ == 'review_reminder':
        return tr(user, 'review_reminder_title'), tr(user, 'review_reminder_body')

    if type_ == 'product_expired' and product:
        return (
            tr(user, 'product_expired_title'),
            tr(user, 'product_expired_body', product=product),
        )

    if type_ == 'low_stock' and product:
        return (
            tr(user, 'low_stock_title'),
            tr(user, 'low_stock_body', product=product),
        )

    if type_ == 'new_product' and (company or product):
        return (
            tr(user, 'new_product_title'),
            tr(user, 'new_product_body', company=company, product=product),
        )

    if type_ == 'order_created':
        title = tr(user, 'order_created_title')
        if product and quantity:
            body = tr(
                user,
                'order_created_hot_body',
                order_number=order_number or '—',
                buyer=buyer or '—',
                product=product,
                quantity=quantity,
                phone=phone,
            )
            return title, body
        if buyer or quantity:
            body = tr(
                user,
                'order_created_cart_body',
                buyer=buyer or '—',
                quantity=quantity or '—',
                phone=phone,
            )
            return title, body

    if type_ == 'order_reserved' and order_number:
        return (
            tr(user, 'order_reserved_title'),
            tr(user, 'order_reserved_body', order_number=order_number),
        )

    # Admin/free-form and unknown notification types remain exactly as authored.
    return str(fallback_title or ''), str(fallback_body or '')
