// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';

import '../providers/locale_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const Color accentColor = Color(0xFFD1BC00);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeProvider = context.watch<LocaleProvider>();
    final currentCode = localeProvider.locale.languageCode;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          l10n.settings,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.language_rounded,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.appLanguage,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _LanguageTile(
                  codeLabel: 'RU',
                  title: l10n.russian,
                  selected: currentCode == 'ru',
                  onTap: () => _setLanguage(context, 'ru'),
                ),
                _LanguageTile(
                  codeLabel: 'ARM',
                  title: l10n.armenian,
                  selected: currentCode == 'hy',
                  onTap: () => _setLanguage(context, 'hy'),
                ),
                _LanguageTile(
                  codeLabel: 'EN',
                  title: l10n.english,
                  selected: currentCode == 'en',
                  onTap: () => _setLanguage(context, 'en'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setLanguage(BuildContext context, String code) async {
    final l10n = AppLocalizations.of(context)!;
    await context.read<LocaleProvider>().setLocale(code);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.languageChanged),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String codeLabel;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.codeLabel,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFFFFF9D9) : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 46,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFD1BC00)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFD1BC00)
                          : const Color(0xFFE1E1E1),
                    ),
                  ),
                  child: Text(
                    codeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: selected
                          ? Colors.white
                          : const Color(0xFF555555),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFFD1BC00),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

