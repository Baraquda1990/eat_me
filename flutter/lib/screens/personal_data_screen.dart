// lib/screens/personal_data_screen.dart

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';
import '../utils/armenian_phone.dart';

class PersonalDataScreen extends StatefulWidget {
  const PersonalDataScreen({
    super.key,
    this.requireDeliveryData = false,
  });

  final bool requireDeliveryData;

  static bool isDeliveryProfileComplete(Map<String, dynamic> profile) {
    final phoneDigits = ArmenianPhone.localDigits(profile['phone']);
    final address = profile['address']?.toString().trim() ?? '';
    final house = profile['house_number']?.toString().trim() ?? '';
    final floor = profile['floor']?.toString().trim() ?? '';

    double? parseCoordinate(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
    }

    final latitude = parseCoordinate(profile['delivery_latitude']);
    final longitude = parseCoordinate(profile['delivery_longitude']);

    return phoneDigits.length == ArmenianPhone.localDigitsLength &&
        address.isNotEmpty &&
        house.isNotEmpty &&
        floor.isNotEmpty &&
        latitude != null &&
        longitude != null &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  @override
  State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
  static const Color _accent = Color(0xFFD1BC00);
  static const LatLng _defaultPoint = LatLng(40.1792, 44.4991);

  final _formKey = GlobalKey<FormState>();

  final _addressController = TextEditingController();
  final _houseController = TextEditingController();
  final _floorController = TextEditingController();
  final _phoneController = TextEditingController();
  final _additionalController = TextEditingController();

  final MapController _mapController = MapController();

  final Dio _geocodingDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'Appsosa/1.0 personal-delivery-data',
      },
    ),
  );

  bool _loading = true;
  bool _saving = false;
  bool _locating = false;
  bool _resolvingAddress = false;
  bool _searchingAddress = false;

  LatLng? _selectedPoint;
  DateTime? _lastNominatimRequestAt;
  int _reverseGeneration = 0;

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

  String _languageChain() {
    final current = Localizations.localeOf(context).languageCode.toLowerCase();
    return <String>[current, 'hy', 'ru', 'en'].toSet().join(',');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _houseController.dispose();
    _floorController.dispose();
    _phoneController.dispose();
    _additionalController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  double? _parseCoordinate(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
  }

  Future<void> _load() async {
    try {
      final profile = await ApiService.getProfile();

      if (!mounted) return;

      final latitude = _parseCoordinate(profile['delivery_latitude']);
      final longitude = _parseCoordinate(profile['delivery_longitude']);

      setState(() {
        _addressController.text =
            profile['address']?.toString().trim() ?? '';
        _houseController.text =
            profile['house_number']?.toString().trim() ?? '';
        _floorController.text =
            profile['floor']?.toString().trim() ?? '';
        _phoneController.text =
            ArmenianPhone.formatLocal(profile['phone']);
        _additionalController.text =
            profile['delivery_additional_info']?.toString().trim() ?? '';

        if (latitude != null &&
            longitude != null &&
            latitude >= -90 &&
            latitude <= 90 &&
            longitude >= -180 &&
            longitude <= 180) {
          _selectedPoint = LatLng(latitude, longitude);
        }

        _loading = false;
      });

      if (_selectedPoint != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _selectedPoint == null) return;
          _mapController.move(_selectedPoint!, 16);
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(
        _t(
          ru: 'Не удалось загрузить личные данные.',
          en: 'Could not load personal data.',
          hy: 'Չհաջողվեց բեռնել անձնական տվյալները։',
        ),
      );
    }
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

  String _compactAddress(Map<String, dynamic> data) {
    final rawAddress = data['address'];

    if (rawAddress is Map) {
      final address = Map<String, dynamic>.from(rawAddress);

      String first(List<String> keys) {
        for (final key in keys) {
          final value = address[key]?.toString().trim() ?? '';
          if (value.isNotEmpty) return value;
        }
        return '';
      }

      final road = first([
        'road',
        'pedestrian',
        'residential',
        'footway',
        'path',
      ]);
      final house = first(['house_number']);
      final suburb = first([
        'suburb',
        'neighbourhood',
        'quarter',
        'city_district',
      ]);
      final city = first([
        'city',
        'town',
        'village',
        'municipality',
      ]);
      final postcode = first(['postcode']);
      final country = first(['country']);

      final street = [
        if (road.isNotEmpty) road,
        if (house.isNotEmpty) house,
      ].join(' ').trim();

      final parts = <String>[
        if (street.isNotEmpty) street,
        if (suburb.isNotEmpty && suburb != city) suburb,
        if (city.isNotEmpty) city,
        if (postcode.isNotEmpty) postcode,
        if (country.isNotEmpty) country,
      ];

      if (parts.isNotEmpty) return parts.join(', ');
    }

    return data['display_name']?.toString().trim() ?? '';
  }

  Future<String?> _reverseGeocode(LatLng point) async {
    await _respectNominatimRateLimit();

    final response = await _geocodingDio.get(
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

    final raw = response.data;
    if (raw is! Map) return null;

    final value = _compactAddress(Map<String, dynamic>.from(raw));
    return value.isEmpty ? null : value;
  }

  Future<void> _selectPoint(
      LatLng point, {
        bool moveMap = false,
      }) async {
    final generation = ++_reverseGeneration;

    setState(() {
      _selectedPoint = point;
      _resolvingAddress = true;
    });

    if (moveMap) {
      try {
        _mapController.move(point, 17);
      } catch (_) {}
    }

    try {
      final address = await _reverseGeocode(point);

      if (!mounted || generation != _reverseGeneration) return;

      if (address != null && address.trim().isNotEmpty) {
        _addressController.text = address.trim();
      }
    } catch (_) {
      if (!mounted || generation != _reverseGeneration) return;
      _showError(
        _t(
          ru: 'Точка выбрана, но адрес определить не удалось.',
          en: 'The point was selected, but the address could not be resolved.',
          hy: 'Կետն ընտրված է, բայց հասցեն որոշել չհաջողվեց։',
        ),
      );
    } finally {
      if (mounted && generation == _reverseGeneration) {
        setState(() => _resolvingAddress = false);
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;

    setState(() => _locating = true);

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw StateError('service_disabled');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('permission_denied');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      await _selectPoint(
        LatLng(position.latitude, position.longitude),
        moveMap: true,
      );
    } catch (_) {
      if (!mounted) return;
      _showError(
        _t(
          ru: 'Не удалось определить местоположение. Проверьте разрешение на геолокацию.',
          en: 'Could not determine your location. Check location permission.',
          hy: 'Չհաջողվեց որոշել տեղադրությունը։ Ստուգեք տեղորոշման թույլտվությունը։',
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _searchAddressOnMap() async {
    final query = _addressController.text.trim();
    if (query.isEmpty || _searchingAddress) return;

    setState(() => _searchingAddress = true);

    try {
      await _respectNominatimRateLimit();

      final response = await _geocodingDio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'jsonv2',
          'limit': 1,
          'addressdetails': 1,
          'accept-language': _languageChain(),
        },
      );

      final data = response.data;
      if (data is! List || data.isEmpty || data.first is! Map) {
        throw StateError('not_found');
      }

      final first = Map<String, dynamic>.from(data.first as Map);
      final lat = double.tryParse(first['lat']?.toString() ?? '');
      final lon = double.tryParse(first['lon']?.toString() ?? '');

      if (lat == null || lon == null) {
        throw StateError('not_found');
      }

      final point = LatLng(lat, lon);

      if (!mounted) return;

      setState(() {
        _selectedPoint = point;
        final display = first['display_name']?.toString().trim() ?? '';
        if (display.isNotEmpty) {
          _addressController.text = display;
        }
      });

      _mapController.move(point, 17);
    } catch (_) {
      if (!mounted) return;
      _showError(
        _t(
          ru: 'Адрес не найден. Уточните адрес или выберите точку на карте.',
          en: 'Address not found. Refine it or choose a point on the map.',
          hy: 'Հասցեն չի գտնվել։ Ճշտեք հասցեն կամ ընտրեք կետը քարտեզի վրա։',
        ),
      );
    } finally {
      if (mounted) setState(() => _searchingAddress = false);
    }
  }

  Future<void> _openFullscreenMap() async {
    FocusScope.of(context).unfocus();

    final initialPoint = _selectedPoint ?? _defaultPoint;

    final result = await Navigator.of(context).push<_PersonalMapSelection>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _PersonalMapPicker(
          initialPoint: initialPoint,
          initialAddress: _addressController.text.trim(),
          reverseGeocode: _reverseGeocode,
        ),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _selectedPoint = result.point;
      if (result.address.trim().isNotEmpty) {
        _addressController.text = result.address.trim();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(result.point, 17);
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? _requiredTextValidator(
      String? value, {
        required String fieldName,
      }) {
    if (!widget.requireDeliveryData) return null;
    if ((value ?? '').trim().isEmpty) {
      return _t(
        ru: 'Заполните: $fieldName',
        en: 'Fill in: $fieldName',
        hy: 'Լրացրեք՝ $fieldName',
      );
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;

    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk) return;

    final rawPhone = _phoneController.text.trim();
    final phoneDigits = ArmenianPhone.localDigits(rawPhone);

    if (phoneDigits.isNotEmpty &&
        phoneDigits.length != ArmenianPhone.localDigitsLength) {
      _showError(
        _t(
          ru: 'Введите корректный номер: +374 XX-XX-XX-XX',
          en: 'Enter a valid number: +374 XX-XX-XX-XX',
          hy: 'Մուտքագրեք ճիշտ համար՝ +374 XX-XX-XX-XX',
        ),
      );
      return;
    }

    if (widget.requireDeliveryData &&
        phoneDigits.length != ArmenianPhone.localDigitsLength) {
      _showError(
        _t(
          ru: 'Для доставки укажите номер телефона.',
          en: 'A phone number is required for delivery.',
          hy: 'Առաքման համար նշեք հեռախոսահամարը։',
        ),
      );
      return;
    }

    if (widget.requireDeliveryData && _selectedPoint == null) {
      _showError(
        _t(
          ru: 'Отметьте адрес доставки на карте.',
          en: 'Mark the delivery address on the map.',
          hy: 'Քարտեզի վրա նշեք առաքման հասցեն։',
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final normalizedPhone = phoneDigits.isEmpty
          ? ''
          : ArmenianPhone.normalize(rawPhone);

      await ApiService.updatePersonalData(
        phone: normalizedPhone,
        address: _addressController.text.trim(),
        houseNumber: _houseController.text.trim(),
        floor: _floorController.text.trim(),
        latitude: _selectedPoint?.latitude,
        longitude: _selectedPoint?.longitude,
        additionalInfo: _additionalController.text.trim(),
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      _showError(
        _t(
          ru: 'Не удалось сохранить личные данные.',
          en: 'Could not save personal data.',
          hy: 'Չհաջողվեց պահպանել անձնական տվյալները։',
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration({
    required String label,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      alignLabelWithHint: true,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _accent,
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _accent,
          width: 1.8,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: _accent),
        ),
      );
    }

    final point = _selectedPoint ?? _defaultPoint;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          _t(
            ru: 'Личные данные',
            en: 'Personal details',
            hy: 'Անձնական տվյալներ',
          ),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
          children: [
            Text(
              _t(
                ru: 'Данные для доставки',
                en: 'Delivery details',
                hy: 'Առաքման տվյալներ',
              ),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.requireDeliveryData
                  ? _t(
                ru: 'Заполните данные, чтобы продавец смог доставить заказ.',
                en: 'Complete the details so the seller can deliver your order.',
                hy: 'Լրացրեք տվյալները, որպեսզի վաճառողը կարողանա առաքել պատվերը։',
              )
                  : _t(
                ru: 'Эти данные будут использоваться при доставке заказов.',
                en: 'These details will be used for deliveries.',
                hy: 'Այս տվյալները կօգտագործվեն պատվերների առաքման համար։',
              ),
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF777777),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _addressController,
              keyboardType: TextInputType.streetAddress,
              minLines: 1,
              maxLines: 2,
              validator: (value) => _requiredTextValidator(
                value,
                fieldName: _t(
                  ru: 'адрес',
                  en: 'address',
                  hy: 'հասցե',
                ),
              ),
              decoration: _decoration(
                label: _t(
                  ru: 'Адрес',
                  en: 'Address',
                  hy: 'Հասցե',
                ),
                suffixIcon: IconButton(
                  tooltip: _t(
                    ru: 'Найти адрес на карте',
                    en: 'Find address on map',
                    hy: 'Գտնել հասցեն քարտեզի վրա',
                  ),
                  onPressed: _searchingAddress ? null : _searchAddressOnMap,
                  icon: _searchingAddress
                      ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _accent,
                    ),
                  )
                      : const Icon(
                    Icons.search_rounded,
                    color: _accent,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _houseController,
                    textInputAction: TextInputAction.next,
                    validator: (value) => _requiredTextValidator(
                      value,
                      fieldName: _t(
                        ru: 'номер дома',
                        en: 'house number',
                        hy: 'տան համարը',
                      ),
                    ),
                    decoration: _decoration(
                      label: _t(
                        ru: 'Номер дома',
                        en: 'House number',
                        hy: 'Տան համար',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _floorController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (value) => _requiredTextValidator(
                      value,
                      fieldName: _t(
                        ru: 'этаж',
                        en: 'floor',
                        hy: 'հարկը',
                      ),
                    ),
                    decoration: _decoration(
                      label: _t(
                        ru: 'Этаж',
                        en: 'Floor',
                        hy: 'Հարկ',
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: const <TextInputFormatter>[
                ArmenianPhoneInputFormatter(),
              ],
              decoration: _decoration(
                label: _t(
                  ru: 'Телефон',
                  en: 'Phone',
                  hy: 'Հեռախոս',
                ),
              ).copyWith(
                prefixText: '+374 ',
                hintText: 'XX-XX-XX-XX',
              ),
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: _additionalController,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: _decoration(
                label: _t(
                  ru: 'Дополнительная информация',
                  en: 'Additional information',
                  hy: 'Լրացուցիչ տեղեկություն',
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(
                          ru: 'Отметьте адрес на карте',
                          en: 'Mark your address',
                          hy: 'Նշեք հասցեն քարտեզի վրա',
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _t(
                          ru: 'Это поможет продавцу найти вас быстрее',
                          en: 'This helps the seller find you faster',
                          hy: 'Սա կօգնի վաճառողին ավելի արագ գտնել ձեզ',
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _accent,
                    ),
                  )
                      : const Icon(
                    Icons.my_location_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _t(
                      ru: 'Я здесь',
                      en: 'Use my location',
                      hy: 'Իմ տեղադրությունը',
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF7A6C00),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 190,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: point,
                        initialZoom: _selectedPoint == null ? 12 : 16,
                        minZoom: 3,
                        maxZoom: 19,
                        onTap: (_, tapped) => _selectPoint(tapped),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'am.appsosa.app',
                        ),
                        if (_selectedPoint != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _selectedPoint!,
                                width: 52,
                                height: 52,
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: Color(0xFFC73A31),
                                  size: 48,
                                ),
                              ),
                            ],
                          ),
                        RichAttributionWidget(
                          attributions: const [
                            TextSourceAttribution(
                              'OpenStreetMap contributors',
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Material(
                        color: Colors.white,
                        elevation: 2,
                        borderRadius: BorderRadius.circular(12),
                        child: IconButton(
                          tooltip: _t(
                            ru: 'Открыть карту',
                            en: 'Open map',
                            hy: 'Բացել քարտեզը',
                          ),
                          onPressed: _openFullscreenMap,
                          icon: const Icon(
                            Icons.fullscreen_rounded,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ),
                    ),
                    if (_resolvingAddress)
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _accent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _t(
                                  ru: 'Определяем адрес…',
                                  en: 'Resolving address…',
                                  hy: 'Որոշվում է հասցեն…',
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            if (_selectedPoint != null) ...[
              const SizedBox(height: 8),
              Text(
                '${_selectedPoint!.latitude.toStringAsFixed(6)}, '
                    '${_selectedPoint!.longitude.toStringAsFixed(6)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF777777),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Text(
                _t(
                  ru: 'Сохранить данные',
                  en: 'Save details',
                  hy: 'Պահպանել տվյալները',
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonalMapSelection {
  const _PersonalMapSelection({
    required this.point,
    required this.address,
  });

  final LatLng point;
  final String address;
}

class _PersonalMapPicker extends StatefulWidget {
  const _PersonalMapPicker({
    required this.initialPoint,
    required this.initialAddress,
    required this.reverseGeocode,
  });

  final LatLng initialPoint;
  final String initialAddress;
  final Future<String?> Function(LatLng point) reverseGeocode;

  @override
  State<_PersonalMapPicker> createState() => _PersonalMapPickerState();
}

class _PersonalMapPickerState extends State<_PersonalMapPicker> {
  static const Color _accent = Color(0xFFD1BC00);

  late LatLng _point;
  late String _address;
  bool _loadingAddress = false;
  int _generation = 0;

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

  @override
  void initState() {
    super.initState();
    _point = widget.initialPoint;
    _address = widget.initialAddress.trim();
  }

  Future<void> _select(LatLng value) async {
    final generation = ++_generation;

    setState(() {
      _point = value;
      _loadingAddress = true;
    });

    try {
      final address = await widget.reverseGeocode(value);
      if (!mounted || generation != _generation) return;

      setState(() {
        _address = address?.trim() ?? '';
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _address = '');
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loadingAddress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            ru: 'Выберите точку',
            en: 'Choose a point',
            hy: 'Ընտրեք կետը',
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
                initialCenter: _point,
                initialZoom: 16,
                minZoom: 3,
                maxZoom: 19,
                onTap: (_, value) => _select(value),
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
                      point: _point,
                      width: 56,
                      height: 56,
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFFC73A31),
                        size: 52,
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
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: _accent,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _loadingAddress
                              ? Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _accent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _t(
                                    ru: 'Определяем адрес…',
                                    en: 'Resolving address…',
                                    hy: 'Որոշվում է հասցեն…',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          )
                              : Text(
                            _address.isEmpty
                                ? _t(
                              ru: 'Нажмите на карту, чтобы выбрать адрес',
                              en: 'Tap the map to choose an address',
                              hy: 'Սեղմեք քարտեզի վրա՝ հասցեն ընտրելու համար',
                            )
                                : _address,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _loadingAddress
                            ? null
                            : () => Navigator.of(context).pop(
                          _PersonalMapSelection(
                            point: _point,
                            address: _address,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded),
                        label: Text(
                          _t(
                            ru: 'Выбрать эту точку',
                            en: 'Choose this point',
                            hy: 'Ընտրել այս կետը',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
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
