// lib/screens/change_password_screen.dart

import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  static const Color accentColor = Color(0xFFD1BC00);

  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _repeatPasswordController = TextEditingController();

  bool _showValidationErrors = false;
  bool _isSaving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureRepeat = true;
  String? _serverError;

  _PasswordUiText get _text => _PasswordUiText.of(context);

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _repeatPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;

    FocusScope.of(context).unfocus();

    if (!_showValidationErrors) {
      setState(() => _showValidationErrors = true);
    }

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() {
      _isSaving = true;
      _serverError = null;
    });

    try {
      await ApiService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
        reNewPassword: _repeatPasswordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(_text.success),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      final raw = error.toString().toLowerCase();
      String message;

      if (raw.contains('current_password_invalid')) {
        message = _text.currentPasswordIncorrect;
      } else if (raw.contains('new_password_invalid')) {
        message = _text.newPasswordRejected;
      } else if (raw.contains('not_authenticated')) {
        message = _text.sessionExpired;
      } else {
        message = _text.saveFailed;
      }

      setState(() => _serverError = message);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF666666)),
      prefixIcon: Icon(icon, color: accentColor),
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: const Color(0xFF777777),
        ),
      ),
      filled: true,
      fillColor: Colors.white,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          text.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: _showValidationErrors
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEAEAEA)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: Color(0xFF6B6000),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text.heading,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF202020),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            text.hint,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: Color(0xFF6D6D6D),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrent,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_serverError != null) {
                    setState(() => _serverError = null);
                  }
                },
                decoration: _decoration(
                  label: text.currentPassword,
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscureCurrent,
                  onToggle: () => setState(
                        () => _obscureCurrent = !_obscureCurrent,
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').isEmpty) return text.enterCurrentPassword;
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_serverError != null) {
                    setState(() => _serverError = null);
                  }
                  if (_showValidationErrors) {
                    _formKey.currentState?.validate();
                  }
                },
                decoration: _decoration(
                  label: text.newPassword,
                  icon: Icons.password_rounded,
                  obscure: _obscureNew,
                  onToggle: () => setState(() => _obscureNew = !_obscureNew),
                ),
                validator: (value) {
                  final password = value ?? '';
                  if (password.isEmpty) return text.enterNewPassword;
                  if (password.length < 8) return text.passwordMinLength;
                  if (password == _currentPasswordController.text) {
                    return text.passwordMustDiffer;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _repeatPasswordController,
                obscureText: _obscureRepeat,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                onChanged: (_) {
                  if (_serverError != null) {
                    setState(() => _serverError = null);
                  }
                },
                decoration: _decoration(
                  label: text.repeatPassword,
                  icon: Icons.lock_reset_rounded,
                  obscure: _obscureRepeat,
                  onToggle: () => setState(
                        () => _obscureRepeat = !_obscureRepeat,
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').isEmpty) return text.repeatNewPassword;
                  if (value != _newPasswordController.text) {
                    return text.passwordsDoNotMatch;
                  }
                  return null;
                },
              ),
              if (_serverError != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F0),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFC7C2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          _serverError!,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8D2E27),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.black,
                    ),
                  )
                      : Text(
                    text.save,
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
    );
  }
}

class _PasswordUiText {
  final String title;
  final String heading;
  final String hint;
  final String currentPassword;
  final String newPassword;
  final String repeatPassword;
  final String enterCurrentPassword;
  final String enterNewPassword;
  final String repeatNewPassword;
  final String passwordMinLength;
  final String passwordMustDiffer;
  final String passwordsDoNotMatch;
  final String save;
  final String success;
  final String currentPasswordIncorrect;
  final String newPasswordRejected;
  final String sessionExpired;
  final String saveFailed;

  const _PasswordUiText({
    required this.title,
    required this.heading,
    required this.hint,
    required this.currentPassword,
    required this.newPassword,
    required this.repeatPassword,
    required this.enterCurrentPassword,
    required this.enterNewPassword,
    required this.repeatNewPassword,
    required this.passwordMinLength,
    required this.passwordMustDiffer,
    required this.passwordsDoNotMatch,
    required this.save,
    required this.success,
    required this.currentPasswordIncorrect,
    required this.newPasswordRejected,
    required this.sessionExpired,
    required this.saveFailed,
  });

  factory _PasswordUiText.of(BuildContext context) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'hy':
        return const _PasswordUiText(
          title: 'Փոխել գաղտնաբառը',
          heading: 'Հաշվի անվտանգություն',
          hint: 'Մուտքագրեք ընթացիկ գաղտնաբառը, ապա ստեղծեք նոր գաղտնաբառ։',
          currentPassword: 'Ընթացիկ գաղտնաբառ',
          newPassword: 'Նոր գաղտնաբառ',
          repeatPassword: 'Կրկնել նոր գաղտնաբառը',
          enterCurrentPassword: 'Մուտքագրեք ընթացիկ գաղտնաբառը',
          enterNewPassword: 'Մուտքագրեք նոր գաղտնաբառը',
          repeatNewPassword: 'Կրկնեք նոր գաղտնաբառը',
          passwordMinLength: 'Գաղտնաբառը պետք է պարունակի առնվազն 8 նիշ',
          passwordMustDiffer: 'Նոր գաղտնաբառը պետք է տարբերվի ընթացիկից',
          passwordsDoNotMatch: 'Գաղտնաբառերը չեն համընկնում',
          save: 'Փոխել գաղտնաբառը',
          success: 'Գաղտնաբառը հաջողությամբ փոխվել է',
          currentPasswordIncorrect: 'Ընթացիկ գաղտնաբառը սխալ է',
          newPasswordRejected: 'Նոր գաղտնաբառը չի համապատասխանում անվտանգության պահանջներին',
          sessionExpired: 'Նորից մուտք գործեք հաշիվ',
          saveFailed: 'Չհաջողվեց փոխել գաղտնաբառը',
        );
      case 'ru':
        return const _PasswordUiText(
          title: 'Сменить пароль',
          heading: 'Безопасность аккаунта',
          hint: 'Введите текущий пароль, затем придумайте новый пароль.',
          currentPassword: 'Текущий пароль',
          newPassword: 'Новый пароль',
          repeatPassword: 'Повторите новый пароль',
          enterCurrentPassword: 'Введите текущий пароль',
          enterNewPassword: 'Введите новый пароль',
          repeatNewPassword: 'Повторите новый пароль',
          passwordMinLength: 'Пароль должен содержать минимум 8 символов',
          passwordMustDiffer: 'Новый пароль должен отличаться от текущего',
          passwordsDoNotMatch: 'Пароли не совпадают',
          save: 'Сменить пароль',
          success: 'Пароль успешно изменён',
          currentPasswordIncorrect: 'Текущий пароль указан неверно',
          newPasswordRejected: 'Новый пароль не соответствует требованиям безопасности',
          sessionExpired: 'Войдите в аккаунт заново',
          saveFailed: 'Не удалось изменить пароль',
        );
      default:
        return const _PasswordUiText(
          title: 'Change password',
          heading: 'Account security',
          hint: 'Enter your current password, then create a new password.',
          currentPassword: 'Current password',
          newPassword: 'New password',
          repeatPassword: 'Repeat new password',
          enterCurrentPassword: 'Enter your current password',
          enterNewPassword: 'Enter a new password',
          repeatNewPassword: 'Repeat the new password',
          passwordMinLength: 'Password must be at least 8 characters',
          passwordMustDiffer: 'New password must differ from the current password',
          passwordsDoNotMatch: 'Passwords do not match',
          save: 'Change password',
          success: 'Password changed successfully',
          currentPasswordIncorrect: 'Current password is incorrect',
          newPasswordRejected: 'New password does not meet the security requirements',
          sessionExpired: 'Please sign in again',
          saveFailed: 'Could not change password',
        );
    }
  }
}
