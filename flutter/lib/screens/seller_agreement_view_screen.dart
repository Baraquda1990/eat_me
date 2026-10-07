import 'package:flutter/material.dart';

class SellerAgreementViewScreen extends StatelessWidget {
  const SellerAgreementViewScreen({
    super.key,
    required this.preview,
  });

  final Map<String, dynamic> preview;

  static const Color _accent = Color(0xFFD1BC00);

  String _text(
      BuildContext context, {
        required String ru,
        required String en,
        required String hy,
      }) {
    return switch (Localizations.localeOf(context).languageCode) {
      'en' => en,
      'hy' => hy,
      _ => ru,
    };
  }

  String _formatAcceptedAt(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '';

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final agreementText = preview['text']?.toString() ?? '';
    final version = preview['version']?.toString().trim() ?? '';
    final acceptedAt = _formatAcceptedAt(preview['accepted_at']);
    final isAccepted = preview['is_accepted'] == true || acceptedAt.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF222222),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _text(
            context,
            ru: 'Агентский договор',
            en: 'Agency Agreement',
            hy: 'Գործակալության պայմանագիր',
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            if (version.isNotEmpty || acceptedAt.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9D9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _accent.withValues(alpha: 0.42),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      color: Color(0xFF7A6C00),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        [
                          if (!isAccepted)
                            _text(
                              context,
                              ru: 'Текущая версия договора',
                              en: 'Current agreement version',
                              hy: 'Պայմանագրի ընթացիկ տարբերակը',
                            ),
                          if (version.isNotEmpty)
                            _text(
                              context,
                              ru: 'Версия: $version',
                              en: 'Version: $version',
                              hy: 'Տարբերակ՝ $version',
                            ),
                          if (acceptedAt.isNotEmpty)
                            _text(
                              context,
                              ru: 'Принят: $acceptedAt',
                              en: 'Accepted: $acceptedAt',
                              hy: 'Ընդունված՝ $acceptedAt',
                            ),
                        ].join('\n'),
                        style: const TextStyle(
                          height: 1.4,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF555555),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: SelectableText(
                agreementText,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: Color(0xFF292929),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
