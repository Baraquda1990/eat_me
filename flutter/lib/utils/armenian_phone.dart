import 'package:flutter/services.dart';

/// Armenia-only phone handling for Appsosa.
///
/// UI format:
///   +374 XX-XX-XX-XX
///
/// Stored/API format:
///   +374XXXXXXXX
class ArmenianPhone {
  ArmenianPhone._();

  static const String countryCode = '+374';
  static const int localDigitsLength = 8;

  static String digitsOnly(dynamic value) {
    return value?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
  }

  /// Returns only the 8 local digits (without +374).
  ///
  /// Accepts both:
  /// - 99123456
  /// - +37499123456
  /// - +374 99-12-34-56
  static String localDigits(dynamic value) {
    var digits = digitsOnly(value);

    if (digits.startsWith('374') && digits.length > localDigitsLength) {
      digits = digits.substring(3);
    }

    if (digits.length > localDigitsLength) {
      return '';
    }

    return digits;
  }

  static bool isValid(dynamic value) {
    return localDigits(value).length == localDigitsLength;
  }

  static String normalize(dynamic value) {
    final local = localDigits(value);
    if (local.length != localDigitsLength) return '';
    return '$countryCode$local';
  }

  static String formatLocal(dynamic value) {
    final local = localDigits(value);
    if (local.isEmpty) return '';

    final groups = <String>[];
    for (var i = 0; i < local.length; i += 2) {
      final end = (i + 2 < local.length) ? i + 2 : local.length;
      groups.add(local.substring(i, end));
    }
    return groups.join('-');
  }

  static String formatInternational(dynamic value) {
    final local = localDigits(value);
    if (local.isEmpty) return '';
    return '$countryCode ${formatLocal(local)}';
  }
}

/// Keeps +374 outside the editable part and formats only the local 8 digits:
/// XX-XX-XX-XX.
///
/// Pasting +37499123456 is also supported: +374 is stripped automatically.
class ArmenianPhoneInputFormatter extends TextInputFormatter {
  const ArmenianPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('374') && digits.length > ArmenianPhone.localDigitsLength) {
      digits = digits.substring(3);
    }

    if (digits.length > ArmenianPhone.localDigitsLength) {
      digits = digits.substring(0, ArmenianPhone.localDigitsLength);
    }

    final formatted = ArmenianPhone.formatLocal(digits);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
      composing: TextRange.empty,
    );
  }
}
