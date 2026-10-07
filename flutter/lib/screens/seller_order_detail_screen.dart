import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';
import '../utils/phone_launcher.dart';
import 'seller_delivery_map_screen.dart';

class SellerOrderDetailScreen extends StatefulWidget {
  final int cardId;
  final int companyId;

  const SellerOrderDetailScreen({
    super.key,
    required this.cardId,
    required this.companyId,
  });

  static const Color accentColor = Color(0xFFD1BC00);

  @override
  State<SellerOrderDetailScreen> createState() => _SellerOrderDetailScreenState();
}

class _SellerOrderDetailScreenState extends State<SellerOrderDetailScreen> {
  late Future<Map<String, dynamic>> _orderFuture;

  @override
  void initState() {
    super.initState();
    _orderFuture = ApiService.getSellerOrder(
      widget.cardId,
      widget.companyId,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _orderFuture = ApiService.getSellerOrder(
        widget.cardId,
        widget.companyId,
      );
    });
    await _orderFuture;
  }

  String _text(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  String _normalizeClientPhone(dynamic value) {
    final digits = value?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
    return digits.isEmpty ? '' : '+$digits';
  }

  String _money(dynamic value) {
    final number = double.tryParse(value?.toString() ?? '0') ?? 0;
    return '${number.toStringAsFixed(0)} ֏';
  }

  String _date(dynamic value) {
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

  List<Map<String, dynamic>> _items(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  double? _coordinate(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
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

  void _openDeliveryMap({
    required double latitude,
    required double longitude,
    required String address,
    required String houseNumber,
    required String floor,
    required String additionalInfo,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SellerDeliveryMapScreen(
          latitude: latitude,
          longitude: longitude,
          address: address,
          houseNumber: houseNumber,
          floor: floor,
          additionalInfo: additionalInfo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text(
          'Заказ',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final order = snapshot.data ?? <String, dynamic>{};

          if (order.isEmpty) {
            return _ErrorState(
              message: 'Заказ не найден',
              onRetry: _refresh,
            );
          }

          final buyer = _text(order['buyer']);
          final phone = _normalizeClientPhone(
            order['buyer_phone'] ?? order['phone'],
          );
          final address = _text(order['buyer_address'] ?? order['address']);
          final houseNumber = _text(order['buyer_house_number']);
          final floor = _text(order['buyer_floor']);
          final additionalInfo =
          _text(order['buyer_delivery_additional_info']);
          final latitude =
          _coordinate(order['buyer_delivery_latitude']);
          final longitude =
          _coordinate(order['buyer_delivery_longitude']);
          final hasDeliveryPoint = latitude != null &&
              longitude != null &&
              latitude >= -90 &&
              latitude <= 90 &&
              longitude >= -180 &&
              longitude <= 180;
          final companyName = _text(order['company_name']);
          final orderNumber = _text(
            order['order_number'] ?? order['card_id'] ?? widget.cardId,
          );
          final created = _date(order['created']);
          final total = _money(order['total']);
          final items = _items(order['items']);

          return RefreshIndicator(
            onRefresh: _refresh,
            color: SellerOrderDetailScreen.accentColor,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                _HeaderCard(
                  title: 'Новый заказ',
                  subtitle: '№$orderNumber · $created',
                ),
                const SizedBox(height: 14),

                _SectionCard(
                  title: 'Покупатель',
                  children: [
                    _InfoRow(
                      icon: Icons.person_rounded,
                      title: 'Имя',
                      value: buyer.isEmpty ? 'Не указано' : buyer,
                    ),
                    _InfoRow(
                      icon: Icons.phone_rounded,
                      title: 'Телефон',
                      value: phone.isEmpty ? 'Не указан' : phone,
                    ),
                    _InfoRow(
                      icon: Icons.location_on_rounded,
                      title: _t(
                        ru: 'Адрес',
                        en: 'Address',
                        hy: 'Հասցե',
                      ),
                      value: address.isEmpty
                          ? _t(
                        ru: 'Не указан',
                        en: 'Not specified',
                        hy: 'Նշված չէ',
                      )
                          : address,
                    ),
                    if (houseNumber.isNotEmpty)
                      _InfoRow(
                        icon: Icons.home_work_outlined,
                        title: _t(
                          ru: 'Дом',
                          en: 'House',
                          hy: 'Տուն',
                        ),
                        value: houseNumber,
                      ),
                    if (floor.isNotEmpty)
                      _InfoRow(
                        icon: Icons.stairs_outlined,
                        title: _t(
                          ru: 'Этаж',
                          en: 'Floor',
                          hy: 'Հարկ',
                        ),
                        value: floor,
                      ),
                    if (additionalInfo.isNotEmpty)
                      _InfoRow(
                        icon: Icons.notes_rounded,
                        title: _t(
                          ru: 'Дополнительно',
                          en: 'Additional',
                          hy: 'Լրացուցիչ',
                        ),
                        value: additionalInfo,
                      ),
                  ],
                ),

                if (hasDeliveryPoint) ...[
                  const SizedBox(height: 14),
                  _DeliveryMapCard(
                    latitude: latitude,
                    longitude: longitude,
                    address: address,
                    onTap: () => _openDeliveryMap(
                      latitude: latitude,
                      longitude: longitude,
                      address: address,
                      houseNumber: houseNumber,
                      floor: floor,
                      additionalInfo: additionalInfo,
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                _SectionCard(
                  title: 'Компания',
                  children: [
                    _InfoRow(
                      icon: Icons.storefront_rounded,
                      title: 'Название',
                      value: companyName.isEmpty ? 'Не указано' : companyName,
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                _ItemsCard(
                  items: items,
                  moneyBuilder: _money,
                ),

                const SizedBox(height: 14),

                _TotalCard(total: total),

                const SizedBox(height: 18),

                if (phone.isNotEmpty)
                  _ActionButton(
                    icon: Icons.call_rounded,
                    title: 'Позвонить покупателю',
                    onTap: () => launchPhoneCall(
                      context,
                      phone,
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


class _DeliveryMapCard extends StatelessWidget {
  const _DeliveryMapCard({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.onTap,
  });

  final double latitude;
  final double longitude;
  final String address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    final lang = Localizations.localeOf(context).languageCode;
    final title = switch (lang) {
      'ru' => 'Место доставки',
      'hy' => 'Առաքման վայրը',
      _ => 'Delivery location',
    };
    final hint = switch (lang) {
      'ru' => 'Нажмите на карту, чтобы открыть',
      'hy' => 'Սեղմեք քարտեզին՝ բացելու համար',
      _ => 'Tap the map to open',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
          const SizedBox(height: 4),
          Text(
            hint,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 190,
              width: double.infinity,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
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
                                width: 48,
                                height: 48,
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: Color(0xFFC73A31),
                                  size: 44,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.fullscreen_rounded,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ),
                      if (address.trim().isNotEmpty)
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              address.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
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


class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HeaderCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SellerOrderDetailScreen.accentColor,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shopping_bag_rounded,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String Function(dynamic value) moneyBuilder;

  const _ItemsCard({
    required this.items,
    required this.moneyBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Товары',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Товары не найдены',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            ...items.map(
                  (item) => _OrderItemRow(
                name: item['product_name']?.toString() ?? '',
                quantity: item['quantity']?.toString() ?? '',
                price: moneyBuilder(item['price']),
                total: moneyBuilder(item['total']),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final String name;
  final String quantity;
  final String price;
  final String total;

  const _OrderItemRow({
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.inventory_2_rounded,
            color: SellerOrderDetailScreen.accentColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Товар' : name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF242424),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Кол-во: $quantity · Цена: $price',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            total,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF242424),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final String total;

  const _TotalCard({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.payments_rounded,
            color: SellerOrderDetailScreen.accentColor,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Итого',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            total,
            style: const TextStyle(
              fontSize: 20,
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
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: SellerOrderDetailScreen.accentColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF242424),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: SellerOrderDetailScreen.accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRetry,
      color: SellerOrderDetailScreen.accentColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 140),
          const Icon(
            Icons.error_outline_rounded,
            size: 54,
            color: Colors.black38,
          ),
          const SizedBox(height: 14),
          const Text(
            'Не удалось открыть заказ',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
