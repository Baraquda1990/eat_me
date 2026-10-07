// lib/screens/support_screen.dart

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../utils/armenian_phone.dart';

class SupportScreen extends StatefulWidget {
  final String? initialEmail;
  final String? initialPhone;

  const SupportScreen({
    super.key,
    this.initialEmail,
    this.initialPhone,
  });

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const Color accentColor = Color(0xFFD1BC00);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();

  bool _sending = false;

  @override
  void initState() {
    super.initState();

    _emailController.text = widget.initialEmail?.trim() ?? '';
    _phoneController.text =
        ArmenianPhone.formatLocal(widget.initialPhone);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillKnownContact();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String _tr({
    required String ru,
    required String en,
    required String hy,
  }) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'hy':
        return hy;
      case 'en':
        return en;
      default:
        return ru;
    }
  }

  static String _phoneDigits(dynamic value) {
    return ArmenianPhone.localDigits(value);
  }

  Future<void> _prefillKnownContact() async {
    try {
      final loggedIn = await ApiService.isLoggedIn();
      if (!loggedIn) return;

      final user = await ApiService.getCurrentUser();
      Map<String, dynamic>? profile;
      try {
        profile = await ApiService.getProfile();
      } catch (_) {
        profile = null;
      }

      if (!mounted) return;

      if (_emailController.text.trim().isEmpty && user.email.trim().isNotEmpty) {
        _emailController.text = user.email.trim();
      }

      if (_phoneController.text.trim().isEmpty && profile != null) {
        final digits = _phoneDigits(profile['phone']);
        if (digits.isNotEmpty) {
          _phoneController.text = ArmenianPhone.formatLocal(digits);
        }
      }
    } catch (_) {
      // Support must remain usable even if profile prefill fails.
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _sending = true);

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiService.apiUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: const {'Content-Type': 'application/json'},
        ),
      );

      final phoneValue = _phoneController.text.trim();

      await dio.post(
        '/feedback/',
        data: {
          'email': _emailController.text.trim(),
          'phone':
          phoneValue.isEmpty ? '' : ArmenianPhone.normalize(phoneValue),
          'text': _messageController.text.trim(),
        },
      );

      if (!mounted) return;

      _messageController.clear();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                ru: 'Запрос отправлен в службу поддержки',
                en: 'Your request has been sent to support',
                hy: 'Հարցումը ուղարկվել է աջակցության ծառայությանը',
              ),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } on DioException catch (e) {
      if (!mounted) return;

      final serverDetail = e.response?.data is Map
          ? (e.response?.data['detail']?.toString() ?? '')
          : '';

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              serverDetail.isNotEmpty
                  ? serverDetail
                  : _tr(
                ru: 'Не удалось отправить запрос. Проверьте интернет и попробуйте снова.',
                en: 'Could not send the request. Check your connection and try again.',
                hy: 'Չհաջողվեց ուղարկել հարցումը։ Ստուգեք ինտերնետ կապը և փորձեք կրկին։',
              ),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                ru: 'Не удалось отправить запрос. Попробуйте снова.',
                en: 'Could not send the request. Please try again.',
                hy: 'Չհաջողվեց ուղարկել հարցումը։ Փորձեք կրկին։',
              ),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _tr(
            ru: 'Поддержка',
            en: 'Support',
            hy: 'Աջակցություն',
          ),
          style: const TextStyle(
            color: Color(0xFF333333),
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/auth_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.13),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: accentColor,
                        size: 46,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _tr(
                      ru: 'Чем мы можем помочь?',
                      en: 'How can we help?',
                      hy: 'Ինչպե՞ս կարող ենք օգնել։',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2A2A2A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tr(
                      ru: 'Опишите вопрос. Мы получим ваше сообщение и свяжемся с вами.',
                      en: 'Describe your issue. We will receive your message and contact you.',
                      hy: 'Նկարագրեք խնդիրը։ Մենք կստանանք ձեր հաղորդագրությունը և կապ կհաստատենք ձեզ հետ։',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: _decoration(
                      label: 'Email',
                      icon: Icons.email_outlined,
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) {
                        return _tr(
                          ru: 'Введите email',
                          en: 'Enter your email',
                          hy: 'Մուտքագրեք էլ. փոստը',
                        );
                      }
                      final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
                      if (!valid) {
                        return _tr(
                          ru: 'Введите корректный email',
                          en: 'Enter a valid email',
                          hy: 'Մուտքագրեք ճիշտ էլ. փոստ',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: const [
                      ArmenianPhoneInputFormatter(),
                    ],
                    decoration: _decoration(
                      label: _tr(
                        ru: 'Телефон (необязательно)',
                        en: 'Phone (optional)',
                        hy: 'Հեռախոս (ըստ ցանկության)',
                      ),
                      icon: Icons.phone_outlined,
                    ).copyWith(
                      prefixText: '+374 ',
                      prefixStyle: const TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      hintText: 'XX-XX-XX-XX',
                    ),
                    validator: (value) {
                      final phone = value?.trim() ?? '';
                      if (phone.isNotEmpty &&
                          !ArmenianPhone.isValid(phone)) {
                        return _tr(
                          ru: 'Введите 8 цифр: +374 XX-XX-XX-XX',
                          en: 'Enter 8 digits: +374 XX-XX-XX-XX',
                          hy: 'Մուտքագրեք 8 թվանշան՝ +374 XX-XX-XX-XX',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _messageController,
                    minLines: 6,
                    maxLines: 10,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _decoration(
                      label: _tr(
                        ru: 'Сообщение',
                        en: 'Message',
                        hy: 'Հաղորդագրություն',
                      ),
                      icon: Icons.chat_bubble_outline_rounded,
                    ).copyWith(
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return _tr(
                          ru: 'Опишите ваш вопрос',
                          en: 'Describe your issue',
                          hy: 'Նկարագրեք ձեր հարցը',
                        );
                      }
                      if (text.length < 5) {
                        return _tr(
                          ru: 'Сообщение слишком короткое',
                          en: 'The message is too short',
                          hy: 'Հաղորդագրությունը չափազանց կարճ է',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _sending ? null : _send,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: _sending
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _tr(
                          ru: 'Отправить в поддержку',
                          en: 'Send to support',
                          hy: 'Ուղարկել աջակցությանը',
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
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

  InputDecoration _decoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF666666)),
      prefixIcon: Icon(icon, color: accentColor),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: accentColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      fillColor: Colors.white,
      filled: true,
    );
  }
}

class SupportShortcutButton extends StatelessWidget {
  static const Color accentColor = Color(0xFFD1BC00);

  final String? initialEmail;
  final String? initialPhone;
  final double size;

  const SupportShortcutButton({
    super.key,
    this.initialEmail,
    this.initialPhone,
    this.size = 44,
  });

  String _label(BuildContext context) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'hy':
        return 'Աջակցություն';
      case 'en':
        return 'Support';
      default:
        return 'Поддержка';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _label(context),
      child: Material(
        color: Colors.white.withValues(alpha: 0.96),
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: Colors.black12,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SupportScreen(
                  initialEmail: initialEmail,
                  initialPhone: initialPhone,
                ),
              ),
            );
          },
          child: SizedBox(
            width: size,
            height: size,
            child: const Icon(
              Icons.support_agent_rounded,
              color: accentColor,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
