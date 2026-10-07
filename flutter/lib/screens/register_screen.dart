// lib/screens/register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../services/api_service.dart';
import '../widgets/registration_legal_consent.dart';
import '../utils/armenian_phone.dart';
import 'support_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _showValidationErrors = false;
  List<Map<String, dynamic>>? _legalAcceptances;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context)!;

    if (!_showValidationErrors) {
      setState(() => _showValidationErrors = true);
    }

    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid || _legalAcceptances == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.register(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        phone: ArmenianPhone.normalize(_phoneController.text),
        password: _passwordController.text,
        rePassword: _confirmPasswordController.text,
        legalAcceptances: _legalAcceptances!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.registrationSuccess),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.registrationError}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          l10n.registration,
          style: const TextStyle(color: Color(0xFF333333)),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: const [
          _RegisterLanguageSwitcher(),
          SizedBox(width: 8),
        ],
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
          child: Stack(
            children: [
              const Positioned(
                top: 8,
                left: 10,
                child: SupportShortcutButton(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 70, 24, 24),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _showValidationErrors
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: 100,
                          height: 100,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          l10n.registration,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.createAccount,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF666666),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: l10n.username,
                            labelStyle: const TextStyle(color: Color(0xFF666666)),
                            prefixIcon: const Icon(Icons.person, color: Color(0xFFD1BC00)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFD1BC00), width: 2),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            fillColor: Colors.white,
                            filled: true,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.enterUsername;
                            }
                            if (value.length < 3) {
                              return l10n.usernameMinLength;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: l10n.email,
                            labelStyle: const TextStyle(color: Color(0xFF666666)),
                            prefixIcon: const Icon(Icons.email, color: Color(0xFFD1BC00)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFD1BC00), width: 2),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            fillColor: Colors.white,
                            filled: true,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.enterEmail;
                            }
                            if (!value.contains('@') || !value.contains('.')) {
                              return l10n.enterValidEmail;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.ltr,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          inputFormatters: const [
                            ArmenianPhoneInputFormatter(),
                          ],
                          decoration: InputDecoration(
                            labelText: _tr(
                              ru: 'Телефон',
                              en: 'Phone',
                              hy: 'Հեռախոս',
                            ),
                            labelStyle: const TextStyle(color: Color(0xFF666666)),
                            prefixIcon: const Icon(Icons.phone, color: Color(0xFFD1BC00)),
                            prefixText: '+374 ',
                            prefixStyle: const TextStyle(
                              color: Color(0xFF333333),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            hintText: 'XX-XX-XX-XX',
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFD1BC00), width: 2),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            fillColor: Colors.white,
                            filled: true,
                          ),
                          validator: (value) {
                            final phone = value?.trim() ?? '';
                            final localDigits =
                            ArmenianPhone.localDigits(phone);

                            if (localDigits.isEmpty) {
                              return _tr(
                                ru: 'Введите номер телефона',
                                en: 'Enter phone number',
                                hy: 'Մուտքագրեք հեռախոսահամարը',
                              );
                            }

                            if (localDigits.length !=
                                ArmenianPhone.localDigitsLength) {
                              return _tr(
                                ru: 'Введите 8 цифр: +374 XX-XX-XX-XX',
                                en: 'Enter 8 digits: +374 XX-XX-XX-XX',
                                hy: 'Մուտքագրեք 8 թվանշան՝ +374 XX-XX-XX-XX',
                              );
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          onChanged: (_) {
                            if (_showValidationErrors) {
                              _formKey.currentState?.validate();
                            }
                          },
                          decoration: InputDecoration(
                            labelText: l10n.password,
                            labelStyle: const TextStyle(color: Color(0xFF666666)),
                            prefixIcon: const Icon(Icons.lock, color: Color(0xFFD1BC00)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                color: const Color(0xFFD1BC00),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFD1BC00), width: 2),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            fillColor: Colors.white,
                            filled: true,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.enterPassword;
                            }
                            if (value.length < 6) {
                              return l10n.passwordMinLength;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          onChanged: (_) {
                            if (_showValidationErrors) {
                              _formKey.currentState?.validate();
                            }
                          },
                          decoration: InputDecoration(
                            labelText: l10n.confirmPassword,
                            labelStyle: const TextStyle(color: Color(0xFF666666)),
                            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFD1BC00)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                color: const Color(0xFFD1BC00),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFD1BC00), width: 2),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            fillColor: Colors.white,
                            filled: true,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.enterConfirmPassword;
                            }
                            if (value != _passwordController.text) {
                              return l10n.passwordsDoNotMatch;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        RegistrationLegalConsent(
                          enabled: !_isLoading,
                          showValidationError: _showValidationErrors,
                          onChanged: (value) {
                            _legalAcceptances = value;
                            if (value != null && _showValidationErrors && mounted) {
                              setState(() {});
                            }
                          },
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD1BC00),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : Text(
                            l10n.register,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.alreadyHaveAccount,
                              style: const TextStyle(color: Color(0xFF666666)),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Text(
                                l10n.login,
                                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterLanguageSwitcher extends StatelessWidget {
  const _RegisterLanguageSwitcher();

  @override
  Widget build(BuildContext context) {
    final currentCode =
        context.watch<LocaleProvider>().locale.languageCode;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RegisterLanguageButton(
          label: 'ARM',
          code: 'hy',
          selected: currentCode == 'hy',
        ),
        _RegisterLanguageButton(
          label: 'EN',
          code: 'en',
          selected: currentCode == 'en',
        ),
        _RegisterLanguageButton(
          label: 'RU',
          code: 'ru',
          selected: currentCode == 'ru',
        ),
      ],
    );
  }
}

class _RegisterLanguageButton extends StatelessWidget {
  final String label;
  final String code;
  final bool selected;

  const _RegisterLanguageButton({
    required this.label,
    required this.code,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.read<LocaleProvider>().setLocale(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD1BC00) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : const Color(0xFF555555),
          ),
        ),
      ),
    );
  }
}

