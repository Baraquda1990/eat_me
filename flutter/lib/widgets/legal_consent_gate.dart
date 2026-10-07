import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/legal_document.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/legal_ui_text.dart';
import '../screens/legal_consent_screen.dart';
import 'app_error_state.dart';

class LegalConsentGate extends StatefulWidget {
  const LegalConsentGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<LegalConsentGate> createState() => _LegalConsentGateState();
}

class _LegalConsentGateState extends State<LegalConsentGate> {
  bool _loading = true;
  Object? _error;
  List<LegalDocumentInfo> _missing = const [];
  String? _language;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (_language != language) {
      _language = language;
      _check();
    }
  }

  Future<void> _check() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final status = await ApiService.getLegalStatus(
        action: 'registration',
        language: _language,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _missing = status.missing;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _openMandatoryConsent() async {
    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LegalConsentScreen(
          action: 'registration',
          documents: _missing,
          allowLogout: true,
          onLogout: () async {
            await context.read<AuthProvider>().logout();
            if (mounted) {
              Navigator.of(context).pop(false);
            }
          },
        ),
      ),
    );

    if (accepted == true && mounted) {
      await _check();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFD1BC00)),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F4F4),
        body: SafeArea(
          child: AppErrorState(
            error: _error,
            onRetry: _check,
          ),
        ),
      );
    }

    if (_missing.isEmpty) {
      return widget.child;
    }

    // Block authenticated account features until mandatory registration
    // documents are accepted, while still allowing the user to sign out.
    final text = LegalUiText.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE8E8E8)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1BC00).withOpacity(.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: Color(0xFFD1BC00),
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    text.updatedTermsTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF272727),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    text.updatedTermsSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._missing.map(
                        (document) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: Color(0xFFD1BC00),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              document.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF444444),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _openMandatoryConsent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD1BC00),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.menu_book_rounded),
                      label: Text(
                        text.continueLabel,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => context.read<AuthProvider>().logout(),
                    child: Text(
                      text.logout,
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
