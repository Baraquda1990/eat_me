import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/locale_provider.dart';

class SellerRegistrationHeader extends StatelessWidget {
  const SellerRegistrationHeader({
    super.key,
    required this.onBack,
    this.height = 112,
  });

  final VoidCallback onBack;
  final double height;

  static const Color accent = Color(0xFFD1BC00);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 8,
            top: 26,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: accent,
                size: 30,
              ),
            ),
          ),
          const Positioned(
            top: 12,
            right: 14,
            child: SellerLanguageSwitcher(),
          ),
          Positioned(
            top: 34,
            child: Image.asset(
              'assets/images/logo.png',
              width: 66,
              height: 66,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                return Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: Colors.redAccent,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SellerLanguageSwitcher extends StatelessWidget {
  const SellerLanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.watch<LocaleProvider>().locale.languageCode;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LanguageButton(label: 'ARM', code: 'hy', selected: current == 'hy'),
        _LanguageButton(label: 'ENG', code: 'en', selected: current == 'en'),
        _LanguageButton(label: 'RU', code: 'ru', selected: current == 'ru'),
      ],
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.label,
    required this.code,
    required this.selected,
  });

  final String label;
  final String code;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.read<LocaleProvider>().setLocale(code),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? SellerRegistrationHeader.accent
                : const Color(0xFF777777),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class SellerRegistrationBackground extends StatelessWidget {
  const SellerRegistrationBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SellerBackgroundPainter(),
      child: child,
    );
  }
}

class _SellerBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD1BC00).withOpacity(0.065)
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width * 0.55, size.height * 0.47);

    canvas.drawLine(
      Offset(size.width * 0.72, 0),
      Offset(size.width * 0.14, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.2),
      Offset(size.width * 0.88, size.height * 0.72),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.05, size.height * 0.55),
      Offset(size.width * 0.95, size.height * 0.37),
      paint,
    );
    canvas.drawCircle(center, size.width * 0.2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
