import 'package:flutter/material.dart';

import '../screens/legal_consent_screen.dart';
import '../services/api_service.dart';

Future<bool> ensureLegalConsent(
    BuildContext context, {
      required String action,
    }) async {
  try {
    final language = Localizations.localeOf(context).languageCode;
    final status = await ApiService.getLegalStatus(
      action: action,
      language: language,
    );

    if (status.ready || status.missing.isEmpty) return true;
    if (!context.mounted) return false;

    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LegalConsentScreen(
          action: action,
          documents: status.missing,
        ),
      ),
    );

    return accepted == true;
  } catch (_) {
    if (!context.mounted) return false;
    final language = Localizations.localeOf(context).languageCode;
    final message = language == 'ru'
        ? 'Не удалось проверить условия. Проверьте соединение и попробуйте снова.'
        : language == 'hy'
        ? 'Չհաջողվեց ստուգել պայմանները։ Ստուգեք կապը և փորձեք կրկին։'
        : 'Could not verify the terms. Check your connection and try again.';
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    return false;
  }
}
