// lib/utils/product_share.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/product.dart';

const String _appsosaShareHost = 'appsosa.am';

String productPublicUrl(Product product) {
  final slug = product.slug.trim();
  return Uri.https(
    _appsosaShareHost,
    '/product/$slug',
  ).toString();
}

String _shareCompanyName(Product product) {
  final name = (product.company.name ?? '').trim();
  if (name.isNotEmpty) return name;

  return product.company.address.trim();
}

double _sharePrice(Product product) {
  if (product.discountPrice > 0 &&
      product.discountPrice < product.price) {
    return product.discountPrice;
  }

  return product.price;
}

String _shareText(BuildContext context, Product product) {
  final languageCode = Localizations.localeOf(context).languageCode;
  final company = _shareCompanyName(product);
  final price = _sharePrice(product);
  final priceText =
  price > 0 ? '${price.toStringAsFixed(0)} ֏' : '';
  final url = productPublicUrl(product);

  final details = <String>[
    product.name.trim(),
    if (company.isNotEmpty) company,
    if (priceText.isNotEmpty) priceText,
  ].join('\n');

  switch (languageCode) {
    case 'hy':
      return 'Դիտեք այս առաջարկը Appsosa-ում 👇\n'
          '$details\n\n'
          '$url';
    case 'en':
      return 'Check out this offer on Appsosa 👇\n'
          '$details\n\n'
          '$url';
    default:
      return 'Посмотрите это предложение в Appsosa 👇\n'
          '$details\n\n'
          '$url';
  }
}

String _copiedMessage(BuildContext context) {
  switch (Localizations.localeOf(context).languageCode) {
    case 'hy':
      return 'Հղումը պատճենված է';
    case 'en':
      return 'Link copied';
    default:
      return 'Ссылка скопирована';
  }
}

Rect _shareOrigin(BuildContext context) {
  final renderObject = context.findRenderObject();

  if (renderObject is RenderBox && renderObject.hasSize) {
    final offset = renderObject.localToGlobal(Offset.zero);
    return offset & renderObject.size;
  }

  final size = MediaQuery.sizeOf(context);
  return Rect.fromLTWH(
    size.width / 2,
    size.height / 2,
    1,
    1,
  );
}

Future<void> shareProduct(
    BuildContext context,
    Product product,
    ) async {
  final text = _shareText(context, product);

  try {
    final result = await SharePlus.instance.share(
      ShareParams(
        text: text,
        title: 'Appsosa',
        subject: '${product.name} — Appsosa',
        sharePositionOrigin: _shareOrigin(context),
      ),
    );

    if (result.status != ShareResultStatus.unavailable) {
      return;
    }
  } catch (_) {
    // If the native/Web share sheet is unavailable, copy the same
    // share text so the user can still paste it into any messenger.
  }

  await Clipboard.setData(ClipboardData(text: text));

  if (!context.mounted) return;

  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(_copiedMessage(context)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
