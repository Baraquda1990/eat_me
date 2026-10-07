import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/pin_service.dart';
import '../widgets/pin_keypad.dart';

enum _PinSettingsMode {
  status,
  create,
  confirm,
  verifyForChange,
  verifyForDisable,
}

class PinSettingsScreen extends StatefulWidget {
  const PinSettingsScreen({super.key});

  @override
  State<PinSettingsScreen> createState() => _PinSettingsScreenState();
}

class _PinSettingsScreenState extends State<PinSettingsScreen> {
  static const Color accentColor = Color(0xFFD1BC00);

  bool _loading = true;
  bool _enabled = false;
  bool _busy = false;

  _PinSettingsMode _mode = _PinSettingsMode.status;

  String _entered = '';
  String _firstPin = '';
  String? _message;
  bool _error = false;

  String get _owner =>
      (context.read<AuthProvider>().username ?? '').trim();

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final enabled = await PinService.hasPinFor(_owner);
    if (!mounted) return;

    setState(() {
      _loading = false;
      _enabled = enabled;
      _mode = enabled ? _PinSettingsMode.status : _PinSettingsMode.create;
    });
  }

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

  String get _title {
    return switch (_mode) {
      _PinSettingsMode.create => _t(
        ru: 'Создайте PIN-код',
        en: 'Create a PIN',
        hy: 'Ստեղծեք PIN կոդ',
      ),
      _PinSettingsMode.confirm => _t(
        ru: 'Повторите PIN-код',
        en: 'Confirm your PIN',
        hy: 'Կրկնեք PIN կոդը',
      ),
      _PinSettingsMode.verifyForChange => _t(
        ru: 'Введите текущий PIN',
        en: 'Enter your current PIN',
        hy: 'Մուտքագրեք ընթացիկ PIN-ը',
      ),
      _PinSettingsMode.verifyForDisable => _t(
        ru: 'Подтвердите текущий PIN',
        en: 'Confirm your current PIN',
        hy: 'Հաստատեք ընթացիկ PIN-ը',
      ),
      _ => _t(
        ru: 'PIN-код',
        en: 'PIN',
        hy: 'PIN կոդ',
      ),
    };
  }

  String get _subtitle {
    return switch (_mode) {
      _PinSettingsMode.create => _t(
        ru: 'Введите 4 цифры. Этот код будет использоваться для быстрого входа на этом устройстве.',
        en: 'Enter 4 digits. This code will be used for quick access on this device.',
        hy: 'Մուտքագրեք 4 թիվ։ Այս կոդը կօգտագործվի այս սարքում արագ մուտքի համար։',
      ),
      _PinSettingsMode.confirm => _t(
        ru: 'Введите те же 4 цифры ещё раз.',
        en: 'Enter the same 4 digits again.',
        hy: 'Կրկին մուտքագրեք նույն 4 թվերը։',
      ),
      _ => _t(
        ru: 'PIN защищает уже авторизованное приложение на этом устройстве.',
        en: 'The PIN protects an already signed-in app on this device.',
        hy: 'PIN-ը պաշտպանում է այս սարքում արդեն մուտք գործած հավելվածը։',
      ),
    };
  }

  void _resetEntry({String? message, bool error = false}) {
    setState(() {
      _entered = '';
      _message = message;
      _error = error;
    });
  }

  void _digit(String value) {
    if (_busy || _entered.length >= 4) return;

    final next = '$_entered$value';
    setState(() {
      _entered = next;
      _message = null;
      _error = false;
    });

    if (next.length == 4) {
      Future<void>.delayed(
        const Duration(milliseconds: 100),
            () => _submitPin(next),
      );
    }
  }

  void _backspace() {
    if (_busy || _entered.isEmpty) return;
    setState(() {
      _entered = _entered.substring(0, _entered.length - 1);
      _message = null;
      _error = false;
    });
  }

  Future<void> _submitPin(String pin) async {
    if (_busy) return;

    switch (_mode) {
      case _PinSettingsMode.create:
        setState(() {
          _firstPin = pin;
          _entered = '';
          _message = null;
          _error = false;
          _mode = _PinSettingsMode.confirm;
        });
        return;

      case _PinSettingsMode.confirm:
        if (pin != _firstPin) {
          setState(() {
            _firstPin = '';
            _entered = '';
            _mode = _PinSettingsMode.create;
            _error = true;
            _message = _t(
              ru: 'PIN-коды не совпадают. Попробуйте ещё раз.',
              en: 'PINs do not match. Please try again.',
              hy: 'PIN կոդերը չեն համընկնում։ Փորձեք կրկին։',
            );
          });
          return;
        }

        setState(() => _busy = true);
        try {
          await PinService.savePin(owner: _owner, pin: pin);
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _t(
                  ru: 'PIN-код создан.',
                  en: 'PIN created.',
                  hy: 'PIN կոդը ստեղծված է։',
                ),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop(true);
        } finally {
          if (mounted) setState(() => _busy = false);
        }
        return;

      case _PinSettingsMode.verifyForChange:
        setState(() => _busy = true);
        final valid = await PinService.verifyPin(owner: _owner, pin: pin);
        if (!mounted) return;
        setState(() => _busy = false);

        if (!valid) {
          _resetEntry(
            message: _t(
              ru: 'Неверный PIN-код.',
              en: 'Incorrect PIN.',
              hy: 'Սխալ PIN կոդ։',
            ),
            error: true,
          );
          return;
        }

        setState(() {
          _entered = '';
          _firstPin = '';
          _mode = _PinSettingsMode.create;
          _message = _t(
            ru: 'Теперь задайте новый PIN-код.',
            en: 'Now create a new PIN.',
            hy: 'Այժմ ստեղծեք նոր PIN կոդ։',
          );
          _error = false;
        });
        return;

      case _PinSettingsMode.verifyForDisable:
        setState(() => _busy = true);
        final valid = await PinService.verifyPin(owner: _owner, pin: pin);
        if (!mounted) return;

        if (!valid) {
          setState(() => _busy = false);
          _resetEntry(
            message: _t(
              ru: 'Неверный PIN-код.',
              en: 'Incorrect PIN.',
              hy: 'Սխալ PIN կոդ։',
            ),
            error: true,
          );
          return;
        }

        await PinService.clear();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                ru: 'PIN-код отключён.',
                en: 'PIN disabled.',
                hy: 'PIN կոդն անջատված է։',
              ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
        return;

      case _PinSettingsMode.status:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _t(
            ru: 'PIN-код',
            en: 'PIN',
            hy: 'PIN կոդ',
          ),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(color: accentColor),
      )
          : SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _mode == _PinSettingsMode.status
                  ? _buildStatus()
                  : _buildPinEntry(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatus() {
    return Column(
      children: [
        SizedBox(
          width: 128,
          height: 128,
          child: Image.asset(
            'assets/icons/app_icon_foreground.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.lock_rounded,
              size: 56,
              color: Color(0xFF7A6C00),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _t(
            ru: 'PIN-код включён',
            en: 'PIN is enabled',
            hy: 'PIN կոդը միացված է',
          ),
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _t(
            ru: 'При следующем запуске приложения можно будет открыть аккаунт с помощью 4-значного PIN-кода.',
            en: 'The next time you launch the app, you can unlock your account with your 4-digit PIN.',
            hy: 'Հավելվածի հաջորդ գործարկման ժամանակ հաշիվը կարող եք բացել 4-նիշ PIN կոդով։',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF666666),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _entered = '';
                _message = null;
                _error = false;
                _mode = _PinSettingsMode.verifyForChange;
              });
            },
            icon: const Icon(Icons.edit_outlined),
            label: Text(
              _t(
                ru: 'Изменить PIN-код',
                en: 'Change PIN',
                hy: 'Փոխել PIN կոդը',
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _entered = '';
                _message = null;
                _error = false;
                _mode = _PinSettingsMode.verifyForDisable;
              });
            },
            icon: const Icon(Icons.lock_open_rounded),
            label: Text(
              _t(
                ru: 'Отключить PIN-код',
                en: 'Disable PIN',
                hy: 'Անջատել PIN կոդը',
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPinEntry() {
    return Column(
      children: [
        SizedBox(
          width: 118,
          height: 118,
          child: Image.asset(
            'assets/icons/app_icon_foreground.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.pin_rounded,
              size: 52,
              color: Color(0xFF7A6C00),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          _subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF666666),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 25),
        PinDots(
          filled: _entered.length,
          error: _error,
        ),
        if (_message != null) ...[
          const SizedBox(height: 14),
          Text(
            _message!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _error ? Colors.red : const Color(0xFF666666),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 28),
        PinKeypad(
          enabled: !_busy,
          onDigit: _digit,
          onBackspace: _backspace,
        ),
        if (_busy) ...[
          const SizedBox(height: 18),
          const CircularProgressIndicator(
            color: accentColor,
            strokeWidth: 2.5,
          ),
        ],
      ],
    );
  }
}
