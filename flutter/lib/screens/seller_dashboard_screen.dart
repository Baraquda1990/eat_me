// lib/screens/seller_dashboard_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../utils/app_feedback.dart';

import '../models/product.dart';
import '../services/api_service.dart';
import 'seller_product_form_screen.dart';
import 'seller_deals_product_form_screen.dart';
import 'seller_sales_screen.dart';
import 'seller_reviews_screen.dart';
import 'seller_deals_orders_screen.dart';

class SellerDashboardScreen extends StatefulWidget {
  final String productType;

  const SellerDashboardScreen({
    super.key,
    this.productType = 'hot',
  });

  static const Color accentColor = Color(0xFFD1BC00);

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  late Future<List<Product>> _productsFuture;
  int _selectedSection = 0; // 0 products, 1 sales, 2 reviews
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refreshProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  String _sellerSearchHint(BuildContext context) {
    return switch (Localizations.localeOf(context).languageCode) {
      'ru' => '\u041F\u043E\u0438\u0441\u043A \u0442\u043E\u0432\u0430\u0440\u0430',
      'hy' => '\u0548\u0580\u0578\u0576\u0565\u056C \u0561\u057A\u0580\u0561\u0576\u0584',
      _ => 'Search product',
    };
  }

  String _sellerSearchEmptyTitle(BuildContext context) {
    return switch (Localizations.localeOf(context).languageCode) {
      'ru' => '\u041D\u0438\u0447\u0435\u0433\u043E \u043D\u0435 \u043D\u0430\u0439\u0434\u0435\u043D\u043E',
      'hy' => '\u0548\u0579\u056B\u0576\u0579 \u0579\u056B \u0563\u057F\u0576\u057E\u0565\u056C',
      _ => 'Nothing found',
    };
  }

  String _sellerSearchEmptySubtitle(BuildContext context) {
    return switch (Localizations.localeOf(context).languageCode) {
      'ru' => '\u041F\u043E\u043F\u0440\u043E\u0431\u0443\u0439\u0442\u0435 \u0438\u0437\u043C\u0435\u043D\u0438\u0442\u044C \u0437\u0430\u043F\u0440\u043E\u0441',
      'hy' => '\u0553\u0578\u0580\u0571\u0565\u0584 \u0583\u0578\u056D\u0565\u056C \u0578\u0580\u0578\u0576\u0578\u0582\u0574\u0568',
      _ => 'Try changing the search query',
    };
  }
  void _refreshProducts() {
    _productsFuture = ApiService.getMySellerProducts();
  }

  bool _matchesDashboardProductType(Product product) {
    final expected = widget.productType.trim().toLowerCase();
    final actual = product.type.trim().toLowerCase();

    if (expected == 'deals' || expected == 'long') {
      return actual == 'deals' || actual == 'long';
    }

    return actual == 'hot';
  }

  bool get _isDealsDashboard {
    final type = widget.productType.trim().toLowerCase();
    return type == 'deals' || type == 'long';
  }

  String _dashboardTitle(BuildContext context) {
    if (!_isDealsDashboard) {
      return AppLocalizations.of(context)!.sellerDashboard;
    }

    return switch (Localizations.localeOf(context).languageCode) {
      'ru' => '\u041F\u0430\u043D\u0435\u043B\u044C \u043F\u0440\u043E\u0434\u0430\u0436 Deals',
      'hy' => 'Deals \u057E\u0561\u0573\u0561\u057C\u0584\u056B \u057E\u0561\u0570\u0561\u0576\u0561\u056F',
      _ => 'Sales Dashboard Deals',
    };
  }

  Future<void> _openAddProduct() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _isDealsDashboard
            ? const SellerDealsProductFormScreen()
            : const SellerProductFormScreen(),
      ),
    );

    if (result == true && mounted) {
      setState(_refreshProducts);
      final l10n = AppLocalizations.of(context)!;
      AppFeedback.success(
        context,
        l10n.productPublished,
        key: 'seller.product.published',
      );
    }
  }

  Future<void> _openEditProduct(Product product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _isDealsDashboard
            ? SellerDealsProductFormScreen(product: product)
            : SellerProductFormScreen(product: product),
      ),
    );

    if (result == true && mounted) {
      setState(_refreshProducts);
      final l10n = AppLocalizations.of(context)!;
      AppFeedback.success(
        context,
        l10n.productUpdated,
        key: 'seller.product.updated:${product.slug}',
      );
    }
  }

  Future<void> _toggleProductActive(Product product) async {
    final actionKey = 'seller.product.status:${product.slug}';
    if (!AppActionGuard.tryLock(actionKey)) return;

    final l10n = AppLocalizations.of(context)!;
    final inactiveReason = product.inactiveReason.trim().toLowerCase();
    final isScheduled = !product.isActive && inactiveReason == 'scheduled';

    try {
      if (isScheduled) {
        if (product.count <= 0) {
          AppFeedback.warning(
            context,
            l10n.sellerStockMustBePositive,
            key: 'seller.product.stock:${product.slug}',
          );
          return;
        }

        if (product.type.toLowerCase() == 'hot' && product.pickupExpired) {
          AppFeedback.warning(
            context,
            l10n.pickupExpiredEdit,
            key: 'seller.product.pickup-expired:${product.slug}',
          );
          await _openEditProduct(product);
          return;
        }

        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(l10n.sellerPublishNow),
              content: Text(l10n.sellerPublishNowConfirm),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: SellerDashboardScreen.accentColor,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(l10n.sellerPublishNow),
                ),
              ],
            );
          },
        );

        if (confirmed != true) return;

        try {
          await ApiService.publishSellerProductNow(
            productSlug: product.slug,
          );

          if (!mounted) return;

          setState(_refreshProducts);
          AppFeedback.success(
            context,
            l10n.sellerProductPublishedNow,
            key: 'seller.product.publish-now:${product.slug}',
          );
        } catch (e) {
          if (!mounted) return;

          AppFeedback.error(
            context,
            ApiService.humanizeError(e),
            key: 'seller.product.status-error:${product.slug}',
          );
        }

        return;
      }

      if (!product.isActive && product.count <= 0) {
        AppFeedback.warning(
          context,
          l10n.sellerStockMustBePositive,
          key: 'seller.product.stock:${product.slug}',
        );
        return;
      }

      if (!product.isActive &&
          product.type.toLowerCase() == 'hot' &&
          product.pickupExpired) {
        AppFeedback.warning(
          context,
          l10n.pickupExpiredEdit,
          key: 'seller.product.pickup-expired:${product.slug}',
        );

        await _openEditProduct(product);
        return;
      }

      try {
        await ApiService.setSellerProductActive(
          productSlug: product.slug,
          isActive: !product.isActive,
        );

        if (!mounted) return;

        setState(_refreshProducts);

        final message = product.isActive
            ? l10n.sellerProductRemovedFromSale
            : l10n.sellerProductBackOnSale;

        AppFeedback.success(
          context,
          message,
          key: 'seller.product.status-ok:${product.slug}',
        );
      } catch (e) {
        if (!mounted) return;

        AppFeedback.error(
          context,
          ApiService.humanizeError(e),
          key: 'seller.product.status-error:${product.slug}',
        );
      }
    } finally {
      AppActionGuard.unlock(actionKey);
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final actionKey = 'seller.product.delete:${product.slug}';
    if (!AppActionGuard.tryLock(actionKey)) return;

    final l10n = AppLocalizations.of(context)!;

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(l10n.deleteProduct),
            content: Text(l10n.deleteProductConfirm(product.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  l10n.delete,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;

      try {
        await ApiService.deleteSellerProduct(product.slug);
        if (!mounted) return;

        setState(_refreshProducts);
        AppFeedback.success(
          context,
          l10n.productDeleted,
          key: 'seller.product.deleted:${product.slug}',
        );
      } catch (e) {
        if (!mounted) return;

        AppFeedback.error(
          context,
          '${l10n.productDeleteFailed}: $e',
          key: 'seller.product.delete-error:${product.slug}',
        );
      }
    } finally {
      AppActionGuard.unlock(actionKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: _selectedSection == 0
          ? FloatingActionButton(
        backgroundColor: SellerDashboardScreen.accentColor,
        foregroundColor: Colors.white,
        onPressed: _openAddProduct,
        child: const Icon(Icons.add_rounded),
      )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 26, 26, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Material(
                        color: const Color(0xFFF8F8F8),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).maybePop(),
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .05),
                                blurRadius: 18,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            enabled: _selectedSection == 0,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery =
                                    value.trim().toLowerCase();
                              });
                            },
                            textAlignVertical: TextAlignVertical.center,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333),
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: _sellerSearchHint(context),
                              hintStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFB7B7B7),
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding:
                              const EdgeInsets.fromLTRB(12, 7, 4, 6),
                              suffixIconConstraints:
                              const BoxConstraints(
                                minWidth: 32,
                                minHeight: 30,
                              ),
                              suffixIcon: _searchQuery.isEmpty
                                  ? const Icon(
                                Icons.search_rounded,
                                size: 17,
                                color: Color(0xFFB7B7B7),
                              )
                                  : InkWell(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                                borderRadius:
                                BorderRadius.circular(18),
                                child: const SizedBox(
                                  width: 32,
                                  height: 30,
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Color(0xFF777777),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _DashboardIconButton(
                        icon: Icons.receipt_long_rounded,
                        selected: _selectedSection == 0,
                        onTap: () => setState(() => _selectedSection = 0),
                      ),
                      const SizedBox(width: 16),
                      _DashboardIconButton(
                        icon: Icons.show_chart_rounded,
                        selected: _selectedSection == 1,
                        onTap: () => setState(() => _selectedSection = 1),
                      ),
                      const SizedBox(width: 16),
                      _DashboardIconButton(
                        icon: _isDealsDashboard
                            ? Icons.bolt_rounded
                            : Icons.star_outline_rounded,
                        selected: _selectedSection == 2,
                        onTap: () => setState(() => _selectedSection = 2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _selectedSection == 1
                  ? SellerSalesScreen(productType: widget.productType)
                  : _selectedSection == 2
                  ? (_isDealsDashboard
                  ? const SellerDealsOrdersScreen()
                  : const SellerReviewsScreen())
                  : RefreshIndicator(
                onRefresh: () async {
                  setState(_refreshProducts);
                  await _productsFuture;
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(32, 4, 32, 120),
                  children: [
                    Text(
                      _dashboardTitle(context),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FutureBuilder<List<Product>>(
                      future: _productsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Center(
                                child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError) {
                          return _InfoBox(
                            icon: Icons.error_outline_rounded,
                            title: l10n.productsLoadFailed,
                            subtitle: snapshot.error.toString(),
                          );
                        }

                        final allProducts = snapshot.data ?? [];
                        final channelProducts = allProducts
                            .where(_matchesDashboardProductType)
                            .where((product) {
                          // A sold-out HOT offer is completed: keep it in
                          // sales/history, but remove it from the active
                          // seller products dashboard.
                          if (!_isDealsDashboard && product.count <= 0) {
                            return false;
                          }

                          // Deals stay visible at zero stock so the seller
                          // can see the sold-out badge, pause the listing,
                          // edit it, and replenish stock later.
                          return true;
                        })
                            .toList();

                        if (channelProducts.isEmpty) {
                          return _InfoBox(
                            icon: Icons.inventory_2_outlined,
                            title: l10n.noProductsYet,
                            subtitle: l10n.noProductsYetSubtitle,
                          );
                        }

                        final query = _searchQuery.trim().toLowerCase();

                        final products = query.isEmpty
                            ? channelProducts
                            : channelProducts.where((product) {
                          final productName =
                          product.name.toLowerCase();
                          final description =
                          (product.description ?? '')
                              .toLowerCase();
                          final companyName =
                          (product.company.name ?? '')
                              .toLowerCase();
                          final address =
                          product.company.address.toLowerCase();
                          final slug =
                          product.slug.toLowerCase();

                          return productName.contains(query) ||
                              description.contains(query) ||
                              companyName.contains(query) ||
                              address.contains(query) ||
                              slug.contains(query);
                        }).toList();

                        if (products.isEmpty) {
                          return _InfoBox(
                            icon: Icons.search_off_rounded,
                            title: _sellerSearchEmptyTitle(context),
                            subtitle:
                            _sellerSearchEmptySubtitle(context),
                          );
                        }

                        return Column(
                          children: products
                              .map(
                                (product) => Padding(
                              padding: const EdgeInsets.only(
                                  bottom: 12),
                              child: _ProductCard(
                                product: product,
                                onEdit: () =>
                                    _openEditProduct(product),
                                onDelete: () =>
                                    _deleteProduct(product),
                                onPause: () =>
                                    _toggleProductActive(product),
                              ),
                            ),
                          )
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardIconButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DashboardIconButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? SellerDashboardScreen.accentColor
          : Colors.transparent,
      shape: CircleBorder(
        side: selected
            ? BorderSide.none
            : const BorderSide(color: Color(0xFFB7B7B7), width: 1.2),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 22,
            color: selected ? Colors.white : const Color(0xFF777777),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPause;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onPause,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  Timer? _timer;
  Duration? _remaining;

  Product get product => widget.product;

  bool get _shouldRunCountdown {
    return product.type.trim().toLowerCase() == 'hot' &&
        product.count > 0 &&
        product.pickupUntil != null;
  }

  @override
  void initState() {
    super.initState();
    _updateCountdown();

    if (_shouldRunCountdown) {
      _timer = Timer.periodic(
        const Duration(seconds: 1),
            (_) => _updateCountdown(),
      );
    }
  }

  @override
  void didUpdateWidget(covariant _ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.product.type != product.type ||
        oldWidget.product.pickupUntil != product.pickupUntil ||
        oldWidget.product.isActive != product.isActive ||
        oldWidget.product.count != product.count) {
      _timer?.cancel();
      _updateCountdown();

      if (_shouldRunCountdown) {
        _timer = Timer.periodic(
          const Duration(seconds: 1),
              (_) => _updateCountdown(),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration? _calculateRemaining() {
    if (product.type.toLowerCase() != 'hot' || product.count <= 0) {
      return null;
    }

    final deadline = DateTime.tryParse(
      product.pickupUntil?.trim() ?? '',
    );

    if (deadline == null) return null;

    final difference = deadline.difference(DateTime.now());
    return difference.isNegative ? Duration.zero : difference;
  }

  void _updateCountdown() {
    final next = _calculateRemaining();

    if (!mounted) {
      _remaining = next;
      return;
    }

    setState(() => _remaining = next);

    if (next != null && next.inSeconds <= 0) {
      _timer?.cancel();
    }
  }

  String _countdownText() {
    final remaining = _remaining;
    if (remaining == null) return '--:--:--';

    final totalSeconds = remaining.inSeconds < 0 ? 0 : remaining.inSeconds;
    final days = totalSeconds ~/ Duration.secondsPerDay;
    final hours = (totalSeconds % Duration.secondsPerDay) ~/ Duration.secondsPerHour;
    final minutes =
        (totalSeconds % Duration.secondsPerHour) ~/ Duration.secondsPerMinute;
    final seconds = totalSeconds % Duration.secondsPerMinute;

    final timeText =
        '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';

    if (days <= 0) return timeText;

    final languageCode = Localizations.localeOf(context).languageCode;

    if (languageCode == 'ru') {
      final mod10 = days % 10;
      final mod100 = days % 100;

      final dayWord = mod10 == 1 && mod100 != 11
          ? 'день'
          : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
          ? 'дня'
          : 'дней';

      return '$days $dayWord $timeText';
    }

    if (languageCode == 'hy') {
      return '$days օր $timeText';
    }

    return '$days ${days == 1 ? 'day' : 'days'} $timeText';
  }

  String _label(
      BuildContext context, {
        required String ru,
        required String en,
        required String hy,
      }) {
    return switch (Localizations.localeOf(context).languageCode) {
      'hy' => hy,
      'ru' => ru,
      _ => en,
    };
  }

  String _deliveryDaysText(BuildContext context) {
    final days = product.deliveryDays;
    if (days == null || days <= 0) return '';

    final code = Localizations.localeOf(context).languageCode;

    if (code == 'ru') {
      final mod10 = days % 10;
      final mod100 = days % 100;
      final word = mod10 == 1 && mod100 != 11
          ? '\u0440\u0430\u0431\u043e\u0447\u0438\u0439 \u0434\u0435\u043d\u044c'
          : (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14))
          ? '\u0440\u0430\u0431\u043e\u0447\u0438\u0445 \u0434\u043d\u044f'
          : '\u0440\u0430\u0431\u043e\u0447\u0438\u0445 \u0434\u043d\u0435\u0439';
      return '$days $word';
    }

    if (code == 'hy') {
      return '$days \u0561\u0577\u056d\u0561\u057f\u0561\u0576\u0584\u0561\u0575\u056b\u0576 \u0585\u0580';
    }

    return '$days business ${days == 1 ? 'day' : 'days'}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oldPrice = product.price;
    final sellingPrice = product.getDiscountPrice;
    final description = (product.description ?? '').trim();
    final rating = product.company.rating;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            border: Border.all(
              color: SellerDashboardScreen.accentColor.withValues(alpha: 0.30),
              width: 0.8,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 48,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 1.45,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: product.cardImageUrl.isEmpty
                                  ? Container(
                                color: Colors.grey.shade200,
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 38,
                                  color: Colors.grey.shade500,
                                ),
                              )
                                  : Image.network(
                                product.cardImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: Colors.grey.shade200,
                                  child: Icon(
                                    Icons.image_outlined,
                                    size: 38,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 0.98,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.15,
                                color: Color(0xFF666666),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 52,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: Column(
                          children: [
                            _FigmaStatRow(
                              title: l10n.price,
                              value: '${sellingPrice.toStringAsFixed(0)} \u058F',
                              strong: true,
                            ),
                            _FigmaStatRow(
                              title: l10n.oldPrice,
                              value: '${oldPrice.toStringAsFixed(0)} \u058F',
                              strike: oldPrice > sellingPrice,
                            ),
                            _FigmaStatRow(
                              title: _label(
                                context,
                                ru: '\u041F\u0440\u043E\u0434\u0430\u043D\u043E',
                                en: 'Sold',
                                hy: '\u054E\u0561\u0573\u0561\u057C\u057E\u0561\u056E',
                              ),
                              value: '${product.soldCount}',
                              strong: true,
                            ),
                            _FigmaStatRow(
                              title: _label(
                                context,
                                ru: '\u041E\u0441\u0442\u0430\u043B\u043E\u0441\u044C',
                                en: 'Left',
                                hy: '\u0544\u0576\u0561\u0581\u0565\u056C \u0567',
                              ),
                              value: '${product.count}',
                              strong: true,
                            ),
                            _FigmaStatRow(
                              title: _label(
                                context,
                                ru: '\u041F\u0440\u043E\u0441\u043C\u043E\u0442\u0440\u0435\u043B\u0438',
                                en: 'Viewed',
                                hy: '\u0534\u056B\u057F\u0578\u0582\u0574\u0576\u0565\u0580',
                              ),
                              value: '${product.viewsCount}',
                            ),
                            _FigmaStatRow(
                              title: _label(
                                context,
                                ru: '\u041F\u043E\u0434\u0435\u043B\u0438\u043B\u0438\u0441\u044C',
                                en: 'Shared',
                                hy: '\u053F\u056B\u057D\u057E\u0565\u056C \u0565\u0576',
                              ),
                              value: '${product.sharesCount}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Row(
                  children: [
                    if (product.type.toLowerCase() == 'hot') ...[
                      const Icon(
                        Icons.star_rounded,
                        size: 22,
                        color: SellerDashboardScreen.accentColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (product.type.toLowerCase() == 'hot' &&
                        product.count > 0 &&
                        product.pickupUntil != null) ...[
                      const Icon(
                        Icons.schedule_rounded,
                        size: 18,
                        color: Color(0xFF777777),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _countdownText(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _remaining != null &&
                              _remaining!.inSeconds <=
                                  const Duration(hours: 1).inSeconds
                              ? Colors.red
                              : Colors.black,
                        ),
                      ),
                    ] else if ((product.type.toLowerCase() == 'long' ||
                        product.type.toLowerCase() == 'deals') &&
                        product.deliveryDays != null &&
                        product.deliveryDays! > 0) ...[
                      const Icon(
                        Icons.local_shipping_outlined,
                        size: 17,
                        color: Color(0xFFE30620),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _deliveryDaysText(context),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFE30620),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: SellerDashboardScreen.accentColor
                          .withValues(alpha: .30),
                      width: .8,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: _CardIconActionButton(
                          icon: product.isActive
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: product.isActive
                              ? const Color(0xFFE30620)
                              : product.count <= 0 ||
                              (product.type.toLowerCase() == 'hot' &&
                                  product.pickupExpired)
                              ? const Color(0xFF9E9E9E)
                              : const Color(0xFF20A85A),
                          onTap: widget.onPause,
                        ),
                      ),
                    ),
                    Container(
                      width: .8,
                      height: double.infinity,
                      color: SellerDashboardScreen.accentColor
                          .withValues(alpha: .22),
                    ),
                    Expanded(
                      child: Center(
                        child: _CardIconActionButton(
                          icon: Icons.edit_rounded,
                          color: SellerDashboardScreen.accentColor,
                          iconColor: Colors.black,
                          onTap: widget.onEdit,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if ((product.type.toLowerCase() == 'long' ||
            product.type.toLowerCase() == 'deals') &&
            product.count <= 0)
          const Positioned(
            top: 8,
            left: 8,
            child: _SoldOutBadge(),
          )
        else if (!product.isActive)
          Positioned(
            top: 8,
            left: 8,
            child: _InactiveBadge(
              reason: product.inactiveReason,
            ),
          ),
        Positioned(
          top: 7,
          right: 7,
          child: Material(
            color: const Color(0xFFE30620),
            shape: const CircleBorder(),
            elevation: 1,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onDelete,
              child: const SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FigmaStatRow extends StatelessWidget {
  final String title;
  final String value;
  final bool strong;
  final bool strike;

  const _FigmaStatRow({
    required this.title,
    required this.value,
    this.strong = false,
    this.strike = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.15,
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: strong ? 13 : 11,
                height: 1.15,
                color: strike ? const Color(0xFFE99AA0) : Colors.black,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
                decoration:
                strike ? TextDecoration.lineThrough : TextDecoration.none,
                decorationColor:
                strike ? const Color(0xFFE99AA0) : Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardIconActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _CardIconActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          width: 82,
          height: 24,
          child: Icon(
            icon,
            size: 17,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}

class _SoldOutBadge extends StatelessWidget {
  const _SoldOutBadge();

  @override
  Widget build(BuildContext context) {
    final text = switch (Localizations.localeOf(context).languageCode) {
      'ru' => 'Товар закончился',
      'hy' => 'Ապրանքը սպառվել է',
      _ => 'Out of stock',
    };

    return Container(
      constraints: const BoxConstraints(maxWidth: 166),
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE30620),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .10),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8.5,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: .1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InactiveBadge extends StatelessWidget {
  final String reason;

  const _InactiveBadge({
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final normalizedReason = reason.trim().toLowerCase();

    final scheduled = normalizedReason == 'scheduled';
    final expired = normalizedReason == 'pickup_expired';

    final text = scheduled
        ? l10n.sellerProductStatusScheduled
        : expired
        ? l10n.sellerProductStatusExpired
        : l10n.sellerProductStatusInactive;

    final backgroundColor = scheduled
        ? SellerDashboardScreen.accentColor
        : expired
        ? const Color(0xFFE30620)
        : const Color(0xFF555555);

    final foregroundColor = scheduled ? Colors.black : Colors.white;

    return Container(
      constraints: const BoxConstraints(maxWidth: 166),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .10),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            scheduled
                ? Icons.schedule_rounded
                : expired
                ? Icons.timer_off_outlined
                : Icons.pause_circle_outline_rounded,
            size: 11,
            color: foregroundColor,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 8.2,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: .1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoBox({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: SellerDashboardScreen.accentColor),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
