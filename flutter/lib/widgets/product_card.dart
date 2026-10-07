// lib/widgets/product_card.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';

import '../models/product.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/company_provider.dart';
import '../providers/favorite_provider.dart';
import '../providers/location_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/products_refresh_provider.dart';
import '../utils/app_feedback.dart';
import '../utils/order_contact_sheet.dart';
import '../screens/company_screen.dart';
import '../screens/login_screen.dart';
import '../screens/product_detail_screen.dart';
import '../widgets/loading_skeletons.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onFavoriteChanged;
  final bool showCompanyLogo;

  /// Seller preview support: render the exact customer card before the
  /// product image exists on the server.
  final Uint8List? previewImageBytes;
  final bool previewMode;
  final VoidCallback? onPreviewTap;

  const ProductCard({
    Key? key,
    required this.product,
    this.onFavoriteChanged,
    this.showCompanyLogo = true,
    this.previewImageBytes,
    this.previewMode = false,
    this.onPreviewTap,
  }) : super(key: key);

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
  bool get _isLong => product.type.toString().toLowerCase() == 'long';

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
    final isFavorite = previewMode
        ? false
        : context
        .watch<FavoriteProvider>()
        .favoriteSlugs
        .contains(product.slug);

    final pickupTimeText = _getPickupTimeText(l10n);
    final distanceText = _getDistanceText(context, l10n);
    final discount = _discountPercent;
    final companyName = product.company.name?.trim().isNotEmpty == true
        ? product.company.name!.trim()
        : product.company.address;

    const cardColor = Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        // Компактный режим нужен для узких карточек в горизонтальных списках
        // и небольших телефонов. Геометрия изображения всегда остаётся 3:2.
        final compact = width < 300;
        final veryCompact = width < 250;

        final outerPadding = veryCompact ? 8.0 : compact ? 10.0 : 12.0;
        final imageRadius = compact ? 17.0 : 20.0;
        final cardRadius = compact ? 22.0 : 26.0;
        final titleSize = veryCompact ? 13.0 : compact ? 14.0 : 15.0;
        final productSize = veryCompact ? 10.5 : compact ? 11.0 : 12.0;
        final priceSize = veryCompact ? 13.0 : compact ? 14.0 : 16.0;
        final oldPriceSize = veryCompact ? 9.0 : compact ? 10.0 : 11.0;
        final infoGap = veryCompact ? 8.0 : compact ? 10.0 : 12.0;
        final logoSize = veryCompact ? 32.0 : compact ? 36.0 : 40.0;

        return Container(
          margin: EdgeInsets.fromLTRB(
            compact ? 1 : 2,
            compact ? 5 : 8,
            compact ? 1 : 2,
            compact ? 7 : 12,
          ),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(cardRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: compact ? 12 : 18,
                offset: Offset(0, compact ? 5 : 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: cardColor,
            child: InkWell(
              onTap: () => _openProduct(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      outerPadding,
                      outerPadding,
                      outerPadding,
                      0,
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(imageRadius),
                          child: AspectRatio(
                            aspectRatio: 3 / 2,
                            child: previewImageBytes != null
                                ? Image.memory(
                              previewImageBytes!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            )
                                : CachedNetworkImage(
                              imageUrl: product.cardImageUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              fadeInDuration:
                              const Duration(milliseconds: 180),
                              fadeOutDuration:
                              const Duration(milliseconds: 80),
                              placeholder: (_, _) =>
                              const ImageLoadingShimmer(),
                              errorWidget: (_, _, _) => Container(
                                width: double.infinity,
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 34,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: compact ? 7 : 10,
                          left: compact ? 7 : 10,
                          right: compact ? 76 : 92,
                          child: _AchievementBadges(
                            badges: _achievementBadges(context),
                          ),
                        ),
                        Positioned(
                          top: compact ? 7 : 10,
                          right: compact ? 7 : 10,
                          child: _CircleIconButton(
                            icon: isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFavorite
                                ? Colors.redAccent
                                : Colors.white,
                            backgroundColor: isFavorite
                                ? Colors.white
                                : Colors.black.withValues(alpha: 0.34),
                            onTap: () => _toggleFavorite(context, l10n),
                            size: compact ? 29 : 33,
                            iconSize: compact ? 16 : 18,
                          ),
                        ),
                        if (showCompanyLogo)
                          Positioned(
                            left: compact ? 8 : 12,
                            bottom: compact ? 8 : 12,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _openCompanyProfile(context),
                              child: Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.16),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: product.company.imageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                    imageUrl: product.company.imageUrl,
                                    width: logoSize,
                                    height: logoSize,
                                    fit: BoxFit.cover,
                                    fadeInDuration: const Duration(
                                      milliseconds: 160,
                                    ),
                                    placeholder: (_, __) =>
                                        ImageLoadingShimmer(
                                          width: logoSize,
                                          height: logoSize,
                                        ),
                                    errorWidget: (_, __, ___) => Container(
                                      width: logoSize,
                                      height: logoSize,
                                      color: Colors.grey.shade100,
                                      child: Icon(
                                        Icons.store_rounded,
                                        size: compact ? 16 : 18,
                                      ),
                                    ),
                                  )
                                      : Container(
                                    width: logoSize,
                                    height: logoSize,
                                    color: Colors.grey.shade100,
                                    child: Icon(
                                      Icons.store_rounded,
                                      size: compact ? 16 : 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      outerPadding,
                      compact ? 6 : 7,
                      outerPadding,
                      compact ? 7 : 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          companyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: titleSize,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.25,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: compact ? 2 : 3),
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: productSize,
                            height: 1.05,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.05,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        SizedBox(height: infoGap),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: compact ? 4 : 7,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _RatingPill(
                                    text: _ratingText(l10n),
                                    compact: compact,
                                  ),
                                  _StockPill(
                                    count: product.count,
                                    dineInOnly: product.dineInOnly,
                                    l10n: l10n,
                                    compact: compact,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: compact ? 6 : 10),
                            Flexible(
                              flex: 0,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: compact ? 78 : 105,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        '${_finalPrice.toStringAsFixed(0)} \u058F',
                                        maxLines: 1,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: priceSize,
                                          height: 1,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    if (discount != null)
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          '${product.price.toStringAsFixed(0)} \u058F',
                                          maxLines: 1,
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: oldPriceSize,
                                            height: 1,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFFE99AA0),
                                            decoration:
                                            TextDecoration.lineThrough,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 1,
                    color: Colors.grey.shade100,
                  ),
                  Container(
                    width: double.infinity,
                    color: cardColor,
                    padding: EdgeInsets.fromLTRB(
                      outerPadding,
                      compact ? 5 : 6,
                      outerPadding,
                      compact ? 6 : 7,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: compact ? 24 : 28,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: pickupTimeText.isNotEmpty
                                ? _PickupTimeText(
                              text: pickupTimeText,
                              compact: compact,
                            )
                                : const SizedBox.shrink(),
                          ),
                          if (distanceText.isNotEmpty) ...[
                            SizedBox(width: compact ? 5 : 8),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _openCompanyOnMap(context),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.near_me_rounded,
                                    size: compact ? 11 : 13,
                                    color: Colors.grey.shade700,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    distanceText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: compact ? 9.5 : 11,
                                      height: 1,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF5D5D5D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openProduct(BuildContext context) async {
    if (previewMode && onPreviewTap != null) {
      onPreviewTap!();
      return;
    }

    final actionKey = 'product.open:${product.slug}';
    if (!AppActionGuard.tryLock(actionKey)) return;

    try {
      await Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.black.withOpacity(0.50),
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (_, animation, _) {
            return FadeTransition(
              opacity: animation,
              child: ProductDetailScreen(product: product),
            );
          },
          transitionsBuilder: (_, animation, _, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );

            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(curved),
                child: ScaleTransition(
                  scale: Tween<double>(
                    begin: 0.96,
                    end: 1,
                  ).animate(curved),
                  child: child,
                ),
              ),
            );
          },
        ),
      );
    } finally {
      AppActionGuard.unlock(actionKey);
    }
  }

  Future<void> _toggleFavorite(
      BuildContext context,
      AppLocalizations l10n,
      ) async {
    if (previewMode) return;

    final actionKey = 'favorite.toggle:${product.slug}';
    if (!AppActionGuard.tryLock(actionKey)) return;

    final auth = context.read<AuthProvider>();

    try {
      if (!auth.isLoggedIn) {
        await _showLoginRequiredDialog(context);
        return;
      }

      final favoriteProvider = context.read<FavoriteProvider>();

      final ok = favoriteProvider.favoriteSlugs.contains(product.slug)
          ? await favoriteProvider.removeFavorite(product.slug)
          : await favoriteProvider.addFavorite(product.slug, product: product);

      if (!ok) return;

      onFavoriteChanged?.call();
    } finally {
      AppActionGuard.unlock(actionKey);
    }
  }

  Future<void> _showLoginRequiredDialog(BuildContext context) async {
    const actionKey = 'auth.required.dialog';
    if (!AppActionGuard.tryLock(actionKey)) return;

    final l10n = AppLocalizations.of(context)!;

    try {
      await showDialog<void>(
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
                  backgroundColor: const Color(0xFFD1BC00),
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.login),
              ),
            ],
          );
        },
      );
    } finally {
      AppActionGuard.unlock(actionKey);
    }
  }

  Future<void> _openCompanyProfile(BuildContext context) async {
    if (previewMode) return;

    final actionKey = 'company.open:${product.company.slug}';
    if (!AppActionGuard.tryLock(actionKey)) return;

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CompanyScreen(company: product.company),
        ),
      );
    } finally {
      AppActionGuard.unlock(actionKey);
    }
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
    if (previewMode) return;

    final actionKey = 'product.card.reserve:${product.slug}';
    if (!AppActionGuard.tryLock(actionKey)) return;

    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthProvider>();

    try {
      if (!auth.isLoggedIn) {
        await _showCartLoginRequiredDialog(context);
        return;
      }

      final isHot = product.type.toLowerCase() == 'hot';

      if (isHot) {
        final contactReady = await ensureOrderContactData(
          context,
          requireAddress: false,
        );

        if (!contactReady || !context.mounted) return;

        try {
          await ApiService.reserveHotProduct(
            productSlug: product.slug,
            quantity: 1,
          );

          if (!context.mounted) return;

          context.read<CartProvider>().applyConfirmedProduct(product, quantity: 1);

          if (!context.mounted) return;

          context
              .read<ProductsRefreshProvider>()
              .markPurchasedSlugs(<String>[product.slug]);
          context.read<ProductsRefreshProvider>().refreshProducts();

          AppFeedback.success(
            context,
            l10n.reserveSuccess,
            key: 'product.card.reserve.success:${product.slug}',
          );
        } on HotReservationException catch (error) {
          if (!context.mounted) return;

          AppFeedback.error(
            context,
            _hotReservationErrorMessage(l10n, error),
            key: 'product.card.reserve.${error.code}:${product.slug}',
          );
        } catch (_) {
          if (!context.mounted) return;

          AppFeedback.error(
            context,
            l10n.reserveFailed,
            key: 'product.card.reserve.error:${product.slug}',
          );
        }

        return;
      }

      final cart = context.read<CartProvider>();

      final added = await cart.addProduct(
        product,
        quantity: 1,
      );

      if (!context.mounted) return;

      if (!added) {
        AppFeedback.error(
          context,
          l10n.productAddFailed,
          key: 'product.card.add-error:${product.slug}',
        );
        return;
      }

      AppFeedback.success(
        context,
        l10n.productAddedToCart,
        key: 'product.card.added:${product.slug}',
        cooldown: const Duration(milliseconds: 1500),
      );
    } finally {
      AppActionGuard.unlock(actionKey);
    }
  }

  Future<void> _showCartLoginRequiredDialog(BuildContext context) async {
    const actionKey = 'auth.required.dialog';
    if (!AppActionGuard.tryLock(actionKey)) return;

    final l10n = AppLocalizations.of(context)!;

    try {
      await showDialog<void>(
        context: context,
        builder: (_) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(l10n.authRequired),
            content: Text(
              _isHot
                  ? l10n.loginToReserveProduct
                  : l10n.loginToAddCart,
            ),
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

                  if (!context.mounted) return;

                  if (result == true) {
                    await context.read<AuthProvider>().checkLoginStatus();
                    await context.read<CartProvider>().loadCart(force: true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD1BC00),
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.login),
              ),
            ],
          );
        },
      );
    } finally {
      AppActionGuard.unlock(actionKey);
    }
  }

  void _openCompanyOnMap(BuildContext context) {
    if (previewMode) return;
    final slug = product.company.slug;

    Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);

    Future.delayed(const Duration(milliseconds: 120), () {
      if (!context.mounted) return;

      context.read<NavigationProvider>().openMapForCompany(slug);
    });
  }

  String _shortAddress(String address, AppLocalizations l10n) {
    final text = address.trim();
    if (text.isEmpty) return l10n.addressNotSpecified;

    final parts = text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.isEmpty) return text;
    if (parts.length == 1) return parts.first;

    final last = parts.last;
    final beforeLast = parts[parts.length - 2];

    if (last.length <= 4 && parts.length >= 2) {
      return '$beforeLast, $last';
    }

    return last;
  }

  String _ratingText(AppLocalizations l10n) {
    final rating = product.company.rating;

    if (rating <= 0) {
      return l10n.newStore;
    }

    return rating.toStringAsFixed(1);
  }

  String _getPickupTimeText(AppLocalizations l10n) {
    try {
      if (!_isHot) return '';

      final from = product.pickupFromArmenia;
      final until = product.pickupUntilArmenia;

      if (from == null || until == null) return '';

      String two(int value) => value.toString().padLeft(2, '0');

      final fromTime = '${two(from.hour)}:${two(from.minute)}';
      final untilTime = '${two(until.hour)}:${two(until.minute)}';

      return '${l10n.pickupTime}: $fromTime - $untilTime';
    } catch (_) {
      return '';
    }
  }

  String _getDistanceText(BuildContext context, AppLocalizations l10n) {
    try {
      final companyProvider = context.watch<CompanyProvider>();
      final locationProvider = context.watch<LocationProvider>();

      final mapCompany = companyProvider.companyBySlug(product.company.slug);
      if (mapCompany == null) return '';

      final lat = _toDouble((mapCompany as dynamic).latitude);
      final lng = _toDouble((mapCompany as dynamic).longitude);

      if (lat == null || lng == null) return '';
      if (lat.abs() > 90 || lng.abs() > 180) return '';

      final distanceKm = locationProvider.distanceTo(
        latitude: lat,
        longitude: lng,
      );

      if (distanceKm == null) return '';

      if (distanceKm < 1) {
        return '${(distanceKm * 1000).round()} ${l10n.m}';
      }

      return '${_trimKm(distanceKm)} ${l10n.km}';
    } catch (_) {
      return '';
    }
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _trimKm(double km) {
    if (km >= 10) return km.round().toString();

    final rounded = (km * 10).round() / 10;
    return rounded.toString().replaceAll('.', ',');
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
              Icon(
                badge.icon,
                size: 12,
                color: Colors.white,
              ),
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

class _PickupTimeText extends StatelessWidget {
  final String text;
  final bool compact;

  const _PickupTimeText({required this.text, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.schedule_rounded,
          size: compact ? 11 : 13,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 8.5 : 9,
              height: 1.0,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }
}

class _StockPill extends StatelessWidget {
  final int count;
  final bool dineInOnly;
  final AppLocalizations l10n;
  final bool compact;

  const _StockPill({
    required this.count,
    required this.dineInOnly,
    required this.l10n,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = count <= 0;
    final isEnough = count > 5;
    final text = isEmpty
        ? l10n.outOfStockUpper
        : '${l10n.leftUpper}: $count';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: isEmpty
            ? Colors.grey.shade300
            : isEnough
            ? const Color(0xFF20A85A)
            : const Color(0xFFE50012),
        borderRadius: BorderRadius.circular(999),
      ),
      child: dineInOnly
          ? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_seat_rounded,
            size: compact ? 12 : 13,
            color: isEmpty ? Colors.grey.shade700 : Colors.white,
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            '$count',
            maxLines: 1,
            style: TextStyle(
              fontSize: compact ? 8.5 : 9.5,
              height: 1,
              fontWeight: FontWeight.w900,
              color: isEmpty ? Colors.grey.shade700 : Colors.white,
            ),
          ),
        ],
      )
          : Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 8 : 9,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.1,
          color: isEmpty ? Colors.grey.shade700 : Colors.white,
        ),
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  final String text;
  final bool compact;

  const _RatingPill({required this.text, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFD1BC00),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: compact ? 11 : 13,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: compact ? 9.5 : 11,
              height: 1,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final bool isHot;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.isHot,
    required this.isLoading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFD1BC00),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: isLoading
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Icon(
            Icons.shopping_cart_outlined,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? backgroundColor;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
    this.backgroundColor,
    this.size = 33,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? Colors.black.withOpacity(0.32),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: iconSize,
            color: color,
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

  const _Badge({
    required this.text,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final int count;
  final AppLocalizations l10n;

  const _StockBadge({
    required this.count,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final isLow = count > 0 && count <= 3;
    final isEmpty = count <= 0;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isEmpty
              ? Colors.grey.shade200
              : isLow
              ? Colors.red.shade50
              : Colors.green.shade50,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          isEmpty
              ? l10n.outOfStock
              : '${l10n.leftItems}: $count ${l10n.piecesShort}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: isEmpty
                ? Colors.grey.shade700
                : isLow
                ? Colors.red.shade600
                : Colors.green.shade700,
          ),
        ),
      ),
    );
  }
}