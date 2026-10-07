import 'package:flutter/material.dart';

class LegalUiText {
  final String legalInformation;
  final String legalInformationSubtitle;
  final String registrationIntro;
  final String registrationError;
  final String loadingDocuments;
  final String loadFailed;
  final String retry;
  final String version;
  final String updatedTermsTitle;
  final String updatedTermsSubtitle;
  final String purchaseConsentTitle;
  final String purchaseConsentSubtitle;
  final String acceptAll;
  final String continueLabel;
  final String logout;
  final String openDocument;
  final String acceptanceFailed;
  final String refundPolicy;

  const LegalUiText({
    required this.legalInformation,
    required this.legalInformationSubtitle,
    required this.registrationIntro,
    required this.registrationError,
    required this.loadingDocuments,
    required this.loadFailed,
    required this.retry,
    required this.version,
    required this.updatedTermsTitle,
    required this.updatedTermsSubtitle,
    required this.purchaseConsentTitle,
    required this.purchaseConsentSubtitle,
    required this.acceptAll,
    required this.continueLabel,
    required this.logout,
    required this.openDocument,
    required this.acceptanceFailed,
    required this.refundPolicy,
  });

  static LegalUiText of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();

    if (code == 'ru') {
      return const LegalUiText(
        legalInformation: 'Юридическая информация',
        legalInformationSubtitle: 'Условия, конфиденциальность и возвраты',
        registrationIntro: 'Я ознакомился и принимаю:',
        registrationError: 'Для регистрации необходимо принять обязательные документы.',
        loadingDocuments: 'Загружаем условия…',
        loadFailed: 'Не удалось загрузить юридические документы.',
        retry: 'Повторить',
        version: 'Версия',
        updatedTermsTitle: 'Условия Appsosa',
        updatedTermsSubtitle: 'Чтобы продолжить пользоваться аккаунтом, ознакомьтесь с актуальными обязательными документами.',
        purchaseConsentTitle: 'Перед оформлением заказа',
        purchaseConsentSubtitle: 'Перед первой покупкой или после обновления условий ознакомьтесь с обязательными документами.',
        acceptAll: 'Я прочитал и принимаю указанные документы',
        continueLabel: 'Принять и продолжить',
        logout: 'Выйти из аккаунта',
        openDocument: 'Открыть документ',
        acceptanceFailed: 'Не удалось сохранить согласие. Попробуйте ещё раз.',
        refundPolicy: 'Политика возврата',
      );
    }

    if (code == 'hy') {
      return const LegalUiText(
        legalInformation: 'Իրավական տեղեկատվություն',
        legalInformationSubtitle: 'Պայմաններ, գաղտնիություն և վերադարձներ',
        registrationIntro: 'Ես ծանոթացել եմ և ընդունում եմ՝',
        registrationError: 'Գրանցվելու համար անհրաժեշտ է ընդունել պարտադիր փաստաթղթերը։',
        loadingDocuments: 'Բեռնվում են պայմանները…',
        loadFailed: 'Չհաջողվեց բեռնել իրավական փաստաթղթերը։',
        retry: 'Կրկին փորձել',
        version: 'Տարբերակ',
        updatedTermsTitle: 'Appsosa-ի պայմանները',
        updatedTermsSubtitle: 'Հաշիվը շարունակելու համար ծանոթացեք գործող պարտադիր փաստաթղթերին։',
        purchaseConsentTitle: 'Պատվերը ձևակերպելուց առաջ',
        purchaseConsentSubtitle: 'Առաջին գնման կամ պայմանների թարմացումից հետո ծանոթացեք պարտադիր փաստաթղթերին։',
        acceptAll: 'Ես կարդացել և ընդունում եմ նշված փաստաթղթերը',
        continueLabel: 'Ընդունել և շարունակել',
        logout: 'Դուրս գալ հաշվից',
        openDocument: 'Բացել փաստաթուղթը',
        acceptanceFailed: 'Չհաջողվեց պահպանել համաձայնությունը։ Փորձեք կրկին։',
        refundPolicy: 'Վերադարձի քաղաքականություն',
      );
    }

    return const LegalUiText(
      legalInformation: 'Legal information',
      legalInformationSubtitle: 'Terms, privacy and refunds',
      registrationIntro: 'I have read and accept:',
      registrationError: 'You must accept the required documents to register.',
      loadingDocuments: 'Loading terms…',
      loadFailed: 'Could not load legal documents.',
      retry: 'Try again',
      version: 'Version',
      updatedTermsTitle: 'Appsosa terms',
      updatedTermsSubtitle: 'To continue using your account, review the current required documents.',
      purchaseConsentTitle: 'Before placing your order',
      purchaseConsentSubtitle: 'Before your first purchase or after an update, review the required documents.',
      acceptAll: 'I have read and accept the documents listed above',
      continueLabel: 'Accept and continue',
      logout: 'Sign out',
      openDocument: 'Open document',
      acceptanceFailed: 'Could not save your consent. Please try again.',
      refundPolicy: 'Refund policy',
    );
  }
}
