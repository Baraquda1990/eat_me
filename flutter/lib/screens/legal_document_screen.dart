import 'package:flutter/material.dart';

import '../models/legal_document.dart';
import '../utils/legal_ui_text.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.document,
  });

  final LegalDocumentInfo document;

  static const Color _accent = Color(0xFFD1BC00);

  @override
  Widget build(BuildContext context) {
    final text = LegalUiText.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF252525),
        elevation: 0,
        title: Text(
          document.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE9E9E9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${text.version} ${document.version}',
                          style: const TextStyle(
                            color: Color(0xFF655B00),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (document.accepted == true)
                        const Icon(
                          Icons.verified_rounded,
                          color: _accent,
                          size: 22,
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SelectableText(
                    document.content.trim(),
                    style: const TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 15,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
