// lib/screens/seller_delivery_map_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SellerDeliveryMapScreen extends StatelessWidget {
  const SellerDeliveryMapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    this.address = '',
    this.houseNumber = '',
    this.floor = '',
    this.additionalInfo = '',
  });

  static const Color accentColor = Color(0xFFD1BC00);

  final double latitude;
  final double longitude;
  final String address;
  final String houseNumber;
  final String floor;
  final String additionalInfo;

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

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);

    final details = <String>[
      if (houseNumber.trim().isNotEmpty)
        '${_t(context, ru: 'Дом', en: 'House', hy: 'Տուն')}: ${houseNumber.trim()}',
      if (floor.trim().isNotEmpty)
        '${_t(context, ru: 'Этаж', en: 'Floor', hy: 'Հարկ')}: ${floor.trim()}',
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _t(
            context,
            ru: 'Адрес доставки',
            en: 'Delivery address',
            hy: 'Առաքման հասցե',
          ),
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 17,
                minZoom: 3,
                maxZoom: 19,
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
                      width: 58,
                      height: 58,
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFFC73A31),
                        size: 54,
                      ),
                    ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: const [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.13),
                      blurRadius: 20,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: accentColor,
                          size: 23,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            address.trim().isEmpty
                                ? _t(
                              context,
                              ru: 'Адрес не указан',
                              en: 'Address not specified',
                              hy: 'Հասցեն նշված չէ',
                            )
                                : address.trim(),
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.3,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF252525),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 31),
                        child: Text(
                          details.join('  •  '),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ),
                    ],
                    if (additionalInfo.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          additionalInfo.trim(),
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF444444),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${latitude.toStringAsFixed(6)}, '
                          '${longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF777777),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
