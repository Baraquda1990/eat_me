import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hy.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hy'),
    Locale('ru'),
  ];

  /// No description provided for @appName.
  ///
  /// In ru, this message translates to:
  /// **'EatMe'**
  String get appName;

  /// No description provided for @home.
  ///
  /// In ru, this message translates to:
  /// **'Главная'**
  String get home;

  /// No description provided for @map.
  ///
  /// In ru, this message translates to:
  /// **'Карта'**
  String get map;

  /// No description provided for @deals.
  ///
  /// In ru, this message translates to:
  /// **'Акции'**
  String get deals;

  /// No description provided for @notifications.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get notifications;

  /// No description provided for @profile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get profile;

  /// No description provided for @today.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get today;

  /// No description provided for @welcome.
  ///
  /// In ru, this message translates to:
  /// **'Добро пожаловать'**
  String get welcome;

  /// No description provided for @loginPrompt.
  ///
  /// In ru, this message translates to:
  /// **'Войдите в аккаунт, чтобы пользоваться\nизбранным, корзиной и заказами'**
  String get loginPrompt;

  /// No description provided for @login.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get login;

  /// No description provided for @registerPrompt.
  ///
  /// In ru, this message translates to:
  /// **'Нет аккаунта? Зарегистрироваться'**
  String get registerPrompt;

  /// No description provided for @user.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь'**
  String get user;

  /// No description provided for @cart.
  ///
  /// In ru, this message translates to:
  /// **'Корзина'**
  String get cart;

  /// No description provided for @favorites.
  ///
  /// In ru, this message translates to:
  /// **'Избранное'**
  String get favorites;

  /// No description provided for @ordersHistory.
  ///
  /// In ru, this message translates to:
  /// **'История заказов'**
  String get ordersHistory;

  /// No description provided for @sellerPanel.
  ///
  /// In ru, this message translates to:
  /// **'Панель продавца'**
  String get sellerPanel;

  /// No description provided for @sellerPanelSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Добавление товаров и управление ценами'**
  String get sellerPanelSubtitle;

  /// No description provided for @settings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settings;

  /// No description provided for @settingsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления, адреса, язык'**
  String get settingsSubtitle;

  /// No description provided for @logout.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get logout;

  /// No description provided for @logoutSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Вы вышли из аккаунта'**
  String get logoutSuccess;

  /// No description provided for @language.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get language;

  /// No description provided for @appLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Язык приложения'**
  String get appLanguage;

  /// No description provided for @russian.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get russian;

  /// No description provided for @armenian.
  ///
  /// In ru, this message translates to:
  /// **'Հայերեն'**
  String get armenian;

  /// No description provided for @english.
  ///
  /// In ru, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @languageChanged.
  ///
  /// In ru, this message translates to:
  /// **'Язык изменён'**
  String get languageChanged;

  /// No description provided for @topOffers.
  ///
  /// In ru, this message translates to:
  /// **'Топ предложения'**
  String get topOffers;

  /// No description provided for @recommended.
  ///
  /// In ru, this message translates to:
  /// **'Рекомендуем для вас'**
  String get recommended;

  /// No description provided for @favoriteStores.
  ///
  /// In ru, this message translates to:
  /// **'Ваши любимые магазины'**
  String get favoriteStores;

  /// No description provided for @all.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get all;

  /// No description provided for @breakfastNearby.
  ///
  /// In ru, this message translates to:
  /// **'Завтрак рядом'**
  String get breakfastNearby;

  /// No description provided for @lunchNearby.
  ///
  /// In ru, this message translates to:
  /// **'Обед рядом'**
  String get lunchNearby;

  /// No description provided for @dinnerNearby.
  ///
  /// In ru, this message translates to:
  /// **'Ужин рядом'**
  String get dinnerNearby;

  /// No description provided for @morningOffers.
  ///
  /// In ru, this message translates to:
  /// **'Утренние предложения'**
  String get morningOffers;

  /// No description provided for @dayOffers.
  ///
  /// In ru, this message translates to:
  /// **'Дневные предложения'**
  String get dayOffers;

  /// No description provided for @eveningOffers.
  ///
  /// In ru, this message translates to:
  /// **'Вечерние предложения'**
  String get eveningOffers;

  /// No description provided for @sort.
  ///
  /// In ru, this message translates to:
  /// **'Сортировка'**
  String get sort;

  /// No description provided for @defaultSort.
  ///
  /// In ru, this message translates to:
  /// **'По умолчанию'**
  String get defaultSort;

  /// No description provided for @cheaperFirst.
  ///
  /// In ru, this message translates to:
  /// **'Сначала дешевле'**
  String get cheaperFirst;

  /// No description provided for @expensiveFirst.
  ///
  /// In ru, this message translates to:
  /// **'Сначала дороже'**
  String get expensiveFirst;

  /// No description provided for @nearestFirst.
  ///
  /// In ru, this message translates to:
  /// **'Сначала рядом'**
  String get nearestFirst;

  /// No description provided for @byRating.
  ///
  /// In ru, this message translates to:
  /// **'По рейтингу'**
  String get byRating;

  /// No description provided for @locationSortError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось определить геолокацию для сортировки'**
  String get locationSortError;

  /// No description provided for @searchResults.
  ///
  /// In ru, this message translates to:
  /// **'Результаты поиска'**
  String get searchResults;

  /// No description provided for @hotNearby.
  ///
  /// In ru, this message translates to:
  /// **'Горячие рядом'**
  String get hotNearby;

  /// No description provided for @offers.
  ///
  /// In ru, this message translates to:
  /// **'предложений'**
  String get offers;

  /// No description provided for @bestOffersNow.
  ///
  /// In ru, this message translates to:
  /// **'Лучшие предложения сейчас'**
  String get bestOffersNow;

  /// No description provided for @recommendedSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Подобрано по вашим интересам'**
  String get recommendedSubtitle;

  /// No description provided for @favoriteStoresSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Предложения от знакомых мест'**
  String get favoriteStoresSubtitle;

  /// No description provided for @timeBasedSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Подборка по времени дня'**
  String get timeBasedSubtitle;

  /// No description provided for @allAvailableNearby.
  ///
  /// In ru, this message translates to:
  /// **'Все доступные предложения рядом'**
  String get allAvailableNearby;

  /// No description provided for @hotOffers.
  ///
  /// In ru, this message translates to:
  /// **'Горячие предложения'**
  String get hotOffers;

  /// No description provided for @searchFoodStoreDeal.
  ///
  /// In ru, this message translates to:
  /// **'Поиск еды, магазина или акции'**
  String get searchFoodStoreDeal;

  /// No description provided for @noHotOffers.
  ///
  /// In ru, this message translates to:
  /// **'Горячих предложений пока нет'**
  String get noHotOffers;

  /// No description provided for @error.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// No description provided for @salesPoints.
  ///
  /// In ru, this message translates to:
  /// **'Точки продаж'**
  String get salesPoints;

  /// No description provided for @salesPointsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Магазины и организации рядом с вами'**
  String get salesPointsSubtitle;

  /// No description provided for @newStore.
  ///
  /// In ru, this message translates to:
  /// **'Новый'**
  String get newStore;

  /// No description provided for @other.
  ///
  /// In ru, this message translates to:
  /// **'Другое'**
  String get other;

  /// No description provided for @removedFromFavorites.
  ///
  /// In ru, this message translates to:
  /// **'Удалено из избранного'**
  String get removedFromFavorites;

  /// No description provided for @addedToFavorites.
  ///
  /// In ru, this message translates to:
  /// **'Добавлено в избранное'**
  String get addedToFavorites;

  /// No description provided for @favoritesError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка избранного'**
  String get favoritesError;

  /// No description provided for @authRequired.
  ///
  /// In ru, this message translates to:
  /// **'Нужна авторизация'**
  String get authRequired;

  /// No description provided for @loginToUseFavoritesCart.
  ///
  /// In ru, this message translates to:
  /// **'Войдите в аккаунт, чтобы добавлять товары в избранное или корзину.'**
  String get loginToUseFavoritesCart;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @addedToCartSuffix.
  ///
  /// In ru, this message translates to:
  /// **'добавлен в корзину'**
  String get addedToCartSuffix;

  /// No description provided for @addToCartError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось добавить товар в корзину'**
  String get addToCartError;

  /// No description provided for @searchDeals.
  ///
  /// In ru, this message translates to:
  /// **'Поиск акций'**
  String get searchDeals;

  /// No description provided for @category.
  ///
  /// In ru, this message translates to:
  /// **'Категория'**
  String get category;

  /// No description provided for @noDeals.
  ///
  /// In ru, this message translates to:
  /// **'Акций пока нет'**
  String get noDeals;

  /// No description provided for @cartEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Корзина пустая'**
  String get cartEmpty;

  /// No description provided for @orderPlaced.
  ///
  /// In ru, this message translates to:
  /// **'Заказ оформлен'**
  String get orderPlaced;

  /// No description provided for @orderCheckoutFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось оформить заказ'**
  String get orderCheckoutFailed;

  /// No description provided for @loginToOpenCart.
  ///
  /// In ru, this message translates to:
  /// **'Войдите, чтобы открыть корзину'**
  String get loginToOpenCart;

  /// No description provided for @loginToManageCart.
  ///
  /// In ru, this message translates to:
  /// **'Авторизуйтесь, чтобы просматривать и управлять вашей корзиной.'**
  String get loginToManageCart;

  /// No description provided for @cartUpdateError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка обновления корзины'**
  String get cartUpdateError;

  /// No description provided for @product.
  ///
  /// In ru, this message translates to:
  /// **'Товар'**
  String get product;

  /// No description provided for @dealType.
  ///
  /// In ru, this message translates to:
  /// **'Акция'**
  String get dealType;

  /// No description provided for @hotType.
  ///
  /// In ru, this message translates to:
  /// **'Горячее'**
  String get hotType;

  /// No description provided for @total.
  ///
  /// In ru, this message translates to:
  /// **'Итого'**
  String get total;

  /// No description provided for @checkout.
  ///
  /// In ru, this message translates to:
  /// **'Оформить'**
  String get checkout;

  /// No description provided for @favoriteEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Избранное пустое'**
  String get favoriteEmpty;

  /// No description provided for @loginToAccount.
  ///
  /// In ru, this message translates to:
  /// **'Войдите в аккаунт'**
  String get loginToAccount;

  /// No description provided for @favoritesAuthSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'После входа вы сможете сохранять любимые товары и быстро возвращаться к ним.'**
  String get favoritesAuthSubtitle;

  /// No description provided for @favoritesEmptySubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Нажимайте на сердечко в карточках товаров, чтобы сохранить их здесь.'**
  String get favoritesEmptySubtitle;

  /// No description provided for @goHome.
  ///
  /// In ru, this message translates to:
  /// **'На главную'**
  String get goHome;

  /// No description provided for @loginTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход'**
  String get loginTitle;

  /// No description provided for @welcomeExclamation.
  ///
  /// In ru, this message translates to:
  /// **'Добро пожаловать!'**
  String get welcomeExclamation;

  /// No description provided for @loginToAccountSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Войдите в свой аккаунт'**
  String get loginToAccountSubtitle;

  /// No description provided for @username.
  ///
  /// In ru, this message translates to:
  /// **'Логин'**
  String get username;

  /// No description provided for @password.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get password;

  /// No description provided for @enterUsername.
  ///
  /// In ru, this message translates to:
  /// **'Введите логин'**
  String get enterUsername;

  /// No description provided for @enterPassword.
  ///
  /// In ru, this message translates to:
  /// **'Введите пароль'**
  String get enterPassword;

  /// No description provided for @forgotPassword.
  ///
  /// In ru, this message translates to:
  /// **'Забыли пароль?'**
  String get forgotPassword;

  /// No description provided for @noAccount.
  ///
  /// In ru, this message translates to:
  /// **'Нет аккаунта?'**
  String get noAccount;

  /// No description provided for @register.
  ///
  /// In ru, this message translates to:
  /// **'Зарегистрироваться'**
  String get register;

  /// No description provided for @registration.
  ///
  /// In ru, this message translates to:
  /// **'Регистрация'**
  String get registration;

  /// No description provided for @createAccount.
  ///
  /// In ru, this message translates to:
  /// **'Создайте новый аккаунт'**
  String get createAccount;

  /// No description provided for @email.
  ///
  /// In ru, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @confirmPassword.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждение пароля'**
  String get confirmPassword;

  /// No description provided for @enterEmail.
  ///
  /// In ru, this message translates to:
  /// **'Введите email'**
  String get enterEmail;

  /// No description provided for @enterValidEmail.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректный email'**
  String get enterValidEmail;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In ru, this message translates to:
  /// **'Пароли не совпадают.'**
  String get passwordsDoNotMatch;

  /// No description provided for @passwordMinLength.
  ///
  /// In ru, this message translates to:
  /// **'Пароль должен содержать минимум 6 символов'**
  String get passwordMinLength;

  /// No description provided for @usernameMinLength.
  ///
  /// In ru, this message translates to:
  /// **'Логин должен содержать минимум 3 символа'**
  String get usernameMinLength;

  /// No description provided for @registrationSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Регистрация успешна! Теперь войдите в аккаунт'**
  String get registrationSuccess;

  /// No description provided for @registrationError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка регистрации'**
  String get registrationError;

  /// No description provided for @loginError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get loginError;

  /// No description provided for @enterConfirmPassword.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердите пароль'**
  String get enterConfirmPassword;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In ru, this message translates to:
  /// **'Уже есть аккаунт?'**
  String get alreadyHaveAccount;

  /// No description provided for @ordersAuthSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'После входа здесь появится история ваших заказов.'**
  String get ordersAuthSubtitle;

  /// No description provided for @noOrders.
  ///
  /// In ru, this message translates to:
  /// **'Заказов пока нет'**
  String get noOrders;

  /// No description provided for @noOrdersSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Когда вы оформите первый заказ, он появится здесь со статусом.'**
  String get noOrdersSubtitle;

  /// No description provided for @chooseProducts.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать товары'**
  String get chooseProducts;

  /// No description provided for @pending.
  ///
  /// In ru, this message translates to:
  /// **'Ожидает подтверждения'**
  String get pending;

  /// No description provided for @ordered.
  ///
  /// In ru, this message translates to:
  /// **'Оформлен'**
  String get ordered;

  /// No description provided for @paid.
  ///
  /// In ru, this message translates to:
  /// **'Оплачен'**
  String get paid;

  /// No description provided for @completed.
  ///
  /// In ru, this message translates to:
  /// **'Получен'**
  String get completed;

  /// No description provided for @cancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменён'**
  String get cancelled;

  /// No description provided for @processing.
  ///
  /// In ru, this message translates to:
  /// **'В обработке'**
  String get processing;

  /// No description provided for @reviewCompany.
  ///
  /// In ru, this message translates to:
  /// **'Оценить'**
  String get reviewCompany;

  /// No description provided for @productQuality.
  ///
  /// In ru, this message translates to:
  /// **'Качество продуктов'**
  String get productQuality;

  /// No description provided for @valueSet.
  ///
  /// In ru, this message translates to:
  /// **'Выгодность набора'**
  String get valueSet;

  /// No description provided for @descriptionMatch.
  ///
  /// In ru, this message translates to:
  /// **'Соответствие'**
  String get descriptionMatch;

  /// No description provided for @service.
  ///
  /// In ru, this message translates to:
  /// **'Сервис'**
  String get service;

  /// No description provided for @commentOptional.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий (необязательно)'**
  String get commentOptional;

  /// No description provided for @send.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get send;

  /// No description provided for @reviewThanks.
  ///
  /// In ru, this message translates to:
  /// **'Спасибо за отзыв!'**
  String get reviewThanks;

  /// No description provided for @reviewAlreadyOrCant.
  ///
  /// In ru, this message translates to:
  /// **'Отзыв уже оставлен или заказ нельзя оценить'**
  String get reviewAlreadyOrCant;

  /// No description provided for @openMap.
  ///
  /// In ru, this message translates to:
  /// **'Открыть карту'**
  String get openMap;

  /// No description provided for @description.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get description;

  /// No description provided for @productUpper.
  ///
  /// In ru, this message translates to:
  /// **'ТОВАР'**
  String get productUpper;

  /// No description provided for @descriptionUpper.
  ///
  /// In ru, this message translates to:
  /// **'ОПИСАНИЕ'**
  String get descriptionUpper;

  /// No description provided for @pickupUpper.
  ///
  /// In ru, this message translates to:
  /// **'КОГДА ЗАБРАТЬ'**
  String get pickupUpper;

  /// No description provided for @phoneUpper.
  ///
  /// In ru, this message translates to:
  /// **'ТЕЛЕФОН'**
  String get phoneUpper;

  /// No description provided for @reserve.
  ///
  /// In ru, this message translates to:
  /// **'ЗАРЕЗЕРВИРОВАТЬ'**
  String get reserve;

  /// No description provided for @descriptionNotSpecified.
  ///
  /// In ru, this message translates to:
  /// **'Описание не указано'**
  String get descriptionNotSpecified;

  /// No description provided for @qualityUpper.
  ///
  /// In ru, this message translates to:
  /// **'КАЧЕСТВО'**
  String get qualityUpper;

  /// No description provided for @valueUpper.
  ///
  /// In ru, this message translates to:
  /// **'ВЫГОДНОСТЬ'**
  String get valueUpper;

  /// No description provided for @descriptionMatchUpper.
  ///
  /// In ru, this message translates to:
  /// **'СООТВЕТСТВИЕ'**
  String get descriptionMatchUpper;

  /// No description provided for @serviceUpper.
  ///
  /// In ru, this message translates to:
  /// **'СЕРВИС'**
  String get serviceUpper;

  /// No description provided for @loginToUseProduct.
  ///
  /// In ru, this message translates to:
  /// **'Войдите в аккаунт, чтобы добавлять товары в избранное и оформлять заказы.'**
  String get loginToUseProduct;

  /// No description provided for @reserveSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Товар успешно зарезервирован'**
  String get reserveSuccess;

  /// No description provided for @reserveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось оформить резерв'**
  String get reserveFailed;

  /// No description provided for @companyPhoneMissing.
  ///
  /// In ru, this message translates to:
  /// **'Телефон компании не указан'**
  String get companyPhoneMissing;

  /// No description provided for @callOpenFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть звонок'**
  String get callOpenFailed;

  /// No description provided for @productInfoCopied.
  ///
  /// In ru, this message translates to:
  /// **'Информация о товаре скопирована'**
  String get productInfoCopied;

  /// No description provided for @profileName.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get profileName;

  /// No description provided for @profilePhone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get profilePhone;

  /// No description provided for @profilePhoneAdd.
  ///
  /// In ru, this message translates to:
  /// **'Указать номер телефона'**
  String get profilePhoneAdd;

  /// No description provided for @profileAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес'**
  String get profileAddress;

  /// No description provided for @profileAddressAdd.
  ///
  /// In ru, this message translates to:
  /// **'Указать адрес доставки'**
  String get profileAddressAdd;

  /// No description provided for @profileDeliveryAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес доставки'**
  String get profileDeliveryAddress;

  /// No description provided for @profileLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get profileLanguage;

  /// No description provided for @profileAboutApp.
  ///
  /// In ru, this message translates to:
  /// **'О приложении'**
  String get profileAboutApp;

  /// No description provided for @profileSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get profileSave;

  /// No description provided for @profileSaved.
  ///
  /// In ru, this message translates to:
  /// **'Сохранено'**
  String get profileSaved;

  /// No description provided for @profileSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить'**
  String get profileSaveError;

  /// No description provided for @profileAboutText.
  ///
  /// In ru, this message translates to:
  /// **'Приложение для покупки товаров и наборов со скидкой.'**
  String get profileAboutText;

  /// No description provided for @notificationsCenter.
  ///
  /// In ru, this message translates to:
  /// **'🔔 Центр уведомлений'**
  String get notificationsCenter;

  /// No description provided for @notificationsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления пока пустые'**
  String get notificationsEmpty;

  /// No description provided for @notificationsToday.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get notificationsToday;

  /// No description provided for @notificationsYesterday.
  ///
  /// In ru, this message translates to:
  /// **'Вчера'**
  String get notificationsYesterday;

  /// No description provided for @notificationsEarlier.
  ///
  /// In ru, this message translates to:
  /// **'Ранее'**
  String get notificationsEarlier;

  /// No description provided for @openingProduct.
  ///
  /// In ru, this message translates to:
  /// **'Открываем товар...'**
  String get openingProduct;

  /// No description provided for @productNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Товар не найден или уже недоступен'**
  String get productNotFound;

  /// No description provided for @adminBadge.
  ///
  /// In ru, this message translates to:
  /// **'АДМИНИСТРАЦИЯ'**
  String get adminBadge;

  /// No description provided for @offerBadge.
  ///
  /// In ru, this message translates to:
  /// **'ПРЕДЛОЖЕНИЕ'**
  String get offerBadge;

  /// No description provided for @storeBadge.
  ///
  /// In ru, this message translates to:
  /// **'МАГАЗИН'**
  String get storeBadge;

  /// No description provided for @reserveBadge.
  ///
  /// In ru, this message translates to:
  /// **'РЕЗЕРВ'**
  String get reserveBadge;

  /// No description provided for @orderBadge.
  ///
  /// In ru, this message translates to:
  /// **'ЗАКАЗ'**
  String get orderBadge;

  /// No description provided for @stockBadge.
  ///
  /// In ru, this message translates to:
  /// **'ОСТАТОК'**
  String get stockBadge;

  /// No description provided for @favoriteStoreBadge.
  ///
  /// In ru, this message translates to:
  /// **'ЛЮБИМЫЙ МАГАЗИН'**
  String get favoriteStoreBadge;

  /// No description provided for @reviewBadge.
  ///
  /// In ru, this message translates to:
  /// **'ОЦЕНКА'**
  String get reviewBadge;

  /// No description provided for @nearbyBadge.
  ///
  /// In ru, this message translates to:
  /// **'РЯДОМ'**
  String get nearbyBadge;

  /// No description provided for @forYouBadge.
  ///
  /// In ru, this message translates to:
  /// **'ДЛЯ ВАС'**
  String get forYouBadge;

  /// No description provided for @itemsCount.
  ///
  /// In ru, this message translates to:
  /// **'Товаров: {count}'**
  String itemsCount(Object count);

  /// No description provided for @moreItems.
  ///
  /// In ru, this message translates to:
  /// **'+ ещё {count}'**
  String moreItems(Object count);

  /// No description provided for @company.
  ///
  /// In ru, this message translates to:
  /// **'Компания'**
  String get company;

  /// No description provided for @rated.
  ///
  /// In ru, this message translates to:
  /// **'Оценено'**
  String get rated;

  /// No description provided for @rate.
  ///
  /// In ru, this message translates to:
  /// **'Оценить'**
  String get rate;

  /// No description provided for @outOfStock.
  ///
  /// In ru, this message translates to:
  /// **'Нет в наличии'**
  String get outOfStock;

  /// No description provided for @remainingCount.
  ///
  /// In ru, this message translates to:
  /// **'ОСТАЛОСЬ: {count}'**
  String remainingCount(Object count);

  /// No description provided for @sellerDashboard.
  ///
  /// In ru, this message translates to:
  /// **'Панель продавца'**
  String get sellerDashboard;

  /// No description provided for @addProduct.
  ///
  /// In ru, this message translates to:
  /// **'Добавить товар'**
  String get addProduct;

  /// No description provided for @sales.
  ///
  /// In ru, this message translates to:
  /// **'Продажи'**
  String get sales;

  /// No description provided for @salesSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'История покупок и выручка'**
  String get salesSubtitle;

  /// No description provided for @customerReviews.
  ///
  /// In ru, this message translates to:
  /// **'Отзывы клиентов'**
  String get customerReviews;

  /// No description provided for @customerReviewsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Отзывы и оценки покупателей'**
  String get customerReviewsSubtitle;

  /// No description provided for @myCompany.
  ///
  /// In ru, this message translates to:
  /// **'Моя компания'**
  String get myCompany;

  /// No description provided for @myCompanySubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Адрес, описание, время работы и координаты'**
  String get myCompanySubtitle;

  /// No description provided for @myProducts.
  ///
  /// In ru, this message translates to:
  /// **'Мои товары'**
  String get myProducts;

  /// No description provided for @productPublished.
  ///
  /// In ru, this message translates to:
  /// **'Товар опубликован и появился в списке'**
  String get productPublished;

  /// No description provided for @productUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Товар обновлён'**
  String get productUpdated;

  /// No description provided for @companyUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Данные компании обновлены'**
  String get companyUpdated;

  /// No description provided for @deleteProduct.
  ///
  /// In ru, this message translates to:
  /// **'Удалить товар?'**
  String get deleteProduct;

  /// No description provided for @deleteProductConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Товар \"{name}\" будет удалён.'**
  String deleteProductConfirm(Object name);

  /// No description provided for @delete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get edit;

  /// No description provided for @productDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Товар удалён'**
  String get productDeleted;

  /// No description provided for @productDeleteFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось удалить товар'**
  String get productDeleteFailed;

  /// No description provided for @productsLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить товары'**
  String get productsLoadFailed;

  /// No description provided for @noProductsYet.
  ///
  /// In ru, this message translates to:
  /// **'Товаров пока нет'**
  String get noProductsYet;

  /// No description provided for @noProductsYetSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите «Добавить товар», чтобы разместить первый товар.'**
  String get noProductsYetSubtitle;

  /// No description provided for @price.
  ///
  /// In ru, this message translates to:
  /// **'Цена'**
  String get price;

  /// No description provided for @oldPrice.
  ///
  /// In ru, this message translates to:
  /// **'Было'**
  String get oldPrice;

  /// No description provided for @stock.
  ///
  /// In ru, this message translates to:
  /// **'Остаток'**
  String get stock;

  /// No description provided for @type.
  ///
  /// In ru, this message translates to:
  /// **'Тип'**
  String get type;

  /// No description provided for @package.
  ///
  /// In ru, this message translates to:
  /// **'Упаковка'**
  String get package;

  /// No description provided for @weight.
  ///
  /// In ru, this message translates to:
  /// **'Вес'**
  String get weight;

  /// No description provided for @delivery.
  ///
  /// In ru, this message translates to:
  /// **'Доставка'**
  String get delivery;

  /// No description provided for @expiration.
  ///
  /// In ru, this message translates to:
  /// **'Срок'**
  String get expiration;

  /// No description provided for @status.
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get status;

  /// No description provided for @hotProduct.
  ///
  /// In ru, this message translates to:
  /// **'Горячая'**
  String get hotProduct;

  /// No description provided for @longTermProduct.
  ///
  /// In ru, this message translates to:
  /// **'Долгосрочная'**
  String get longTermProduct;

  /// No description provided for @pickup.
  ///
  /// In ru, this message translates to:
  /// **'Самовывоз'**
  String get pickup;

  /// No description provided for @pickupDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Самовывоз/доставка'**
  String get pickupDelivery;

  /// No description provided for @revenue.
  ///
  /// In ru, this message translates to:
  /// **'Выручка'**
  String get revenue;

  /// No description provided for @orders.
  ///
  /// In ru, this message translates to:
  /// **'Заказы'**
  String get orders;

  /// No description provided for @soldProducts.
  ///
  /// In ru, this message translates to:
  /// **'Продано товаров'**
  String get soldProducts;

  /// No description provided for @rating.
  ///
  /// In ru, this message translates to:
  /// **'Рейтинг'**
  String get rating;

  /// No description provided for @top.
  ///
  /// In ru, this message translates to:
  /// **'ТОП'**
  String get top;

  /// No description provided for @addProductPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Добавить фото товара'**
  String get addProductPhoto;

  /// No description provided for @takePhoto.
  ///
  /// In ru, this message translates to:
  /// **'Сделать фото'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать из галереи'**
  String get chooseFromGallery;

  /// No description provided for @companyNotFound.
  ///
  /// In ru, this message translates to:
  /// **'У продавца не найдена компания'**
  String get companyNotFound;

  /// No description provided for @selectProductPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Выберите фото товара'**
  String get selectProductPhoto;

  /// No description provided for @productAdded.
  ///
  /// In ru, this message translates to:
  /// **'Товар добавлен'**
  String get productAdded;

  /// No description provided for @productUpdateError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка изменения товара'**
  String get productUpdateError;

  /// No description provided for @productCreateError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка добавления товара'**
  String get productCreateError;

  /// No description provided for @editProduct.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать товар'**
  String get editProduct;

  /// No description provided for @saveChanges.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить изменения'**
  String get saveChanges;

  /// No description provided for @publishProduct.
  ///
  /// In ru, this message translates to:
  /// **'Опубликовать товар'**
  String get publishProduct;

  /// No description provided for @productName.
  ///
  /// In ru, this message translates to:
  /// **'Название товара'**
  String get productName;

  /// No description provided for @enterProductName.
  ///
  /// In ru, this message translates to:
  /// **'Введите название'**
  String get enterProductName;

  /// No description provided for @enterDescription.
  ///
  /// In ru, this message translates to:
  /// **'Введите описание'**
  String get enterDescription;

  /// No description provided for @enterPrice.
  ///
  /// In ru, this message translates to:
  /// **'Введите цену'**
  String get enterPrice;

  /// No description provided for @discountPercent.
  ///
  /// In ru, this message translates to:
  /// **'Скидка %'**
  String get discountPercent;

  /// No description provided for @dealsFields.
  ///
  /// In ru, this message translates to:
  /// **'Поля для акций / доставки'**
  String get dealsFields;

  /// No description provided for @packageQuantity.
  ///
  /// In ru, this message translates to:
  /// **'Количество в упаковке'**
  String get packageQuantity;

  /// No description provided for @weightVolume.
  ///
  /// In ru, this message translates to:
  /// **'Вес / объём'**
  String get weightVolume;

  /// No description provided for @receivingProduct.
  ///
  /// In ru, this message translates to:
  /// **'Получение товара'**
  String get receivingProduct;

  /// No description provided for @deliveryOnlyForDeals.
  ///
  /// In ru, this message translates to:
  /// **'Для акций доступна только доставка'**
  String get deliveryOnlyForDeals;

  /// No description provided for @deliveryWithinDays.
  ///
  /// In ru, this message translates to:
  /// **'Доставка в течение {days} дн.'**
  String deliveryWithinDays(Object days);

  /// No description provided for @expirationDate.
  ///
  /// In ru, this message translates to:
  /// **'СРОК ГОДНОСТИ'**
  String get expirationDate;

  /// No description provided for @canUseUntil.
  ///
  /// In ru, this message translates to:
  /// **'Можно использовать до'**
  String get canUseUntil;

  /// No description provided for @noTagsAdded.
  ///
  /// In ru, this message translates to:
  /// **'Теги пока не добавлены в админке'**
  String get noTagsAdded;

  /// No description provided for @tags.
  ///
  /// In ru, this message translates to:
  /// **'Теги'**
  String get tags;

  /// No description provided for @changePhoto.
  ///
  /// In ru, this message translates to:
  /// **'Изменить фото'**
  String get changePhoto;

  /// No description provided for @chooseDate.
  ///
  /// In ru, this message translates to:
  /// **'Выберите дату'**
  String get chooseDate;

  /// No description provided for @done.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get done;

  /// No description provided for @date.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get date;

  /// No description provided for @dateHint.
  ///
  /// In ru, this message translates to:
  /// **'дд.мм.гггг'**
  String get dateHint;

  /// No description provided for @companyLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить компанию'**
  String get companyLoadFailed;

  /// No description provided for @companyNotSelected.
  ///
  /// In ru, this message translates to:
  /// **'Компания не выбрана'**
  String get companyNotSelected;

  /// No description provided for @companySaveError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сохранения компании'**
  String get companySaveError;

  /// No description provided for @sellerCompanyNotFound.
  ///
  /// In ru, this message translates to:
  /// **'У продавца не найдена компания. Сначала привяжите пользователя к компании на backend.'**
  String get sellerCompanyNotFound;

  /// No description provided for @companyName.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get companyName;

  /// No description provided for @enterCompanyName.
  ///
  /// In ru, this message translates to:
  /// **'Введите название компании'**
  String get enterCompanyName;

  /// No description provided for @address.
  ///
  /// In ru, this message translates to:
  /// **'Адрес'**
  String get address;

  /// No description provided for @enterAddress.
  ///
  /// In ru, this message translates to:
  /// **'Введите адрес'**
  String get enterAddress;

  /// No description provided for @phone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get phone;

  /// No description provided for @openingTime.
  ///
  /// In ru, this message translates to:
  /// **'Открытие'**
  String get openingTime;

  /// No description provided for @closingTime.
  ///
  /// In ru, this message translates to:
  /// **'Закрытие'**
  String get closingTime;

  /// No description provided for @latitude.
  ///
  /// In ru, this message translates to:
  /// **'Широта'**
  String get latitude;

  /// No description provided for @longitude.
  ///
  /// In ru, this message translates to:
  /// **'Долгота'**
  String get longitude;

  /// No description provided for @coordinatesHelp.
  ///
  /// In ru, this message translates to:
  /// **'Координаты нужны для отображения магазина на карте и расчёта расстояния.'**
  String get coordinatesHelp;

  /// No description provided for @socialNetworks.
  ///
  /// In ru, this message translates to:
  /// **'Соцсети'**
  String get socialNetworks;

  /// No description provided for @timeFormat.
  ///
  /// In ru, this message translates to:
  /// **'Формат HH:MM'**
  String get timeFormat;

  /// No description provided for @selectCompanyPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать фото компании'**
  String get selectCompanyPhoto;

  /// No description provided for @noReviewsYet.
  ///
  /// In ru, this message translates to:
  /// **'Отзывов пока нет'**
  String get noReviewsYet;

  /// No description provided for @buyer.
  ///
  /// In ru, this message translates to:
  /// **'Покупатель'**
  String get buyer;

  /// No description provided for @quality.
  ///
  /// In ru, this message translates to:
  /// **'Качество'**
  String get quality;

  /// No description provided for @valueForMoney.
  ///
  /// In ru, this message translates to:
  /// **'Выгодность'**
  String get valueForMoney;

  /// No description provided for @salesLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить продажи'**
  String get salesLoadFailed;

  /// No description provided for @noSalesYet.
  ///
  /// In ru, this message translates to:
  /// **'Продаж пока нет'**
  String get noSalesYet;

  /// No description provided for @salesWillAppearHere.
  ///
  /// In ru, this message translates to:
  /// **'Когда покупатели оформят заказы, они появятся здесь.'**
  String get salesWillAppearHere;

  /// No description provided for @salesHistory.
  ///
  /// In ru, this message translates to:
  /// **'История продаж'**
  String get salesHistory;

  /// No description provided for @salesFor30Days.
  ///
  /// In ru, this message translates to:
  /// **'Продажи за 30 дней'**
  String get salesFor30Days;

  /// No description provided for @salesForYear.
  ///
  /// In ru, this message translates to:
  /// **'Продажи за год'**
  String get salesForYear;

  /// No description provided for @salesFor7Days.
  ///
  /// In ru, this message translates to:
  /// **'Продажи за 7 дней'**
  String get salesFor7Days;

  /// No description provided for @sevenDays.
  ///
  /// In ru, this message translates to:
  /// **'7 дней'**
  String get sevenDays;

  /// No description provided for @thirtyDays.
  ///
  /// In ru, this message translates to:
  /// **'30 дней'**
  String get thirtyDays;

  /// No description provided for @year.
  ///
  /// In ru, this message translates to:
  /// **'Год'**
  String get year;

  /// No description provided for @thisWeek.
  ///
  /// In ru, this message translates to:
  /// **'За неделю'**
  String get thisWeek;

  /// No description provided for @thisMonth.
  ///
  /// In ru, this message translates to:
  /// **'За месяц'**
  String get thisMonth;

  /// No description provided for @averageCheck.
  ///
  /// In ru, this message translates to:
  /// **'Средний чек'**
  String get averageCheck;

  /// No description provided for @noSalesForPeriod.
  ///
  /// In ru, this message translates to:
  /// **'За выбранный период продаж не было'**
  String get noSalesForPeriod;

  /// No description provided for @quantity.
  ///
  /// In ru, this message translates to:
  /// **'Количество'**
  String get quantity;

  /// No description provided for @aboutAppDescription.
  ///
  /// In ru, this message translates to:
  /// **'Приложение для поиска скидочных товаров и специальных предложений местных организаций.'**
  String get aboutAppDescription;

  /// No description provided for @allowLocationAccess.
  ///
  /// In ru, this message translates to:
  /// **'Сначала разрешите доступ к геолокации'**
  String get allowLocationAccess;

  /// No description provided for @selectRadius.
  ///
  /// In ru, this message translates to:
  /// **'Выберите радиус поиска'**
  String get selectRadius;

  /// No description provided for @showShopsInRadius.
  ///
  /// In ru, this message translates to:
  /// **'Покажем магазины и товары внутри выбранной зоны'**
  String get showShopsInRadius;

  /// No description provided for @radius.
  ///
  /// In ru, this message translates to:
  /// **'Радиус'**
  String get radius;

  /// No description provided for @showInRadius.
  ///
  /// In ru, this message translates to:
  /// **'Показать в радиусе'**
  String get showInRadius;

  /// No description provided for @resetRadius.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить радиус'**
  String get resetRadius;

  /// No description provided for @mapLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки карты'**
  String get mapLoadError;

  /// No description provided for @open.
  ///
  /// In ru, this message translates to:
  /// **'Открыто'**
  String get open;

  /// No description provided for @closed.
  ///
  /// In ru, this message translates to:
  /// **'Закрыто'**
  String get closed;

  /// No description provided for @offersByTag.
  ///
  /// In ru, this message translates to:
  /// **'Предложения по тегу'**
  String get offersByTag;

  /// No description provided for @noProductsForFilter.
  ///
  /// In ru, this message translates to:
  /// **'Нет товаров по выбранному фильтру'**
  String get noProductsForFilter;

  /// No description provided for @searchShopOrProduct.
  ///
  /// In ru, this message translates to:
  /// **'Поиск магазина или товара'**
  String get searchShopOrProduct;

  /// No description provided for @nearby.
  ///
  /// In ru, this message translates to:
  /// **'Рядом'**
  String get nearby;

  /// No description provided for @newCompany.
  ///
  /// In ru, this message translates to:
  /// **'Новый'**
  String get newCompany;

  /// No description provided for @pickupLabel.
  ///
  /// In ru, this message translates to:
  /// **'Выдача'**
  String get pickupLabel;

  /// No description provided for @shopsNearby.
  ///
  /// In ru, this message translates to:
  /// **'магазинов рядом'**
  String get shopsNearby;

  /// No description provided for @products.
  ///
  /// In ru, this message translates to:
  /// **'товаров'**
  String get products;

  /// No description provided for @shops.
  ///
  /// In ru, this message translates to:
  /// **'магазинов'**
  String get shops;

  /// No description provided for @productsShort.
  ///
  /// In ru, this message translates to:
  /// **'тов.'**
  String get productsShort;

  /// No description provided for @m.
  ///
  /// In ru, this message translates to:
  /// **'м'**
  String get m;

  /// No description provided for @km.
  ///
  /// In ru, this message translates to:
  /// **'км'**
  String get km;

  /// No description provided for @badgeTop.
  ///
  /// In ru, this message translates to:
  /// **'ТОП'**
  String get badgeTop;

  /// No description provided for @badgeBest.
  ///
  /// In ru, this message translates to:
  /// **'ЛУЧШИЙ'**
  String get badgeBest;

  /// No description provided for @badgeChoice.
  ///
  /// In ru, this message translates to:
  /// **'ВЫБОР'**
  String get badgeChoice;

  /// No description provided for @badgeRating.
  ///
  /// In ru, this message translates to:
  /// **'РЕЙТИНГ'**
  String get badgeRating;

  /// No description provided for @badgeReliable.
  ///
  /// In ru, this message translates to:
  /// **'НАДЁЖНЫЙ'**
  String get badgeReliable;

  /// No description provided for @badgeNew.
  ///
  /// In ru, this message translates to:
  /// **'НОВЫЙ'**
  String get badgeNew;

  /// No description provided for @stockLeft.
  ///
  /// In ru, this message translates to:
  /// **'Остаток'**
  String get stockLeft;

  /// No description provided for @addressNotSpecified.
  ///
  /// In ru, this message translates to:
  /// **'Адрес не указан'**
  String get addressNotSpecified;

  /// No description provided for @productAddFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось добавить товар'**
  String get productAddFailed;

  /// No description provided for @productAddedToCart.
  ///
  /// In ru, this message translates to:
  /// **'Товар добавлен в корзину'**
  String get productAddedToCart;

  /// No description provided for @loginToReserveProduct.
  ///
  /// In ru, this message translates to:
  /// **'Войдите в аккаунт, чтобы зарезервировать товар.'**
  String get loginToReserveProduct;

  /// No description provided for @loginToAddCart.
  ///
  /// In ru, this message translates to:
  /// **'Войдите в аккаунт, чтобы добавить товар в корзину.'**
  String get loginToAddCart;

  /// No description provided for @outOfStockUpper.
  ///
  /// In ru, this message translates to:
  /// **'НЕТ В НАЛИЧИИ'**
  String get outOfStockUpper;

  /// No description provided for @leftUpper.
  ///
  /// In ru, this message translates to:
  /// **'ОСТАЛОСЬ'**
  String get leftUpper;

  /// No description provided for @leftItems.
  ///
  /// In ru, this message translates to:
  /// **'Осталось'**
  String get leftItems;

  /// No description provided for @piecesShort.
  ///
  /// In ru, this message translates to:
  /// **'шт.'**
  String get piecesShort;

  /// No description provided for @pickupTime.
  ///
  /// In ru, this message translates to:
  /// **'Выдача'**
  String get pickupTime;

  /// No description provided for @workingHours.
  ///
  /// In ru, this message translates to:
  /// **'Время работы'**
  String get workingHours;

  /// No description provided for @enterPhoneAndAddress.
  ///
  /// In ru, this message translates to:
  /// **'Укажите телефон и адрес'**
  String get enterPhoneAndAddress;

  /// No description provided for @deliveryDataSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить данные доставки'**
  String get deliveryDataSaveError;

  /// No description provided for @deliveryDataTitle.
  ///
  /// In ru, this message translates to:
  /// **'Данные для доставки'**
  String get deliveryDataTitle;

  /// No description provided for @deliveryDataDescription.
  ///
  /// In ru, this message translates to:
  /// **'Для оформления заказа нужно указать телефон и адрес. Эти данные увидит продавец.'**
  String get deliveryDataDescription;

  /// No description provided for @deliveryAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес доставки'**
  String get deliveryAddress;

  /// No description provided for @saveAndCheckout.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить и оформить'**
  String get saveAndCheckout;

  /// No description provided for @deliveryDays.
  ///
  /// In ru, this message translates to:
  /// **'Срок доставки (дней)'**
  String get deliveryDays;

  /// No description provided for @aboutProduct.
  ///
  /// In ru, this message translates to:
  /// **'О ТОВАРЕ'**
  String get aboutProduct;

  /// No description provided for @aboutPackage.
  ///
  /// In ru, this message translates to:
  /// **'О ТОВАРЕ В УПАКОВКЕ'**
  String get aboutPackage;

  /// No description provided for @productDescriptionMissing.
  ///
  /// In ru, this message translates to:
  /// **'Описание товара пока не добавлено'**
  String get productDescriptionMissing;

  /// No description provided for @usableUntil.
  ///
  /// In ru, this message translates to:
  /// **'МОЖНО ИСПОЛЬЗОВАТЬ ДО'**
  String get usableUntil;

  /// No description provided for @addToCartUpper.
  ///
  /// In ru, this message translates to:
  /// **'В КОРЗИНУ'**
  String get addToCartUpper;

  /// No description provided for @addedToCart.
  ///
  /// In ru, this message translates to:
  /// **'Товар добавлен в корзину'**
  String get addedToCart;

  /// No description provided for @quantityLabel.
  ///
  /// In ru, this message translates to:
  /// **'Количество'**
  String get quantityLabel;

  /// No description provided for @myPurchases.
  ///
  /// In ru, this message translates to:
  /// **'Мои покупки'**
  String get myPurchases;

  /// No description provided for @myPurchasesSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'История заказов и общая сумма'**
  String get myPurchasesSubtitle;

  /// No description provided for @myReviews.
  ///
  /// In ru, this message translates to:
  /// **'Мои отзывы'**
  String get myReviews;

  /// No description provided for @myReviewsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Отзывы и оценки, которые вы оставили'**
  String get myReviewsSubtitle;

  /// No description provided for @daysShort.
  ///
  /// In ru, this message translates to:
  /// **'дн.'**
  String get daysShort;

  /// No description provided for @loadDataError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить данные'**
  String get loadDataError;

  /// No description provided for @minimumZero.
  ///
  /// In ru, this message translates to:
  /// **'Минимум 0'**
  String get minimumZero;

  /// No description provided for @enterDaysRange.
  ///
  /// In ru, this message translates to:
  /// **'Введите число от 1 до 365'**
  String get enterDaysRange;

  /// No description provided for @dateFormatHint.
  ///
  /// In ru, this message translates to:
  /// **'дд.мм.гггг'**
  String get dateFormatHint;

  /// No description provided for @packageQuantityHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: x3 бутылки в одной упаковке'**
  String get packageQuantityHint;

  /// No description provided for @weightVolumeHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: 500 г, 1 л, 6 x 0.5 л'**
  String get weightVolumeHint;

  /// No description provided for @deliveryDaysHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: 3'**
  String get deliveryDaysHint;

  /// No description provided for @coordinateRange.
  ///
  /// In ru, this message translates to:
  /// **'Допустимый диапазон'**
  String get coordinateRange;

  /// No description provided for @orderOpenError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть заказ'**
  String get orderOpenError;

  /// No description provided for @welcomeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Спасайте еду. Экономьте больше.'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Находите предложения рядом и специальные скидки от местных организаций.'**
  String get welcomeSubtitle;

  /// No description provided for @continueWithGoogle.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить через Google'**
  String get continueWithGoogle;

  /// No description provided for @continueAsGuest.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить как гость'**
  String get continueAsGuest;

  /// No description provided for @signInWithPassword.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get signInWithPassword;

  /// No description provided for @registerAsSeller.
  ///
  /// In ru, this message translates to:
  /// **'Зарегистрироваться как продавец'**
  String get registerAsSeller;

  /// No description provided for @aboutUs.
  ///
  /// In ru, this message translates to:
  /// **'О нас'**
  String get aboutUs;

  /// No description provided for @sellerRegistrationComingSoon.
  ///
  /// In ru, this message translates to:
  /// **'Регистрацию продавца добавим на следующем этапе.'**
  String get sellerRegistrationComingSoon;

  /// No description provided for @notificationsLoginTitle.
  ///
  /// In ru, this message translates to:
  /// **'Войдите, чтобы видеть уведомления'**
  String get notificationsLoginTitle;

  /// No description provided for @notificationsLoginSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Получайте обновления по заказам, напоминания и персональные предложения.'**
  String get notificationsLoginSubtitle;

  /// No description provided for @or.
  ///
  /// In ru, this message translates to:
  /// **'или'**
  String get or;

  /// No description provided for @loginWithGoogle.
  ///
  /// In ru, this message translates to:
  /// **'Войти через Google'**
  String get loginWithGoogle;

  /// No description provided for @registerAction.
  ///
  /// In ru, this message translates to:
  /// **'Зарегистрироваться'**
  String get registerAction;

  /// No description provided for @requiredField.
  ///
  /// In ru, this message translates to:
  /// **'Обязательное поле'**
  String get requiredField;

  /// No description provided for @sellerUsernameExists.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь с таким логином уже существует.'**
  String get sellerUsernameExists;

  /// No description provided for @sellerEmailExists.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь с таким email уже существует.'**
  String get sellerEmailExists;

  /// No description provided for @invalidCredentials.
  ///
  /// In ru, this message translates to:
  /// **'Неверный логин или пароль.'**
  String get invalidCredentials;

  /// No description provided for @authorizationConfirmationFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось подтвердить авторизацию.'**
  String get authorizationConfirmationFailed;

  /// No description provided for @createSellerAccount.
  ///
  /// In ru, this message translates to:
  /// **'Создать аккаунт продавца'**
  String get createSellerAccount;

  /// No description provided for @loginAsSeller.
  ///
  /// In ru, this message translates to:
  /// **'Войти как продавец'**
  String get loginAsSeller;

  /// No description provided for @createSellerAccountSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Создайте аккаунт, чтобы заполнить и отправить заявку продавца.'**
  String get createSellerAccountSubtitle;

  /// No description provided for @loginSellerSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Войдите в существующий аккаунт, чтобы продолжить оформление заявки.'**
  String get loginSellerSubtitle;

  /// No description provided for @createAndContinue.
  ///
  /// In ru, this message translates to:
  /// **'Создать и продолжить'**
  String get createAndContinue;

  /// No description provided for @loginAndContinue.
  ///
  /// In ru, this message translates to:
  /// **'Войти и продолжить'**
  String get loginAndContinue;

  /// No description provided for @alreadyHaveAccountSignIn.
  ///
  /// In ru, this message translates to:
  /// **'Уже есть аккаунт? Войти'**
  String get alreadyHaveAccountSignIn;

  /// No description provided for @noAccountCreate.
  ///
  /// In ru, this message translates to:
  /// **'Нет аккаунта? Создать'**
  String get noAccountCreate;

  /// No description provided for @sellerStatusAfterApproval.
  ///
  /// In ru, this message translates to:
  /// **'Статус продавца будет присвоен только после одобрения заявки.'**
  String get sellerStatusAfterApproval;

  /// No description provided for @chooseBusinessCategory.
  ///
  /// In ru, this message translates to:
  /// **'Выберите категорию бизнеса'**
  String get chooseBusinessCategory;

  /// No description provided for @applicationIdMissing.
  ///
  /// In ru, this message translates to:
  /// **'Идентификатор заявки отсутствует.'**
  String get applicationIdMissing;

  /// No description provided for @networkError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сети'**
  String get networkError;

  /// No description provided for @failedSaveDraft.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить черновик: {error}'**
  String failedSaveDraft(String error);

  /// No description provided for @couldNotLoadCategories.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить категории.\n{error}'**
  String couldNotLoadCategories(String error);

  /// No description provided for @noCategoriesAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Для этого направления нет доступных категорий.'**
  String get noCategoriesAvailable;

  /// No description provided for @businessCategorySubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Давайте определим, какой у вас тип бизнеса'**
  String get businessCategorySubtitle;

  /// No description provided for @next.
  ///
  /// In ru, this message translates to:
  /// **'Далее'**
  String get next;

  /// No description provided for @skip.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить'**
  String get skip;

  /// No description provided for @chooseYourBusinessCategory.
  ///
  /// In ru, this message translates to:
  /// **'Выберите категорию вашего бизнеса'**
  String get chooseYourBusinessCategory;

  /// No description provided for @weAreA.
  ///
  /// In ru, this message translates to:
  /// **'Мы — ...'**
  String get weAreA;

  /// No description provided for @tryAgain.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get tryAgain;

  /// No description provided for @companyNameHelper.
  ///
  /// In ru, this message translates to:
  /// **'Наименование, зарегистрированное в государственном реестре'**
  String get companyNameHelper;

  /// No description provided for @tin.
  ///
  /// In ru, this message translates to:
  /// **'ИНН'**
  String get tin;

  /// No description provided for @tinHelper.
  ///
  /// In ru, this message translates to:
  /// **'Необходимо для налогового учета и проверки'**
  String get tinHelper;

  /// No description provided for @addressHelper.
  ///
  /// In ru, this message translates to:
  /// **'Фактический адрес для самовывоза и местной логистики'**
  String get addressHelper;

  /// No description provided for @findAddressOnMap.
  ///
  /// In ru, this message translates to:
  /// **'Найти адрес на карте'**
  String get findAddressOnMap;

  /// No description provided for @addressNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Адрес не найден. Выберите точку вручную на карте.'**
  String get addressNotFound;

  /// No description provided for @addressLookupFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось определить адрес. Выберите точку вручную на карте.'**
  String get addressLookupFailed;

  /// No description provided for @mapPointHint.
  ///
  /// In ru, this message translates to:
  /// **'Точка определяется по адресу автоматически. При необходимости нажмите на нужное место на карте.'**
  String get mapPointHint;

  /// No description provided for @contacts.
  ///
  /// In ru, this message translates to:
  /// **'Контакты'**
  String get contacts;

  /// No description provided for @officialBusinessNumber.
  ///
  /// In ru, this message translates to:
  /// **'Официальный номер организации'**
  String get officialBusinessNumber;

  /// No description provided for @personResponsible.
  ///
  /// In ru, this message translates to:
  /// **'Ответственное лицо'**
  String get personResponsible;

  /// No description provided for @personResponsibleHelper.
  ///
  /// In ru, this message translates to:
  /// **'Менеджер или сотрудник, ответственный за работу с приложением'**
  String get personResponsibleHelper;

  /// No description provided for @directContactPhone.
  ///
  /// In ru, this message translates to:
  /// **'Прямой контактный номер'**
  String get directContactPhone;

  /// No description provided for @docRegistration.
  ///
  /// In ru, this message translates to:
  /// **'Учредительный документ'**
  String get docRegistration;

  /// No description provided for @docTax.
  ///
  /// In ru, this message translates to:
  /// **'Налоговый документ'**
  String get docTax;

  /// No description provided for @docLicense.
  ///
  /// In ru, this message translates to:
  /// **'Лицензия'**
  String get docLicense;

  /// No description provided for @docFoodSafety.
  ///
  /// In ru, this message translates to:
  /// **'Пищевая безопасность'**
  String get docFoodSafety;

  /// No description provided for @docCertificate.
  ///
  /// In ru, this message translates to:
  /// **'Сертификат'**
  String get docCertificate;

  /// No description provided for @docIdentity.
  ///
  /// In ru, this message translates to:
  /// **'Документ ответственного лица'**
  String get docIdentity;

  /// No description provided for @docBank.
  ///
  /// In ru, this message translates to:
  /// **'Банковский документ'**
  String get docBank;

  /// No description provided for @docOther.
  ///
  /// In ru, this message translates to:
  /// **'Другое'**
  String get docOther;

  /// No description provided for @createApplicationFirst.
  ///
  /// In ru, this message translates to:
  /// **'Сначала необходимо создать заявку.'**
  String get createApplicationFirst;

  /// No description provided for @fileReadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось прочитать выбранный файл.'**
  String get fileReadFailed;

  /// No description provided for @fileTooLarge20.
  ///
  /// In ru, this message translates to:
  /// **'Размер файла не должен превышать 20 МБ.'**
  String get fileTooLarge20;

  /// No description provided for @documentUploaded.
  ///
  /// In ru, this message translates to:
  /// **'Документ загружен.'**
  String get documentUploaded;

  /// No description provided for @documentUploadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить документ: {error}'**
  String documentUploadFailed(String error);

  /// No description provided for @documentDeleteFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось удалить документ: {error}'**
  String documentDeleteFailed(String error);

  /// No description provided for @uploadAtLeastOneDocument.
  ///
  /// In ru, this message translates to:
  /// **'Загрузите хотя бы один документ.'**
  String get uploadAtLeastOneDocument;

  /// No description provided for @documents.
  ///
  /// In ru, this message translates to:
  /// **'Документы'**
  String get documents;

  /// No description provided for @documentsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Выберите тип документа и загрузите файл. Поддерживаются PDF, JPG, PNG, WEBP, DOC и DOCX до 20 МБ.'**
  String get documentsSubtitle;

  /// No description provided for @documentType.
  ///
  /// In ru, this message translates to:
  /// **'Тип документа'**
  String get documentType;

  /// No description provided for @uploading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка...'**
  String get uploading;

  /// No description provided for @chooseAndUploadFile.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать и загрузить файл'**
  String get chooseAndUploadFile;

  /// No description provided for @uploadedDocuments.
  ///
  /// In ru, this message translates to:
  /// **'Загруженные документы'**
  String get uploadedDocuments;

  /// No description provided for @document.
  ///
  /// In ru, this message translates to:
  /// **'Документ'**
  String get document;

  /// No description provided for @logoTooLarge10.
  ///
  /// In ru, this message translates to:
  /// **'Логотип должен быть не больше 10 МБ.'**
  String get logoTooLarge10;

  /// No description provided for @applicationNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Заявка не найдена.'**
  String get applicationNotFound;

  /// No description provided for @applicationSubmitFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отправить заявку: {error}'**
  String applicationSubmitFailed(String error);

  /// No description provided for @bankDetails.
  ///
  /// In ru, this message translates to:
  /// **'Банковские реквизиты'**
  String get bankDetails;

  /// No description provided for @bankDetailsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Укажите реквизиты для выплат. Логотип и описание можно добавить сейчас.'**
  String get bankDetailsSubtitle;

  /// No description provided for @bankName.
  ///
  /// In ru, this message translates to:
  /// **'Название банка'**
  String get bankName;

  /// No description provided for @accountHolder.
  ///
  /// In ru, this message translates to:
  /// **'Владелец банковского счёта'**
  String get accountHolder;

  /// No description provided for @companyDescriptionOptional.
  ///
  /// In ru, this message translates to:
  /// **'Описание компании (необязательно)'**
  String get companyDescriptionOptional;

  /// No description provided for @companyLogo.
  ///
  /// In ru, this message translates to:
  /// **'Логотип компании'**
  String get companyLogo;

  /// No description provided for @logo.
  ///
  /// In ru, this message translates to:
  /// **'Логотип'**
  String get logo;

  /// No description provided for @chooseLogo.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать логотип'**
  String get chooseLogo;

  /// No description provided for @submitApplication.
  ///
  /// In ru, this message translates to:
  /// **'Отправить заявку'**
  String get submitApplication;

  /// No description provided for @applicationSent.
  ///
  /// In ru, this message translates to:
  /// **'Заявка отправлена'**
  String get applicationSent;

  /// No description provided for @applicationSentSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Мы получили вашу заявку. После проверки вы получите уведомление.'**
  String get applicationSentSubtitle;

  /// No description provided for @applicationNumber.
  ///
  /// In ru, this message translates to:
  /// **'Номер заявки'**
  String get applicationNumber;

  /// No description provided for @underReview.
  ///
  /// In ru, this message translates to:
  /// **'На проверке'**
  String get underReview;

  /// No description provided for @sellerTypeHotTitle.
  ///
  /// In ru, this message translates to:
  /// **'Я хочу, чтобы покупатели забирали излишки товаров из моего магазина.'**
  String get sellerTypeHotTitle;

  /// No description provided for @sellerTypeDealsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Я производитель или представитель и хочу доставлять излишки товаров.'**
  String get sellerTypeDealsTitle;

  /// No description provided for @submitAnApplication.
  ///
  /// In ru, this message translates to:
  /// **'Подать заявку'**
  String get submitAnApplication;

  /// No description provided for @selectTime.
  ///
  /// In ru, this message translates to:
  /// **'Выберите время'**
  String get selectTime;

  /// No description provided for @pickupWindowRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите период получения товара'**
  String get pickupWindowRequired;

  /// No description provided for @pickupUntilAfterFrom.
  ///
  /// In ru, this message translates to:
  /// **'Время окончания получения должно быть позже времени начала'**
  String get pickupUntilAfterFrom;

  /// No description provided for @pickupUntilFuture.
  ///
  /// In ru, this message translates to:
  /// **'Время окончания получения должно быть в будущем'**
  String get pickupUntilFuture;

  /// No description provided for @sellerPublishNow.
  ///
  /// In ru, this message translates to:
  /// **'Сейчас'**
  String get sellerPublishNow;

  /// No description provided for @sellerPublishInHours.
  ///
  /// In ru, this message translates to:
  /// **'Через {hours} ч'**
  String sellerPublishInHours(int hours);

  /// No description provided for @sellerChoosePublishDateTime.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать дату и время'**
  String get sellerChoosePublishDateTime;

  /// No description provided for @sellerPublicationDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата публикации'**
  String get sellerPublicationDate;

  /// No description provided for @sellerPublicationTime.
  ///
  /// In ru, this message translates to:
  /// **'Время публикации'**
  String get sellerPublicationTime;

  /// No description provided for @sellerPublicationMustBeFuture.
  ///
  /// In ru, this message translates to:
  /// **'Выберите будущее время публикации'**
  String get sellerPublicationMustBeFuture;

  /// No description provided for @sellerPublishImmediately.
  ///
  /// In ru, this message translates to:
  /// **'Опубликовать сразу'**
  String get sellerPublishImmediately;

  /// No description provided for @sellerYerevanTime.
  ///
  /// In ru, this message translates to:
  /// **'По времени Еревана'**
  String get sellerYerevanTime;

  /// No description provided for @sellerCustomPublicationSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Пользовательское время публикации'**
  String get sellerCustomPublicationSubtitle;

  /// No description provided for @sellerHotNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название сюрприз-бокса'**
  String get sellerHotNameLabel;

  /// No description provided for @sellerHotNameExample.
  ///
  /// In ru, this message translates to:
  /// **'Например: «Сюрприз-бокс с ассорти сладостей»'**
  String get sellerHotNameExample;

  /// No description provided for @sellerDealsNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название товара'**
  String get sellerDealsNameLabel;

  /// No description provided for @sellerDescriptionLabel.
  ///
  /// In ru, this message translates to:
  /// **'Опишите, что получит покупатель...'**
  String get sellerDescriptionLabel;

  /// No description provided for @sellerHotDescriptionExample.
  ///
  /// In ru, this message translates to:
  /// **'Например: «До 4 видов свежей выпечки и сладостей, приготовленных сегодня»'**
  String get sellerHotDescriptionExample;

  /// No description provided for @sellerDealsDescriptionExample.
  ///
  /// In ru, this message translates to:
  /// **'Например: «В коробке 3 бутылки крафтового пива»'**
  String get sellerDealsDescriptionExample;

  /// No description provided for @sellerPickupDetailsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Как забрать товар'**
  String get sellerPickupDetailsLabel;

  /// No description provided for @sellerStockQuantityLabel.
  ///
  /// In ru, this message translates to:
  /// **'Количество в наличии'**
  String get sellerStockQuantityLabel;

  /// No description provided for @sellerEnterStockQuantity.
  ///
  /// In ru, this message translates to:
  /// **'Введите количество товара в наличии'**
  String get sellerEnterStockQuantity;

  /// No description provided for @sellerSetPrice.
  ///
  /// In ru, this message translates to:
  /// **'Укажите цену'**
  String get sellerSetPrice;

  /// No description provided for @sellerFullPrice.
  ///
  /// In ru, this message translates to:
  /// **'Полная цена'**
  String get sellerFullPrice;

  /// No description provided for @sellerRecommendedTags.
  ///
  /// In ru, this message translates to:
  /// **'Рекомендуемые теги'**
  String get sellerRecommendedTags;

  /// No description provided for @sellerMaxTagsSelected.
  ///
  /// In ru, this message translates to:
  /// **'Выбрано максимум тегов: {count}'**
  String sellerMaxTagsSelected(int count);

  /// No description provided for @sellerChooseUpToTags.
  ///
  /// In ru, this message translates to:
  /// **'Выберите до {count} тегов'**
  String sellerChooseUpToTags(int count);

  /// No description provided for @sellerAddPhotoShort.
  ///
  /// In ru, this message translates to:
  /// **'Добавить фото'**
  String get sellerAddPhotoShort;

  /// No description provided for @sellerTapUploadImage.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите, чтобы выбрать изображение'**
  String get sellerTapUploadImage;

  /// No description provided for @sellerTapChangePhoto.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите, чтобы изменить фото'**
  String get sellerTapChangePhoto;

  /// No description provided for @sellerOrganisation.
  ///
  /// In ru, this message translates to:
  /// **'Организация'**
  String get sellerOrganisation;

  /// No description provided for @sellerYourOrganisation.
  ///
  /// In ru, this message translates to:
  /// **'Ваша организация'**
  String get sellerYourOrganisation;

  /// No description provided for @sellerAddressNotSet.
  ///
  /// In ru, this message translates to:
  /// **'В настройках организации не указан адрес'**
  String get sellerAddressNotSet;

  /// No description provided for @sellerPickupLocation.
  ///
  /// In ru, this message translates to:
  /// **'Выберите место получения'**
  String get sellerPickupLocation;

  /// No description provided for @sellerPickupPointMovedHint.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите на карту ещё раз, чтобы изменить точку получения.'**
  String get sellerPickupPointMovedHint;

  /// No description provided for @sellerPickupPointOrganisationHint.
  ///
  /// In ru, this message translates to:
  /// **'Точка загружена из настроек организации. Нажмите на карту, если товар нужно забрать в другой точке или магазине.'**
  String get sellerPickupPointOrganisationHint;

  /// No description provided for @sellerUseOrganisationLocation.
  ///
  /// In ru, this message translates to:
  /// **'Использовать адрес организации'**
  String get sellerUseOrganisationLocation;

  /// No description provided for @sellerSelectDateTime.
  ///
  /// In ru, this message translates to:
  /// **'Выберите дату и время'**
  String get sellerSelectDateTime;

  /// No description provided for @sellerPickupWindow.
  ///
  /// In ru, this message translates to:
  /// **'Период получения'**
  String get sellerPickupWindow;

  /// No description provided for @sellerFrom.
  ///
  /// In ru, this message translates to:
  /// **'С'**
  String get sellerFrom;

  /// No description provided for @sellerTo.
  ///
  /// In ru, this message translates to:
  /// **'До'**
  String get sellerTo;

  /// No description provided for @sellerPreviewProductName.
  ///
  /// In ru, this message translates to:
  /// **'Название товара'**
  String get sellerPreviewProductName;

  /// No description provided for @sellerPreviewProductDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание товара'**
  String get sellerPreviewProductDescription;

  /// No description provided for @sellerDealsEditTitle.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать Deals-товар'**
  String get sellerDealsEditTitle;

  /// No description provided for @sellerDealsAddTitle.
  ///
  /// In ru, this message translates to:
  /// **'Добавить Deals-товар'**
  String get sellerDealsAddTitle;

  /// No description provided for @sellerDealsPackageLabel.
  ///
  /// In ru, this message translates to:
  /// **'Количество в упаковке'**
  String get sellerDealsPackageLabel;

  /// No description provided for @sellerDealsPackageHint.
  ///
  /// In ru, this message translates to:
  /// **'Укажите количество в упаковке, например: 3 бутылки × 0,5 л'**
  String get sellerDealsPackageHint;

  /// No description provided for @sellerExpirationDate.
  ///
  /// In ru, this message translates to:
  /// **'Срок годности'**
  String get sellerExpirationDate;

  /// No description provided for @sellerBestBeforeDate.
  ///
  /// In ru, this message translates to:
  /// **'Использовать до / Лучше употребить до'**
  String get sellerBestBeforeDate;

  /// No description provided for @sellerUseBeforeDate.
  ///
  /// In ru, this message translates to:
  /// **'Использовать до'**
  String get sellerUseBeforeDate;

  /// No description provided for @sellerDatesOptionalHint.
  ///
  /// In ru, this message translates to:
  /// **'* Заполните эти даты, только если они применимы к товару'**
  String get sellerDatesOptionalHint;

  /// No description provided for @sellerChooseOneCategory.
  ///
  /// In ru, this message translates to:
  /// **'Выберите одну категорию'**
  String get sellerChooseOneCategory;

  /// No description provided for @sellerChooseCategory.
  ///
  /// In ru, this message translates to:
  /// **'Выберите категорию'**
  String get sellerChooseCategory;

  /// No description provided for @sellerDeliveryArea.
  ///
  /// In ru, this message translates to:
  /// **'Зона доставки'**
  String get sellerDeliveryArea;

  /// No description provided for @sellerOrganisationCoordinatesMissing.
  ///
  /// In ru, this message translates to:
  /// **'Координаты организации не указаны'**
  String get sellerOrganisationCoordinatesMissing;

  /// No description provided for @sellerOrganisationCoordinatesMissingHint.
  ///
  /// In ru, this message translates to:
  /// **'Укажите широту и долготу в настройках организации, чтобы показать зону доставки.'**
  String get sellerOrganisationCoordinatesMissingHint;

  /// No description provided for @sellerDeliveryRadiusHint.
  ///
  /// In ru, this message translates to:
  /// **'Выберите радиус доставки от адреса организации.'**
  String get sellerDeliveryRadiusHint;

  /// No description provided for @sellerRadiusKm.
  ///
  /// In ru, this message translates to:
  /// **'{km} км'**
  String sellerRadiusKm(int km);

  /// No description provided for @sellerWhenDeliver.
  ///
  /// In ru, this message translates to:
  /// **'Срок доставки'**
  String get sellerWhenDeliver;

  /// No description provided for @sellerWithinOneDay.
  ///
  /// In ru, this message translates to:
  /// **'В течение 1 дня'**
  String get sellerWithinOneDay;

  /// No description provided for @sellerWithinDays.
  ///
  /// In ru, this message translates to:
  /// **'В течение {days} дней'**
  String sellerWithinDays(int days);

  /// No description provided for @sellerSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get sellerSave;

  /// No description provided for @sellerClearDate.
  ///
  /// In ru, this message translates to:
  /// **'Очистить дату'**
  String get sellerClearDate;

  /// No description provided for @sellerNoOrganisation.
  ///
  /// In ru, this message translates to:
  /// **'У продавца нет организации'**
  String get sellerNoOrganisation;

  /// No description provided for @sellerCheckExpirationDate.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте срок годности'**
  String get sellerCheckExpirationDate;

  /// No description provided for @sellerCheckUseBeforeDate.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте дату «Использовать до»'**
  String get sellerCheckUseBeforeDate;

  /// No description provided for @sellerCategoryRequired.
  ///
  /// In ru, this message translates to:
  /// **'Выберите одну категорию товара'**
  String get sellerCategoryRequired;

  /// No description provided for @companyAddressLookupTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось найти адрес: превышено время ожидания.'**
  String get companyAddressLookupTimeout;

  /// No description provided for @companyCouldNotDetermine.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось определить организацию. Обновите экран.'**
  String get companyCouldNotDetermine;

  /// No description provided for @companySelectLocation.
  ///
  /// In ru, this message translates to:
  /// **'Выберите местоположение организации на карте.'**
  String get companySelectLocation;

  /// No description provided for @organization.
  ///
  /// In ru, this message translates to:
  /// **'Организация'**
  String get organization;

  /// No description provided for @companyBasicInformation.
  ///
  /// In ru, this message translates to:
  /// **'Основная информация'**
  String get companyBasicInformation;

  /// No description provided for @companyNameLockedHelper.
  ///
  /// In ru, this message translates to:
  /// **'Наименование подтверждено администратором и недоступно для изменения.'**
  String get companyNameLockedHelper;

  /// No description provided for @companyAddressAndLocation.
  ///
  /// In ru, this message translates to:
  /// **'Адрес и местоположение'**
  String get companyAddressAndLocation;

  /// No description provided for @enterCompanyAddress.
  ///
  /// In ru, this message translates to:
  /// **'Введите адрес организации'**
  String get enterCompanyAddress;

  /// No description provided for @findOnMap.
  ///
  /// In ru, this message translates to:
  /// **'Найти на карте'**
  String get findOnMap;

  /// No description provided for @companyMapPointHelper.
  ///
  /// In ru, this message translates to:
  /// **'Точка определяется по адресу автоматически. При необходимости нажмите на нужное место на карте.'**
  String get companyMapPointHelper;

  /// No description provided for @organizationSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки организации'**
  String get organizationSettings;

  /// No description provided for @becomeSeller.
  ///
  /// In ru, this message translates to:
  /// **'Стать продавцом'**
  String get becomeSeller;

  /// No description provided for @becomeSellerSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Подать заявку на подключение магазина'**
  String get becomeSellerSubtitle;

  /// No description provided for @sellerStatusApproved.
  ///
  /// In ru, this message translates to:
  /// **'Одобрено'**
  String get sellerStatusApproved;

  /// No description provided for @sellerStatusRejected.
  ///
  /// In ru, this message translates to:
  /// **'Отклонено'**
  String get sellerStatusRejected;

  /// No description provided for @sellerStatusChangesRequested.
  ///
  /// In ru, this message translates to:
  /// **'Требуются изменения'**
  String get sellerStatusChangesRequested;

  /// No description provided for @sellerStatusPending.
  ///
  /// In ru, this message translates to:
  /// **'На проверке'**
  String get sellerStatusPending;

  /// No description provided for @sellerStatusDraft.
  ///
  /// In ru, this message translates to:
  /// **'Черновик'**
  String get sellerStatusDraft;

  /// No description provided for @sellerApplication.
  ///
  /// In ru, this message translates to:
  /// **'Заявка продавца'**
  String get sellerApplication;

  /// No description provided for @sellerApplicationChangesRequired.
  ///
  /// In ru, this message translates to:
  /// **'Администратор запросил изменения в заявке.'**
  String get sellerApplicationChangesRequired;

  /// No description provided for @fixSellerApplication.
  ///
  /// In ru, this message translates to:
  /// **'Исправить заявку'**
  String get fixSellerApplication;

  /// No description provided for @continueSellerApplication.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить заявку'**
  String get continueSellerApplication;

  /// No description provided for @pickupExpiredEdit.
  ///
  /// In ru, this message translates to:
  /// **'Время получения истекло. Откройте товар и укажите новое время получения.'**
  String get pickupExpiredEdit;

  /// No description provided for @sellerProductStatusScheduled.
  ///
  /// In ru, this message translates to:
  /// **'ОТЛОЖЕННАЯ ПУБЛИКАЦИЯ'**
  String get sellerProductStatusScheduled;

  /// No description provided for @sellerProductStatusExpired.
  ///
  /// In ru, this message translates to:
  /// **'ВРЕМЯ ИСТЕКЛО'**
  String get sellerProductStatusExpired;

  /// No description provided for @sellerProductStatusInactive.
  ///
  /// In ru, this message translates to:
  /// **'НЕАКТИВЕН'**
  String get sellerProductStatusInactive;

  /// No description provided for @sellerStockMustBePositive.
  ///
  /// In ru, this message translates to:
  /// **'Сначала откройте редактирование и увеличьте остаток товара.'**
  String get sellerStockMustBePositive;

  /// No description provided for @sellerProductRemovedFromSale.
  ///
  /// In ru, this message translates to:
  /// **'Товар снят с продажи.'**
  String get sellerProductRemovedFromSale;

  /// No description provided for @sellerProductBackOnSale.
  ///
  /// In ru, this message translates to:
  /// **'Товар снова в продаже.'**
  String get sellerProductBackOnSale;

  /// No description provided for @sellerChangePublicationTime.
  ///
  /// In ru, this message translates to:
  /// **'Изменить время'**
  String get sellerChangePublicationTime;

  /// No description provided for @sellerPublishNowConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Отложенная публикация будет отменена, и товар сразу появится в продаже.'**
  String get sellerPublishNowConfirm;

  /// No description provided for @sellerProductPublishedNow.
  ///
  /// In ru, this message translates to:
  /// **'Товар опубликован и уже доступен покупателям.'**
  String get sellerProductPublishedNow;

  /// No description provided for @orderPhoneTitle.
  ///
  /// In ru, this message translates to:
  /// **'Номер телефона'**
  String get orderPhoneTitle;

  /// No description provided for @orderPhoneDescription.
  ///
  /// In ru, this message translates to:
  /// **'Укажите номер телефона, чтобы продавец мог связаться с вами по заказу.'**
  String get orderPhoneDescription;

  /// No description provided for @enterPhoneNumber.
  ///
  /// In ru, this message translates to:
  /// **'Укажите номер телефона'**
  String get enterPhoneNumber;

  /// No description provided for @enterDeliveryAddress.
  ///
  /// In ru, this message translates to:
  /// **'Укажите адрес доставки'**
  String get enterDeliveryAddress;

  /// No description provided for @saveAndContinue.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить и продолжить'**
  String get saveAndContinue;

  /// No description provided for @sellerRegistrationApprovedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Заявка продавца уже одобрена. Новую регистрацию начинать нельзя. Откройте панель продавца в профиле.'**
  String get sellerRegistrationApprovedMessage;

  /// No description provided for @sellerRegistrationPendingMessage.
  ///
  /// In ru, this message translates to:
  /// **'Заявка продавца уже отправлена и находится на проверке. Дождитесь решения администратора.'**
  String get sellerRegistrationPendingMessage;

  /// No description provided for @sellerRegistrationRejectedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Эта заявка продавца отклонена и больше не редактируется. Новую заявку пока нельзя создать.'**
  String get sellerRegistrationRejectedMessage;

  /// No description provided for @sellerRegistrationLockedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Эту заявку продавца больше нельзя изменять. Вернитесь в профиль и проверьте её текущий статус.'**
  String get sellerRegistrationLockedMessage;

  /// No description provided for @sellerRegistrationResumeRequiredMessage.
  ///
  /// In ru, this message translates to:
  /// **'У вас уже есть незавершённая заявка продавца. Вернитесь в профиль и продолжите существующую заявку вместо создания новой.'**
  String get sellerRegistrationResumeRequiredMessage;

  /// No description provided for @sellerRegistrationCheckFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось проверить текущую заявку продавца. Повторите попытку.'**
  String get sellerRegistrationCheckFailed;

  /// No description provided for @sellerCustomDeliveryDays.
  ///
  /// In ru, this message translates to:
  /// **'Свой срок'**
  String get sellerCustomDeliveryDays;

  /// No description provided for @sellerCustomDeliveryDaysTitle.
  ///
  /// In ru, this message translates to:
  /// **'Свой срок доставки'**
  String get sellerCustomDeliveryDaysTitle;

  /// No description provided for @sellerCustomDeliveryDaysHint.
  ///
  /// In ru, this message translates to:
  /// **'Количество дней'**
  String get sellerCustomDeliveryDaysHint;

  /// No description provided for @sellerCustomDeliveryDaysRange.
  ///
  /// In ru, this message translates to:
  /// **'Введите количество дней от 1 до 365'**
  String get sellerCustomDeliveryDaysRange;

  /// No description provided for @sellerDaysShort.
  ///
  /// In ru, this message translates to:
  /// **'дн.'**
  String get sellerDaysShort;

  /// No description provided for @sellerDealsStockRemaining.
  ///
  /// In ru, this message translates to:
  /// **'Остаток товара'**
  String get sellerDealsStockRemaining;

  /// No description provided for @sellerHelpContinue.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get sellerHelpContinue;

  /// No description provided for @sellerHelpPhotoTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сделайте хорошее фото'**
  String get sellerHelpPhotoTitle;

  /// No description provided for @sellerHelpPhotoStepTitle.
  ///
  /// In ru, this message translates to:
  /// **'Шаг 1: Сделайте хорошее фото — советы и рекомендации'**
  String get sellerHelpPhotoStepTitle;

  /// No description provided for @sellerHelpPhotoHotIntro.
  ///
  /// In ru, this message translates to:
  /// **'Покупатели сначала оценивают товар глазами. Яркая и аккуратная фотография сделает ваш сюрприз-набор гораздо привлекательнее.'**
  String get sellerHelpPhotoHotIntro;

  /// No description provided for @sellerHelpPhotoDealsIntro.
  ///
  /// In ru, this message translates to:
  /// **'Покупатель в первую очередь замечает фотографию. Яркое и аккуратное фото делает товар более привлекательным и вызывает больше доверия.'**
  String get sellerHelpPhotoDealsIntro;

  /// No description provided for @sellerHelpPhotoCleanTitle.
  ///
  /// In ru, this message translates to:
  /// **'Более чистый фон — более профессиональное фото'**
  String get sellerHelpPhotoCleanTitle;

  /// No description provided for @sellerHelpPhotoCleanAccent.
  ///
  /// In ru, this message translates to:
  /// **'Быстрый способ сделать белый фон'**
  String get sellerHelpPhotoCleanAccent;

  /// No description provided for @sellerHelpPhotoCleanBody.
  ///
  /// In ru, this message translates to:
  /// **'Если фон на фото выглядит неаккуратно, загрузите снимок в бесплатный сервис вроде Remove.bg на телефоне или компьютере. Он автоматически удалит фон и за несколько секунд сделает изображение чище и профессиональнее. Также можно использовать бесплатную версию Canva, чтобы разместить фото по центру на белом квадратном фоне.'**
  String get sellerHelpPhotoCleanBody;

  /// No description provided for @sellerHelpPhotoBackgroundTitle.
  ///
  /// In ru, this message translates to:
  /// **'Фон'**
  String get sellerHelpPhotoBackgroundTitle;

  /// No description provided for @sellerHelpPhotoBackgroundHot.
  ///
  /// In ru, this message translates to:
  /// **'Положите упакованный пакет, коробку или контейнер на чистую нейтральную поверхность: белую столешницу, однотонный стол или простой белый лист. Чистый фон сразу повышает доверие к товару.'**
  String get sellerHelpPhotoBackgroundHot;

  /// No description provided for @sellerHelpPhotoBackgroundDeals.
  ///
  /// In ru, this message translates to:
  /// **'Положите товар или упаковку на чистую нейтральную поверхность: белую столешницу, однотонный стол или простой белый лист. Чистый фон сразу повышает доверие к товару.'**
  String get sellerHelpPhotoBackgroundDeals;

  /// No description provided for @sellerHelpPhotoLightingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Освещение'**
  String get sellerHelpPhotoLightingTitle;

  /// No description provided for @sellerHelpPhotoLightingHot.
  ///
  /// In ru, this message translates to:
  /// **'По возможности фотографируйте при естественном дневном свете. Избегайте тёмных теней и слишком жёлтого верхнего освещения, чтобы еда выглядела свежей и аппетитной.'**
  String get sellerHelpPhotoLightingHot;

  /// No description provided for @sellerHelpPhotoLightingDeals.
  ///
  /// In ru, this message translates to:
  /// **'По возможности фотографируйте при естественном дневном свете. Избегайте тёмных теней и слишком жёлтого верхнего освещения, чтобы товар выглядел естественно и чётко.'**
  String get sellerHelpPhotoLightingDeals;

  /// No description provided for @sellerHelpPhotoShowTitle.
  ///
  /// In ru, this message translates to:
  /// **'Что показать'**
  String get sellerHelpPhotoShowTitle;

  /// No description provided for @sellerHelpPhotoShowHot.
  ///
  /// In ru, this message translates to:
  /// **'Сфотографируйте закрытый пакет или коробку либо положите рядом несколько характерных товаров, чтобы покупатель примерно понимал, что его ждёт, например выпечка или свежий хлеб.'**
  String get sellerHelpPhotoShowHot;

  /// No description provided for @sellerHelpPhotoShowDeals.
  ///
  /// In ru, this message translates to:
  /// **'Сфотографируйте коробку, упаковку или несколько характерных товаров, чтобы покупатель сразу понял, что именно вы предлагаете.'**
  String get sellerHelpPhotoShowDeals;

  /// No description provided for @sellerHelpPhotoSizeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Размер и разрешение'**
  String get sellerHelpPhotoSizeTitle;

  /// No description provided for @sellerHelpPhotoSizeBody.
  ///
  /// In ru, this message translates to:
  /// **'Лучше использовать квадратное изображение 1:1 размером примерно 1080 × 1080 пикселей — оно будет выглядеть чётко и хорошо впишется в ленту приложения.'**
  String get sellerHelpPhotoSizeBody;

  /// No description provided for @sellerHelpListingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройте карточку товара'**
  String get sellerHelpListingTitle;

  /// No description provided for @sellerHelpListingIntro.
  ///
  /// In ru, this message translates to:
  /// **'Пишите просто, честно и интересно.'**
  String get sellerHelpListingIntro;

  /// No description provided for @sellerHelpNameHotAccent.
  ///
  /// In ru, this message translates to:
  /// **'Придумайте привлекательное название. Вместо простого «Пакет 1» лучше написать, например, «Свежий набор выпечки дня» или «Вечерний набор от шефа».'**
  String get sellerHelpNameHotAccent;

  /// No description provided for @sellerHelpNameHotBody1.
  ///
  /// In ru, this message translates to:
  /// **'Используйте короткое и понятное название и убедитесь, что описание соответствует тому, что покупатель, скорее всего, получит.'**
  String get sellerHelpNameHotBody1;

  /// No description provided for @sellerHelpNameHotBody2.
  ///
  /// In ru, this message translates to:
  /// **'Избегайте слишком общих названий. Чем понятнее и привлекательнее название, тем выше вероятность, что покупатель откроет карточку.'**
  String get sellerHelpNameHotBody2;

  /// No description provided for @sellerHelpNameDealsAccent.
  ///
  /// In ru, this message translates to:
  /// **'Придумайте понятное и привлекательное название, которое сразу объясняет покупателю, что именно входит в предложение.'**
  String get sellerHelpNameDealsAccent;

  /// No description provided for @sellerHelpNameDealsBody1.
  ///
  /// In ru, this message translates to:
  /// **'Используйте короткое и понятное название и убедитесь, что описание соответствует реальному товару.'**
  String get sellerHelpNameDealsBody1;

  /// No description provided for @sellerHelpNameDealsBody2.
  ///
  /// In ru, this message translates to:
  /// **'Для Deals лучше использовать названия вроде «Набор хозяйственных товаров» или «Набор напитков», а не внутренние или непонятные обозначения.'**
  String get sellerHelpNameDealsBody2;

  /// No description provided for @sellerHelpPickupIntro.
  ///
  /// In ru, this message translates to:
  /// **'Укажите окно получения: выберите удобный интервал примерно 30–60 минут ближе к закрытию, например 19:00–19:30, чтобы выдача заказов не мешала основной работе.'**
  String get sellerHelpPickupIntro;

  /// No description provided for @sellerHelpPickupBody1.
  ///
  /// In ru, this message translates to:
  /// **'Выбирайте реальное время, когда заказ уже будет собран и его можно будет быстро передать покупателю.'**
  String get sellerHelpPickupBody1;

  /// No description provided for @sellerHelpPickupBody2.
  ///
  /// In ru, this message translates to:
  /// **'Короткое и понятное окно получения помогает покупателям лучше планировать время и уменьшает путаницу при выдаче.'**
  String get sellerHelpPickupBody2;

  /// No description provided for @sellerHelpPriceTitle.
  ///
  /// In ru, this message translates to:
  /// **'Укажите стоимость и цену'**
  String get sellerHelpPriceTitle;

  /// No description provided for @sellerHelpPriceIntro.
  ///
  /// In ru, this message translates to:
  /// **'Покажите покупателю выгоду предложения. Например: «Обычная стоимость 4 000 AMD — у вас всего за 2 000 AMD».'**
  String get sellerHelpPriceIntro;

  /// No description provided for @sellerHelpPriceBody1.
  ///
  /// In ru, this message translates to:
  /// **'Сначала укажите полную обычную стоимость товара, затем процент скидки — так покупатель сразу поймёт, сколько он экономит.'**
  String get sellerHelpPriceBody1;

  /// No description provided for @sellerHelpPriceBody2.
  ///
  /// In ru, this message translates to:
  /// **'Скидка не обязательна, но она делает выгоду предложения понятнее и заметнее.'**
  String get sellerHelpPriceBody2;

  /// No description provided for @sellerHelpDeliveryTitle.
  ///
  /// In ru, this message translates to:
  /// **'Укажите срок доставки'**
  String get sellerHelpDeliveryTitle;

  /// No description provided for @sellerHelpDeliveryIntro.
  ///
  /// In ru, this message translates to:
  /// **'Выберите реальный срок доставки, чтобы покупатель заранее понимал, когда ждать заказ.'**
  String get sellerHelpDeliveryIntro;

  /// No description provided for @sellerHelpDeliveryBody1.
  ///
  /// In ru, this message translates to:
  /// **'Указывайте минимальный срок, который вы действительно сможете стабильно соблюдать.'**
  String get sellerHelpDeliveryBody1;

  /// No description provided for @sellerHelpDeliveryBody2.
  ///
  /// In ru, this message translates to:
  /// **'Если доставка занимает больше 14 дней, выберите «Свой срок» и укажите нужное количество дней.'**
  String get sellerHelpDeliveryBody2;

  /// No description provided for @alarmNotificationsActive.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления активны'**
  String get alarmNotificationsActive;

  /// No description provided for @alarmNoTags.
  ///
  /// In ru, this message translates to:
  /// **'Теги пока не добавлены'**
  String get alarmNoTags;

  /// No description provided for @alarmSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get alarmSave;

  /// No description provided for @alarmSet.
  ///
  /// In ru, this message translates to:
  /// **'Установить'**
  String get alarmSet;

  /// No description provided for @alarmDisable.
  ///
  /// In ru, this message translates to:
  /// **'Отключить уведомления'**
  String get alarmDisable;

  /// No description provided for @alarmAnyDistance.
  ///
  /// In ru, this message translates to:
  /// **'Любое'**
  String get alarmAnyDistance;

  /// No description provided for @alarmNotificationRadius.
  ///
  /// In ru, this message translates to:
  /// **'Радиус уведомлений'**
  String get alarmNotificationRadius;

  /// No description provided for @alarmRadiusHint.
  ///
  /// In ru, this message translates to:
  /// **'Будем искать предложения рядом с выбранной точкой'**
  String get alarmRadiusHint;

  /// No description provided for @alarmAnyDistanceLong.
  ///
  /// In ru, this message translates to:
  /// **'Любое расстояние'**
  String get alarmAnyDistanceLong;

  /// No description provided for @alarmLoginTitle.
  ///
  /// In ru, this message translates to:
  /// **'Нужно войти'**
  String get alarmLoginTitle;

  /// No description provided for @alarmLoginBody.
  ///
  /// In ru, this message translates to:
  /// **'Сперва нужно войти под аккаунтом, чтобы сохранить уведомления.'**
  String get alarmLoginBody;

  /// No description provided for @alarmUnderstood.
  ///
  /// In ru, this message translates to:
  /// **'Понятно'**
  String get alarmUnderstood;

  /// No description provided for @alarmMinFiveMinutes.
  ///
  /// In ru, this message translates to:
  /// **'Выберите время минимум на 5 минут позже текущего'**
  String get alarmMinFiveMinutes;

  /// No description provided for @alarmChooseType.
  ///
  /// In ru, this message translates to:
  /// **'Выберите: Горячее или Акции'**
  String get alarmChooseType;

  /// No description provided for @alarmUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления обновлены'**
  String get alarmUpdated;

  /// No description provided for @alarmSaved.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления сохранены'**
  String get alarmSaved;

  /// No description provided for @alarmSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить уведомления'**
  String get alarmSaveFailed;

  /// No description provided for @alarmDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления отключены'**
  String get alarmDisabled;

  /// No description provided for @alarmDisableFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отключить уведомления'**
  String get alarmDisableFailed;

  /// No description provided for @alarmEndAfterStart.
  ///
  /// In ru, this message translates to:
  /// **'Время «До» должно быть позже времени «С»'**
  String get alarmEndAfterStart;

  /// No description provided for @alarmSelectArea.
  ///
  /// In ru, this message translates to:
  /// **'Выберите область'**
  String get alarmSelectArea;

  /// No description provided for @alarmChooseArea.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать область'**
  String get alarmChooseArea;

  /// No description provided for @alarmFrom.
  ///
  /// In ru, this message translates to:
  /// **'С'**
  String get alarmFrom;

  /// No description provided for @alarmTo.
  ///
  /// In ru, this message translates to:
  /// **'До'**
  String get alarmTo;

  /// No description provided for @reviewEditSupportApproved.
  ///
  /// In ru, this message translates to:
  /// **'Поддержка разрешила редактирование'**
  String get reviewEditSupportApproved;

  /// No description provided for @reviewEditRejectedCanRetry.
  ///
  /// In ru, this message translates to:
  /// **'Запрос отклонён. Можно отправить новый запрос.'**
  String get reviewEditRejectedCanRetry;

  /// No description provided for @reviewEditPendingSupport.
  ///
  /// In ru, this message translates to:
  /// **'Запрос ещё ожидает решения поддержки.'**
  String get reviewEditPendingSupport;

  /// No description provided for @reviewEditStatusCheckFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось проверить статус запроса'**
  String get reviewEditStatusCheckFailed;

  /// No description provided for @reviewEditRequestTitle.
  ///
  /// In ru, this message translates to:
  /// **'Запросить редактирование?'**
  String get reviewEditRequestTitle;

  /// No description provided for @reviewEditRequestRejectedPrompt.
  ///
  /// In ru, this message translates to:
  /// **'Предыдущий запрос был отклонён. Отправить новый запрос в поддержку на редактирование этого отзыва?'**
  String get reviewEditRequestRejectedPrompt;

  /// No description provided for @reviewEditRequestPrompt.
  ///
  /// In ru, this message translates to:
  /// **'Опубликованный отзыв можно изменить только после разрешения поддержки. Отправить запрос на редактирование?'**
  String get reviewEditRequestPrompt;

  /// No description provided for @reviewEditRequestSend.
  ///
  /// In ru, this message translates to:
  /// **'Отправить запрос'**
  String get reviewEditRequestSend;

  /// No description provided for @reviewEditAllowed.
  ///
  /// In ru, this message translates to:
  /// **'Редактирование разрешено'**
  String get reviewEditAllowed;

  /// No description provided for @reviewEditRequestSent.
  ///
  /// In ru, this message translates to:
  /// **'Запрос отправлен. После одобрения поддержки обновите список отзывов.'**
  String get reviewEditRequestSent;

  /// No description provided for @reviewEditSavedNeedsNewRequest.
  ///
  /// In ru, this message translates to:
  /// **'Отзыв обновлён. Для следующего редактирования понадобится новый запрос.'**
  String get reviewEditSavedNeedsNewRequest;

  /// No description provided for @reviewWaitAfterDelivery.
  ///
  /// In ru, this message translates to:
  /// **'После доставки'**
  String get reviewWaitAfterDelivery;

  /// No description provided for @reviewWaitAfterPickup.
  ///
  /// In ru, this message translates to:
  /// **'После самовывоза'**
  String get reviewWaitAfterPickup;

  /// No description provided for @reviewWaitSoon.
  ///
  /// In ru, this message translates to:
  /// **'Скоро'**
  String get reviewWaitSoon;

  /// No description provided for @reviewWaitUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Пока недоступно'**
  String get reviewWaitUnavailable;

  /// No description provided for @reviewEditTitle.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать отзыв'**
  String get reviewEditTitle;

  /// No description provided for @reviewEditOneTimeApproved.
  ///
  /// In ru, this message translates to:
  /// **'Поддержка разрешила одно редактирование. После сохранения разрешение будет использовано.'**
  String get reviewEditOneTimeApproved;

  /// No description provided for @reviewEditStatusPending.
  ///
  /// In ru, this message translates to:
  /// **'Запрос на редактирование ожидает решения'**
  String get reviewEditStatusPending;

  /// No description provided for @reviewEditStatusApproved.
  ///
  /// In ru, this message translates to:
  /// **'Редактирование разрешено'**
  String get reviewEditStatusApproved;

  /// No description provided for @reviewEditStatusRejected.
  ///
  /// In ru, this message translates to:
  /// **'Запрос отклонён — можно отправить новый'**
  String get reviewEditStatusRejected;

  /// No description provided for @reviewEditStatusUsed.
  ///
  /// In ru, this message translates to:
  /// **'Разрешение использовано — нужен новый запрос'**
  String get reviewEditStatusUsed;

  /// No description provided for @reviewEditTooltipEdit.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать отзыв'**
  String get reviewEditTooltipEdit;

  /// No description provided for @reviewEditTooltipPending.
  ///
  /// In ru, this message translates to:
  /// **'Запрос ожидает решения'**
  String get reviewEditTooltipPending;

  /// No description provided for @reviewEditTooltipRequest.
  ///
  /// In ru, this message translates to:
  /// **'Запросить редактирование'**
  String get reviewEditTooltipRequest;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hy', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hy':
      return AppLocalizationsHy();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
