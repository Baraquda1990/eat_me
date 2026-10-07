import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

class LocaleProvider extends ChangeNotifier {
  static const List<String> supportedLanguages = ['ru', 'en', 'hy'];

  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  String _normalizeCode(String code) {
    final normalized = code.trim().toLowerCase();

    if (supportedLanguages.contains(normalized)) {
      return normalized;
    }

    return 'en';
  }

  Future<void> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();

    final savedCode = _normalizeCode(
      prefs.getString('app_language') ?? 'en',
    );

    ApiService.setRequestLanguage(savedCode);
    _locale = Locale(savedCode);
    notifyListeners();

    try {
      final backendCode = await ApiService.getProfileLanguage();

      if (backendCode == null) return;

      final normalizedBackendCode = _normalizeCode(backendCode);

      if (normalizedBackendCode == savedCode) return;

      await prefs.setString(
        'app_language',
        normalizedBackendCode,
      );

      ApiService.setRequestLanguage(normalizedBackendCode);
      _locale = Locale(normalizedBackendCode);
      notifyListeners();
    } catch (_) {
      // Если пользователь не авторизован или backend временно недоступен,
      // оставляем локально сохранённый язык.
    }
  }

  Future<void> setLocale(String code) async {
    final normalizedCode = _normalizeCode(code);
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'app_language',
      normalizedCode,
    );

    ApiService.setRequestLanguage(normalizedCode);
    _locale = Locale(normalizedCode);
    notifyListeners();

    try {
      await ApiService.updateLanguage(normalizedCode);
    } catch (_) {
      // Если пользователь не авторизован — язык всё равно сохранён локально.
      // После входа ApiService.syncSavedLanguageToBackend() отправит его на backend.
    }
  }
}
