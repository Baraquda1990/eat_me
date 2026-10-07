// lib/widgets/deal_product_card.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';

import '../models/product.dart';
import '../providers/favorite_provider.dart';
import '../screens/deal_detail_screen.dart';
import '../widgets/loading_skeletons.dart';

class DealProductCard extends StatefulWidget {
  final Product product;
  final double width;
  final Future<void> Function(int quantity) onAddToCart;
  final Future<void> Function() onToggleFavorite;
  final bool isAddingToCart;

  /// Used by the seller form so preview renders this exact customer card
  /// before the product has been uploaded to the server.
  final Uint8List? previewImageBytes;
  final bool previewMode;
  final VoidCallback? onPreviewTap;

  const DealProductCard({
    Key? key,
    required this.product,
    required this.width,
    required this.onAddToCart,
    required this.onToggleFavorite,
    required this.isAddingToCart,
    this.previewImageBytes,
    this.previewMode = false,
    this.onPreviewTap,
  }) : super(key: key);

  @override
  State<DealProductCard> createState() => _DealProductCardState();
}

class _DealProductCardState extends State<DealProductCard> {
  static const Color accentColor = Color(0xFFD1BC00);
  static const Color darkText = Color(0xFF242424);
  static const Color mutedText = Color(0xFF666666);
  static const Color softBg = Colors.white;

  int _quantity = 1;

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

  List<_AchievementBadgeData> _achievementBadges(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final company = product.company;
    final badges = <_AchievementBadgeData>[];

    if (product.isPromoted) {
      badges.add(
        _AchievementBadgeData(
          text: l10n.badgeTop,
          icon: Icons.local_fire_department_rounded,
        ),
      );
    }

    if (company.companyScore >= 90) {
      badges.add(
        _AchievementBadgeData(
          text: l10n.badgeBest,
          icon: Icons.emoji_events_rounded,
        ),
      );
    } else if (company.reviewsCount >= 100 && company.rating >= 4.8) {
      badges.add(
        _AchievementBadgeData(
          text: l10n.badgeChoice,
          icon: Icons.favorite_rounded,
        ),
      );
    } else if (company.rating >= 4.7 && company.reviewsCount >= 20) {
      badges.add(
        _AchievementBadgeData(
          text: l10n.badgeRating,
          icon: Icons.star_rounded,
        ),
      );
    } else if (company.successfulOrders >= 50) {
      badges.add(
        _AchievementBadgeData(
          text: l10n.badgeReliable,
          icon: Icons.verified_rounded,
        ),
      );
    } else if (company.reviewsCount == 0) {
      badges.add(
        _AchievementBadgeData(
          text: l10n.badgeNew,
          icon: Icons.fiber_new_rounded,
        ),
      );
    }

    return badges.take(2).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isFavorite = widget.previewMode
        ? false
        : context
        .watch<FavoriteProvider>()
        .favoriteSlugs
        .contains(product.slug);

    if (_quantity > _maxCount) {
      _quantity = _maxCount;
    }

    final badges = _achievementBadges(context);

    return GestureDetector(
      onTap: () {
        if (widget.previewMode && widget.onPreviewTap != null) {
          widget.onPreviewTap!();
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DealDetailScreen(product: product),
          ),
        );
      },
      child: Container(
        width: widget.width,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: product.isPromoted ? accentColor : Colors.transparent,
            width: product.isPromoted ? 1.7 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: product.isPromoted
                  ? accentColor.withOpacity(0.18)
                  : Colors.black.withOpacity(0.07),
              blurRadius: product.isPromoted ? 18 : 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(isFavorite, badges),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: _buildProductInfoRow(),
            ),
            _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(
      bool isFavorite,
      List<_AchievementBadgeData> badges,
      ) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 3 / 2,
              child: Container(
                color: Colors.white,
                alignment: Alignment.center,
                child: widget.previewImageBytes != null
                    ? Image.memory(
                  widget.previewImageBytes!,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                )
                    : Image.network(
                  product.cardImageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const ImageLoadingShimmer();
                  },
                  errorBuilder: (_, _, _) {
                    return const Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 38,
                        color: Colors.black26,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          top: 12,
          child: _AchievementBadges(badges: badges),
        ),
        Positioned(
          right: 10,
          top: 10,
          child: _TopIconButton(
            icon: isFavorite ? Icons.favorite : Icons.favorite_border,
            iconColor: isFavorite ? Colors.redAccent : const Color(0xFF8E8E93),
            onTap: widget.previewMode ? () {} : widget.onToggleFavorite,
          ),
        ),
      ],
    );
  }

  Widget _buildProductInfoRow() {
    final discount = _discountPercent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFEDEDED)),
          ),
          child: ClipOval(
            child: product.company.imageUrl.isNotEmpty
                ? Image.network(
              product.company.imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return const ImageLoadingShimmer();
              },
              errorBuilder: (_, __, ___) => const Icon(
                Icons.store_rounded,
                size: 20,
                color: darkText,
              ),
            )
                : const Icon(
              Icons.store_rounded,
              size: 20,
              color: darkText,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.25,
                  color: darkText,
                ),
              ),
              if (_packageText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _packageText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: mutedText,
                    letterSpacing: 0.15,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (discount != null) ...[
          const SizedBox(width: 10),
          _TopBadge(
            text: '-$discount%',
            color: const Color(0xFFFFE1E3),
            textColor: Colors.redAccent,
          ),
        ],
      ],
    );
  }

  String get _packageText {
    final raw = (product.packageQuantity ?? '').trim();
    if (raw.isEmpty) return '';

    var normalized = raw
        .replaceAll('×', 'x')
        .replaceAll('Х', 'x')
        .replaceAll('х', 'x')
        .replaceAll('X', 'x')
        .replaceAll('шт.', '')
        .replaceAll('шт', '')
        .replaceAll('порц.', '')
        .replaceAll('порц', '')
        .replaceAll('Г—', 'x')
        .trim();

    if (normalized.toLowerCase().startsWith('x')) {
      normalized = normalized.substring(1).trim();
    }

    if (normalized.isEmpty) return '';
    return '$normalized ×';
  }

  Widget _buildBottomPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
      decoration: const BoxDecoration(
        color: softBg,
        border: Border(
          top: BorderSide(
            color: Color(0xFFEFEFEF),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _QuantityStepper(
            value: _quantity,
            max: _maxCount,
            onChanged: (value) {
              setState(() => _quantity = value);
            },
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_finalPrice < product.price)
                Text(
                  '${product.price.toStringAsFixed(0)} \u058F',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade400,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: Colors.grey.shade400,
                  ),
                ),
              const SizedBox(height: 3),
              Text(
                '${_finalPrice.toStringAsFixed(0)} \u058F',
                style: const TextStyle(
                  fontSize: 17,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: darkText,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.white,
            elevation: 1,
            shadowColor: Colors.black12,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: widget.isAddingToCart
                  ? null
                  : widget.previewMode
                  ? () {}
                  : () async => widget.onAddToCart(_quantity),
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                width: 34,
                height: 34,
                child: Center(
                  child: widget.isAddingToCart
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(
                    Icons.shopping_cart_outlined,
                    size: 20,
                    color: darkText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _AchievementBadgeData {
  final String text;
  final IconData icon;

  const _AchievementBadgeData({
    required this.text,
    required this.icon,
  });
}

class _AchievementBadges extends StatelessWidget {
  final List<_AchievementBadgeData> badges;

  const _AchievementBadges({required this.badges});

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: badges.map((badge) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFD1BC00),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(badge.icon, size: 12, color: Colors.white),
              const SizedBox(width: 3),
              Text(
                badge.text,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _TopBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  final IconData? icon;

  const _TopBadge({
    required this.text,
    required this.color,
    required this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: textColor),
            const SizedBox(width: 2),
          ],
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _TopIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor = _DealProductCardState.darkText,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 39,
          height: 39,
          child: Center(
            child: Icon(
              icon,
              size: 23,
              color: iconColor,
            ),
          ),
        ),
      ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SmallQtyButton(
          icon: Icons.remove_rounded,
          enabled: value > 1,
          onTap: () => onChanged(value - 1),
        ),
        SizedBox(
          width: 30,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF242424),
            ),
          ),
        ),
        _SmallQtyButton(
          icon: Icons.add_rounded,
          enabled: value < max,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _SmallQtyButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _SmallQtyButton({
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
        width: 28,
        height: 34,
        child: Icon(
          icon,
          size: 18,
          color: enabled ? const Color(0xFF242424) : Colors.grey.shade400,
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final int count;

  const _StockBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEmpty = count <= 0;

    return Text(
      isEmpty ? l10n.outOfStock : '${l10n.leftItems}: $count',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isEmpty
            ? Colors.red.shade700
            : Colors.green.shade700,
      ),
    );
  }
}
