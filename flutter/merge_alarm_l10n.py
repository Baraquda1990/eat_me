#!/usr/bin/env python3
import json
from pathlib import Path

PATCH = {
    'ru': {
        'alarmNotificationsActive': 'Уведомления активны',
        'alarmNoTags': 'Теги пока не добавлены',
        'alarmSave': 'Сохранить',
        'alarmSet': 'Установить',
        'alarmDisable': 'Отключить уведомления',
        'alarmAnyDistance': 'Любое',
        'alarmNotificationRadius': 'Радиус уведомлений',
        'alarmRadiusHint': 'Будем искать предложения рядом с выбранной точкой',
        'alarmAnyDistanceLong': 'Любое расстояние',
        'alarmLoginTitle': 'Нужно войти',
        'alarmLoginBody': 'Сперва нужно войти под аккаунтом, чтобы сохранить уведомления.',
        'alarmUnderstood': 'Понятно',
        'alarmMinFiveMinutes': 'Выберите время минимум на 5 минут позже текущего',
        'alarmChooseType': 'Выберите: Горячее или Акции',
        'alarmUpdated': 'Уведомления обновлены',
        'alarmSaved': 'Уведомления сохранены',
        'alarmSaveFailed': 'Не удалось сохранить уведомления',
        'alarmDisabled': 'Уведомления отключены',
        'alarmDisableFailed': 'Не удалось отключить уведомления',
        'alarmEndAfterStart': 'Время «До» должно быть позже времени «С»',
        'alarmSelectArea': 'Выберите область',
        'alarmChooseArea': 'Выбрать область',
        'alarmFrom': 'С',
        'alarmTo': 'До',
    },
    'en': {
        'alarmNotificationsActive': 'Notifications are active',
        'alarmNoTags': 'No tags added yet',
        'alarmSave': 'Save',
        'alarmSet': 'Set',
        'alarmDisable': 'Disable notifications',
        'alarmAnyDistance': 'Any',
        'alarmNotificationRadius': 'Notification radius',
        'alarmRadiusHint': 'We will look for offers near the selected point',
        'alarmAnyDistanceLong': 'Any distance',
        'alarmLoginTitle': 'Sign in required',
        'alarmLoginBody': 'Please sign in first to save notifications.',
        'alarmUnderstood': 'Got it',
        'alarmMinFiveMinutes': 'Choose a time at least 5 minutes later than now',
        'alarmChooseType': 'Choose Hot or Deals',
        'alarmUpdated': 'Notifications updated',
        'alarmSaved': 'Notifications saved',
        'alarmSaveFailed': 'Could not save notifications',
        'alarmDisabled': 'Notifications disabled',
        'alarmDisableFailed': 'Could not disable notifications',
        'alarmEndAfterStart': 'The “To” time must be later than the “From” time',
        'alarmSelectArea': 'Select area',
        'alarmChooseArea': 'Choose area',
        'alarmFrom': 'From',
        'alarmTo': 'To',
    },
    'hy': {
        'alarmNotificationsActive': 'Ծանուցումները ակտիվ են',
        'alarmNoTags': 'Պիտակներ դեռ չեն ավելացվել',
        'alarmSave': 'Պահպանել',
        'alarmSet': 'Սահմանել',
        'alarmDisable': 'Անջատել ծանուցումները',
        'alarmAnyDistance': 'Ցանկացած',
        'alarmNotificationRadius': 'Ծանուցումների շառավիղ',
        'alarmRadiusHint': 'Առաջարկները կփնտրենք ընտրված կետի մոտակայքում',
        'alarmAnyDistanceLong': 'Ցանկացած հեռավորություն',
        'alarmLoginTitle': 'Անհրաժեշտ է մուտք գործել',
        'alarmLoginBody': 'Ծանուցումները պահպանելու համար նախ մուտք գործեք հաշիվ։',
        'alarmUnderstood': 'Հասկացա',
        'alarmMinFiveMinutes': 'Ընտրեք ընթացիկ ժամանակից առնվազն 5 րոպե ուշ ժամանակ',
        'alarmChooseType': 'Ընտրեք՝ Թեժ կամ Առաջարկներ',
        'alarmUpdated': 'Ծանուցումները թարմացվել են',
        'alarmSaved': 'Ծանուցումները պահպանվել են',
        'alarmSaveFailed': 'Չհաջողվեց պահպանել ծանուցումները',
        'alarmDisabled': 'Ծանուցումները անջատվել են',
        'alarmDisableFailed': 'Չհաջողվեց անջատել ծանուցումները',
        'alarmEndAfterStart': '«Մինչև» ժամը պետք է լինի «Սկս.» ժամից ուշ',
        'alarmSelectArea': 'Ընտրեք տարածքը',
        'alarmChooseArea': 'Ընտրել տարածքը',
        'alarmFrom': 'Սկս.',
        'alarmTo': 'Մինչև',
    },
}

l10n_dir = Path('lib/l10n')
for lang, patch in PATCH.items():
    path = l10n_dir / f'app_{lang}.arb'
    if not path.exists():
        raise SystemExit(f'Not found: {path}')
    data = json.loads(path.read_text(encoding='utf-8'))
    data.update(patch)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Updated {path}: +{len(patch)} alarm keys')
