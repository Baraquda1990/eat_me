import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/pin_service.dart';
import '../widgets/pin_keypad.dart';

class PinLockGate extends StatefulWidget {
  final String username;
  final Widget child;

  const PinLockGate({
    super.key,
    required this.username,
    required this.child,
  });

  @override
  State<PinLockGate> createState() => _PinLockGateState();
}

class _PinLockGateState extends State<PinLockGate>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _locked = false;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_check);
  }

  @override
  void didUpdateWidget(covariant PinLockGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.username != widget.username) {
      _check();
    }
  }

  Future<void> _check() async {
    final enabled = await PinService.hasPinFor(widget.username);
    if (!mounted) return;

    setState(() {
      _loading = false;
      _locked = enabled;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final leftAt = _backgroundedAt;
      _backgroundedAt = null;

      if (leftAt == null) return;
      final away = DateTime.now().difference(leftAt);

      if (away >= const Duration(seconds: 30)) {
        Future.microtask(() async {
          final enabled = await PinService.hasPinFor(widget.username);
          if (!mounted || !enabled) return;
          setState(() => _locked = true);
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFD1BC00),
          ),
        ),
      );
    }

    if (!_locked) return widget.child;

    return PinUnlockScreen(
      username: widget.username,
      onUnlocked: () {
        if (mounted) setState(() => _locked = false);
      },
    );
  }
}

class PinUnlockScreen extends StatefulWidget {
  final String username;
  final VoidCallback onUnlocked;

  const PinUnlockScreen({
    super.key,
    required this.username,
    required this.onUnlocked,
  });

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  static const Color accentColor = Color(0xFFD1BC00);

  String _entered = '';
  String? _errorText;
  bool _checking = false;
  int _failedAttempts = 0;
  int _lockSeconds = 0;
  Timer? _timer;

  String _t({
    required String ru,
    required String en,
    required String hy,
  }) {
    return switch (Localizations.localeOf(context).languageCode) {
      'ru' => ru,
      'hy' => hy,
      _ => en,
    };
  }

  bool get _blocked => _lockSeconds > 0;

  void _digit(String value) {
    if (_checking || _blocked || _entered.length >= 4) return;

    final next = '$_entered$value';
    setState(() {
      _entered = next;
      _errorText = null;
    });

    if (next.length == 4) {
      Future<void>.delayed(
        const Duration(milliseconds: 100),
            () => _verify(next),
      );
    }
  }

  void _backspace() {
    if (_checking || _blocked || _entered.isEmpty) return;
    setState(() {
      _entered = _entered.substring(0, _entered.length - 1);
      _errorText = null;
    });
  }

  Future<void> _verify(String pin) async {
    if (_checking || _blocked) return;

    setState(() => _checking = true);

    final valid = await PinService.verifyPin(
      owner: widget.username,
      pin: pin,
    );

    if (!mounted) return;

    if (valid) {
      setState(() {
        _checking = false;
        _entered = '';
        _failedAttempts = 0;
      });
      widget.onUnlocked();
      return;
    }

    final attempts = _failedAttempts + 1;

    if (attempts >= 5) {
      _startTemporaryLock();
      return;
    }

    setState(() {
      _checking = false;
      _entered = '';
      _failedAttempts = attempts;
      _errorText = _t(
        ru: 'Неверный PIN. Осталось попыток: ${5 - attempts}',
        en: 'Incorrect PIN. Attempts left: ${5 - attempts}',
        hy: 'Սխալ PIN։ Մնացել է ${5 - attempts} փորձ։',
      );
    });
  }

  void _startTemporaryLock() {
    _timer?.cancel();

    setState(() {
      _checking = false;
      _entered = '';
      _failedAttempts = 0;
      _lockSeconds = 30;
      _errorText = null;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_lockSeconds <= 1) {
        timer.cancel();
        setState(() => _lockSeconds = 0);
      } else {
        setState(() => _lockSeconds -= 1);
      }
    });
  }

  Future<void> _logoutAndResetPin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            _t(
              ru: 'Войти обычным способом?',
              en: 'Use normal sign-in?',
              hy: 'Մուտք գործե՞լ սովորական եղանակով',
            ),
          ),
          content: Text(
            _t(
              ru: 'Локальный PIN будет удалён. Для следующего входа понадобится логин/пароль или Google.',
              en: 'The local PIN will be removed. You will need your username/password or Google to sign in again.',
              hy: 'Տեղային PIN-ը կջնջվի։ Հաջորդ մուտքի համար անհրաժեշտ կլինի մուտքանուն/գաղտնաբառ կամ Google։',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                _t(
                  ru: 'Отмена',
                  en: 'Cancel',
                  hy: 'Չեղարկել',
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                _t(
                  ru: 'Продолжить',
                  en: 'Continue',
                  hy: 'Շարունակել',
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await PinService.clear();
    if (!mounted) return;

    await context.read<AuthProvider>().logout();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  SizedBox(
                    width: 132,
                    height: 132,
                    child: Image.asset(
                      'assets/icons/app_icon_foreground.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.lock_rounded,
                        size: 58,
                        color: Color(0xFF7A6C00),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _t(
                      ru: 'Введите PIN-код',
                      en: 'Enter your PIN',
                      hy: 'Մուտքագրեք PIN կոդը',
                    ),
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t(
                      ru: 'Быстрый вход в Appsosa',
                      en: 'Quick access to Appsosa',
                      hy: 'Արագ մուտք Appsosa',
                    ),
                    style: const TextStyle(
                      color: Color(0xFF777777),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 28),
                  PinDots(
                    filled: _entered.length,
                    error: _errorText != null,
                  ),
                  if (_blocked) ...[
                    const SizedBox(height: 16),
                    Text(
                      _t(
                        ru: 'Слишком много попыток. Повторите через $_lockSeconds сек.',
                        en: 'Too many attempts. Try again in $_lockSeconds sec.',
                        hy: 'Չափազանց շատ փորձեր։ Կրկին փորձեք $_lockSeconds վրկ. հետո։',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ] else if (_errorText != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorText!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  PinKeypad(
                    enabled: !_checking && !_blocked,
                    onDigit: _digit,
                    onBackspace: _backspace,
                  ),
                  if (_checking) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(
                      color: accentColor,
                      strokeWidth: 2.5,
                    ),
                  ],
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: _checking ? null : _logoutAndResetPin,
                    child: Text(
                      _t(
                        ru: 'Забыли PIN? Войти обычным способом',
                        en: 'Forgot PIN? Use normal sign-in',
                        hy: 'Մոռացե՞լ եք PIN-ը։ Մուտք գործել սովորական եղանակով',
                      ),
                      textAlign: TextAlign.center,
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
