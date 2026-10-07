import 'package:flutter/material.dart';

import '../models/legal_document.dart';
import '../screens/legal_document_screen.dart';
import '../services/api_service.dart';
import '../utils/legal_ui_text.dart';

class RegistrationLegalConsent extends StatefulWidget {
  const RegistrationLegalConsent({
    super.key,
    required this.onChanged,
    this.showValidationError = false,
    this.enabled = true,
  });

  final ValueChanged<List<Map<String, dynamic>>?> onChanged;
  final bool showValidationError;
  final bool enabled;

  @override
  State<RegistrationLegalConsent> createState() =>
      _RegistrationLegalConsentState();
}

class _RegistrationLegalConsentState extends State<RegistrationLegalConsent> {
  static const Color _accent = Color(0xFFD1BC00);

  List<LegalDocumentInfo> _documents = const [];
  Object? _error;
  bool _loading = true;
  bool _accepted = false;
  String? _language;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (_language != language) {
      _language = language;
      _accepted = false;
      widget.onChanged(null);
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final documents = await ApiService.getLegalDocuments(
        action: 'registration',
        language: _language,
      );
      if (!mounted) return;

      setState(() {
        _documents = documents;
        _loading = false;
        _error = null;
      });

      // No active required documents means registration can proceed. This is
      // useful while v1.0 is seeded but intentionally still inactive.
      if (documents.isEmpty) {
        widget.onChanged(const <Map<String, dynamic>>[]);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
      widget.onChanged(null);
    }
  }

  void _setAccepted(bool value) {
    if (!widget.enabled || _documents.isEmpty) return;

    setState(() => _accepted = value);
    widget.onChanged(
      value
          ? _documents.map((doc) => doc.toAcceptancePayload()).toList()
          : null,
    );
  }

  Future<void> _open(LegalDocumentInfo document) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(document: document),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = LegalUiText.of(context);

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text.loadingDocuments,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(.055),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.withOpacity(.24)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text.loadFailed,
                style: const TextStyle(fontSize: 13, color: Color(0xFF444444)),
              ),
            ),
            TextButton(
              onPressed: widget.enabled ? _load : null,
              child: Text(text.retry),
            ),
          ],
        ),
      );
    }

    if (_documents.isEmpty) {
      return const SizedBox.shrink();
    }

    final showError = widget.showValidationError && !_accepted;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: showError
              ? Colors.red
              : const Color(0xFFE0E0E0),
          width: showError ? 1.3 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _accepted,
                activeColor: _accent,
                onChanged: widget.enabled
                    ? (value) => _setAccepted(value == true)
                    : null,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text.registrationIntro,
                        style: const TextStyle(
                          color: Color(0xFF444444),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 4,
                        runSpacing: 0,
                        children: _documents
                            .map(
                              (document) => InkWell(
                            onTap: () => _open(document),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),
                              child: Text(
                                document.title,
                                style: const TextStyle(
                                  color: Color(0xFF7A6E00),
                                  fontSize: 13,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (showError)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 5, 8, 4),
              child: Text(
                text.registrationError,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
