import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../utils/armenian_phone.dart';

import 'seller_category_screen.dart';
import 'seller_registration_provider.dart';
import 'widgets/seller_registration_header.dart';
import 'widgets/seller_step_indicator.dart';

class SellerCompanyInfoScreen extends StatefulWidget {
  const SellerCompanyInfoScreen({super.key});

  @override
  State<SellerCompanyInfoScreen> createState() =>
      _SellerCompanyInfoScreenState();
}

class _SellerCompanyInfoScreenState extends State<SellerCompanyInfoScreen> {
  static const Color _accent = Color(0xFFD1BC00);
  static const LatLng _initialPoint = LatLng(40.1772, 44.5035);

  final _formKey = GlobalKey<FormState>();
  final _mapController = MapController();

  late final TextEditingController _nameController;
  late final TextEditingController _tinController;
  late final TextEditingController _addressController;
  late final TextEditingController _businessPhoneController;
  late final TextEditingController _businessEmailController;
  late final TextEditingController _contactNameController;
  late final TextEditingController _contactPhoneController;
  late final TextEditingController _contactEmailController;

  LatLng _selectedPoint = _initialPoint;
  bool _initializedFromProvider = false;
  bool _isSearchingAddress = false;
  bool _showValidationErrors = false;
  Timer? _addressDebounce;
  DateTime? _lastNominatimRequestAt;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _tinController = TextEditingController();
    _addressController = TextEditingController();
    _businessPhoneController = TextEditingController();
    _businessEmailController = TextEditingController();
    _contactNameController = TextEditingController();
    _contactPhoneController = TextEditingController();
    _contactEmailController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedFromProvider) return;
    _initializedFromProvider = true;

    final registration = context.read<SellerRegistrationProvider>();
    _nameController.text = registration.organizationName;
    _tinController.text = registration.taxNumber;
    _addressController.text = registration.address;
    _businessPhoneController.text =
        ArmenianPhone.formatLocal(registration.businessPhone);
    _businessEmailController.text = registration.businessEmail;
    _contactNameController.text = registration.contactName;
    _contactPhoneController.text =
        ArmenianPhone.formatLocal(registration.contactPhone);
    _contactEmailController.text = registration.contactEmail;

    if (registration.latitude != null && registration.longitude != null) {
      _selectedPoint = LatLng(
        registration.latitude!,
        registration.longitude!,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tinController.dispose();
    _addressController.dispose();
    _businessPhoneController.dispose();
    _businessEmailController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    _addressDebounce?.cancel();
    super.dispose();
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)!.requiredField;
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    final local = ArmenianPhone.localDigits(value);

    if (local.isEmpty) {
      return AppLocalizations.of(context)!.requiredField;
    }

    if (local.length != ArmenianPhone.localDigitsLength) {
      return switch (Localizations.localeOf(context).languageCode) {
        'ru' => 'Введите 8 цифр: +374 XX-XX-XX-XX',
        'hy' => 'Մուտքագրեք 8 թվանշան՝ +374 XX-XX-XX-XX',
        _ => 'Enter 8 digits: +374 XX-XX-XX-XX',
      };
    }

    return null;
  }

  String? _optionalEmailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!valid) return AppLocalizations.of(context)!.enterValidEmail;
    return null;
  }


  void _scheduleAddressLookup(String value) {
    _addressDebounce?.cancel();
    final address = value.trim();
    if (address.length < 4) return;

    _addressDebounce = Timer(
      const Duration(milliseconds: 1100),
          () => _findAddressOnMap(showError: false),
    );
  }

  Future<void> _findAddressOnMap({required bool showError}) async {
    final address = _addressController.text.trim();
    if (address.length < 4 || _isSearchingAddress) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSearchingAddress = true);

    try {
      final query = address.toLowerCase().contains('armenia') ||
          address.toLowerCase().contains('Х°ХЎХµХЎХЅХїХЎХ¶') ||
          address.toLowerCase().contains('Р°СЂРјРµРЅРёСЏ')
          ? address
          : '$address, Armenia';

      final response = await Dio().get<List<dynamic>>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'jsonv2',
          'limit': 1,
          'countrycodes': 'am',
          'addressdetails': 1,
        },
        options: Options(
          headers: const {
            'Accept': 'application/json',
            'Accept-Language': 'en,ru,hy',
          },
          receiveTimeout: const Duration(seconds: 12),
        ),
      );

      final results = response.data ?? const [];
      if (results.isEmpty) {
        if (showError && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.addressNotFound,
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final item = Map<String, dynamic>.from(results.first as Map);
      final latitude = double.tryParse(item['lat']?.toString() ?? '');
      final longitude = double.tryParse(item['lon']?.toString() ?? '');
      if (latitude == null || longitude == null) return;

      final point = LatLng(latitude, longitude);
      if (!mounted) return;

      setState(() => _selectedPoint = point);
      _mapController.move(point, 16);
    } on DioException {
      if (showError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.addressLookupFailed,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearchingAddress = false);
    }
  }


  String _addressLanguageChain() {
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

  String _compactReverseAddress(Map<String, dynamic> data) {
    final rawAddress = data['address'];

    if (rawAddress is Map) {
      final address = Map<String, dynamic>.from(rawAddress);

      String firstNonEmpty(List<String> keys) {
        for (final key in keys) {
          final value = address[key]?.toString().trim() ?? '';
          if (value.isNotEmpty) return value;
        }
        return '';
      }

      final road = firstNonEmpty([
        'road',
        'pedestrian',
        'residential',
        'footway',
        'path',
      ]);
      final house = firstNonEmpty(['house_number']);
      final suburb = firstNonEmpty([
        'suburb',
        'neighbourhood',
        'quarter',
        'city_district',
      ]);
      final city = firstNonEmpty([
        'city',
        'town',
        'village',
        'municipality',
      ]);
      final postcode = firstNonEmpty(['postcode']);
      final country = firstNonEmpty(['country']);

      final streetPart = [
        if (house.isNotEmpty) house,
        if (road.isNotEmpty) road,
      ].join(', ').trim();

      final parts = <String>[
        if (streetPart.isNotEmpty) streetPart,
        if (suburb.isNotEmpty && suburb != city) suburb,
        if (city.isNotEmpty) city,
        if (postcode.isNotEmpty) postcode,
        if (country.isNotEmpty) country,
      ];

      if (parts.isNotEmpty) return parts.join(', ');
    }

    return data['display_name']?.toString().trim() ?? '';
  }

  Future<String?> _reverseGeocodePoint(LatLng point) async {
    await _respectNominatimRateLimit();

    final response = await Dio().get(
      'https://nominatim.openstreetmap.org/reverse',
      queryParameters: {
        'lat': point.latitude,
        'lon': point.longitude,
        'format': 'jsonv2',
        'zoom': 18,
        'addressdetails': 1,
        'accept-language': _addressLanguageChain(),
      },
      options: Options(
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'Appsosa/1.0 seller-registration-map',
        },
        receiveTimeout: const Duration(seconds: 12),
      ),
    );

    final raw = response.data;
    if (raw is! Map) return null;

    final address = _compactReverseAddress(
      Map<String, dynamic>.from(raw),
    );

    return address.isEmpty ? null : address;
  }

  Future<void> _openFullscreenMap() async {
    FocusScope.of(context).unfocus();

    final selected = await Navigator.of(context).push<_CompanyMapSelection>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenCompanyMapPicker(
          initialPoint: _selectedPoint,
          initialAddress: _addressController.text.trim(),
          resolveAddress: _reverseGeocodePoint,
        ),
      ),
    );

    if (!mounted || selected == null) return;

    setState(() {
      _selectedPoint = selected.point;

      if (selected.address.trim().isNotEmpty) {
        _addressController.text = selected.address.trim();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(selected.point, 16);
      }
    });
  }

  void _saveAndContinue() {
    FocusScope.of(context).unfocus();

    if (!_showValidationErrors) {
      setState(() => _showValidationErrors = true);
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final provider = context.read<SellerRegistrationProvider>();

    provider.saveCompanyInfo(
      organizationName: _nameController.text.trim(),
      taxNumber: _tinController.text.trim(),
      address: _addressController.text.trim(),
      latitude: _selectedPoint.latitude,
      longitude: _selectedPoint.longitude,
      businessPhone: ArmenianPhone.normalize(_businessPhoneController.text),
      businessEmail: _businessEmailController.text.trim(),
      contactName: _contactNameController.text.trim(),
      contactPhone: ArmenianPhone.normalize(_contactPhoneController.text),
      contactEmail: _contactEmailController.text.trim(),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: const SellerCategoryScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/auth_bg.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.white),
          ),
          SafeArea(
            child: Column(
              children: [
                SellerRegistrationHeader(
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SellerStepIndicator(currentStep: 2),
                const SizedBox(height: 12),
                Expanded(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _showValidationErrors
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    child: ListView(
                      keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
                      children: [
                        _LabeledField(
                          title: AppLocalizations.of(context)!.companyName,
                          required: true,
                          helper:
                          AppLocalizations.of(context)!.companyNameHelper,
                          controller: _nameController,
                          validator: _phoneValidator,
                          textInputAction: TextInputAction.next,
                        ),
                        _LabeledField(
                          title: AppLocalizations.of(context)!.tin,
                          required: true,
                          helper: AppLocalizations.of(context)!.tinHelper,
                          controller: _tinController,
                          validator: _requiredValidator,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                        ),
                        _LabeledField(
                          title: AppLocalizations.of(context)!.address,
                          required: true,
                          helper:
                          AppLocalizations.of(context)!.addressHelper,
                          controller: _addressController,
                          validator: _requiredValidator,
                          textInputAction: TextInputAction.search,
                          onChanged: _scheduleAddressLookup,
                          onFieldSubmitted: (_) =>
                              _findAddressOnMap(showError: true),
                          suffixIcon: _isSearchingAddress
                              ? const Padding(
                            padding: EdgeInsets.all(13),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _accent,
                              ),
                            ),
                          )
                              : IconButton(
                            tooltip: AppLocalizations.of(context)!.findAddressOnMap,
                            onPressed: () =>
                                _findAddressOnMap(showError: true),
                            icon: const Icon(
                              Icons.location_searching,
                              color: _accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        _MapPicker(
                          controller: _mapController,
                          selectedPoint: _selectedPoint,
                          onChanged: (point) {
                            setState(() => _selectedPoint = point);
                          },
                          onFullscreen: _openFullscreenMap,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppLocalizations.of(context)!.mapPointHint,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.3,
                            color: Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          AppLocalizations.of(context)!.contacts,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _PhoneField(
                          label: AppLocalizations.of(context)!.phone,
                          helper: AppLocalizations.of(context)!.officialBusinessNumber,
                          controller: _businessPhoneController,
                          validator: _requiredValidator,
                        ),
                        _LabeledField(
                          title: AppLocalizations.of(context)!.email,
                          controller: _businessEmailController,
                          validator: _optionalEmailValidator,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                        ),
                        _LabeledField(
                          title: AppLocalizations.of(context)!.personResponsible,
                          helper:
                          AppLocalizations.of(context)!.personResponsibleHelper,
                          controller: _contactNameController,
                          validator: _requiredValidator,
                          textInputAction: TextInputAction.next,
                        ),
                        _PhoneField(
                          label: AppLocalizations.of(context)!.phone,
                          helper: AppLocalizations.of(context)!.directContactPhone,
                          controller: _contactPhoneController,
                          validator: _phoneValidator,
                        ),
                        _LabeledField(
                          title: AppLocalizations.of(context)!.email,
                          controller: _contactEmailController,
                          validator: _optionalEmailValidator,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _saveAndContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.next,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
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
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.title,
    required this.controller,
    this.required = false,
    this.helper,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onFieldSubmitted,
    this.suffixIcon,
  });

  final String title;
  final TextEditingController controller;
  final bool required;
  final String? helper;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              children: [
                TextSpan(text: title),
                if (required)
                  const TextSpan(
                    text: '*',
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    helper!,
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.25,
                      color: Color(0xFF444444),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.info_outline,
                  size: 13,
                  color: Color(0xFFB0B0B0),
                ),
              ],
            ),
          ],
          const SizedBox(height: 7),
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onChanged: onChanged,
            onFieldSubmitted: onFieldSubmitted,
            decoration: _fieldDecoration(suffixIcon: suffixIcon),
          ),
        ],
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.label,
    required this.controller,
    required this.validator,
    this.helper,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _SellerFieldColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '+374',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  validator: validator,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: const [
                    ArmenianPhoneInputFormatter(),
                  ],
                  decoration: _fieldDecoration().copyWith(
                    hintText: 'XX-XX-XX-XX',
                  ),
                ),
              ),
            ],
          ),
          if (helper != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 76),
              child: Text(
                helper!,
                style: const TextStyle(
                  fontSize: 9.5,
                  color: Color(0xFF555555),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapPicker extends StatelessWidget {
  const _MapPicker({
    required this.controller,
    required this.selectedPoint,
    required this.onChanged,
    required this.onFullscreen,
  });

  final MapController controller;
  final LatLng selectedPoint;
  final ValueChanged<LatLng> onChanged;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 165,
        child: Stack(
          children: [
            FlutterMap(
              mapController: controller,
              options: MapOptions(
                initialCenter: selectedPoint,
                initialZoom: 15,
                onTap: (_, point) => onChanged(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.armenia',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: selectedPoint,
                      width: 46,
                      height: 46,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.redAccent,
                        size: 42,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.white,
                elevation: 2,
                borderRadius: BorderRadius.circular(10),
                child: IconButton(
                  tooltip: switch (Localizations.localeOf(context).languageCode) {
                    'ru' => 'Открыть карту на весь экран',
                    'hy' => 'Բացել քարտեզը ամբողջ էկրանով',
                    _ => 'Open map fullscreen',
                  },
                  onPressed: onFullscreen,
                  icon: const Icon(
                    Icons.fullscreen_rounded,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyMapSelection {
  const _CompanyMapSelection({
    required this.point,
    required this.address,
  });

  final LatLng point;
  final String address;
}

class _FullscreenCompanyMapPicker extends StatefulWidget {
  const _FullscreenCompanyMapPicker({
    required this.initialPoint,
    required this.initialAddress,
    required this.resolveAddress,
  });

  final LatLng initialPoint;
  final String initialAddress;
  final Future<String?> Function(LatLng point) resolveAddress;

  @override
  State<_FullscreenCompanyMapPicker> createState() =>
      _FullscreenCompanyMapPickerState();
}

class _FullscreenCompanyMapPickerState
    extends State<_FullscreenCompanyMapPicker> {
  static const Color _accent = Color(0xFFD1BC00);

  late LatLng _selectedPoint;
  late String _address;

  final MapController _mapController = MapController();

  bool _resolvingAddress = false;
  int _resolveGeneration = 0;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialPoint;
    _address = widget.initialAddress.trim();

    // If the form already has coordinates but the address field is empty,
    // resolve the current map point as soon as the fullscreen map opens.
    if (_address.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectPoint(_selectedPoint, moveMap: false);
        }
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  String _text({
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

  Future<void> _selectPoint(
      LatLng point, {
        bool moveMap = false,
      }) async {
    final generation = ++_resolveGeneration;

    setState(() {
      _selectedPoint = point;
      _address = '';
      _resolvingAddress = true;
    });

    if (moveMap) {
      try {
        _mapController.move(point, 17);
      } catch (_) {
        // The map may not be attached yet.
      }
    }

    try {
      final address = await widget.resolveAddress(point);

      if (!mounted || generation != _resolveGeneration) return;

      if (address != null && address.trim().isNotEmpty) {
        setState(() {
          _address = address.trim();
        });
      }
    } catch (_) {
      // The selected point remains valid even if reverse geocoding fails.
    } finally {
      if (mounted && generation == _resolveGeneration) {
        setState(() => _resolvingAddress = false);
      }
    }
  }

  String _displayAddress() {
    if (_resolvingAddress) {
      return _text(
        ru: 'Определяем адрес…',
        en: 'Resolving address…',
        hy: 'Որոշվում է հասցեն…',
      );
    }

    if (_address.isNotEmpty) return _address;

    return _text(
      ru: 'Адрес для этой точки не найден',
      en: 'No address found for this point',
      hy: 'Այս կետի հասցեն չի գտնվել',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF242424),
        elevation: 0,
        centerTitle: true,
        title: Text(
          _text(
            ru: 'Выберите точку',
            en: 'Choose a point',
            hy: 'Ընտրեք կետը',
          ),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _selectedPoint,
                  initialZoom: 16,
                  minZoom: 3,
                  maxZoom: 19,
                  onTap: (_, point) => _selectPoint(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.armenia',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedPoint,
                        width: 54,
                        height: 54,
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFF8A7900),
                          size: 50,
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
              top: 14,
              right: 14,
              child: Material(
                color: Colors.white.withValues(alpha: 0.96),
                elevation: 2,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _mapController.move(_selectedPoint, 17),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.center_focus_strong_rounded,
                      color: _accent,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.98),
                    borderRadius: BorderRadius.circular(24),
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
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF9CC),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.location_on_outlined,
                              color: _accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _resolvingAddress
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
                                    _displayAddress(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.3,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                ),
                              ],
                            )
                                : Text(
                              _displayAddress(),
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 40),
                          child: Text(
                            '${_selectedPoint.latitude.toStringAsFixed(6)}, '
                                '${_selectedPoint.longitude.toStringAsFixed(6)}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _resolvingAddress
                              ? null
                              : () => Navigator.of(context).pop(
                            _CompanyMapSelection(
                              point: _selectedPoint,
                              address: _address,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: const Color(0xFF242424),
                            disabledBackgroundColor:
                            _accent.withValues(alpha: 0.45),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          icon: const Icon(
                            Icons.check_rounded,
                            size: 20,
                          ),
                          label: Text(
                            _text(
                              ru: 'Выбрать эту точку',
                              en: 'Choose this point',
                              hy: 'Ընտրել այս կետը',
                            ),
                            style: const TextStyle(
                              fontSize: 14,
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
      ),
    );
  }
}

InputDecoration _fieldDecoration({Widget? suffixIcon}) {
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
    suffixIcon: suffixIcon,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(
        color: _SellerFieldColors.border,
        width: 1.2,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(
        color: Color(0xFFD1BC00),
        width: 1.6,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
    ),
  );
}

abstract final class _SellerFieldColors {
  static const Color border = Color(0xFFD1BC00);
}
