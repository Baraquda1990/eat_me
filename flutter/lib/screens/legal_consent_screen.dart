import 'package:flutter/material.dart';

import '../models/legal_document.dart';
import '../services/api_service.dart';
import '../utils/legal_ui_text.dart';
import 'legal_document_screen.dart';

class LegalConsentScreen extends StatefulWidget {
  const LegalConsentScreen({
    super.key,
    required this.action,
    required this.documents,
    this.allowLogout = false,
    this.onLogout,
  });

  final String action;
  final List<LegalDocumentInfo> documents;
  final bool allowLogout;
  final Future<void> Function()? onLogout;

  @override
  State<LegalConsentScreen> createState() => _LegalConsentScreenState();
}

class _LegalConsentScreenState extends State<LegalConsentScreen> {
  static const Color _accent = Color(0xFFD1BC00);

  bool _accepted = false;
  bool _saving = false;
  String? _error;

  Future<void> _openDocument(LegalDocumentInfo document) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(document: document),
      ),
    );
  }

  Future<void> _save() async {
    if (!_accepted || _saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final result = await ApiService.acceptLegalDocuments(
        action: widget.action,
        documents: widget.documents,
      );

      if (!mounted) return;

      if (!result.ready) {
        setState(() {
          _saving = false;
          _error = LegalUiText.of(context).acceptanceFailed;
        });
        return;
      }

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = LegalUiText.of(context).acceptanceFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = LegalUiText.of(context);
    final isCheckout = widget.action == 'checkout';

    return PopScope(
      canPop: !widget.allowLogout,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F4F4),
        appBar: AppBar(
          automaticallyImplyLeading: !widget.allowLogout,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF252525),
          elevation: 0,
          title: Text(
            isCheckout
                ? text.purchaseConsentTitle
                : text.updatedTermsTitle,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(.11),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isCheckout
                            ? text.purchaseConsentSubtitle
                            : text.updatedTermsSubtitle,
                        style: const TextStyle(
                          color: Color(0xFF4C4500),
                          fontSize: 14,
                          height: 1.42,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...widget.documents.map(
                          (document) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE7E7E7)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _accent.withOpacity(.12),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.description_outlined,
                              color: _accent,
                            ),
                          ),
                          title: Text(
                            document.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            '${text.version} ${document.version}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _openDocument(document),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _error != null
                              ? Colors.red.withOpacity(.45)
                              : const Color(0xFFE4E4E4),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _accepted,
                            activeColor: _accent,
                            onChanged: _saving
                                ? null
                                : (value) {
                              setState(() {
                                _accepted = value == true;
                                if (_accepted) _error = null;
                              });
                            },
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                text.acceptAll,
                                style: const TextStyle(
                                  color: Color(0xFF3D3D3D),
                                  fontSize: 13.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  12 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _accepted && !_saving ? _save : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                            : Text(
                          text.continueLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    if (widget.allowLogout && widget.onLogout != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () async {
                          await widget.onLogout!.call();
                        },
                        child: Text(
                          text.logout,
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
