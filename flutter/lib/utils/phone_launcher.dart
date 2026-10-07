import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

String normalizePhone(String phone) {
  var value = phone.trim();
  value = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

  if (value.startsWith('00')) {
    value = '+${value.substring(2)}';
  }

  return value;
}

Future<void> launchPhoneCall(
    BuildContext context,
    String phone,
    ) async {
  final normalized = normalizePhone(phone);

  if (normalized.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Номер телефона не указан')),
    );
    return;
  }

  final uri = Uri(scheme: 'tel', path: normalized);

  try {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть звонок: $normalized')),
      );
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось открыть звонок: $normalized')),
    );
  }
}