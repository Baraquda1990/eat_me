// lib/screens/purchases_screen.dart

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../models/product.dart';
import 'product_detail_screen.dart';
import 'login_screen.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  static const Color accentColor = Color(0xFFD1BC00);

  late Future<List<dynamic>> _ordersFuture;
  bool _isLoggedIn = true;

  String _historyFilter = 'all';
  DateTimeRange? _customHistoryRange;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _loadOrders();
  }

  Future<List<dynamic>> _loadOrders() async {
    final loggedIn = await ApiService.isLoggedIn();

    if (!mounted) return [];

    setState(() => _isLoggedIn = loggedIn);

    if (!loggedIn) return [];

    return ApiService.getPastOrders();
  }

  Future<void> _refresh() async {
    setState(() {
      _ordersFuture = _loadOrders();
    });

    await _ordersFuture;
  }

  Future<void> _goLogin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );

    if (!mounted) return;

    if (result == true) {
      setState(() {
        _ordersFuture = _loadOrders();
      });
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(num value) {
    return '${value.toStringAsFixed(0)} \u058F';
  }

  String _dateText(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '';

    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day.$month.$year $hour:$minute';
  }

  List<Map<String, dynamic>> _orderItems(dynamic order) {
    if (order is! Map) return [];

    final rawItems = order['items'] ?? order['card_item'] ?? [];
    if (rawItems is! List) return [];

    return rawItems
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  double _orderTotal(dynamic order) {
    if (order is! Map) return 0;

    final total = _toDouble(order['total_price']);
    if (total > 0) return total;

    return _orderItems(order).fold<double>(
      0,
          (sum, item) => sum + _toDouble(item['price_by_quantity']),
    );
  }

  int _orderItemsCount(dynamic order) {
    return _orderItems(order).fold<int>(
      0,
          (sum, item) => sum + _toInt(item['quantity']),
    );
  }

  double _ordersTotal(List<dynamic> orders) {
    return orders.fold<double>(0, (sum, order) => sum + _orderTotal(order));
  }

  int _ordersItemsCount(List<dynamic> orders) {
    return orders.fold<int>(0, (sum, order) => sum + _orderItemsCount(order));
  }

  Future<void> _openPurchasedProduct(
      Map<String, dynamic> item,
      ) async {
    final l10n = AppLocalizations.of(context)!;
    final rawProduct = item['product'];

    Product? product;

    // PastOrders already contains a nested ProductsListSerializer object.
    // Prefer it over the public product-detail endpoint because a sold-out
    // HOT product can legitimately be hidden from public_available_products.
    if (rawProduct is Map) {
      try {
        product = Product.fromJson(
          Map<String, dynamic>.from(rawProduct),
        );
      } catch (_) {
        product = null;
      }
    }

    // Fallback for an older order payload that only contains a slug.
    if (product == null) {
      final slug = rawProduct is Map
          ? rawProduct['slug']?.toString().trim() ?? ''
          : item['product_slug']?.toString().trim() ?? '';

      if (slug.isNotEmpty) {
        product = await ApiService.getProductBySlug(slug);
      }
    }

    if (!mounted) return;

    if (product == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.productNotFound),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.50),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, animation, __) {
          return FadeTransition(
            opacity: animation,
            child: ProductDetailScreen(
              product: product!,
              historyMode: true,
            ),
          );
        },
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.045),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  String _filterText(String key) {
    final languageCode = Localizations.localeOf(context).languageCode;

    const ru = <String, String>{
      'all': 'Все',
      'today': 'Сегодня',
      '7d': '7 дней',
      '30d': '30 дней',
      'period': 'Период',
      'selectPeriod': 'Выберите период покупок',
      'apply': 'Применить',
      'cancel': 'Отмена',
      'amount': 'Сумма',
      'orders': 'Заказов',
      'products': 'Товаров',
      'noPurchases': 'Покупок за выбранный период нет',
      'chooseAnother': 'Выберите другой период или сбросьте фильтр.',
    };

    const en = <String, String>{
      'all': 'All',
      'today': 'Today',
      '7d': '7 days',
      '30d': '30 days',
      'period': 'Period',
      'selectPeriod': 'Select purchase period',
      'apply': 'Apply',
      'cancel': 'Cancel',
      'amount': 'Amount',
      'orders': 'Orders',
      'products': 'Products',
      'noPurchases': 'No purchases for the selected period',
      'chooseAnother': 'Choose another period or reset the filter.',
    };

    const hy = <String, String>{
      'all': 'Բոլորը',
      'today': 'Այսօր',
      '7d': '7 օր',
      '30d': '30 օր',
      'period': 'Ժամանակահատված',
      'selectPeriod': 'Ընտրեք գնումների ժամանակահատվածը',
      'apply': 'Կիրառել',
      'cancel': 'Չեղարկել',
      'amount': 'Գումար',
      'orders': 'Պատվերներ',
      'products': 'Ապրանքներ',
      'noPurchases': 'Ընտրված ժամանակահատվածում գնումներ չկան',
      'chooseAnother': 'Ընտրեք այլ ժամանակահատված կամ մաքրեք ֆիլտրը։',
    };

    if (languageCode == 'hy') return hy[key] ?? ru[key] ?? key;
    if (languageCode == 'en') return en[key] ?? ru[key] ?? key;
    return ru[key] ?? key;
  }

  DateTime? _orderCreatedLocal(dynamic order) {
    if (order is! Map) return null;

    try {
      final raw =
          (order['paid_at'] ?? order['created'])?.toString().trim() ?? '';
      if (raw.isEmpty) return null;
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  List<dynamic> _filteredOrders(List<dynamic> orders) {
    final now = DateTime.now();
    final today = _dateOnly(now);

    final filtered = orders.where((order) {
      final created = _orderCreatedLocal(order);
      if (created == null) return false;

      final createdDate = _dateOnly(created);

      switch (_historyFilter) {
        case 'today':
          return createdDate == today;
        case '7d':
          final start = today.subtract(const Duration(days: 6));
          return !createdDate.isBefore(start) && !createdDate.isAfter(today);
        case '30d':
          final start = today.subtract(const Duration(days: 29));
          return !createdDate.isBefore(start) && !createdDate.isAfter(today);
        case 'custom':
          final range = _customHistoryRange;
          if (range == null) return true;

          final start = _dateOnly(range.start);
          final end = _dateOnly(range.end);
          return !createdDate.isBefore(start) && !createdDate.isAfter(end);
        case 'all':
        default:
          return true;
      }
    }).toList();

    // Newest actual purchase first. paid_at is the real checkout time.
    // Old orders fall back to created because their exact payment time did
    // not exist before the backend migration.
    filtered.sort((a, b) {
      final aDate = _orderCreatedLocal(a);
      final bDate = _orderCreatedLocal(b);

      if (aDate != null && bDate != null) {
        final byDate = bDate.compareTo(aDate);
        if (byDate != 0) return byDate;
      } else if (aDate != null) {
        return -1;
      } else if (bDate != null) {
        return 1;
      }

      final aId = a is Map ? _toInt(a['id'] ?? a['card_id']) : 0;
      final bId = b is Map ? _toInt(b['id'] ?? b['card_id']) : 0;
      return bId.compareTo(aId);
    });

    return filtered;
  }

  String _formatShortDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day.$month.$year';
  }

  String _historyFilterTitle() {
    if (_historyFilter == 'custom' && _customHistoryRange != null) {
      return '${_formatShortDate(_customHistoryRange!.start)} — '
          '${_formatShortDate(_customHistoryRange!.end)}';
    }

    return _filterText(_historyFilter);
  }

  Future<void> _selectCustomHistoryRange() async {
    final now = DateTime.now();
    final initialRange = _customHistoryRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 6)),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: now,
      initialDateRange: initialRange,
      helpText: _filterText('selectPeriod'),
      cancelText: _filterText('cancel'),
      confirmText: _filterText('apply'),
      saveText: _filterText('apply'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: accentColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    setState(() {
      _historyFilter = 'custom';
      _customHistoryRange = picked;
    });
  }

  void _setHistoryFilter(String value) {
    if (value == 'custom') {
      _selectCustomHistoryRange();
      return;
    }

    setState(() {
      _historyFilter = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        title: const Text(
          'Мои покупки',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF333333),
          ),
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
        child: !_isLoggedIn
            ? _AuthRequired(onLogin: _goLogin)
            : FutureBuilder<List<dynamic>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _ErrorState(onRetry: _refresh);
            }

            final orders = snapshot.data ?? [];

            if (orders.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 150),
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 88,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        'Покупок пока нет',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final filteredOrders = _filteredOrders(orders);

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
                itemCount: filteredOrders.isEmpty
                    ? 3
                    : filteredOrders.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _PurchasesSummary(
                      ordersCount: filteredOrders.length,
                      itemsCount: _ordersItemsCount(filteredOrders),
                      totalPrice: _money(_ordersTotal(filteredOrders)),
                    );
                  }

                  if (index == 1) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _PurchasesFilterBar(
                        selected: _historyFilter,
                        customTitle: _historyFilterTitle(),
                        totalAmount: _money(_ordersTotal(filteredOrders)),
                        ordersCount: filteredOrders.length,
                        productsCount: _ordersItemsCount(filteredOrders),
                        allTitle: _filterText('all'),
                        todayTitle: _filterText('today'),
                        sevenDaysTitle: _filterText('7d'),
                        thirtyDaysTitle: _filterText('30d'),
                        periodTitle: _filterText('period'),
                        amountTitle: _filterText('amount'),
                        ordersTitle: _filterText('orders'),
                        productsTitle: _filterText('products'),
                        onChanged: _setHistoryFilter,
                      ),
                    );
                  }

                  if (filteredOrders.isEmpty) {
                    return _PurchasesFilterEmpty(
                      title: _filterText('noPurchases'),
                      subtitle: _filterText('chooseAnother'),
                    );
                  }

                  return _OrderCard(
                    order: filteredOrders[index - 2],
                    orderItems: _orderItems,
                    orderTotal: _orderTotal,
                    orderItemsCount: _orderItemsCount,
                    money: _money,
                    dateText: _dateText,
                    onProductTap: _openPurchasedProduct,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PurchasesFilterBar extends StatelessWidget {
  final String selected;
  final String customTitle;
  final String totalAmount;
  final int ordersCount;
  final int productsCount;
  final String allTitle;
  final String todayTitle;
  final String sevenDaysTitle;
  final String thirtyDaysTitle;
  final String periodTitle;
  final String amountTitle;
  final String ordersTitle;
  final String productsTitle;
  final ValueChanged<String> onChanged;

  const _PurchasesFilterBar({
    required this.selected,
    required this.customTitle,
    required this.totalAmount,
    required this.ordersCount,
    required this.productsCount,
    required this.allTitle,
    required this.todayTitle,
    required this.sevenDaysTitle,
    required this.thirtyDaysTitle,
    required this.periodTitle,
    required this.amountTitle,
    required this.ordersTitle,
    required this.productsTitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _PurchasesFilterChip(
                  title: allTitle,
                  value: 'all',
                  selected: selected,
                  onChanged: onChanged,
                ),
                _PurchasesFilterChip(
                  title: todayTitle,
                  value: 'today',
                  selected: selected,
                  onChanged: onChanged,
                ),
                _PurchasesFilterChip(
                  title: sevenDaysTitle,
                  value: '7d',
                  selected: selected,
                  onChanged: onChanged,
                ),
                _PurchasesFilterChip(
                  title: thirtyDaysTitle,
                  value: '30d',
                  selected: selected,
                  onChanged: onChanged,
                ),
                _PurchasesFilterChip(
                  title: selected == 'custom'
                      ? customTitle
                      : periodTitle,
                  value: 'custom',
                  selected: selected,
                  onChanged: onChanged,
                  icon: Icons.date_range_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 6,
                child: _PurchasesMiniStat(
                  title: amountTitle,
                  value: totalAmount,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: _PurchasesMiniStat(
                  title: ordersTitle,
                  value: '$ordersCount',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: _PurchasesMiniStat(
                  title: productsTitle,
                  value: '$productsCount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PurchasesFilterChip extends StatelessWidget {
  final String title;
  final String value;
  final String selected;
  final ValueChanged<String> onChanged;
  final IconData? icon;

  const _PurchasesFilterChip({
    required this.title,
    required this.value,
    required this.selected,
    required this.onChanged,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final active = selected == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFD1BC00)
                : const Color(0xFFF4F4F4),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? const Color(0xFFD1BC00)
                  : const Color(0xFFEAEAEA),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: active
                      ? Colors.white
                      : const Color(0xFF555555),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: active
                      ? Colors.white
                      : const Color(0xFF333333),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchasesMiniStat extends StatelessWidget {
  final String title;
  final String value;

  const _PurchasesMiniStat({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFD1BC00).withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF333333),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchasesFilterEmpty extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PurchasesFilterEmpty({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 34),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.filter_alt_off_outlined,
            size: 46,
            color: Color(0xFFD1BC00),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchasesSummary extends StatelessWidget {
  final int ordersCount;
  final int itemsCount;
  final String totalPrice;

  const _PurchasesSummary({
    required this.ordersCount,
    required this.itemsCount,
    required this.totalPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFD1BC00).withOpacity(0.14),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFD1BC00).withOpacity(0.55),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFFD1BC00),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: Colors.black,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Общая сумма покупок',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF555555),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  totalPrice,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Заказов: $ordersCount • Товаров: $itemsCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final dynamic order;
  final List<Map<String, dynamic>> Function(dynamic order) orderItems;
  final double Function(dynamic order) orderTotal;
  final int Function(dynamic order) orderItemsCount;
  final String Function(num value) money;
  final String Function(dynamic value) dateText;
  final Future<void> Function(Map<String, dynamic> item) onProductTap;

  const _OrderCard({
    required this.order,
    required this.orderItems,
    required this.orderTotal,
    required this.orderItemsCount,
    required this.money,
    required this.dateText,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    final orderMap = order is Map ? order as Map : const {};
    final orderNumber =
        (orderMap['order_number'] ?? orderMap['id'])?.toString() ?? '';
    final created = dateText(orderMap['paid_at'] ?? orderMap['created']);
    final items = orderItems(order);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  orderNumber.isEmpty
                      ? 'Заказ'
                      : 'Заказ #$orderNumber',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Оплачен',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (created.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              created,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...items.map(
                (item) => _PurchasedItem(
              item: item,
              money: money,
              onTap: () => onProductTap(item),
            ),
          ),
          const Divider(height: 22),
          Row(
            children: [
              Text(
                'Товаров: ${orderItemsCount(order)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              const Text(
                'Итого: ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF555555),
                ),
              ),
              Text(
                money(orderTotal(order)),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFD1BC00),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PurchasedItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(num value) money;
  final VoidCallback onTap;

  const _PurchasedItem({
    required this.item,
    required this.money,
    required this.onTap,
  });

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _isDealsProduct(Map product) {
    final type = product['type']?.toString().trim().toLowerCase() ?? '';
    return type == 'long' || type == 'deals';
  }

  String _deliveryStatusText(BuildContext context, String status) {
    final languageCode = Localizations.localeOf(context).languageCode;

    switch (status.trim().toLowerCase()) {
      case 'delivering':
        if (languageCode == 'ru') {
          return '\u0414\u043E\u0441\u0442\u0430\u0432\u043B\u044F\u0435\u0442\u0441\u044F';
        }
        if (languageCode == 'hy') {
          return '\u0531\u057C\u0561\u0584\u057E\u0578\u0582\u0574 \u0567';
        }
        return 'Delivering';

      case 'delivered':
        if (languageCode == 'ru') {
          return '\u0414\u043E\u0441\u0442\u0430\u0432\u043B\u0435\u043D\u043E';
        }
        if (languageCode == 'hy') {
          return '\u0531\u057C\u0561\u0584\u057E\u0561\u056E \u0567';
        }
        return 'Delivered';

      case 'processing':
      default:
        if (languageCode == 'ru') {
          return '\u0412 \u043E\u0431\u0440\u0430\u0431\u043E\u0442\u043A\u0435';
        }
        if (languageCode == 'hy') {
          return '\u0544\u0577\u0561\u056F\u057E\u0578\u0582\u0574 \u0567';
        }
        return 'Processing';
    }
  }

  String _deliveryStatusLabel(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;

    if (languageCode == 'ru') {
      return '\u0421\u0442\u0430\u0442\u0443\u0441';
    }
    if (languageCode == 'hy') {
      return '\u053F\u0561\u0580\u0563\u0561\u057E\u056B\u0573\u0561\u056F';
    }
    return 'Status';
  }

  Color _deliveryStatusBackground(String status) {
    switch (status.trim().toLowerCase()) {
      case 'delivering':
        return const Color(0xFFD1BC00);
      case 'delivered':
        return const Color(0xFF45AA55);
      case 'processing':
      default:
        return const Color(0xFFF4F4F4);
    }
  }

  Color _deliveryStatusForeground(String status) {
    switch (status.trim().toLowerCase()) {
      case 'processing':
        return const Color(0xFFD1BC00);
      case 'delivering':
      case 'delivered':
      default:
        return const Color(0xFF202020);
    }
  }

  IconData _deliveryStatusIcon(String status) {
    switch (status.trim().toLowerCase()) {
      case 'delivering':
        return Icons.local_shipping_outlined;
      case 'delivered':
        return Icons.check_circle_outline_rounded;
      case 'processing':
      default:
        return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final productRaw = item['product'];
    final product = productRaw is Map ? productRaw : const {};

    final name = product['name']?.toString() ?? 'Товар';
    final thumbUrl = product['image_thumb_url']?.toString().trim() ?? '';
    final cardUrl = product['image_card_url']?.toString().trim() ?? '';
    final originalUrl = product['image_url']?.toString().trim() ?? '';
    final imageUrl = thumbUrl.isNotEmpty
        ? thumbUrl
        : (cardUrl.isNotEmpty ? cardUrl : originalUrl);
    final companyRaw = product['company'];
    final company = companyRaw is Map ? companyRaw : const {};
    final companyName = company['name']?.toString() ?? '';
    final quantity = _toInt(item['quantity']);
    final totalPrice = _toDouble(item['price_by_quantity']);
    final pricePerOne = quantity > 0 ? totalPrice / quantity : totalPrice;

    final isDeals = _isDealsProduct(product);
    final deliveryStatus =
        item['delivery_status']?.toString().trim().toLowerCase() ??
            'processing';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                    ApiService.fixImageUrl(imageUrl),
                    width: 66,
                    height: 66,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _emptyImage(),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF333333),
                        ),
                      ),
                      if (companyName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          companyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        '$quantity × ${money(pricePerOne)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      if (isDeals) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_deliveryStatusLabel(context)}:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _deliveryStatusBackground(deliveryStatus),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: deliveryStatus == 'processing'
                                        ? const Color(0xFFD1BC00)
                                        : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _deliveryStatusIcon(deliveryStatus),
                                      size: 14,
                                      color: _deliveryStatusForeground(
                                        deliveryStatus,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        _deliveryStatusText(
                                          context,
                                          deliveryStatus,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: _deliveryStatusForeground(
                                            deliveryStatus,
                                          ),
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
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money(totalPrice),
                      style: const TextStyle(
                        color: Color(0xFFD1BC00),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Color(0xFF9A9A9A),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyImage() {
    return Container(
      width: 66,
      height: 66,
      color: const Color(0xFFEDEDED),
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey,
      ),
    );
  }
}

class _AuthRequired extends StatelessWidget {
  final VoidCallback onLogin;

  const _AuthRequired({required this.onLogin});

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'Войдите в аккаунт',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Чтобы посмотреть историю покупок, нужно авторизоваться.',
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
                  child: const Text(
                    'Войти',
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

class _ErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 64,
              ),
              const SizedBox(height: 14),
              const Text(
                'Не удалось загрузить покупки',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD1BC00),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Повторить',
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
