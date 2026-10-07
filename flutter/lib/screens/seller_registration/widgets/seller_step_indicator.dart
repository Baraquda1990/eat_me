import 'package:flutter/material.dart';

class SellerStepIndicator extends StatelessWidget {
  const SellerStepIndicator({
    super.key,
    required this.currentStep,
  }) : assert(currentStep >= 1 && currentStep <= 5);

  final int currentStep;

  static const Color accent = Color(0xFFD1BC00);
  static const Color inactive = Color(0xFF8A8A8A);

  List<String> _labels(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;

    switch (languageCode) {
      case 'hy':
        return const [
          'Տեսակ',
          'Ընկերության\nտվյալներ',
          'Կատեգորիա',
          'Փաստաթղթեր',
          'Բանկ և\nբրենդինգ',
        ];
      case 'ru':
        return const [
          'Тип',
          'Данные\nкомпании',
          'Категория',
          'Документы',
          'Банк и\nбрендинг',
        ];
      default:
        return const [
          'Type',
          'Company\ninfo',
          'Category',
          'Documents',
          'Bank &\nbranding',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = _labels(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final labelFontSize = languageCode == 'hy' ? 8.4 : 9.5;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const stepCount = 5;
          const stepDiameter = 24.0;
          const lineHeight = 3.0;

          final columnWidth = constraints.maxWidth / stepCount;

          double centerX(int index) =>
              columnWidth * index + (columnWidth / 2);

          return SizedBox(
            height: 54,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (int index = 0; index < stepCount - 1; index++)
                  Positioned(
                    left: centerX(index) + (stepDiameter / 2),
                    top: (stepDiameter - lineHeight) / 2,
                    width: centerX(index + 1) -
                        centerX(index) -
                        stepDiameter,
                    child: Container(
                      height: lineHeight,
                      decoration: BoxDecoration(
                        color:
                        index + 1 < currentStep ? accent : inactive,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),

                for (int index = 0; index < stepCount; index++)
                  Positioned(
                    left: centerX(index) - (stepDiameter / 2),
                    top: 0,
                    width: stepDiameter,
                    height: stepDiameter,
                    child: _StepCircle(
                      step: index + 1,
                      currentStep: currentStep,
                    ),
                  ),

                for (int index = 0; index < labels.length; index++)
                  Positioned(
                    left: columnWidth * index,
                    top: 30,
                    width: columnWidth,
                    child: Text(
                      labels[index],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        fontSize: labelFontSize,
                        height: 1.1,
                        color: index + 1 == currentStep
                            ? Colors.black
                            : inactive,
                        fontWeight: index + 1 == currentStep
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({
    required this.step,
    required this.currentStep,
  });

  final int step;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final completed = step < currentStep;
    final selected = step == currentStep;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected
            ? SellerStepIndicator.accent
            : Colors.white,
        border: Border.all(
          color: completed || selected
              ? SellerStepIndicator.accent
              : SellerStepIndicator.inactive,
          width: 1.5,
        ),
      ),
      child: completed
          ? const Icon(
        Icons.check_rounded,
        size: 15,
        color: SellerStepIndicator.accent,
      )
          : Text(
        '$step',
        style: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
