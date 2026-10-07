import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';

import 'screens/startup_gate.dart';
import 'services/api_service.dart';

import 'providers/auth_provider.dart';
import 'providers/favorite_provider.dart';
import 'providers/company_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/location_provider.dart';
import 'providers/products_refresh_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

bool _firebaseMessagingListenersReady = false;

Future<void> _setupFirebaseMessaging({
  bool requestPermission = false,
}) async {
  if (kIsWeb) return;

  try {
    final messaging = FirebaseMessaging.instance;

    if (!_firebaseMessagingListenersReady) {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      messaging.onTokenRefresh.listen((token) async {
        try {
          await ApiService.registerDeviceToken(
            token: token,
            deviceType: 'android',
          );
        } catch (e) {
          debugPrint('FCM REFRESH TOKEN ERROR: $e');
        }
      });

      FirebaseMessaging.onMessage.listen((message) {
        ApiService.notificationsVersion.value++;
      });

      _firebaseMessagingListenersReady = true;
    }

    final settings = requestPermission
        ? await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    )
        : await messaging.getNotificationSettings();

    final canUseNotifications =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!canUseNotifications) {
      debugPrint('FCM PERMISSION NOT GRANTED');
      return;
    }

    final token = await messaging
        .getToken()
        .timeout(const Duration(seconds: 8));

    debugPrint('FCM TOKEN EXISTS: ${token != null && token.isNotEmpty}');

    if (token != null && token.isNotEmpty) {
      try {
        await ApiService.registerDeviceToken(
          token: token,
          deviceType: 'android',
        );
      } catch (e) {
        debugPrint('FCM REGISTER TOKEN ERROR: $e');
      }
    }

    debugPrint('FCM READY');
  } catch (e) {
    debugPrint('FCM SETUP ERROR: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await ApiService.loadTokens();
  await ApiService.init();

  if (!kIsWeb) {
    try {
      await FMTCObjectBoxBackend().initialise();
      await const FMTCStore('mapStore').manage.create();
    } catch (e) {
      debugPrint('MAP CACHE INIT ERROR: $e');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => FavoriteProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => CompanyProvider()..loadCompanies(),
        ),
        ChangeNotifierProvider(
          create: (_) => CartProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => LocationProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => NavigationProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ProductsRefreshProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => LocaleProvider()..loadLocale(),
        ),
      ],
      child: const MyApp(),
    ),
  );

  // Firebase Messaging Р·Р°РїСѓСЃРєР°РµС‚СЃСЏ РїРѕСЃР»Рµ РѕС‚РєСЂС‹С‚РёСЏ РїСЂРёР»РѕР¶РµРЅРёСЏ
  if (!kIsWeb) {
    Future.microtask(() async {
      await _setupFirebaseMessaging(requestPermission: false);
    });
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();

    return MaterialApp(
      locale: localeProvider.locale,
      supportedLocales: const [
        Locale('ru'),
        Locale('hy'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      title: 'Shop App',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.robotoTextTheme(),
        primaryTextTheme: GoogleFonts.robotoTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF3F3F3),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD1BC00),
          brightness: Brightness.light,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF2B2B2B),
          indicatorColor: const Color(0xFFD1BC00),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: states.contains(WidgetState.selected)
                  ? Colors.white
                  : Colors.grey.shade400,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            return IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? Colors.white
                  : Colors.grey.shade400,
              size: 24,
            );
          }),
        ),
      ),
      home: const _FirstLaunchPermissionsGate(child: StartupGate()),
    );
  }
}

class _FirstLaunchPermissionsGate extends StatefulWidget {
  final Widget child;

  const _FirstLaunchPermissionsGate({
    required this.child,
  });

  @override
  State<_FirstLaunchPermissionsGate> createState() =>
      _FirstLaunchPermissionsGateState();
}

class _FirstLaunchPermissionsGateState
    extends State<_FirstLaunchPermissionsGate> {
  static const String _prefsKey = 'initial_permissions_intro_seen_v1';
  static const Color _accentColor = Color(0xFFD1BC00);

  bool _checking = true;
  bool _showApp = false;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    if (kIsWeb) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _showApp = true;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_prefsKey) ?? false;

    if (!mounted) return;

    if (seen) {
      setState(() {
        _checking = false;
        _showApp = true;
      });

      // Never block the UI while refreshing an already granted location.
      Future.microtask(
            () => context.read<LocationProvider>().refreshIfAllowed(),
      );
      return;
    }

    setState(() {
      _checking = false;
      _showApp = false;
    });
  }

  Future<void> _finish({
    required bool requestPermissions,
  }) async {
    if (_requesting) return;

    setState(() => _requesting = true);

    try {
      if (requestPermissions) {
        // Ask one permission at a time. Location first, then notifications.
        await context
            .read<LocationProvider>()
            .requestPermissionAndLoad();

        await _setupFirebaseMessaging(requestPermission: true);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, true);
    } finally {
      if (!mounted) return;
      setState(() {
        _requesting = false;
        _showApp = true;
      });
    }
  }

  String _t({
    required String en,
    required String ru,
    required String hy,
  }) {
    final code = Localizations.localeOf(context).languageCode;

    return switch (code) {
      'ru' => ru,
      'hy' => hy,
      _ => en,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: _accentColor),
        ),
      );
    }

    if (_showApp) return widget.child;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: _accentColor.withValues(alpha: 0.13),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        size: 48,
                        color: _accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    _t(
                      en: 'Apsosa works better with permissions',
                      ru: 'Apsosa работает лучше с разрешениями',
                      hy: 'Apsosa-ն ավելի լավ է աշխատում թույլտվություններով',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF252525),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t(
                      en: 'Before you continue, you can allow the permissions used for nearby offers and notifications.',
                      ru: 'Перед продолжением можно разрешить доступы, которые нужны для предложений рядом и уведомлений.',
                      hy: 'Շարունակելուց առաջ կարող եք թույլատրել մոտակա առաջարկների և ծանուցումների համար անհրաժեշտ հասանելիությունները։',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _PermissionInfoRow(
                    icon: Icons.near_me_rounded,
                    title: _t(
                      en: 'Location',
                      ru: 'Геолокация',
                      hy: 'Տեղադրություն',
                    ),
                    subtitle: _t(
                      en: 'Shows nearby shops, distance and map results.',
                      ru: 'Показывает магазины рядом, расстояние и результаты на карте.',
                      hy: 'Ցույց է տալիս մոտակա խանութները, հեռավորությունը և քարտեզի արդյունքները։',
                    ),
                  ),
                  const SizedBox(height: 14),
                  _PermissionInfoRow(
                    icon: Icons.notifications_none_rounded,
                    title: _t(
                      en: 'Notifications',
                      ru: 'Уведомления',
                      hy: 'Ծանուցումներ',
                    ),
                    subtitle: _t(
                      en: 'Used for orders, pickup reminders and new offers.',
                      ru: 'Нужны для заказов, напоминаний о получении и новых предложений.',
                      hy: 'Պետք են պատվերների, ստացման հիշեցումների և նոր առաջարկների համար։',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t(
                      en: 'Camera access will only be requested later when you choose to add a photo.',
                      ru: 'Доступ к камере будет запрошен позже только при добавлении фотографии.',
                      hy: 'Տեսախցիկի հասանելիությունը կպահանջվի ավելի ուշ՝ միայն լուսանկար ավելացնելիս։',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Color(0xFF888888),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _requesting
                          ? null
                          : () => _finish(requestPermissions: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _requesting
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                          : Text(
                        _t(
                          en: 'Continue',
                          ru: 'Продолжить',
                          hy: 'Շարունակել',
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _requesting
                        ? null
                        : () => _finish(requestPermissions: false),
                    child: Text(
                      _t(
                        en: 'Not now',
                        ru: 'Не сейчас',
                        hy: 'Ոչ հիմա',
                      ),
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PermissionInfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFD1BC00).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFD1BC00),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2A2A2A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Color(0xFF707070),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

