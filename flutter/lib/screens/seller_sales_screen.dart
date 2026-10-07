// lib/screens/seller_sales_screen.dart

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

import '../models/product.dart';

import '../services/api_service.dart';
import '../utils/phone_launcher.dart';
import 'seller_order_detail_screen.dart';


String _sellerSalesText(BuildContext context, String key) {
  final languageCode = Localizations.localeOf(context).languageCode;

  const ru = {
    'orderOpenError': '\u041D\u0435 \u0443\u0434\u0430\u043B\u043E\u0441\u044C \u043E\u0442\u043A\u0440\u044B\u0442\u044C \u0437\u0430\u043A\u0430\u0437',
    'allSales': '\u0412\u0441\u0435 \u043F\u0440\u043E\u0434\u0430\u0436\u0438',
    'selectSalesPeriod': '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043F\u0435\u0440\u0438\u043E\u0434 \u043F\u0440\u043E\u0434\u0430\u0436',
    'apply': '\u041F\u0440\u0438\u043C\u0435\u043D\u0438\u0442\u044C',
    'noSalesForSelectedPeriod': '\u041F\u0440\u043E\u0434\u0430\u0436 \u0437\u0430 \u0432\u044B\u0431\u0440\u0430\u043D\u043D\u044B\u0439 \u043F\u0435\u0440\u0438\u043E\u0434 \u043D\u0435\u0442',
    'chooseAnotherPeriod': '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u0434\u0440\u0443\u0433\u043E\u0439 \u043F\u0435\u0440\u0438\u043E\u0434 \u0438\u043B\u0438 \u0441\u0431\u0440\u043E\u0441\u044C\u0442\u0435 \u0444\u0438\u043B\u044C\u0442\u0440.',
    'all': '\u0412\u0441\u0435',
    'period': '\u041F\u0435\u0440\u0438\u043E\u0434',
    'totalAmount': '\u0421\u0443\u043C\u043C\u0430',
    'products': '\u0422\u043E\u0432\u0430\u0440\u043E\u0432',
    'orderNumber': '\u0417\u0430\u043A\u0430\u0437 \u2116',
    'scrollChart': '\u041F\u0440\u043E\u043A\u0440\u0443\u0442\u0438\u0442\u0435 \u0433\u0440\u0430\u0444\u0438\u043A',
    'janShort': '\u042F\u043D\u0432',
    'febShort': '\u0424\u0435\u0432',
    'marShort': '\u041C\u0430\u0440',
    'aprShort': '\u0410\u043F\u0440',
    'mayShort': '\u041C\u0430\u0439',
    'junShort': '\u0418\u044E\u043D',
    'julShort': '\u0418\u044E\u043B',
    'augShort': '\u0410\u0432\u0433',
    'sepShort': '\u0421\u0435\u043D',
    'octShort': '\u041E\u043A\u0442',
    'novShort': '\u041D\u043E\u044F',
    'decShort': '\u0414\u0435\u043A',
  };

  const en = {
    'orderOpenError': 'Failed to open order',
    'allSales': 'All sales',
    'selectSalesPeriod': 'Select sales period',
    'apply': 'Apply',
    'noSalesForSelectedPeriod': 'No sales for the selected period',
    'chooseAnotherPeriod': 'Choose another period or reset the filter.',
    'all': 'All',
    'period': 'Period',
    'totalAmount': 'Amount',
    'products': 'Products',
    'orderNumber': 'Order #',
    'scrollChart': 'Scroll the chart',
    'janShort': 'Jan',
    'febShort': 'Feb',
    'marShort': 'Mar',
    'aprShort': 'Apr',
    'mayShort': 'May',
    'junShort': 'Jun',
    'julShort': 'Jul',
    'augShort': 'Aug',
    'sepShort': 'Sep',
    'octShort': 'Oct',
    'novShort': 'Nov',
    'decShort': 'Dec',
  };

  const hy = {
    'orderOpenError': '\u0549\u0570\u0561\u057B\u0578\u0572\u057E\u0565\u0581 \u0562\u0561\u0581\u0565\u056C \u057A\u0561\u057F\u057E\u0565\u0580\u0568',
    'allSales': '\u0532\u0578\u056C\u0578\u0580 \u057E\u0561\u0573\u0561\u057C\u0584\u0576\u0565\u0580\u0568',
    'selectSalesPeriod': '\u0538\u0576\u057F\u0580\u0565\u0584 \u057E\u0561\u0573\u0561\u057C\u0584\u0576\u0565\u0580\u056B \u056A\u0561\u0574\u0561\u0576\u0561\u056F\u0561\u0570\u0561\u057F\u057E\u0561\u056E\u0568',
    'apply': '\u053F\u056B\u0580\u0561\u057C\u0565\u056C',
    'noSalesForSelectedPeriod': '\u0538\u0576\u057F\u0580\u057E\u0561\u056E \u056A\u0561\u0574\u0561\u0576\u0561\u056F\u0561\u0570\u0561\u057F\u057E\u0561\u056E\u0578\u0582\u0574 \u057E\u0561\u0573\u0561\u057C\u0584\u0576\u0565\u0580 \u0579\u056F\u0561\u0576',
    'chooseAnotherPeriod': '\u0538\u0576\u057F\u0580\u0565\u0584 \u0561\u0575\u056C \u056A\u0561\u0574\u0561\u0576\u0561\u056F\u0561\u0570\u0561\u057F\u057E\u0561\u056E \u056F\u0561\u0574 \u0574\u0561\u0584\u0580\u0565\u0584 \u0586\u056B\u056C\u057F\u0580\u0568\u0589',
    'all': '\u0532\u0578\u056C\u0578\u0580\u0568',
    'period': '\u053A\u0561\u0574\u0561\u0576\u0561\u056F\u0561\u0570\u0561\u057F\u057E\u0561\u056E',
    'totalAmount': '\u0533\u0578\u0582\u0574\u0561\u0580',
    'products': '\u0531\u057A\u0580\u0561\u0576\u0584\u0576\u0565\u0580',
    'orderNumber': '\u054A\u0561\u057F\u057E\u0565\u0580 \u2116',
    'scrollChart': '\u0548\u056C\u0578\u0580\u0565\u0584 \u0563\u0580\u0561\u0586\u056B\u056F\u0568',
    'janShort': '\u0540\u0576\u057E',
    'febShort': '\u0553\u057F\u0580',
    'marShort': '\u0544\u0580\u057F',
    'aprShort': '\u0531\u057A\u0580',
    'mayShort': '\u0544\u0575\u057D',
    'junShort': '\u0540\u0576\u057D',
    'julShort': '\u0540\u056C\u057D',
    'augShort': '\u0555\u0563\u057D',
    'sepShort': '\u054D\u0565\u057A',
    'octShort': '\u0540\u0578\u056F',
    'novShort': '\u0546\u0578\u0575',
    'decShort': '\u0534\u0565\u056F',
  };

  if (languageCode == 'en') return en[key] ?? ru[key] ?? key;
  if (languageCode == 'hy') return hy[key] ?? ru[key] ?? key;
  return ru[key] ?? key;
}
String _normalizeSellerCustomerPhone(dynamic value) {
  final digits = value?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
  return digits.isEmpty ? '' : '+$digits';
}

class SellerSalesScreen extends StatefulWidget {
  final String? productType;

  const SellerSalesScreen({
    super.key,
    this.productType,
  });

  static const Color accentColor = Color(0xFFD1BC00);

  @override
  State<SellerSalesScreen> createState() => _SellerSalesScreenState();
}

class _SellerSalesScreenState extends State<SellerSalesScreen> {
  late Future<_SellerSalesData> _dataFuture;
  String _period = '7d';
  String _historyFilter = 'all';
  DateTimeRange? _customHistoryRange;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_SellerSalesData> _loadData() async {
    final requestedType = widget.productType?.trim().toLowerCase();

    final futures = <Future<dynamic>>[
      ApiService.getSellerSales(),
      ApiService.getSellerStats(),
      if (requestedType != null && requestedType.isNotEmpty)
        ApiService.getMySellerProducts(),
    ];

    final results = await Future.wait<dynamic>(futures);

    final rawSales =
    List<Map<String, dynamic>>.from(results[0] as List);
    final rawStats =
    Map<String, dynamic>.from(results[1] as Map);

    if (requestedType == null || requestedType.isEmpty) {
      return _SellerSalesData(
        sales: rawSales,
        stats: rawStats,
      );
    }

    final sellerProducts = List<Product>.from(results[2] as List);
    final allowedSlugs = sellerProducts
        .where((product) => _matchesRequestedType(product, requestedType))
        .map((product) => product.slug.trim())
        .where((slug) => slug.isNotEmpty)
        .toSet();

    final filteredSales =
    _filterSalesByProductSlugs(rawSales, allowedSlugs);

    final stats = Map<String, dynamic>.from(rawStats);
    stats['total_sales'] = filteredSales.fold<double>(
      0,
          (sum, sale) =>
      sum +
          (double.tryParse(sale['total']?.toString() ?? '0') ?? 0),
    );

    stats['orders_count'] = filteredSales
        .map((sale) => sale['card_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;

    stats['sold_items'] = filteredSales.fold<int>(
      0,
          (sum, sale) =>
      sum +
          (int.tryParse(
            (sale['total_quantity'] ?? sale['quantity'] ?? 0).toString(),
          ) ??
              0),
    );

    return _SellerSalesData(
      sales: filteredSales,
      stats: stats,
    );
  }

  bool _matchesRequestedType(Product product, String requestedType) {
    final actual = product.type.trim().toLowerCase();

    if (requestedType == 'deals' || requestedType == 'long') {
      return actual == 'deals' || actual == 'long';
    }

    return actual == 'hot';
  }

  List<Map<String, dynamic>> _filterSalesByProductSlugs(
      List<Map<String, dynamic>> sales,
      Set<String> allowedSlugs,
      ) {
    if (allowedSlugs.isEmpty) return <Map<String, dynamic>>[];

    final result = <Map<String, dynamic>>[];

    for (final sale in sales) {
      final rawProducts = sale['products'];

      if (rawProducts is List) {
        final matchingProducts = rawProducts
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) {
          final slug = item['product_slug']?.toString().trim() ?? '';
          return allowedSlugs.contains(slug);
        })
            .toList();

        if (matchingProducts.isEmpty) continue;

        final filteredSale = Map<String, dynamic>.from(sale);

        filteredSale['products'] = matchingProducts;
        filteredSale['items_count'] = matchingProducts.length;
        filteredSale['total_quantity'] = matchingProducts.fold<int>(
          0,
              (sum, item) =>
          sum +
              (int.tryParse(item['quantity']?.toString() ?? '0') ?? 0),
        );
        filteredSale['total'] = matchingProducts.fold<double>(
          0,
              (sum, item) =>
          sum +
              (double.tryParse(item['total']?.toString() ?? '0') ?? 0),
        );

        final names = matchingProducts
            .map((item) => item['product_name']?.toString().trim() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();

        filteredSale['products_text'] = names.take(3).join(', ');
        if (names.length > 3) {
          filteredSale['products_text'] =
          '${filteredSale['products_text']} +${names.length - 3}';
        }

        result.add(filteredSale);
        continue;
      }

      final slug = sale['product_slug']?.toString().trim() ?? '';
      if (allowedSlugs.contains(slug)) {
        result.add(Map<String, dynamic>.from(sale));
      }
    }

    return result;
  }

  Future<void> _refresh() async {
    setState(() {
      _dataFuture = _loadData();
    });
    await _dataFuture;
  }


  void _openOrderDetail(Map<String, dynamic> sale) {
    final l10n = AppLocalizations.of(context)!;
    final cardId = int.tryParse(sale['card_id']?.toString() ?? '');
    final companyId = int.tryParse(sale['company_id']?.toString() ?? '');

    if (cardId == null || companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_sellerSalesText(context, 'orderOpenError')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SellerOrderDetailScreen(
          cardId: cardId,
          companyId: companyId,
        ),
      ),
    );
  }

  String _formatMoney(dynamic value) {
    final number = double.tryParse(value?.toString() ?? '0') ?? 0;
    return '${number.toStringAsFixed(0)} \u058F';
  }

  String _formatDate(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return '';

    try {
      final date = DateTime.parse(text).toLocal();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return '$day.$month.$year $hour:$minute';
    } catch (_) {
      return text;
    }
  }

  double _totalSales(List<Map<String, dynamic>> sales) {
    double total = 0;
    for (final sale in sales) {
      total += double.tryParse(sale['total']?.toString() ?? '0') ?? 0;
    }
    return total;
  }

  int _totalItems(List<Map<String, dynamic>> sales) {
    int total = 0;
    for (final sale in sales) {
      total += int.tryParse((sale['total_quantity'] ?? sale['quantity'] ?? 0).toString()) ?? 0;
    }
    return total;
  }

  int _ordersInRange(List<Map<String, dynamic>> sales, Duration duration) {
    final start = DateTime.now().subtract(duration);
    int count = 0;

    for (final sale in sales) {
      try {
        final created = DateTime.parse(sale['created'].toString()).toLocal();
        if (!created.isBefore(start)) count++;
      } catch (_) {}
    }

    return count;
  }

  int _ordersToday(List<Map<String, dynamic>> sales) {
    final now = DateTime.now();
    int count = 0;

    for (final sale in sales) {
      try {
        final created = DateTime.parse(sale['created'].toString()).toLocal();
        if (created.year == now.year &&
            created.month == now.month &&
            created.day == now.day) {
          count++;
        }
      } catch (_) {}
    }

    return count;
  }

  DateTime? _saleCreatedLocal(Map<String, dynamic> sale) {
    try {
      final raw = sale['created']?.toString() ?? '';
      if (raw.trim().isEmpty) return null;
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  List<Map<String, dynamic>> _filteredHistorySales(
      List<Map<String, dynamic>> sales,
      ) {
    final now = DateTime.now();
    final today = _dateOnly(now);

    return sales.where((sale) {
      final created = _saleCreatedLocal(sale);
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
  }

  String _formatShortDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day.$month.$year';
  }

  String _historyFilterTitle(AppLocalizations l10n) {
    if (_historyFilter == 'today') return l10n.today;
    if (_historyFilter == '7d') return l10n.sevenDays;
    if (_historyFilter == '30d') return l10n.thirtyDays;

    if (_historyFilter == 'custom' && _customHistoryRange != null) {
      return '${_formatShortDate(_customHistoryRange!.start)} \u2014 ${_formatShortDate(_customHistoryRange!.end)}';
    }

    return _sellerSalesText(context, 'allSales');
  }

  Future<void> _selectCustomHistoryRange() async {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final initialRange = _customHistoryRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 6)),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initialRange,
      helpText: _sellerSalesText(context, 'selectSalesPeriod'),
      cancelText: l10n.cancel,
      confirmText: _sellerSalesText(context, 'apply'),
      saveText: _sellerSalesText(context, 'apply'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: SellerSalesScreen.accentColor,
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

  List<Map<String, dynamic>> _salesChartData(
      List<Map<String, dynamic>> sales,
      String period,
      ) {
    final now = DateTime.now();
    final Map<String, double> result = {};

    if (period == 'year') {
      for (int i = 11; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final key = '${month.month.toString().padLeft(2, '0')}.${month.year.toString().substring(2)}';
        result[key] = 0;
      }

      for (final sale in sales) {
        try {
          final created = DateTime.parse(sale['created'].toString()).toLocal();
          final key = '${created.month.toString().padLeft(2, '0')}.${created.year.toString().substring(2)}';

          if (result.containsKey(key)) {
            result[key] = result[key]! +
                (double.tryParse(sale['total']?.toString() ?? '0') ?? 0);
          }
        } catch (_) {}
      }
    } else {
      final days = period == '30d' ? 30 : 7;

      for (int i = days - 1; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final key =
            '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}';
        result[key] = 0;
      }

      for (final sale in sales) {
        try {
          final created = DateTime.parse(sale['created'].toString()).toLocal();
          final key =
              '${created.day.toString().padLeft(2, '0')}.${created.month.toString().padLeft(2, '0')}';

          if (result.containsKey(key)) {
            result[key] = result[key]! +
                (double.tryParse(sale['total']?.toString() ?? '0') ?? 0);
          }
        } catch (_) {}
      }
    }

    return result.entries
        .map((e) => {'day': e.key, 'value': e.value})
        .toList();
  }

  String _periodTitle(String period, AppLocalizations l10n) {
    if (period == '30d') return l10n.salesFor30Days;
    if (period == 'year') return l10n.salesForYear;
    return l10n.salesFor7Days;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: Text(
          l10n.sales,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<_SellerSalesData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _EmptyState(
              icon: Icons.error_outline_rounded,
              title: l10n.salesLoadFailed,
              subtitle: snapshot.error.toString(),
            );
          }

          final data = snapshot.data ?? const _SellerSalesData(sales: <Map<String, dynamic>>[], stats: <String, dynamic>{});
          final sales = data.sales;
          final stats = data.stats;

          if (sales.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              color: SellerSalesScreen.accentColor,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 120),
                  _EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: l10n.noSalesYet,
                    subtitle: l10n.salesWillAppearHere,
                  ),
                ],
              ),
            );
          }

          final totalSales = double.tryParse(stats['total_sales']?.toString() ?? '') ?? _totalSales(sales);
          final ordersCount = int.tryParse(stats['orders_count']?.toString() ?? '') ?? sales.length;
          final soldItems = int.tryParse(stats['sold_items']?.toString() ?? '') ?? _totalItems(sales);
          final rating = stats['rating']?.toString() ?? '0';
          final averageCheck = ordersCount > 0 ? totalSales / ordersCount : 0;
          final historySales = _filteredHistorySales(sales);
          final historyTotal = _totalSales(historySales);
          final historyItems = _totalItems(historySales);

          return RefreshIndicator(
            onRefresh: _refresh,
            color: SellerSalesScreen.accentColor,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                _SalesSummaryCard(
                  totalSales: _formatMoney(totalSales),
                  ordersCount: ordersCount,
                  soldItems: soldItems,
                  rating: rating,
                ),
                const SizedBox(height: 16),
                _PeriodSelector(
                  selected: _period,
                  onChanged: (value) => setState(() => _period = value),
                ),
                const SizedBox(height: 12),
                _SalesChartCard(
                  title: _periodTitle(_period, l10n),
                  data: _salesChartData(sales, _period),
                ),
                const SizedBox(height: 16),
                _SalesExtraStatsCard(
                  today: _ordersToday(sales),
                  week: _ordersInRange(sales, const Duration(days: 7)),
                  month: _ordersInRange(sales, const Duration(days: 30)),
                  averageCheck: _formatMoney(averageCheck),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.salesHistory,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${historySales.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: SellerSalesScreen.accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _HistoryFilterBar(
                  selected: _historyFilter,
                  customTitle: _historyFilterTitle(l10n),
                  totalSales: _formatMoney(historyTotal),
                  soldItems: historyItems,
                  onChanged: _setHistoryFilter,
                ),
                const SizedBox(height: 12),
                if (historySales.isEmpty)
                  _InfoMessageCard(
                    icon: Icons.filter_alt_off_outlined,
                    title: _sellerSalesText(context, 'noSalesForSelectedPeriod'),
                    subtitle: _sellerSalesText(context, 'chooseAnotherPeriod'),
                  )
                else
                  ...historySales.map(
                        (sale) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SaleCard(
                        sale: sale,
                        money: _formatMoney,
                        date: _formatDate,
                        onTap: () => _openOrderDetail(sale),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SellerSalesData {
  final List<Map<String, dynamic>> sales;
  final Map<String, dynamic> stats;

  const _SellerSalesData({
    required this.sales,
    required this.stats,
  });
}

class _SalesSummaryCard extends StatelessWidget {
  final String totalSales;
  final int ordersCount;
  final int soldItems;
  final String rating;

  const _SalesSummaryCard({
    required this.totalSales,
    required this.ordersCount,
    required this.soldItems,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  icon: Icons.payments_rounded,
                  title: l10n.revenue,
                  value: totalSales,
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  icon: Icons.shopping_bag_outlined,
                  title: l10n.orders,
                  value: '$ordersCount',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  icon: Icons.inventory_2_outlined,
                  title: l10n.soldProducts,
                  value: '$soldItems',
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  icon: Icons.star_rounded,
                  title: l10n.rating,
                  value: rating,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: SellerSalesScreen.accentColor, size: 26),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _PeriodSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _PeriodButton(
            title: l10n.sevenDays,
            value: '7d',
            selected: selected,
            onChanged: onChanged,
          ),
          _PeriodButton(
            title: l10n.thirtyDays,
            value: '30d',
            selected: selected,
            onChanged: onChanged,
          ),
          _PeriodButton(
            title: l10n.year,
            value: 'year',
            selected: selected,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final String title;
  final String value;
  final String selected;
  final ValueChanged<String> onChanged;

  const _PeriodButton({
    required this.title,
    required this.value,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final active = selected == value;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? SellerSalesScreen.accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: active ? Colors.white : const Color(0xFF333333),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryFilterBar extends StatelessWidget {
  final String selected;
  final String customTitle;
  final String totalSales;
  final int soldItems;
  final ValueChanged<String> onChanged;

  const _HistoryFilterBar({
    required this.selected,
    required this.customTitle,
    required this.totalSales,
    required this.soldItems,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _HistoryFilterChip(
                  title: _sellerSalesText(context, 'all'),
                  value: 'all',
                  selected: selected,
                  onChanged: onChanged,
                ),
                _HistoryFilterChip(
                  title: l10n.today,
                  value: 'today',
                  selected: selected,
                  onChanged: onChanged,
                ),
                _HistoryFilterChip(
                  title: l10n.sevenDays,
                  value: '7d',
                  selected: selected,
                  onChanged: onChanged,
                ),
                _HistoryFilterChip(
                  title: l10n.thirtyDays,
                  value: '30d',
                  selected: selected,
                  onChanged: onChanged,
                ),
                _HistoryFilterChip(
                  title: selected == 'custom' ? customTitle : _sellerSalesText(context, 'period'),
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
                child: _HistoryMiniStat(
                  title: _sellerSalesText(context, 'totalAmount'),
                  value: totalSales,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HistoryMiniStat(
                  title: _sellerSalesText(context, 'products'),
                  value: '$soldItems',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryFilterChip extends StatelessWidget {
  final String title;
  final String value;
  final String selected;
  final ValueChanged<String> onChanged;
  final IconData? icon;

  const _HistoryFilterChip({
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
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: active
                ? SellerSalesScreen.accentColor
                : const Color(0xFFF4F4F4),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? SellerSalesScreen.accentColor
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
                  color: active ? Colors.white : const Color(0xFF555555),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: active ? Colors.white : const Color(0xFF333333),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryMiniStat extends StatelessWidget {
  final String title;
  final String value;

  const _HistoryMiniStat({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SellerSalesScreen.accentColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
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
              fontSize: 15,
              color: Color(0xFF333333),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoMessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoMessageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: SellerSalesScreen.accentColor),
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
              height: 1.3,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesExtraStatsCard extends StatelessWidget {
  final int today;
  final int week;
  final int month;
  final String averageCheck;

  const _SalesExtraStatsCard({
    required this.today,
    required this.week,
    required this.month,
    required this.averageCheck,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _SmallStat(title: l10n.today, value: '$today')),
              Expanded(child: _SmallStat(title: l10n.thisWeek, value: '$week')),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _SmallStat(title: l10n.thisMonth, value: '$month')),
              Expanded(child: _SmallStat(title: l10n.averageCheck, value: averageCheck)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String title;
  final String value;

  const _SmallStat({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;

  const _InfoRow({
    required this.title,
    required this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              '$title:',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: SellerSalesScreen.accentColor,
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
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
}

class _SaleCard extends StatelessWidget {
  final Map<String, dynamic> sale;
  final String Function(dynamic) money;
  final String Function(dynamic) date;
  final VoidCallback onTap;

  const _SaleCard({
    required this.sale,
    required this.money,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final productName = (
        sale['products_text'] ??
            sale['product_names'] ??
            sale['product_name'] ??
            l10n.product)
        .toString();
    final buyer = sale['buyer']?.toString() ?? '';
    final company = sale['company_name']?.toString() ?? '';
    final quantity = (
        sale['total_quantity'] ??
            sale['quantity'] ??
            '1')
        .toString();
    final price = sale['price'] == null ? '' : money(sale['price']);
    final total = money(sale['total']);

    final buyerPhone = _normalizeSellerCustomerPhone(
      sale['buyer_phone'] ?? sale['phone'],
    );
    final buyerAddress = (sale['buyer_address'] ?? sale['address'])?.toString() ?? '';

    final orderId =
        (sale['order_number'] ?? sale['card_id'])?.toString() ?? '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: SellerSalesScreen.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_rounded,
                    color: SellerSalesScreen.accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  total,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: SellerSalesScreen.accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (company.isNotEmpty)
              Text(
                company,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (orderId.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: SellerSalesScreen.accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_sellerSalesText(context, 'orderNumber')} $orderId',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: SellerSalesScreen.accentColor,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            _InfoRow(title: l10n.quantity, value: quantity),
            _InfoRow(title: l10n.price, value: price),
            if (buyer.isNotEmpty) _InfoRow(title: l10n.buyer, value: buyer),
            if (buyerPhone.isNotEmpty)
              InkWell(
                onTap: () => launchPhoneCall(context, buyerPhone),
                borderRadius: BorderRadius.circular(4),
                child: _InfoRow(
                  title: l10n.phone,
                  value: buyerPhone,
                  icon: Icons.phone,
                ),
              ),
            if (buyerAddress.isNotEmpty) _InfoRow(title: l10n.address, value: buyerAddress),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                date(sale['created']),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

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
              Icon(icon, size: 48, color: SellerSalesScreen.accentColor),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SalesChartCard extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> data;

  const _SalesChartCard({
    required this.title,
    required this.data,
  });

  String _axisLabel(String raw, BuildContext context) {
    if (data.length >= 28 && data.length <= 32) {
      final parts = raw.split('.');
      final day = parts.isNotEmpty ? parts.first : raw;
      final month = parts.length > 1 ? parts[1] : '';
      return '${day.replaceFirst(RegExp(r'^0'), '')}.${month.replaceFirst(RegExp(r'^0'), '')}';
    }

    if (data.length == 12) {
      final month = int.tryParse(raw.split('.').first) ?? 0;
      final months = [
        '',
        _sellerSalesText(context, 'janShort'),
        _sellerSalesText(context, 'febShort'),
        _sellerSalesText(context, 'marShort'),
        _sellerSalesText(context, 'aprShort'),
        _sellerSalesText(context, 'mayShort'),
        _sellerSalesText(context, 'junShort'),
        _sellerSalesText(context, 'julShort'),
        _sellerSalesText(context, 'augShort'),
        _sellerSalesText(context, 'sepShort'),
        _sellerSalesText(context, 'octShort'),
        _sellerSalesText(context, 'novShort'),
        _sellerSalesText(context, 'decShort'),
      ];
      if (month >= 1 && month <= 12) return months[month];
    }

    return raw;
  }

  double _chartWidth(double maxWidth) {
    if (data.length >= 28 && data.length <= 32) {
      return data.length * 32;
    }

    if (data.length == 12) {
      return data.length * 46;
    }

    return maxWidth;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxValue = data.fold<double>(
      0,
          (max, item) {
        final value = double.tryParse(item['value']?.toString() ?? '0') ?? 0;
        return value > max ? value : max;
      },
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          if (maxValue <= 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  l10n.noSalesForPeriod,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final chartWidth = _chartWidth(constraints.maxWidth);
                final isScrollable = chartWidth > constraints.maxWidth;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isScrollable)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.swipe_rounded,
                              size: 16,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _sellerSalesText(context, 'scrollChart'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: SizedBox(
                        width: chartWidth,
                        height: 220,
                        child: Column(
                          children: [
                            SizedBox(
                              height: 24,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: data.map((item) {
                                  final value = double.tryParse(
                                    item['value']?.toString() ?? '0',
                                  ) ??
                                      0;

                                  return Expanded(
                                    child: Text(
                                      value > 0 ? value.toStringAsFixed(0) : '',
                                      maxLines: 1,
                                      overflow: TextOverflow.visible,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: data.map((item) {
                                  final value = double.tryParse(
                                    item['value']?.toString() ?? '0',
                                  ) ??
                                      0;
                                  final heightFactor =
                                  (value / maxValue).clamp(0.04, 1.0);

                                  return Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: data.length >= 28 ? 5 : 4,
                                      ),
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: FractionallySizedBox(
                                          heightFactor: heightFactor,
                                          alignment: Alignment.bottomCenter,
                                          child: Container(
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: SellerSalesScreen.accentColor,
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 26,
                              child: Row(
                                children: data.map((item) {
                                  final label = _axisLabel(
                                    item['day']?.toString() ?? '',
                                    context,
                                  );

                                  return Expanded(
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.visible,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        height: 1,
                                        color: Color(0xFF666666),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}


