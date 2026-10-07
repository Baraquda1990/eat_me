// lib/screens/seller_deals_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';
import '../services/seller_delivery_api.dart';
import 'seller_order_detail_screen.dart';
import 'seller_delivery_map_screen.dart';

class SellerDealsOrdersScreen extends StatefulWidget {
  const SellerDealsOrdersScreen({super.key});

  static const Color accentColor = Color(0xFFD1BC00);

  @override
  State<SellerDealsOrdersScreen> createState() =>
      _SellerDealsOrdersScreenState();
}

class _SellerDealsOrdersScreenState
    extends State<SellerDealsOrdersScreen> {
  late Future<List<Map<String, dynamic>>> _deliveriesFuture;
  final Set<int> _updatingItems = <int>{};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _deliveriesFuture = SellerDeliveryApi.getActiveDeliveries();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _deliveriesFuture;
  }

  String _t({
    required String ru,
    required String en,
    required String hy,
  }) {
    return switch (Localizations.localeOf(context).languageCode) {
      'ru' => ru,
      'hy' => hy,
      _ => en,
    };
  }

  String _statusText(String status) {
    switch (status.toLowerCase()) {
      case 'delivering':
        return _t(
          ru: '\u0414\u043E\u0441\u0442\u0430\u0432\u043B\u044F\u0435\u0442\u0441\u044F',
          en: 'Delivering',
          hy: '\u0531\u057C\u0561\u0584\u057E\u0578\u0582\u0574 \u0567',
        );
      case 'delivered':
        return _t(
          ru: '\u0414\u043E\u0441\u0442\u0430\u0432\u043B\u0435\u043D\u043E',
          en: 'Delivered',
          hy: '\u0531\u057C\u0561\u0584\u057E\u0561\u056E \u0567',
        );
      case 'processing':
      default:
        return _t(
          ru: '\u0412 \u043E\u0431\u0440\u0430\u0431\u043E\u0442\u043A\u0435',
          en: 'Processing',
          hy: '\u0544\u0577\u0561\u056F\u057E\u0578\u0582\u0574 \u0567',
        );
    }
  }

  String _businessDaysText(dynamic value) {
    final days = int.tryParse(value?.toString() ?? '') ?? 0;

    if (days <= 0) {
      return _t(
        ru: '\u0421\u0440\u043E\u043A \u0434\u043E\u0441\u0442\u0430\u0432\u043A\u0438 \u043D\u0435 \u0443\u043A\u0430\u0437\u0430\u043D',
        en: 'Delivery time not specified',
        hy: '\u0531\u057C\u0561\u0584\u0574\u0561\u0576 \u056A\u0561\u0574\u056F\u0565\u057F\u0568 \u0576\u0577\u057E\u0561\u056E \u0579\u0567',
      );
    }

    if (Localizations.localeOf(context).languageCode == 'ru') {
      final mod10 = days % 10;
      final mod100 = days % 100;
      final word = mod10 == 1 && mod100 != 11
          ? '\u0440\u0430\u0431\u043E\u0447\u0438\u0439 \u0434\u0435\u043D\u044C'
          : (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14))
          ? '\u0440\u0430\u0431\u043E\u0447\u0438\u0445 \u0434\u043D\u044F'
          : '\u0440\u0430\u0431\u043E\u0447\u0438\u0445 \u0434\u043D\u0435\u0439';
      return '$days $word';
    }

    if (Localizations.localeOf(context).languageCode == 'hy') {
      return '$days \u0561\u0577\u056D\u0561\u057F\u0561\u0576\u0584\u0561\u0575\u056B\u0576 \u0585\u0580';
    }

    return '$days business ${days == 1 ? 'day' : 'days'}';
  }

  Color _statusBackground(String status) {
    switch (status.toLowerCase()) {
      case 'delivering':
        return SellerDealsOrdersScreen.accentColor;
      case 'delivered':
        return const Color(0xFF45AA55);
      case 'processing':
      default:
        return const Color(0xFFF7F7F7);
    }
  }

  Color _statusForeground(String status) {
    return status.toLowerCase() == 'processing'
        ? SellerDealsOrdersScreen.accentColor
        : Colors.black;
  }

  Future<void> _updateStatus(
      Map<String, dynamic> delivery,
      String selected,
      ) async {
    final itemId =
        int.tryParse(delivery['id']?.toString() ?? '') ?? 0;

    if (itemId <= 0 || _updatingItems.contains(itemId)) return;

    final current =
        delivery['delivery_status']?.toString() ?? 'processing';

    if (selected == current) return;

    setState(() => _updatingItems.add(itemId));

    try {
      await SellerDeliveryApi.updateDeliveryStatus(
        itemId: itemId,
        status: selected,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              ru: '\u0421\u0442\u0430\u0442\u0443\u0441 \u0434\u043E\u0441\u0442\u0430\u0432\u043A\u0438 \u043E\u0431\u043D\u043E\u0432\u043B\u0451\u043D',
              en: 'Delivery status updated',
              hy: '\u0531\u057C\u0561\u0584\u0574\u0561\u0576 \u056F\u0561\u0580\u0563\u0561\u057E\u056B\u0573\u0561\u056F\u0568 \u0569\u0561\u0580\u0574\u0561\u0581\u057E\u0565\u056C \u0567',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(_reload);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              ru: '\u041D\u0435 \u0443\u0434\u0430\u043B\u043E\u0441\u044C \u043E\u0431\u043D\u043E\u0432\u0438\u0442\u044C \u0441\u0442\u0430\u0442\u0443\u0441',
              en: 'Could not update status',
              hy: '\u0549\u0570\u0561\u057B\u0578\u0572\u057E\u0565\u0581 \u0569\u0561\u0580\u0574\u0561\u0581\u0576\u0565\u056C \u056F\u0561\u0580\u0563\u0561\u057E\u056B\u0573\u0561\u056F\u0568',
            ),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingItems.remove(itemId));
      }
    }
  }

  void _openOrder(Map<String, dynamic> delivery) {
    final cardId =
    int.tryParse(delivery['card_id']?.toString() ?? '');
    final companyId =
    int.tryParse(delivery['company_id']?.toString() ?? '');

    if (cardId == null || companyId == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SellerOrderDetailScreen(
          cardId: cardId,
          companyId: companyId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: SellerDealsOrdersScreen.accentColor,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _deliveriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 100),
                Center(
                  child: CircularProgressIndicator(
                    color: SellerDealsOrdersScreen.accentColor,
                  ),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(26, 24, 26, 120),
              children: [
                const SizedBox(height: 70),
                const Icon(
                  Icons.error_outline_rounded,
                  size: 44,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 12),
                Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            );
          }

          final deliveries = snapshot.data ?? const <Map<String, dynamic>>[];

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(26, 6, 26, 120),
            children: [
              Text(
                _t(
                  ru: '\u0410\u043A\u0442\u0438\u0432\u043D\u044B\u0435 \u0434\u043E\u0441\u0442\u0430\u0432\u043A\u0438',
                  en: 'Active Deliveries',
                  hy: '\u0531\u056F\u057F\u056B\u057E \u0561\u057C\u0561\u0584\u0578\u0582\u0574\u0576\u0565\u0580',
                ),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 18),
              if (deliveries.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 70),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.local_shipping_outlined,
                        size: 50,
                        color: Color(0xFFBDBDBD),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _t(
                          ru: '\u0410\u043A\u0442\u0438\u0432\u043D\u044B\u0445 \u0434\u043E\u0441\u0442\u0430\u0432\u043E\u043A \u043F\u043E\u043A\u0430 \u043D\u0435\u0442',
                          en: 'No active deliveries yet',
                          hy: '\u0531\u056F\u057F\u056B\u057E \u0561\u057C\u0561\u0584\u0578\u0582\u0574\u0576\u0565\u0580 \u0564\u0565\u057C \u0579\u056F\u0561\u0576',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...deliveries.map(
                      (delivery) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _DeliveryCard(
                      delivery: delivery,
                      statusText: _statusText(
                        delivery['delivery_status']?.toString() ??
                            'processing',
                      ),
                      businessDaysText:
                      _businessDaysText(delivery['delivery_days']),
                      statusBackground: _statusBackground(
                        delivery['delivery_status']?.toString() ??
                            'processing',
                      ),
                      statusForeground: _statusForeground(
                        delivery['delivery_status']?.toString() ??
                            'processing',
                      ),
                      isUpdating: _updatingItems.contains(
                        int.tryParse(delivery['id']?.toString() ?? '') ?? -1,
                      ),
                      onStatusChanged: (value) => _updateStatus(delivery, value),
                      onEdit: () => _openOrder(delivery),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  static const Color accentColor = SellerDealsOrdersScreen.accentColor;

  final Map<String, dynamic> delivery;
  final String statusText;
  final String businessDaysText;
  final Color statusBackground;
  final Color statusForeground;
  final bool isUpdating;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onEdit;

  const _DeliveryCard({
    required this.delivery,
    required this.statusText,
    required this.businessDaysText,
    required this.statusBackground,
    required this.statusForeground,
    required this.isUpdating,
    required this.onStatusChanged,
    required this.onEdit,
  });

  double _money(dynamic value) {
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  double? _coordinate(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
  }

  String _t(
      BuildContext context, {
        required String ru,
        required String en,
        required String hy,
      }) {
    return switch (Localizations.localeOf(context).languageCode) {
      'ru' => ru,
      'hy' => hy,
      _ => en,
    };
  }

  void _openBuyerLocation(
      BuildContext context,
      LatLng point,
      ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SellerDeliveryMapScreen(
          latitude: point.latitude,
          longitude: point.longitude,
          address: delivery['buyer_address']?.toString() ?? '',
          houseNumber:
          delivery['buyer_house_number']?.toString() ?? '',
          floor: delivery['buyer_floor']?.toString() ?? '',
          additionalInfo:
          delivery['buyer_delivery_additional_info']?.toString() ?? '',
        ),
      ),
    );
  }

  Widget _buildBuyerLocationPreview(BuildContext context, LatLng? point) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 96,
        height: 96,
        child: point == null
            ? Container(
          color: const Color(0xFFF2F2F2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_off_outlined,
                color: Colors.black38,
                size: 26,
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  _t(
                    context,
                    ru: 'Точка не указана',
                    en: 'No map point',
                    hy: 'Կետը նշված չէ',
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black45,
                  ),
                ),
              ),
            ],
          ),
        )
            : Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openBuyerLocation(context, point),
            child: Stack(
              fit: StackFit.expand,
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: 16,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'am.appsosa.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 34,
                          height: 34,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFFC73A31),
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fullscreen_rounded,
                      size: 16,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabelForCard(BuildContext context, String status) {
    final languageCode = Localizations.localeOf(context).languageCode;

    if (status == 'delivering') {
      if (languageCode == 'ru') {
        return '\u0414\u043E\u0441\u0442\u0430\u0432\u043B\u044F\u0435\u0442\u0441\u044F';
      }
      if (languageCode == 'hy') {
        return '\u0531\u057C\u0561\u0584\u057E\u0578\u0582\u0574 \u0567';
      }
      return 'Delivering';
    }

    if (status == 'delivered') {
      if (languageCode == 'ru') {
        return '\u0414\u043E\u0441\u0442\u0430\u0432\u043B\u0435\u043D\u043E';
      }
      if (languageCode == 'hy') {
        return '\u0531\u057C\u0561\u0584\u057E\u0561\u056E \u0567';
      }
      return 'Delivered';
    }

    if (languageCode == 'ru') {
      return '\u0412 \u043E\u0431\u0440\u0430\u0431\u043E\u0442\u043A\u0435';
    }
    if (languageCode == 'hy') {
      return '\u0544\u0577\u0561\u056F\u057E\u0578\u0582\u0574 \u0567';
    }
    return 'Processing';
  }


  Color _statusOptionBackground(String status) {
    switch (status) {
      case 'delivering':
        return const Color(0xFFD1BC00);
      case 'delivered':
        return const Color(0xFF45AA55);
      case 'processing':
      default:
        return const Color(0xFFF7F7F7);
    }
  }

  Color _statusOptionForeground(String status) {
    switch (status) {
      case 'processing':
        return const Color(0xFFD1BC00);
      case 'delivering':
      case 'delivered':
      default:
        return const Color(0xFF1F1F1F);
    }
  }

  Color _statusOptionBorder(String status) {
    return status == 'processing'
        ? const Color(0xFFD1BC00)
        : Colors.transparent;
  }

  Widget _statusDropdownItem(
      BuildContext context,
      String status,
      ) {
    return Container(
      width: double.infinity,
      height: 34,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _statusOptionBackground(status),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _statusOptionBorder(status),
          width: 1,
        ),
      ),
      child: Text(
        _statusLabelForCard(context, status),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: _statusOptionForeground(status),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sellingPrice = _money(delivery['price']);
    final fullPrice = _money(delivery['full_price']);
    final quantity =
        int.tryParse(delivery['quantity']?.toString() ?? '0') ?? 0;
    final package =
        delivery['package_quantity']?.toString().trim() ?? '';
    final imageUrl = ApiService.fixImageUrl(
      delivery['product_image_url']?.toString() ?? '',
    );
    final productName =
        delivery['product_name']?.toString() ?? '';
    final address =
        delivery['buyer_address']?.toString().trim() ?? '';
    final phone =
        delivery['buyer_phone']?.toString().trim() ?? '';
    final houseNumber =
        delivery['buyer_house_number']?.toString().trim() ?? '';
    final floor =
        delivery['buyer_floor']?.toString().trim() ?? '';
    final additionalInfo =
        delivery['buyer_delivery_additional_info']?.toString().trim() ?? '';
    final orderNumber =
        (delivery['order_number'] ?? delivery['card_id'])
            ?.toString()
            .trim() ??
            '';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.28),
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 112,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 1.15,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: imageUrl.isEmpty
                                  ? Container(
                                color: Colors.white,
                                child: const Icon(
                                  Icons.image_outlined,
                                  color: Colors.black38,
                                ),
                              )
                                  : Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Container(
                                      color: Colors.white,
                                      child: const Icon(
                                        Icons.image_outlined,
                                        color: Colors.black38,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (package.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              package,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          children: [
                            _DeliveryStatRow(
                              title: 'Selling price',
                              value:
                              '${sellingPrice.toStringAsFixed(0)} \u058F',
                              strong: true,
                            ),
                            _DeliveryStatRow(
                              title: 'Full price',
                              value:
                              '${fullPrice.toStringAsFixed(0)} \u058F',
                              strike: fullPrice > sellingPrice,
                            ),
                            _DeliveryStatRow(
                              title: 'Amount',
                              value: package.isNotEmpty
                                  ? '$quantity ($package)'
                                  : '$quantity',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Builder(
                    builder: (context) {
                      final latitude = _coordinate(
                        delivery['buyer_delivery_latitude'],
                      );
                      final longitude = _coordinate(
                        delivery['buyer_delivery_longitude'],
                      );
                      final point = latitude != null &&
                          longitude != null &&
                          latitude >= -90 &&
                          latitude <= 90 &&
                          longitude >= -180 &&
                          longitude <= 180
                          ? LatLng(latitude, longitude)
                          : null;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBuyerLocationPreview(context, point),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (orderNumber.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.receipt_long_rounded,
                                        color: accentColor,
                                        size: 17,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Заказ #$orderNumber',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (address.isNotEmpty || phone.isNotEmpty)
                                    const SizedBox(height: 7),
                                ],
                                if (address.isNotEmpty)
                                  Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.location_on_rounded,
                                        color: accentColor,
                                        size: 17,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          address,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            height: 1.2,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (phone.isNotEmpty) ...[
                                  if (address.isNotEmpty)
                                    const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.phone_rounded,
                                        color: accentColor,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          phone,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (houseNumber.isNotEmpty ||
                                    floor.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.apartment_rounded,
                                        color: accentColor,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          [
                                            if (houseNumber.isNotEmpty)
                                              '${_t(context, ru: 'Дом', en: 'House', hy: 'Տուն')} $houseNumber',
                                            if (floor.isNotEmpty)
                                              '${_t(context, ru: 'Этаж', en: 'Floor', hy: 'Հարկ')} $floor',
                                          ].join(' • '),
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (additionalInfo.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.notes_rounded,
                                        color: accentColor,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          additionalInfo,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            height: 1.2,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF555555),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 9),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Icon(
                                      Icons.local_shipping_outlined,
                                      size: 16,
                                      color: Color(0xFFE30620),
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        businessDaysText,
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFE30620),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: accentColor.withValues(alpha: 0.30),
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 120,
                        maxWidth: 158,
                      ),
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: statusBackground,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: accentColor,
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: isUpdating
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                          : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: delivery['delivery_status']
                              ?.toString()
                              .toLowerCase() ??
                              'processing',
                          isDense: true,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 21,
                            color: Colors.black87,
                          ),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          menuMaxHeight: 190,
                          itemHeight: 48,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: statusForeground,
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: 'processing',
                              child: _statusDropdownItem(
                                context,
                                'processing',
                              ),
                            ),
                            DropdownMenuItem<String>(
                              value: 'delivering',
                              child: _statusDropdownItem(
                                context,
                                'delivering',
                              ),
                            ),
                            DropdownMenuItem<String>(
                              value: 'delivered',
                              child: _statusDropdownItem(
                                context,
                                'delivered',
                              ),
                            ),
                          ],
                          selectedItemBuilder: (context) => [
                            Center(
                              child: Text(
                                _statusLabelForCard(
                                  context,
                                  'processing',
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Center(
                              child: Text(
                                _statusLabelForCard(
                                  context,
                                  'delivering',
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Center(
                              child: Text(
                                _statusLabelForCard(
                                  context,
                                  'delivered',
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              onStatusChanged(value);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Material(
                      color: const Color(0xFFF4F4F4),
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onEdit,
                        child: Container(
                          width: 72,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: accentColor,
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 17,
                            color: Colors.black,
                          ),
                        ),
                      ),
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

class _DeliveryStatRow extends StatelessWidget {
  final String title;
  final String value;
  final bool strong;
  final bool strike;

  const _DeliveryStatRow({
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
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: strong ? 13 : 10,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
                color: strike ? const Color(0xFFE99AA0) : Colors.black,
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
