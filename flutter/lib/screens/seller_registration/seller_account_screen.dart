// lib/screens/seller_registration/seller_account_screen.dart

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/registration_legal_consent.dart';
import '../../utils/legal_consent.dart';
import 'seller_type_screen.dart';

class SellerAccountScreen extends StatefulWidget {
  const SellerAccountScreen({super.key});

  @override
  State<SellerAccountScreen> createState() => _SellerAccountScreenState();
}

class _SellerAccountScreenState extends State<SellerAccountScreen> {
  static const Color _accent = Color(0xFFD1BC00);

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _createAccount = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _showValidationErrors = false;
  List<Map<String, dynamic>>? _legalAcceptances;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchMode() {
    if (_isLoading) return;

    setState(() {
      _createAccount = !_createAccount;
      _formKey.currentState?.reset();
      _showValidationErrors = false;
      _legalAcceptances = null;
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)!.requiredField;
    }
    return null;
  }

  String? _validateUsername(String? value) {
    final username = value?.trim() ?? '';

    if (username.isEmpty) {
      return AppLocalizations.of(context)!.enterUsername;
    }

    if (username.length < 3) {
      return AppLocalizations.of(context)!.usernameMinLength;
    }

    return null;
  }

  String? _validateEmail(String? value) {
    if (!_createAccount) return null;

    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return AppLocalizations.of(context)!.enterEmail;
    }

    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email)) {
      return AppLocalizations.of(context)!.enterValidEmail;
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return AppLocalizations.of(context)!.enterPassword;
    }

    if (password.length < 6) {
      return AppLocalizations.of(context)!.passwordMinLength;
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;

    if (_createAccount && value != _passwordController.text) {
      return AppLocalizations.of(context)!.passwordsDoNotMatch;
    }

    return null;
  }

  String _errorMessage(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');

    if (text.contains('username') && text.contains('already')) {
      return AppLocalizations.of(context)!.sellerUsernameExists;
    }

    if (text.contains('email') && text.contains('already')) {
      return AppLocalizations.of(context)!.sellerEmailExists;
    }

    if (text.toLowerCase().contains('no active account') ||
        text.toLowerCase().contains('credentials')) {
      return AppLocalizations.of(context)!.invalidCredentials;
    }

    return text;
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();

    if (!_showValidationErrors) {
      setState(() => _showValidationErrors = true);
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_createAccount && _legalAcceptances == null) return;

    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      if (_createAccount) {
        await ApiService.register(
          username: username,
          email: _emailController.text.trim(),
          // РўРµР»РµС„РѕРЅ Рё РґР°РЅРЅС‹Рµ РєРѕРјРїР°РЅРёРё Р±СѓРґСѓС‚ Р·Р°РїРѕР»РЅРµРЅС‹ РЅР° СЃР»РµРґСѓСЋС‰РёС… С€Р°РіР°С….
          phone: '',
          password: password,
          rePassword: _confirmPasswordController.text,
          legalAcceptances: _legalAcceptances!,
        );
      }

      await ApiService.login(
        username: username,
        password: password,
      );

      await context.read<AuthProvider>().checkLoginStatus();

      if (!mounted) return;

      if (!context.read<AuthProvider>().isLoggedIn) {
        throw Exception(AppLocalizations.of(context)!.authorizationConfirmationFailed);
      }

      final legalReady = await ensureLegalConsent(
        context,
        action: 'registration',
      );
      if (!legalReady || !mounted) return;

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const SellerTypeScreen(),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage(error)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _accent),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accent, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF242424),
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/auth_bg.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: Color(0xFFF7F7F7),
            ),
          ),
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Form(
                key: _formKey,
                autovalidateMode: _showValidationErrors
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _createAccount
                          ? AppLocalizations.of(context)!.createSellerAccount
                          : AppLocalizations.of(context)!.loginAsSeller,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF242424),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _createAccount
                          ? AppLocalizations.of(context)!.createSellerAccountSubtitle
                          : AppLocalizations.of(context)!.loginSellerSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _usernameController,
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.next,
                      validator: _validateUsername,
                      decoration: _decoration(
                        label: AppLocalizations.of(context)!.username,
                        icon: Icons.person_outline,
                      ),
                    ),
                    if (_createAccount) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _emailController,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: _validateEmail,
                        decoration: _decoration(
                          label: AppLocalizations.of(context)!.email,
                          icon: Icons.email_outlined,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_isLoading,
                      obscureText: _obscurePassword,
                      textInputAction: _createAccount
                          ? TextInputAction.next
                          : TextInputAction.done,
                      validator: _validatePassword,
                      onChanged: (_) {
                        if (_showValidationErrors && _createAccount) {
                          _formKey.currentState?.validate();
                        }
                      },
                      onFieldSubmitted: (_) {
                        if (!_createAccount) _submit();
                      },
                      decoration: _decoration(
                        label: AppLocalizations.of(context)!.password,
                        icon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    if (_createAccount) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmPasswordController,
                        enabled: !_isLoading,
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        validator: _validateConfirmPassword,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: _decoration(
                          label: AppLocalizations.of(context)!.confirmPassword,
                          icon: Icons.lock_reset_outlined,
                          suffixIcon: IconButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                              setState(() {
                                _obscureConfirmPassword =
                                !_obscureConfirmPassword;
                              });
                            },
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_createAccount) ...[
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
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                            : Text(
                          _createAccount
                              ? AppLocalizations.of(context)!.createAndContinue
                              : AppLocalizations.of(context)!.loginAndContinue,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: _isLoading ? null : _switchMode,
                      child: Text(
                        _createAccount
                            ? AppLocalizations.of(context)!.alreadyHaveAccountSignIn
                            : AppLocalizations.of(context)!.noAccountCreate,
                        style: const TextStyle(
                          color: Color(0xFF242424),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.sellerStatusAfterApproval,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Color(0xFF777777),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

