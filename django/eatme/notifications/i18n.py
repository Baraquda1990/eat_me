def get_user_language(user):
    profile = getattr(user, 'profile', None)
    lang = getattr(profile, 'language', 'ru')
    return lang if lang in ['ru', 'en', 'hy'] else 'ru'


TEXTS = {
    'review_reminder_title': {
        'ru': 'Оцените заказ',
        'en': 'Rate your order',
        'hy': 'Գնահատեք պատվերը',
    },
    'review_reminder_body': {
        'ru': 'Поделитесь впечатлениями о покупке',
        'en': 'Share your shopping experience',
        'hy': 'Կիսվեք գնումից ստացած տպավորություններով',
    },

    'favorite_store_title': {
        'ru': 'Любимый магазин',
        'en': 'Favorite store',
        'hy': 'Սիրելի խանութ',
    },
    'favorite_store_body': {
        'ru': '{company} добавил новое предложение: {product}',
        'en': '{company} added a new offer: {product}',
        'hy': '{company}-ը ավելացրել է նոր առաջարկ՝ {product}',
    },

    'nearby_title': {
        'ru': 'Новое предложение рядом',
        'en': 'New offer nearby',
        'hy': 'Նոր առաջարկ մոտակայքում',
    },
    'nearby_body': {
        'ru': 'Рядом появилось предложение: {product}',
        'en': 'A nearby offer appeared: {product}',
        'hy': 'Մոտակայքում հայտնվել է առաջարկ՝ {product}',
    },

    'alarm_match_title': {
        'ru': 'Найдено предложение',
        'en': 'Offer found',
        'hy': 'Առաջարկ է գտնվել',
    },
    'alarm_match_body': {
        'ru': '{company} добавил товар "{product}"',
        'en': '{company} added "{product}"',
        'hy': '{company}-ը ավելացրել է «{product}» ապրանքը',
    },

    'recommendation_title': {
        'ru': 'Рекомендация для вас',
        'en': 'Recommended for you',
        'hy': 'Առաջարկ ձեզ համար',
    },
    'recommendation_body': {
        'ru': 'Мы нашли предложение, которое может вам понравиться: {product}',
        'en': 'We found an offer you may like: {product}',
        'hy': 'Մենք գտել ենք առաջարկ, որը կարող է ձեզ դուր գալ՝ {product}',
    },

    'alarm_saved_title': {
        'ru': 'Уведомление сохранено',
        'en': 'Notification saved',
        'hy': 'Ծանուցումը պահպանված է',
    },
    'alarm_saved_body': {
        'ru': 'Уведомление сохранено на {date}. Мы уведомим вас о новых предложениях.',
        'en': 'Notification saved for {date}. We will notify you about new offers.',
        'hy': 'Ծանուցումը պահպանված է {date}-ի համար։ Մենք ձեզ կտեղեկացնենք նոր առաջարկների մասին։',
    },

    'new_order_title': {
        'ru': 'Новый заказ',
        'en': 'New order',
        'hy': 'Նոր պատվեր',
    },
    'new_order_body': {
        'ru': '{buyer} купил товаров: {quantity}. {products}. Тел: {phone}',
        'en': '{buyer} bought items: {quantity}. {products}. Phone: {phone}',
        'hy': '{buyer}-ը գնել է ապրանքներ՝ {quantity}. {products}. Հեռ․՝ {phone}',
    },
    'not_specified': {
        'ru': 'не указан',
        'en': 'not specified',
        'hy': 'նշված չէ',
    },
    'and_more': {
        'ru': 'и ещё {count}',
        'en': 'and {count} more',
        'hy': 'և ևս {count}',
    },
}


def tr(user, key, **kwargs):
    lang = get_user_language(user)
    text = TEXTS.get(key, {}).get(lang) or TEXTS.get(key, {}).get('ru') or key
    return text.format(**kwargs)
