import 'package:flutter/material.dart';

class PinDots extends StatelessWidget {
  final int length;
  final int filled;
  final bool error;

  const PinDots({
    super.key,
    this.length = 4,
    required this.filled,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (index) {
        final isFilled = index < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 16,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? (error ? Colors.red : const Color(0xFFD1BC00))
                : Colors.transparent,
            border: Border.all(
              color: error
                  ? Colors.red
                  : isFilled
                  ? const Color(0xFFD1BC00)
                  : const Color(0xFFBDBDBD),
              width: 1.7,
            ),
          ),
        );
      }),
    );
  }
}

class PinKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    const keys = <String>['1', '2', '3', '4', '5', '6', '7', '8', '9'];

    Widget numberButton(String value) {
      return SizedBox(
        width: 72,
        height: 58,
        child: Material(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: enabled ? () => onDigit(value) : null,
            borderRadius: BorderRadius.circular(18),
            child: Center(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF333333),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var row = 0; row < 3; row++) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: 14),
                numberButton(keys[row * 3 + col]),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 72, height: 58),
            const SizedBox(width: 14),
            numberButton('0'),
            const SizedBox(width: 14),
            SizedBox(
              width: 72,
              height: 58,
              child: IconButton(
                onPressed: enabled ? onBackspace : null,
                icon: const Icon(Icons.backspace_outlined),
                color: const Color(0xFF555555),
                iconSize: 25,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
