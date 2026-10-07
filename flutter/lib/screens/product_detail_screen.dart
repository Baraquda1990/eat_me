// lib/screens/product_detail_screen.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../utils/product_share.dart';
import '../l10n/app_localizations.dart';
import '../utils/app_feedback.dart';
import '../utils/order_contact_sheet.dart';
import '../utils/legal_consent.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../utils/phone_launcher.dart';

import '../models/product.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/company_provider.dart';
import '../providers/favorite_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/products_refresh_provider.dart';
import 'company_screen.dart';
import 'login_screen.dart';
import 'cart_screen.dart';
import 'purchases_screen.dart';
import 'company_reviews_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  /// Seller preview support: use this same customer detail screen with a local
  /// image and disabled customer actions.
  final Uint8List? previewImageBytes;
  final bool previewMode;

  /// True only when this screen is opened from purchase history.
  /// Historical order snapshots intentionally contain count=0/is_active=false,
  /// so availability/reservation UI must not be shown in this mode.
  final bool historyMode;

  const ProductDetailScreen({
    Key? key,
    required this.product,
    this.previewImageBytes,
    this.previewMode = false,
    this.historyMode = false,
  }) : super(key: key);

  static const Color accentColor = Color(0xFFD1BC00);
  static const Color darkText = Color(0xFF111111);
  static const Color mutedText = Color(0xFF696969);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  bool _isReserving = false;
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

  bool get _isHot => product.type.toString().toLowerCase() == 'hot';

  String _localizedInline(String ru, String en, String hy) {
    final language = Localizations.localeOf(context).languageCode.toLowerCase();
    if (language == 'hy') return hy;
    if (language == 'en') return en;
    return ru;
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = (widget.previewMode || widget.historyMode)
        ? false
        : _isProductFavorite(context.watch<FavoriteProvider>());
    final distanceText = _getDistanceText(context);
    final pickupDateText = _getPickupDateText(context);
    final pickupTimeText = _getPickupTimeText();
    final companyName = product.company.name?.trim().isNotEmpty == true
        ? product.company.name!.trim()
        : product.company.address;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                14,
                10,
                14,
                widget.historyMode ? 24 : 112,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImageHeader(context, isFavorite),
                    _buildCompanyBlock(context, companyName, distanceText),
                    const _YellowDivider(),
                    _buildProductInfoBlock(context),
                    if (_isHot && product.dineInOnly)
                      _buildDineInNotice(context),
                    const _YellowDivider(),
                    if (_isHot && pickupTimeText.isNotEmpty) ...[
                      _buildPickupBlock(
                        context,
                        pickupDateText,
                        pickupTimeText,
                      ),
                      const _YellowDivider(),
                    ],
                    _buildPhoneBlock(context),
                    const _YellowDivider(),
                    _buildMapBlock(context, distanceText),
                    if (_isHot) _buildRatingBlock(context),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            if (!widget.historyMode)
              Align(
                alignment: Alignment.bottomCenter,
                child: _buildBottomReserveBar(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageHeader(BuildContext context, bool isFavorite) {
    final l10n = AppLocalizations.of(context)!;

    return Stack(
      children: [
        Hero(
          tag: 'product_${product.slug}',
          child: AspectRatio(
            aspectRatio: 3 / 2,
            child: widget.previewImageBytes != null
                ? Image.memory(
              widget.previewImageBytes!,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            )
                : Image.network(
              product.imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) {
                return Container(
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: const Icon(
                    Icons.image_not_supported,
                    size: 48,
                  ),
                );
              },
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.24),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.14),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 14,
          left: 14,
          child: _CircleIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
        ),
        Positioned(
          top: 14,
          right: 14,
          child: Row(
            children: [
              _CircleIconButton(
                icon: Icons.ios_share_rounded,
                onTap: () => _shareProduct(context),
              ),
              const SizedBox(width: 8),
              _CircleIconButton(
                icon: isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isFavorite ? Colors.redAccent : Colors.white,
                onTap: _isFavoriteLoading ? null : () => _toggleFavorite(context),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          bottom: 18,
          child: GestureDetector(
            onTap: () => _openCompany(context),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 29,
                backgroundColor: Colors.grey.shade100,
                backgroundImage: product.company.imageUrl.isNotEmpty
                    ? NetworkImage(product.company.imageUrl)
                    : null,
                child: product.company.imageUrl.isEmpty
                    ? const Icon(Icons.store_rounded, size: 30)
                    : null,
              ),
            ),
          ),
        ),
        if (!widget.historyMode)
          Positioned(
            left: 88,
            bottom: 28,
            child: _StockImageBadge(
              count: product.count,
              dineInOnly: product.dineInOnly,
            ),
          ),
      ],
    );
  }

  Widget _buildCompanyBlock(BuildContext context, String companyName, String distanceText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 13),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openCompany(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              companyName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 21,
                height: 1.1,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.45,
                color: ProductDetailScreen.darkText,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.company.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ProductDetailScreen.mutedText,
                    ),
                  ),
                ),
                if (distanceText.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    distanceText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: ProductDetailScreen.darkText,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  _ProductDescriptionParts _splitProductDescription(String raw) {
    final value = raw.trim();

    if (value.isEmpty) {
      return const _ProductDescriptionParts(
        description: '',
        pickupDetails: '',
      );
    }

    // HOT seller form historically stores pickup instructions inside
    // description as:
    //   <description>\n\nPickup details: <instructions>
    //
    // Strip that technical English marker and render a localized label in UI.
    final marker = RegExp(
      r'(?:^|\n\s*)Pickup details\s*:\s*',
      caseSensitive: false,
    );

    final match = marker.firstMatch(value);
    if (match == null) {
      return _ProductDescriptionParts(
        description: value,
        pickupDetails: '',
      );
    }

    final description = value.substring(0, match.start).trim();
    final pickupDetails = value.substring(match.end).trim();

    return _ProductDescriptionParts(
      description: description,
      pickupDetails: pickupDetails,
    );
  }

  Widget _buildProductInfoBlock(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final parts = _splitProductDescription(product.description ?? '');
    final description = parts.description;
    final pickupDetails = parts.pickupDetails;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 9,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(l10n.productUpper),
                  const SizedBox(height: 9),
                  Text(
                    product.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.15,
                      color: ProductDetailScreen.darkText,
                    ),
                  ),
                ],
              ),
            ),
            const _CenteredVerticalDivider(height: 55),
            const SizedBox(width: 12),
            Expanded(
              flex: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(l10n.descriptionUpper),
                  const SizedBox(height: 9),
                  Text(
                    description.isEmpty
                        ? l10n.descriptionNotSpecified
                        : description,
                    // Показываем описание полностью. Переносы строк и пробелы,
                    // введённые продавцом, сохраняются.
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.23,
                      fontWeight: FontWeight.w800,
                      color: ProductDetailScreen.darkText,
                    ),
                  ),
                  if (pickupDetails.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${l10n.sellerPickupDetailsLabel}:',
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        color: ProductDetailScreen.accentColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pickupDetails,
                      // Инструкции по получению тоже не обрезаем.
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.23,
                        fontWeight: FontWeight.w800,
                        color: ProductDetailScreen.darkText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDineInNotice(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ProductDetailScreen.accentColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: ProductDetailScreen.accentColor.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.event_seat_rounded,
              size: 20,
              color: ProductDetailScreen.darkText,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                _localizedInline(
                  'Только в заведении • доступно мест: ${product.count}',
                  'Dine-in only • available seats: ${product.count}',
                  'Միայն տեղում • հասանելի տեղեր՝ ${product.count}',
                ),
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                  color: ProductDetailScreen.darkText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupBlock(
      BuildContext context,
      String pickupDateText,
      String pickupTimeText,
      ) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
      child: Row(
        children: [
          Expanded(
            flex: 9,
            child: _SectionLabel(
              product.dineInOnly
                  ? _localizedInline(
                'КОГДА ПРИЙТИ',
                'WHEN TO VISIT',
                'ԵՐԲ ԱՅՑԵԼԵԼ',
              )
                  : l10n.pickupUpper,
            ),
          ),
          const _CenteredVerticalDivider(height: 18),
          const SizedBox(width: 12),
          Expanded(
            flex: 10,
            child: Row(
              children: [
                Text(
                  pickupDateText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: ProductDetailScreen.darkText,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    pickupTimeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: ProductDetailScreen.darkText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneBlock(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final phone = product.company.phone?.trim() ?? '';

    if (phone.isEmpty) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () => _callCompany(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Row(
          children: [
            Expanded(
              flex: 9,
              child: _SectionLabel(l10n.phoneUpper),
            ),
            const _CenteredVerticalDivider(height: 18),
            const SizedBox(width: 12),
            Expanded(
              flex: 10,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: ProductDetailScreen.darkText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.call_rounded,
                    color: ProductDetailScreen.accentColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapBlock(BuildContext context, String distanceText) {
    final l10n = AppLocalizations.of(context)!;
    final point = _companyLatLng();

    return GestureDetector(
      onTap: () => _openCompanyOnMap(context),
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFE8EEF2),
          border: Border(
            top: BorderSide(color: Color(0xFFF5EDC6)),
            bottom: BorderSide(color: Color(0xFFF5EDC6)),
          ),
        ),
        child: point == null
            ? _MapFallback(distanceText: distanceText)
            : Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 15.5,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.armenia',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: ProductDetailScreen.accentColor,
                        size: 42,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.06),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.openMap,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: ProductDetailScreen.darkText,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBlock(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final company = product.company;

    final rating = company.rating;
    final reviews = company.reviewsCount;

    final ratingText =
    rating <= 0 ? l10n.newStore : rating.toStringAsFixed(1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.previewMode
            ? null
            : () => _openCompanyReviews(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: ProductDetailScreen.accentColor,
                    size: 30,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ratingText,
                    style: const TextStyle(
                      fontSize: 26,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF555555),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '($reviews)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF777777),
                    ),
                  ),
                  const Spacer(),
                  if (!widget.previewMode)
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 24,
                      color: Color(0xFF9A9A9A),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _RatingLine(
                title: l10n.qualityUpper,
                value: (company.avgQuality / 5).clamp(0, 1),
              ),
              _RatingLine(
                title: l10n.valueUpper,
                value: (company.avgValue / 5).clamp(0, 1),
              ),
              _RatingLine(
                title: l10n.descriptionMatchUpper,
                value: (company.avgDescriptionMatch / 5).clamp(0, 1),
              ),
              _RatingLine(
                title: l10n.serviceUpper,
                value: (company.avgService / 5).clamp(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomReserveBar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final discount = _discountPercent;
    final availableCount = product.count < 0 ? 0 : product.count;
    final canReserve = availableCount > 0 && !_isReserving;
    final totalPrice = _finalPrice * _quantity;
    final oldTotalPrice = product.price * _quantity;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ProductDetailScreen.accentColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _QuantitySelector(
              value: _quantity,
              maxValue: availableCount,
              enabled: canReserve,
              onMinus: _decreaseQuantity,
              onPlus: _increaseQuantity,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 140,
              child: Material(
                color: canReserve
                    ? ProductDetailScreen.accentColor
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: canReserve ? () => _reserve(context) : null,
                  child: SizedBox(
                    height: 34,
                    child: Center(
                      child: _isReserving
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Text(
                        l10n.reserve,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: canReserve
                              ? Colors.white
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (discount != null)
                  Text(
                    '${oldTotalPrice.toStringAsFixed(0)} \u058F',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE99AA0),
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Color(0xFFE99AA0),
                      decorationThickness: 2,
                    ),
                  ),
                Text(
                  '${totalPrice.toStringAsFixed(0)} \u058F',
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    color: ProductDetailScreen.darkText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _increaseQuantity() {
    final maxCount = product.count < 0 ? 0 : product.count;

    if (_quantity >= maxCount) {
      AppFeedback.warning(
        context,
        'Доступно только $maxCount шт.',
        key: 'product.quantity.max:${product.slug}',
      );
      return;
    }

    setState(() => _quantity++);
  }

  void _decreaseQuantity() {
    if (_quantity <= 1) return;
    setState(() => _quantity--);
  }

  bool _isProductFavorite(FavoriteProvider favoriteProvider) {
    return favoriteProvider.favoriteSlugs.contains(product.slug);
  }

  Future<void> _toggleFavorite(BuildContext context) async {
    if (widget.previewMode || widget.historyMode) return;
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
    } catch (_) {
      if (context.mounted) {
        _showLoginRequiredDialog(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isFavoriteLoading = false);
      }
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
          content: Text(l10n.loginToUseProduct),
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
                backgroundColor: ProductDetailScreen.accentColor,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.login),
            ),
          ],
        );
      },
    );
  }

  String _hotReservationErrorMessage(
      AppLocalizations l10n,
      HotReservationException error,
      ) {
    switch (error.code) {
      case 'hot_out_of_stock':
        if ((error.available ?? 0) <= 0) {
          return l10n.outOfStock;
        }
        return '${l10n.remainingCount(error.available!)}';
      case 'hot_unavailable':
      case 'hot_not_found':
        return l10n.productNotFound;
      case 'not_authenticated':
        return l10n.authRequired;
      case 'phone_required':
        return l10n.enterPhoneNumber;
      case 'invalid_quantity':
      case 'not_hot':
        return l10n.reserveFailed;
      default:
        return l10n.reserveFailed;
    }
  }

  Future<void> _reserve(BuildContext context) async {
    if (widget.previewMode || widget.historyMode) return;
    if (_isReserving) return;

    final actionKey = 'product.reserve:${product.slug}';
    if (!AppActionGuard.tryLock(actionKey)) return;

    final auth = context.read<AuthProvider>();
    final l10n = AppLocalizations.of(context)!;

    try {
      if (!auth.isLoggedIn) {
        _showLoginRequiredDialog(context);
        return;
      }

      setState(() {
        _isReserving = true;
      });

      final availableCount = product.count < 0 ? 0 : product.count;

      if (availableCount <= 0) {
        if (!context.mounted) return;

        AppFeedback.error(
          context,
          l10n.outOfStock,
          key: 'product.out-of-stock:${product.slug}',
        );
        return;
      }

      if (_quantity > availableCount) {
        if (mounted) {
          setState(() => _quantity = availableCount);
        }
        if (!context.mounted) return;

        AppFeedback.warning(
          context,
          l10n.remainingCount(availableCount),
          key: 'product.quantity.max:${product.slug}',
        );
        return;
      }

      final isHot = product.type.toLowerCase() == 'hot';

      if (isHot) {
        final legalReady = await ensureLegalConsent(
          context,
          action: 'checkout',
        );
        if (!legalReady || !context.mounted) return;

        final contactReady = await ensureOrderContactData(
          context,
          requireAddress: false,
        );

        if (!contactReady || !context.mounted) return;

        try {
          await ApiService.reserveHotProduct(
            productSlug: product.slug,
            quantity: _quantity,
          );

          if (!context.mounted) return;

          // Reservation is already confirmed by backend, so update the local
          // cart directly instead of issuing a second GET /cart/.
          context.read<CartProvider>().applyConfirmedProduct(
            product,
            quantity: _quantity,
          );

          if (!context.mounted) return;

          context
              .read<ProductsRefreshProvider>()
              .markPurchasedSlugs(<String>[product.slug]);
          context.read<ProductsRefreshProvider>().refreshProducts();

          AppFeedback.success(
            context,
            l10n.reserveSuccess,
            key: 'product.reserve.success:${product.slug}',
          );

          if (!context.mounted) return;

          // HOT reservation is already an order, so continue in My Purchases.
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const PurchasesScreen(),
            ),
          );
        } on HotReservationException catch (error) {
          if (!context.mounted) return;

          AppFeedback.error(
            context,
            _hotReservationErrorMessage(l10n, error),
            key: 'product.reserve.${error.code}:${product.slug}',
          );
        } catch (_) {
          if (!context.mounted) return;

          AppFeedback.error(
            context,
            l10n.reserveFailed,
            key: 'product.reserve.error:${product.slug}',
          );
        }

        return;
      }

      // Non-HOT products keep the normal cart flow.
      final cart = context.read<CartProvider>();

      final added = await cart.addProduct(
        product,
        quantity: _quantity,
      );

      if (!context.mounted) return;

      if (!added) {
        AppFeedback.error(
          context,
          l10n.addToCartError,
          key: 'product.cart.add-error:${product.slug}',
        );
        return;
      }

      AppFeedback.success(
        context,
        l10n.addedToCartSuffix,
        key: 'product.cart.added:${product.slug}',
      );

      if (!context.mounted) return;

      // Delivery/Deals products still require checkout, so continue in cart.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const CartScreen(),
        ),
      );
    } finally {
      AppActionGuard.unlock(actionKey);

      if (mounted && _isReserving) {
        setState(() {
          _isReserving = false;
        });
      }
    }
  }

  Future<void> _callCompany(BuildContext context) async {
    if (widget.previewMode) return;
    final phone = product.company.phone?.trim() ?? '';
    await launchPhoneCall(context, phone);
  }

  Future<void> _shareProduct(BuildContext context) async {
    if (widget.previewMode) return;
    await shareProduct(context, product);
  }

  void _openCompanyReviews(BuildContext context) {
    if (widget.previewMode) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompanyReviewsScreen(
          company: product.company,
        ),
      ),
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

  void _openCompanyOnMap(BuildContext context) {
    if (widget.previewMode) return;
    final slug = product.company.slug;

    Navigator.of(context, rootNavigator: true)
        .popUntil((route) => route.isFirst);

    Future.delayed(const Duration(milliseconds: 120), () {
      if (!context.mounted) return;

      context.read<NavigationProvider>().openMapForCompany(slug);
    });
  }


  LatLng? _companyLatLng() {
    final lat = double.tryParse(product.company.latitude?.replaceAll(',', '.') ?? '');
    final lng = double.tryParse(product.company.longitude?.replaceAll(',', '.') ?? '');

    if (lat == null || lng == null) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    if (lat == 0 && lng == 0) return null;

    return LatLng(lat, lng);
  }

  String _getPickupDateText(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final from = product.pickupFromArmenia;
    final until = product.pickupUntilArmenia;
    final value = from ?? until;

    if (value == null) return '';

    final now = Product.nowInArmenia();
    final isToday = value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;

    if (isToday) return l10n.today;

    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year}';
  }

  String _getPickupTimeText() {
    final from = product.pickupFromArmenia;
    final until = product.pickupUntilArmenia;

    if (from == null || until == null) return '';

    String two(int number) => number.toString().padLeft(2, '0');
    String time(DateTime value) => '${two(value.hour)}:${two(value.minute)}';

    return '${time(from)} - ${time(until)}';
  }

  String _getDistanceText(BuildContext context) {
    try {
      final companyProvider = context.watch<CompanyProvider>();
      final distanceKm = companyProvider.distanceKmBySlug(product.company.slug);

      if (distanceKm == null) return '';

      if (distanceKm < 1) {
        return '${(distanceKm * 1000).round()} м';
      }

      return '${_trimKm(distanceKm)} км';
    } catch (_) {
      return '';
    }
  }

  String _trimKm(double km) {
    if (km >= 10) return km.round().toString();
    final rounded = (km * 10).round() / 10;
    return rounded.toString().replaceAll('.', ',');
  }
}


class _ProductDescriptionParts {
  final String description;
  final String pickupDetails;

  const _ProductDescriptionParts({
    required this.description,
    required this.pickupDetails,
  });
}

class _MapFallback extends StatelessWidget {
  final String distanceText;

  const _MapFallback({required this.distanceText});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_rounded, color: ProductDetailScreen.accentColor),
            const SizedBox(width: 8),
            Text(
              distanceText.isEmpty
                  ? l10n.openMap
                  : '${l10n.openMap} • $distanceText',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: ProductDetailScreen.darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.34),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: color, size: 23),
        ),
      ),
    );
  }
}


class _CenteredVerticalDivider extends StatelessWidget {
  final double height;

  const _CenteredVerticalDivider({required this.height});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 2,
        height: height,
        decoration: BoxDecoration(
          color: ProductDetailScreen.accentColor.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}


class _QuantitySelector extends StatelessWidget {
  final int value;
  final int maxValue;
  final bool enabled;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _QuantitySelector({
    required this.value,
    required this.maxValue,
    required this.enabled,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    final canMinus = enabled && value > 1;
    final canPlus = enabled && value < maxValue;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE7E7E7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QuantityButton(
            icon: Icons.remove_rounded,
            enabled: canMinus,
            onTap: onMinus,
          ),
          SizedBox(
            width: 28,
            child: Text(
              enabled ? '$value' : '0',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111111),
              ),
            ),
          ),
          _QuantityButton(
            icon: Icons.add_rounded,
            enabled: canPlus,
            onTap: onPlus,
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _QuantityButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? const Color(0xFFD1BC00) : Colors.grey.shade300,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

class _YellowDivider extends StatelessWidget {
  const _YellowDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1.2,
      color: ProductDetailScreen.accentColor.withValues(alpha: 0.55),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.3,
        color: Color(0xFF777777),
      ),
    );
  }
}

class _StockImageBadge extends StatelessWidget {
  final int count;
  final bool dineInOnly;

  const _StockImageBadge({
    required this.count,
    required this.dineInOnly,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEmpty = count <= 0;
    final isEnough = count > 5;

    final text = isEmpty
        ? l10n.outOfStock
        : l10n.remainingCount(count);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: isEmpty
            ? Colors.grey.shade500
            : isEnough
            ? const Color(0xFF20A85A)
            : const Color(0xFFE50012),
        borderRadius: BorderRadius.circular(999),
      ),
      child: dineInOnly
          ? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.event_seat_rounded,
            size: 15,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      )
          : Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _RatingLine extends StatelessWidget {
  final String title;
  final double value;

  const _RatingLine({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF5B5B5B),
            ),
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 3.2,
              backgroundColor: ProductDetailScreen.accentColor.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(
                ProductDetailScreen.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
