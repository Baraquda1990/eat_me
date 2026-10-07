// lib/screens/welcome_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';


import '../providers/auth_provider.dart';
import '../providers/favorite_provider.dart';
import '../providers/locale_provider.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'seller_registration/seller_account_screen.dart';
import 'support_screen.dart';
import 'about_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const Color accentColor = Color(0xFFD1BC00);
  static const String _welcomeCompletedKey = 'welcome_completed';

  bool _isLoading = false;

  Future<void> _completeWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeCompletedKey, true);
  }

  void _openMainScreen() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainScreen()),
          (_) => false,
    );
  }

  Future<void> _continueAsGuest() async {
    if (_isLoading) return;

    await _completeWelcome();
    if (!mounted) return;
    _openMainScreen();
  }

  Future<void> _loginWithGoogle() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await ApiService.loginWithGoogle();
      await context.read<AuthProvider>().checkLoginStatus();
      await context.read<FavoriteProvider>().loadFavorites();
      await _completeWelcome();

      if (!mounted) return;
      _openMainScreen();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)!.loginError}: $e'),
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

  Future<void> _openPasswordLogin() async {
    if (_isLoading) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );

    if (result == true) {
      await _completeWelcome();
      if (!mounted) return;
      _openMainScreen();
    }
  }

  Future<void> _openSellerRegistration() async {
    if (_isLoading) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SellerAccountScreen(),
      ),
    );
  }

  void _showAbout() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AboutScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SupportShortcutButton(),
                      _LanguageTextSwitcher(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Image.asset(
                    'assets/images/logo.png',
                    width: 170,
                    height: 170,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.welcomeTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.7,
                      color: Color(0xFF242424),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.welcomeSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 34),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _loginWithGoogle,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF242424),
                        side: const BorderSide(color: Color(0xFFE1E1E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accentColor,
                        ),
                      )
                          : const Text(
                        'G',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4285F4),
                        ),
                      ),
                      label: Text(
                        l10n.continueWithGoogle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isLoading ? null : _continueAsGuest,
                    child: Text(
                      l10n.continueAsGuest,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.alreadyHaveAccount,
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: _isLoading ? null : _openPasswordLogin,
                        child: Text(
                          l10n.signInWithPassword,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _openSellerRegistration,
                    icon: const Icon(Icons.storefront_rounded, size: 18),
                    label: Text(l10n.registerAsSeller),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF242424),
                      side: const BorderSide(color: Colors.red, width: 1.2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 46),
                  TextButton.icon(
                    onPressed: _showAbout,
                    icon: const Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                    ),
                    label: Text(l10n.aboutUs),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageTextSwitcher extends StatelessWidget {
  const _LanguageTextSwitcher();

  @override
  Widget build(BuildContext context) {
    final currentCode = context.watch<LocaleProvider>().locale.languageCode;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LanguageTextButton(
          label: 'ARM',
          code: 'hy',
          selected: currentCode == 'hy',
        ),
        _LanguageTextButton(
          label: 'EN',
          code: 'en',
          selected: currentCode == 'en',
        ),
        _LanguageTextButton(
          label: 'RU',
          code: 'ru',
          selected: currentCode == 'ru',
        ),
      ],
    );
  }
}

class _LanguageTextButton extends StatelessWidget {
  final String label;
  final String code;
  final bool selected;

  const _LanguageTextButton({
    required this.label,
    required this.code,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.read<LocaleProvider>().setLocale(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD1BC00) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : const Color(0xFF555555),
          ),
        ),
      ),
    );
  }
}

