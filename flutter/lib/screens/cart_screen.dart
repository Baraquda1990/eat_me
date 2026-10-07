// lib/screens/cart_screen.dart

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../utils/app_feedback.dart';
import '../utils/order_contact_sheet.dart';
import '../utils/legal_consent.dart';
import '../models/product.dart';
import '../widgets/app_error_state.dart';
import '../utils/legal_ui_text.dart';
import 'legal_document_screen.dart';

import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/products_refresh_provider.dart';
import 'login_screen.dart';
import 'product_detail_screen.dart';
import 'deal_detail_screen.dart';
import 'personal_data_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final Set<String> _updatingItems = {};
  bool _isCheckingOut = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    await auth.checkLoginStatus();

    if (!mounted) return;

    if (auth.isLoggedIn) {
      await context.read<CartProvider>().loadCart();
    }
  }

  Future<void> _goLogin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );

    if (!mounted) return;

    if (result == true) {
      await context.read<AuthProvider>().checkLoginStatus();
      await context.read<CartProvider>().loadCart(force: true);
    }
  }

  bool _cartNeedsDeliveryAddress(List<dynamic> items) {
    for (final item in items) {
      if (item is! Map) continue;

      final product = item['product'];
      if (product is! Map) continue;

      final type = product['type']?.toString().trim().toLowerCase() ?? '';
      if (type != 'long') continue;

      final deliveryType =
          product['delivery_type']?.toString().trim().toLowerCase() ?? '';

      // Explicit pickup does not require an address.
      // Current Deals publications use delivery_type='delivery'.
      // "both" stays delivery-capable until a buyer choice is added.
      if (deliveryType != 'pickup') {
        return true;
      }
    }

    return false;
  }

  Future<bool> _ensureCheckoutContactData() async {
    final cartProvider = context.read<CartProvider>();

    // Deals delivery needs the complete delivery profile.
    // HOT keeps the existing phone-only contact flow.
    final requireDeliveryData =
    _cartNeedsDeliveryAddress(cartProvider.items);

    if (!requireDeliveryData) {
      return ensureOrderContactData(
        context,
        requireAddress: false,
      );
    }

    Map<String, dynamic> profile = <String, dynamic>{};

    try {
      profile = await ApiService.getProfile();
    } catch (_) {
      // Open the form below; it will load the profile again and show an error
      // if the backend is really unavailable.
    }

    if (PersonalDataScreen.isDeliveryProfileComplete(profile)) {
      return true;
    }

    if (!mounted) return false;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const PersonalDataScreen(
          requireDeliveryData: true,
        ),
      ),
    );

    if (saved != true || !mounted) return false;

    try {
      final updated = await ApiService.getProfile();
      return PersonalDataScreen.isDeliveryProfileComplete(updated);
    } catch (_) {
      return false;
    }
  }

  Future<void> _openRefundPolicy() async {
    try {
      final documents = await ApiService.getLegalDocuments(
        action: 'all',
        language: Localizations.localeOf(context).languageCode,
      );
      if (!mounted) return;

      final matches = documents.where((doc) => doc.type == 'refund').toList();
      if (matches.isEmpty) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LegalDocumentScreen(document: matches.first),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      AppFeedback.error(
        context,
        LegalUiText.of(context).loadFailed,
        key: 'cart.refund-policy.load-error',
      );
    }
  }

  Future<void> _checkout() async {
    if (_isCheckingOut) return;

    if (!AppActionGuard.tryLock('cart.checkout')) {
      return;
    }

    try {
      final legalReady = await ensureLegalConsent(
        context,
        action: 'checkout',
      );
      if (!legalReady || !mounted) return;

      final contactReady = await _ensureCheckoutContactData();
      if (!contactReady || !mounted) return;

      setState(() => _isCheckingOut = true);

      final cartProvider = context.read<CartProvider>();

      final purchasedSlugs = cartProvider.items
          .map((item) => item is Map ? item['product'] : null)
          .whereType<Map>()
          .map((product) => product['slug']?.toString() ?? '')
          .where((slug) => slug.isNotEmpty)
          .toList();

      final ok = await cartProvider.checkout(status: 'paided');

      if (!mounted) return;

      if (ok) {
        context
            .read<ProductsRefreshProvider>()
            .markPurchasedSlugs(purchasedSlugs);
        context.read<ProductsRefreshProvider>().refreshProducts();
      }

      if (!mounted) return;

      setState(() => _isCheckingOut = false);

      if (ok) {
        AppFeedback.success(
          context,
          AppLocalizations.of(context)!.orderPlaced,
          key: 'cart.checkout.success',
        );
      } else {
        AppFeedback.error(
          context,
          AppLocalizations.of(context)!.orderCheckoutFailed,
          key: 'cart.checkout.error',
        );
      }
    } finally {
      AppActionGuard.unlock('cart.checkout');

      if (mounted && _isCheckingOut) {
        setState(() => _isCheckingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cart = context.watch<CartProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        title: Text(
          l10n.cart,
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF333333)),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/auth_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: !auth.isLoggedIn
            ? _AuthRequired(onLogin: _goLogin)
            : cart.isLoading && cart.items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : cart.loadError != null && cart.items.isEmpty
            ? AppErrorState(
          error: cart.loadError,
          onRetry: () => context.read<CartProvider>().loadCart(
            force: true,
          ),
        )
            : RefreshIndicator(
          onRefresh: () => context.read<CartProvider>().loadCart(
            force: true,
            silent: true,
          ),
          child: cart.items.isEmpty
              ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 160),
              Icon(
                Icons.shopping_bag_outlined,
                size: 86,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  l10n.cartEmpty,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          )
              : ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 220),
            itemCount: cart.items.length + (cart.loadError != null ? 1 : 0),
            itemBuilder: (_, index) {
              if (cart.loadError != null && index == 0) {
                return AppInlineError(
                  error: cart.loadError,
                  onRetry: () => context.read<CartProvider>().loadCart(
                    force: true,
                    silent: true,
                  ),
                );
              }

              final itemIndex = index - (cart.loadError != null ? 1 : 0);
              final item = cart.items[itemIndex];
              return _CartItemCard(
                item: item,
                updatingItems: _updatingItems,
                onUpdateState: (slug, loading) {
                  if (!mounted) return;
                  setState(() {
                    if (loading) {
                      _updatingItems.add(slug);
                    } else {
                      _updatingItems.remove(slug);
                    }
                  });
                },
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: auth.isLoggedIn && cart.items.isNotEmpty
          ? SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 104),
        child: _CartCheckoutBar(
          totalPrice: cart.totalPrice,
          isLoading: _isCheckingOut,
          onCheckout: _checkout,
          onOpenRefundPolicy: _openRefundPolicy,
        ),
      )
          : null,
    );
  }
}



class _AuthRequired extends StatelessWidget {
  final VoidCallback onLogin;

  const _AuthRequired({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1BC00).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 44,
                  color: Color(0xFFD1BC00),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.loginToOpenCart,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.loginToManageCart,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD1BC00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    l10n.login,
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final dynamic item;
  final Set<String> updatingItems;
  final Function(String slug, bool loading) onUpdateState;

  const _CartItemCard({
    required this.item,
    required this.updatingItems,
    required this.onUpdateState,
  });

  int _quantity() {
    final q = item is Map ? item['quantity'] : 1;
    return q is int ? q : int.tryParse(q?.toString() ?? '1') ?? 1;
  }

  Map? _product() {
    final product = item is Map ? item['product'] : null;
    return product is Map ? product : null;
  }

  Future<void> _update(
      BuildContext context,
      Future<bool> Function() action,
      String slug,
      ) async {
    if (slug.isEmpty || updatingItems.contains(slug)) return;

    onUpdateState(slug, true);
    final ok = await action();
    onUpdateState(slug, false);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();

    if (!ok) {
      AppFeedback.error(
        context,
        AppLocalizations.of(context)!.cartUpdateError,
        key: 'cart.item.update-error:$slug',
      );
    }
  }

  void _openProduct(BuildContext context, Map productJson) {
    try {
      final product = Product.fromJson(
        Map<String, dynamic>.from(productJson),
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => product.type.toLowerCase() == 'long'
              ? DealDetailScreen(product: product)
              : ProductDetailScreen(product: product),
        ),
      );
    } catch (_) {
      AppFeedback.error(
        context,
        'Не удалось открыть товар',
        key: 'cart.product.open-error',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cart = context.read<CartProvider>();
    final product = _product();

    final name = product?['name']?.toString() ?? l10n.product;
    final thumbUrl = product?['image_thumb_url']?.toString().trim() ?? '';
    final cardUrl = product?['image_card_url']?.toString().trim() ?? '';
    final originalUrl = product?['image_url']?.toString().trim() ?? '';
    final imageUrl = thumbUrl.isNotEmpty
        ? thumbUrl
        : (cardUrl.isNotEmpty ? cardUrl : originalUrl);
    final slug = product?['slug']?.toString() ?? '';
    final type = product?['type']?.toString() ?? '';
    final quantity = _quantity();
    final price = item is Map ? item['price_by_quantity']?.toString() ?? '' : '';

    final loading = updatingItems.contains(slug);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: product == null
                    ? null
                    : () => _openProduct(context, product),
                borderRadius: BorderRadius.circular(18),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                        ApiService.fixImageUrl(imageUrl),
                        width: 82,
                        height: 82,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => _emptyImage(),
                      )
                          : _emptyImage(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (type.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: type == 'long'
                                    ? const Color(0xFFD1BC00)
                                    .withOpacity(0.12)
                                    : Colors.green.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                type == 'long'
                                    ? l10n.dealType
                                    : l10n.hotType,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: type == 'long'
                                      ? const Color(0xFFD1BC00)
                                      : Colors.green,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  price.isEmpty ? '' : '$price ֏',
                                  style: const TextStyle(
                                    color: Color(0xFFD1BC00),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (product != null)
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                  color: Colors.grey.shade400,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Column(
            children: [
              loading
                  ? const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD1BC00)),
                ),
              )
                  : IconButton(
                onPressed: slug.isEmpty
                    ? null
                    : () => _update(
                  context,
                      () => cart.removeProduct(slug),
                  slug,
                ),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QtyButton(
                    icon: Icons.remove,
                    onTap: loading || slug.isEmpty
                        ? null
                        : () => _update(
                      context,
                          () => cart.decreaseQuantity(
                        productSlug: slug,
                        currentQuantity: quantity,
                      ),
                      slug,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '$quantity',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF333333)),
                    ),
                  ),
                  _QtyButton(
                    icon: Icons.add,
                    onTap: loading || slug.isEmpty
                        ? null
                        : () => _update(
                      context,
                          () => cart.increaseQuantity(
                        productSlug: slug,
                        currentQuantity: quantity,
                      ),
                      slug,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyImage() {
    return Container(
      width: 82,
      height: 82,
      color: Colors.grey.shade200,
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QtyButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? Colors.grey.shade200 : const Color(0xFFF1F1F1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? Colors.grey : const Color(0xFF333333),
          ),
        ),
      ),
    );
  }
}

class _CartCheckoutBar extends StatelessWidget {
  final double totalPrice;
  final bool isLoading;
  final VoidCallback onCheckout;
  final VoidCallback onOpenRefundPolicy;

  const _CartCheckoutBar({
    required this.totalPrice,
    required this.isLoading,
    required this.onCheckout,
    required this.onOpenRefundPolicy,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.total,
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      '${totalPrice.toStringAsFixed(0)} \u058F',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD1BC00),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                    const Color(0xFFD1BC00).withOpacity(0.45),
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text(
                    l10n.checkout,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isLoading ? null : onOpenRefundPolicy,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                LegalUiText.of(context).refundPolicy,
                style: const TextStyle(
                  color: Color(0xFF756A00),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
