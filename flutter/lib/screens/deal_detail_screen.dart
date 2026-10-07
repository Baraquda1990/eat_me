// lib/screens/deal_detail_screen.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../utils/product_share.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/app_feedback.dart';

import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/favorite_provider.dart';
import 'company_screen.dart';
import 'login_screen.dart';
import 'cart_screen.dart';

class DealDetailScreen extends StatefulWidget {
  final Product product;

  /// Seller preview uses this same customer screen with local image bytes.
  final Uint8List? previewImageBytes;
  final bool previewMode;

  const DealDetailScreen({
    Key? key,
    required this.product,
    this.previewImageBytes,
    this.previewMode = false,
  }) : super(key: key);

  @override
  State<DealDetailScreen> createState() => _DealDetailScreenState();
}

class _DealDetailScreenState extends State<DealDetailScreen> {
  static const Color accentColor = Color(0xFFD1BC00);
  static const Color darkText = Color(0xFF111111);
  static const Color mutedText = Color(0xFF6B6B6B);

  int _quantity = 1;
  bool _isAdding = false;
  bool _isFavoriteLoading = false;

  Product get product => widget.product;

  double get _finalPrice {
    if (product.discountPrice > 0 && product.discountPrice < product.price) {
      return product.discountPrice;
    }
    return product.price;
  }

  int? get _discountPercent {
    if (product.discountPrice <= 0 || product.discountPrice >= product.price) {
      return null;
    }
    return ((1 - product.discountPrice / product.price) * 100).round();
  }

  int get _maxCount => product.count <= 0 ? 1 : product.count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final favoriteProvider = context.watch<FavoriteProvider>();
    final isFavorite = favoriteProvider.favoriteSlugs.contains(product.slug);

    if (_quantity > _maxCount) {
      _quantity = _maxCount;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 108),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImageHeader(context, isFavorite, l10n),
                    _buildMainInfo(context, l10n),
                    const _SoftDivider(),
                    _buildPackageDeliveryBlock(l10n),
                    const _SoftDivider(),
                    _buildAboutBlock(l10n),
                    _buildDatesBlock(l10n),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildBottomBar(context, l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageHeader(BuildContext context, bool isFavorite, AppLocalizations l10n) {
    final discount = _discountPercent;

    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 250,
          color: Colors.white,
          child: widget.previewImageBytes != null
              ? Image.memory(
            widget.previewImageBytes!,
            fit: BoxFit.contain,
          )
              : Image.network(
            product.imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Container(
              color: Colors.grey.shade100,
              child: const Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  size: 48,
                  color: Colors.black26,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 14,
          left: 14,
          child: _RoundIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
            light: true,
          ),
        ),
        Positioned(
          top: 14,
          right: 14,
          child: Row(
            children: [
              _RoundIconButton(
                icon: Icons.ios_share_rounded,
                onTap: widget.previewMode ? () {} : _shareProduct,
              ),
              const SizedBox(width: 8),
              _RoundIconButton(
                icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                iconColor: isFavorite ? Colors.white : Colors.white,
                onTap: widget.previewMode
                    ? () {}
                    : _isFavoriteLoading
                    ? null
                    : () => _toggleFavorite(context),
              ),
            ],
          ),
        ),
        if (product.isPromoted)
          Positioned(
            left: 16,
            bottom: 14,
            child: _Badge(
              text: l10n.badgeTop,
              color: accentColor,
              textColor: Colors.black,
              icon: Icons.local_fire_department_rounded,
            ),
          ),
        if (discount != null)
          Positioned(
            right: 16,
            bottom: 14,
            child: _Badge(
              text: '-$discount%',
              color: const Color(0xFFFFE0E3),
              textColor: Colors.redAccent,
            ),
          ),
      ],
    );
  }

  Widget _buildMainInfo(BuildContext context, AppLocalizations l10n) {
    final companyName = product.company.name?.trim().isNotEmpty == true
        ? product.company.name!.trim()
        : product.company.address;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => _openCompany(context),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: accentColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 31,
                backgroundColor: Colors.grey.shade100,
                backgroundImage: product.company.imageUrl.isNotEmpty
                    ? NetworkImage(product.company.imageUrl)
                    : null,
                child: product.company.imageUrl.isEmpty
                    ? const Icon(Icons.store_rounded, color: accentColor)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_finalPrice.toStringAsFixed(0)} \u058F',
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                  ),
                ),
                if (_finalPrice < product.price) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${product.price.toStringAsFixed(0)} \u058F',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9A9A9A),
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  companyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: mutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageDeliveryBlock(AppLocalizations l10n) {
    final rows = <Widget>[];

    if (_packageText(l10n).isNotEmpty) {
      rows.add(
        _InfoRow(
          icon: Icons.inventory_2_outlined,
          text: _packageText(l10n),
        ),
      );
    }

    if ((product.weight ?? '').trim().isNotEmpty) {
      rows.add(
        _InfoRow(
          icon: Icons.scale_outlined,
          text: product.weight!.trim(),
        ),
      );
    }

    switch ((product.deliveryType ?? 'pickup').toLowerCase()) {
      case 'delivery':
        rows.add(
          _InfoRow(
            icon: Icons.local_shipping_outlined,
            text: product.deliveryDays != null
                ? l10n.deliveryWithinDays(product.deliveryDays!)
                : l10n.delivery,
          ),
        );
        break;

      case 'both':
        rows.add(
          _InfoRow(
            icon: Icons.storefront_outlined,
            text: l10n.pickup,
          ),
        );

        rows.add(
          _InfoRow(
            icon: Icons.local_shipping_outlined,
            text: product.deliveryDays != null
                ? l10n.deliveryWithinDays(product.deliveryDays!)
                : l10n.delivery,
          ),
        );
        break;

      default:
        rows.add(
          _InfoRow(
            icon: Icons.storefront_outlined,
            text: l10n.pickup,
          ),
        );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 22, 30, 22),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1) const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildAboutBlock(AppLocalizations l10n) {
    final description = (product.description ?? '').trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 24, 30, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(l10n.aboutProduct),
          const SizedBox(height: 15),
          Text(
            description.isEmpty ? l10n.productDescriptionMissing : description,
            style: const TextStyle(
              fontSize: 12,
              height: 1.28,
              fontWeight: FontWeight.w800,
              color: darkText,
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(l10n.aboutPackage),
        ],
      ),
    );
  }

  Widget _buildDatesBlock(AppLocalizations l10n) {
    final expiration = _formatDate(product.expirationDate);
    final canUse = _formatDate(product.canUseUntil);
    final hasNoExpirationDate = expiration.isEmpty && canUse.isEmpty;
    final unlimited = _localizedUnlimitedText(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 8, 30, 24),
      child: Column(
        children: [
          _DateLine(
            title: l10n.expirationDate,
            value: hasNoExpirationDate ? unlimited : expiration,
          ),
          const SizedBox(height: 22),
          _DateLine(
            title: l10n.usableUntil,
            value: hasNoExpirationDate ? unlimited : canUse,
          ),
        ],
      ),
    );
  }

  String _localizedUnlimitedText(BuildContext context) {
    return switch (Localizations.localeOf(context).languageCode) {
      'ru' => 'Неограничен',
      'hy' => 'Անսահմանափակ',
      _ => 'Unlimited',
    };
  }

  Widget _buildBottomBar(BuildContext context, AppLocalizations l10n) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            _QuantityStepper(
              value: _quantity,
              max: _maxCount,
              onChanged: (value) => setState(() => _quantity = value),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: widget.previewMode
                      ? () {}
                      : _isAdding
                      ? null
                      : () => _addToCart(context, l10n),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    disabledBackgroundColor: accentColor.withOpacity(0.35),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: _isAdding
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text(
                    l10n.addToCartUpper,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToCart(
      BuildContext context,
      AppLocalizations l10n,
      ) async {
    if (_isAdding) return;

    final actionKey = 'deal.cart.add:${product.slug}';
    if (!AppActionGuard.tryLock(actionKey)) return;

    final auth = context.read<AuthProvider>();

    try {
      if (!auth.isLoggedIn) {
        _showLoginRequiredDialog(context);
        return;
      }

      setState(() => _isAdding = true);

      final added = await context.read<CartProvider>().addProduct(
        product,
        quantity: _quantity,
      );

      if (!added) {
        if (!mounted) return;
        AppFeedback.error(
          context,
          l10n.addToCartError,
          key: 'deal.cart.add-error:${product.slug}',
        );
        return;
      }

      if (!mounted) return;

      AppFeedback.success(
        context,
        l10n.addedToCart,
        key: 'deal.cart.added:${product.slug}',
      );

      if (!context.mounted) return;

      // The Deals item still needs checkout, so leave the detail screen
      // and continue directly in the cart.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const CartScreen(),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      AppFeedback.error(
        context,
        l10n.addToCartError,
        key: 'deal.cart.add-error:${product.slug}',
      );
    } finally {
      AppActionGuard.unlock(actionKey);

      if (mounted && _isAdding) {
        setState(() => _isAdding = false);
      }
    }
  }

  Future<void> _toggleFavorite(BuildContext context) async {
    if (_isFavoriteLoading) return;

    final auth = context.read<AuthProvider>();

    if (!auth.isLoggedIn) {
      _showLoginRequiredDialog(context);
      return;
    }

    setState(() => _isFavoriteLoading = true);

    try {
      final favoriteProvider = context.read<FavoriteProvider>();

      if (favoriteProvider.favoriteSlugs.contains(product.slug)) {
        await favoriteProvider.removeFavorite(product.slug);
      } else {
        await favoriteProvider.addFavorite(product.slug, product: product);
      }

      if (mounted) setState(() {});
    } catch (_) {
      if (context.mounted) {
        _showLoginRequiredDialog(context);
      }
    } finally {
      if (mounted) setState(() => _isFavoriteLoading = false);
    }
  }

  void _showLoginRequiredDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(l10n.authRequired),
          content: Text(l10n.loginToUseFavoritesCart),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(),
                  ),
                );

                if (result == true && context.mounted) {
                  await context.read<AuthProvider>().checkLoginStatus();
                  await context.read<FavoriteProvider>().loadFavorites(force: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.login),
            ),
          ],
        );
      },
    );
  }

  void _openCompany(BuildContext context) {
    if (widget.previewMode) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompanyScreen(company: product.company),
      ),
    );
  }

  Future<void> _shareProduct() async {
    if (widget.previewMode) return;
    await shareProduct(context, product);
  }

  String _packageText(AppLocalizations l10n) {
    final package = (product.packageQuantity ?? '').trim();

    if (package.isEmpty) return '';

    return '${l10n.quantityLabel}: $package';
  }

  String _formatDate(String? value) {
    if (value == null || value.trim().isEmpty) return '';

    final parts = value.split('-');
    if (parts.length == 3) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }

    return value;
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool light;
  final Color iconColor;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.light = false,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: light ? Colors.transparent : Colors.black.withOpacity(0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            color: light ? _DealDetailScreenState.accentColor : iconColor,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  final IconData? icon;

  const _Badge({
    required this.text,
    required this.color,
    required this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: _DealDetailScreenState.accentColor, size: 23),
        const SizedBox(width: 13),
        Container(
          width: 1.5,
          height: 26,
          color: _DealDetailScreenState.accentColor,
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w900,
              color: _DealDetailScreenState.darkText,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            color: Color(0xFF555555),
          ),
        ),
        const SizedBox(height: 7),
        Container(
          width: 104,
          height: 1.4,
          color: _DealDetailScreenState.accentColor,
        ),
      ],
    );
  }
}

class _DateLine extends StatelessWidget {
  final String title;
  final String value;

  const _DateLine({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            title,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF555555),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 1.4,
          height: 24,
          color: _DealDetailScreenState.accentColor,
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 100,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: _DealDetailScreenState.darkText,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  const _QuantityStepper({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 37,
      decoration: BoxDecoration(
        color: const Color(0xFFE4E4E4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          _QtyButton(
            icon: Icons.remove_rounded,
            enabled: value > 1,
            onTap: () => onChanged(value - 1),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: _DealDetailScreenState.darkText,
              ),
            ),
          ),
          _QtyButton(
            icon: Icons.add_rounded,
            enabled: value < max,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _QtyButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 34,
        height: 37,
        child: Icon(
          icon,
          size: 18,
          color: enabled ? _DealDetailScreenState.darkText : Colors.grey,
        ),
      ),
    );
  }
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: const Color(0xFFE9E1B8),
    );
  }
}
