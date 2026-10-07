import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SellerProductLocation {
  final LatLng point;
  final String address;
  final int? radiusKm;

  const SellerProductLocation({
    required this.point,
    required this.address,
    this.radiusKm,
  });
}

class SellerProductLocationPicker extends StatefulWidget {
  final LatLng initialPoint;
  final String initialAddress;
  final int? radiusKm;
  final ValueChanged<SellerProductLocation> onChanged;
  final ValueChanged<int>? onRadiusChanged;

  const SellerProductLocationPicker({
    super.key,
    required this.initialPoint,
    required this.initialAddress,
    required this.onChanged,
    this.radiusKm,
    this.onRadiusChanged,
  });

  @override
  State<SellerProductLocationPicker> createState() =>
      _SellerProductLocationPickerState();
}

class _SellerProductLocationPickerState
    extends State<SellerProductLocationPicker> {
  static const Color _accent = Color(0xFFD1BC00);

  final MapController _mapController = MapController();
  final TextEditingController _addressController = TextEditingController();
  final FocusNode _addressFocusNode = FocusNode();
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: const {
        'User-Agent': 'Appsosa/1.0 product-location-picker',
      },
    ),
  );

  Timer? _addressDebounce;
  DateTime? _lastNominatimRequestAt;
  late LatLng _point;
  late String _address;
  late int? _radiusKm;
  bool _resolving = false;
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    _point = widget.initialPoint;
    _address = widget.initialAddress.trim();
    _radiusKm = widget.radiusKm;
    _addressController.text = _address;
  }

  @override
  void didUpdateWidget(covariant SellerProductLocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    final incomingPoint = widget.initialPoint;
    final pointChanged =
        incomingPoint.latitude != _point.latitude ||
            incomingPoint.longitude != _point.longitude;
    final addressChanged = widget.initialAddress.trim() != _address;
    final radiusChanged = widget.radiusKm != _radiusKm;

    if (!pointChanged && !addressChanged && !radiusChanged) return;

    setState(() {
      if (pointChanged) _point = incomingPoint;
      if (addressChanged) {
        _address = widget.initialAddress.trim();
        if (!_addressFocusNode.hasFocus) {
          _addressController.text = _address;
        }
      }
      if (radiusChanged) _radiusKm = widget.radiusKm;
    });

    if (pointChanged || radiusChanged) {
      _moveMapToSelection();
    }
  }

  @override
  void dispose() {
    _addressDebounce?.cancel();
    _addressController.dispose();
    _addressFocusNode.dispose();
    _dio.close(force: true);
    super.dispose();
  }

  String _text({required String ru, required String en, required String hy}) {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    if (code == 'ru') return ru;
    if (code == 'hy') return hy;
    return en;
  }

  String _languageChain() {
    final current = Localizations.localeOf(context).languageCode.toLowerCase();
    return <String>[current, 'hy', 'ru', 'en'].toSet().join(',');
  }

  Future<void> _respectNominatimRateLimit() async {
    final previous = _lastNominatimRequestAt;
    if (previous != null) {
      final elapsed = DateTime.now().difference(previous);
      const minimumGap = Duration(milliseconds: 1100);
      if (elapsed < minimumGap) {
        await Future<void>.delayed(minimumGap - elapsed);
      }
    }
    _lastNominatimRequestAt = DateTime.now();
  }

  Future<String?> _reverseGeocode(LatLng point) async {
    await _respectNominatimRateLimit();
    final response = await _dio.get(
      'https://nominatim.openstreetmap.org/reverse',
      queryParameters: {
        'lat': point.latitude,
        'lon': point.longitude,
        'format': 'jsonv2',
        'zoom': 18,
        'addressdetails': 1,
        'accept-language': _languageChain(),
      },
    );
    final data = response.data;
    if (data is! Map) return null;
    final value = data['display_name']?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  Future<_GeocodeResult?> _forwardGeocode(String query) async {
    final normalized = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < 3) return null;

    await _respectNominatimRateLimit();
    final response = await _dio.get(
      'https://nominatim.openstreetmap.org/search',
      queryParameters: {
        'q': normalized,
        'format': 'jsonv2',
        'limit': 1,
        'addressdetails': 1,
        'dedupe': 1,
        'countrycodes': 'am',
        'accept-language': _languageChain(),
      },
    );

    final data = response.data;
    if (data is! List || data.isEmpty || data.first is! Map) return null;
    final item = Map<String, dynamic>.from(data.first as Map);
    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lng = double.tryParse(item['lon']?.toString() ?? '');
    final label = item['display_name']?.toString().trim() ?? normalized;
    if (lat == null || lng == null) return null;
    return _GeocodeResult(LatLng(lat, lng), label);
  }

  void _notifyParent() {
    widget.onChanged(
      SellerProductLocation(
        point: _point,
        address: _address,
        radiusKm: _radiusKm,
      ),
    );
  }

  Future<void> _selectPoint(LatLng point) async {
    final serial = ++_requestSerial;
    setState(() {
      _point = point;
      _resolving = true;
    });
    _notifyParent();
    _moveMapToSelection();

    try {
      final address = await _reverseGeocode(point);
      if (!mounted || serial != _requestSerial) return;
      if (address != null) {
        setState(() {
          _address = address;
          _addressController.text = address;
        });
        _notifyParent();
      }
    } catch (_) {
      // Keep the selected point even when geocoding is temporarily unavailable.
    } finally {
      if (mounted && serial == _requestSerial) {
        setState(() => _resolving = false);
      }
    }
  }

  void _onAddressChanged(String value) {
    _address = value.trim();
    _notifyParent();
    _addressDebounce?.cancel();
    if (_address.length < 3) return;

    _addressDebounce = Timer(const Duration(milliseconds: 900), () async {
      final serial = ++_requestSerial;
      if (mounted) setState(() => _resolving = true);
      try {
        final result = await _forwardGeocode(_address);
        if (!mounted || serial != _requestSerial || result == null) return;
        setState(() {
          _point = result.point;
          _address = result.address;
          if (!_addressFocusNode.hasFocus) {
            _addressController.text = result.address;
          }
        });
        _notifyParent();
        _moveMapToSelection();
      } catch (_) {
        // A typed address remains usable even if it cannot be resolved now.
      } finally {
        if (mounted && serial == _requestSerial) {
          setState(() => _resolving = false);
        }
      }
    });
  }

  double _zoomForRadius(int? radiusKm) {
    if (radiusKm == null) return 15;
    const usableRadiusPixels = 70.0;
    final radiusMeters = math.max(1000.0, radiusKm * 1000.0);
    final metersPerPixel = radiusMeters / usableRadiusPixels;
    final latitudeFactor = math
        .cos(_point.latitude * math.pi / 180.0)
        .abs()
        .clamp(0.15, 1.0)
        .toDouble();
    final zoom =
        math.log((156543.03392 * latitudeFactor) / metersPerPixel) / math.ln2;
    return zoom.clamp(3.0, 17.0).toDouble();
  }

  void _moveMapToSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(_point, _zoomForRadius(_radiusKm));
      } catch (_) {}
    });
  }

  Future<void> _openFullScreen() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.of(context).push<SellerProductLocation>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _SellerProductLocationFullScreen(
          initialPoint: _point,
          initialAddress: _address,
          initialRadiusKm: _radiusKm,
        ),
      ),
    );

    if (!mounted || result == null) return;
    setState(() {
      _point = result.point;
      _address = result.address;
      _radiusKm = result.radiusKm;
      _addressController.text = result.address;
    });
    _notifyParent();
    if (result.radiusKm != null) {
      widget.onRadiusChanged?.call(result.radiusKm!);
    }
    _moveMapToSelection();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _addressController,
          focusNode: _addressFocusNode,
          onChanged: _onAddressChanged,
          textInputAction: TextInputAction.search,
          onFieldSubmitted: (_) {
            _addressDebounce?.cancel();
            _onAddressChanged(_addressController.text);
          },
          decoration: InputDecoration(
            labelText: _text(
              ru: 'Адрес',
              en: 'Address',
              hy: 'Հասցե',
            ),
            hintText: _text(
              ru: 'Введите адрес или выберите точку на карте',
              en: 'Enter an address or choose a point on the map',
              hy: 'Մուտքագրեք հասցեն կամ ընտրեք կետ քարտեզի վրա',
            ),
            prefixIcon: const Icon(Icons.location_on_outlined),
            suffixIcon: _resolving
                ? const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
                : const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _accent, width: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: widget.radiusKm == null ? 180 : 205,
            child: Stack(
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _point,
                      initialZoom: _zoomForRadius(_radiusKm),
                      onTap: (_, point) => _selectPoint(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'am.appsosa.app',
                      ),
                      if (_radiusKm != null)
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: _point,
                              radius: _radiusKm! * 1000.0,
                              useRadiusInMeter: true,
                              color: _accent.withValues(alpha: 0.16),
                              borderColor: _accent,
                              borderStrokeWidth: 2.4,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _point,
                            width: 48,
                            height: 48,
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFF746800),
                              size: 44,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.96),
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: IconButton(
                      tooltip: _text(
                        ru: 'Открыть карту',
                        en: 'Open map',
                        hy: 'Բացել քարտեզը',
                      ),
                      onPressed: _openFullScreen,
                      icon: const Icon(Icons.fullscreen_rounded),
                      color: const Color(0xFF5C5200),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SellerProductLocationFullScreen extends StatefulWidget {
  final LatLng initialPoint;
  final String initialAddress;
  final int? initialRadiusKm;

  const _SellerProductLocationFullScreen({
    required this.initialPoint,
    required this.initialAddress,
    required this.initialRadiusKm,
  });

  @override
  State<_SellerProductLocationFullScreen> createState() =>
      _SellerProductLocationFullScreenState();
}

class _SellerProductLocationFullScreenState
    extends State<_SellerProductLocationFullScreen> {
  static const Color _accent = Color(0xFFD1BC00);
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: const {'User-Agent': 'Appsosa/1.0 product-location-picker'},
    ),
  );
  late LatLng _point;
  late String _address;
  late int? _radiusKm;
  bool _resolving = false;
  DateTime? _lastRequestAt;

  @override
  void initState() {
    super.initState();
    _point = widget.initialPoint;
    _address = widget.initialAddress;
    _radiusKm = widget.initialRadiusKm;
  }

  @override
  void dispose() {
    _dio.close(force: true);
    super.dispose();
  }

  String _text({required String ru, required String en, required String hy}) {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    if (code == 'ru') return ru;
    if (code == 'hy') return hy;
    return en;
  }

  String _languageChain() {
    final current = Localizations.localeOf(context).languageCode.toLowerCase();
    return <String>[current, 'hy', 'ru', 'en'].toSet().join(',');
  }

  Future<void> _rateLimit() async {
    final previous = _lastRequestAt;
    if (previous != null) {
      final elapsed = DateTime.now().difference(previous);
      const gap = Duration(milliseconds: 1100);
      if (elapsed < gap) await Future<void>.delayed(gap - elapsed);
    }
    _lastRequestAt = DateTime.now();
  }

  Future<void> _selectPoint(LatLng point) async {
    setState(() {
      _point = point;
      _resolving = true;
    });
    try {
      await _rateLimit();
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': point.latitude,
          'lon': point.longitude,
          'format': 'jsonv2',
          'zoom': 18,
          'addressdetails': 1,
          'accept-language': _languageChain(),
        },
      );
      final data = response.data;
      final value = data is Map
          ? data['display_name']?.toString().trim() ?? ''
          : '';
      if (mounted && value.isNotEmpty) setState(() => _address = value);
    } catch (_) {
      // The point remains selected even without reverse geocoding.
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _text(
            ru: 'Выберите точку',
            en: 'Choose location',
            hy: 'Ընտրեք կետը',
          ),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _point,
              initialZoom: _radiusKm == null ? 15 : 12,
              onTap: (_, point) => _selectPoint(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'am.appsosa.app',
              ),
              if (_radiusKm != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _point,
                      radius: _radiusKm! * 1000.0,
                      useRadiusInMeter: true,
                      color: _accent.withValues(alpha: 0.18),
                      borderColor: _accent,
                      borderStrokeWidth: 3,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _point,
                    width: 52,
                    height: 52,
                    child: const Icon(
                      Icons.location_on_rounded,
                      size: 50,
                      color: Color(0xFF746800),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 22,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: _accent),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _address.isEmpty
                                ? _text(
                              ru: 'Нажмите на карту, чтобы выбрать адрес',
                              en: 'Tap the map to choose an address',
                              hy: 'Սեղմեք քարտեզին՝ հասցեն ընտրելու համար',
                            )
                                : _address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (_resolving)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
                    if (_radiusKm != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _text(
                          ru: 'Радиус: $_radiusKm км',
                          en: 'Radius: $_radiusKm km',
                          hy: 'Շառավիղ՝ $_radiusKm կմ',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Slider(
                        value: _radiusKm!.toDouble(),
                        min: 1,
                        max: 50,
                        divisions: 49,
                        activeColor: _accent,
                        label: '$_radiusKm km',
                        onChanged: (value) {
                          setState(() => _radiusKm = value.round());
                        },
                      ),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(
                            SellerProductLocation(
                              point: _point,
                              address: _address,
                              radiusKm: _radiusKm,
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: Text(
                          _text(
                            ru: 'Выбрать эту точку',
                            en: 'Use this location',
                            hy: 'Ընտրել այս կետը',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
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

class _GeocodeResult {
  final LatLng point;
  final String address;

  const _GeocodeResult(this.point, this.address);
}
