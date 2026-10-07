// lib/screens/seller_company_form_screen.dart

import 'dart:typed_data';

import 'package:armenia/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';
import '../utils/armenian_phone.dart';
import 'image_frame_editor_screen.dart';

class SellerCompanyFormScreen extends StatefulWidget {
  const SellerCompanyFormScreen({super.key});

  @override
  State<SellerCompanyFormScreen> createState() =>
      _SellerCompanyFormScreenState();
}

class _SellerCompanyFormScreenState extends State<SellerCompanyFormScreen> {
  static const Color accentColor = Color(0xFFD1BC00);
  static const LatLng _defaultPoint = LatLng(40.1772, 44.5035);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _openTimeController = TextEditingController();
  final _closeTimeController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final MapController _mapController = MapController();
  final Dio _geocodingDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'Appsosa/1.0 (am.appsosa.app)',
      },
    ),
  );

  final Map<String, List<_NominatimCandidate>> _addressSearchCache =
  <String, List<_NominatimCandidate>>{};
  DateTime? _lastNominatimRequestAt;

  bool _loading = true;
  bool _saving = false;
  bool _isSearchingAddress = false;
  bool _isResolvingLocation = false;

  List<Map<String, dynamic>> _companies = [];
  Map<String, dynamic>? _selectedCompany;
  String? _selectedCompanySlug;

  XFile? _image;
  XFile? _originalImage;
  Uint8List? _imagePreviewBytes;

  LatLng? _selectedPoint;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _openTimeController.dispose();
    _closeTimeController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    try {
      final companies = await ApiService.getMyCompanies();

      if (!mounted) return;

      setState(() {
        _companies = companies;
        _loading = false;
      });

      if (companies.isNotEmpty) {
        final firstCompany = Map<String, dynamic>.from(companies.first);
        if (!mounted) return;
        _selectCompany(firstCompany);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);
      final l10n = AppLocalizations.of(context)!;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.companyLoadFailed}: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _selectCompany(Map<String, dynamic> company) {
    final latitude = double.tryParse(company['latitude']?.toString() ?? '');
    final longitude = double.tryParse(company['longitude']?.toString() ?? '');

    final point = latitude != null &&
        longitude != null &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180
        ? LatLng(latitude, longitude)
        : _defaultPoint;

    final slug = company['slug']?.toString().trim() ?? '';

    setState(() {
      _selectedCompany = company;
      _selectedCompanySlug = slug.isEmpty ? null : slug;
      _image = null;
      _originalImage = null;
      _imagePreviewBytes = null;
      _selectedPoint = point;

      _nameController.text = company['name']?.toString() ?? '';
      _addressController.text = company['address']?.toString() ?? '';
      _descriptionController.text =
          company['description']?.toString() ?? '';
      _phoneController.text =
          ArmenianPhone.formatLocal(company['phone']);
      _openTimeController.text =
          _normalizeTime(company['open_time']?.toString() ?? '');
      _closeTimeController.text =
          _normalizeTime(company['close_time']?.toString() ?? '');
      _instagramController.text = company['instagram']?.toString() ?? '';
      _facebookController.text = company['facebook']?.toString() ?? '';
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(point, 15);
      } catch (_) {
        // Карта может ещё не быть построена.
      }
    });
  }

  String _normalizeTime(String value) {
    if (value.length >= 5) return value.substring(0, 5);
    return value;
  }

  String _companyLogoEditLabel() {
    return switch (Localizations.localeOf(context).languageCode) {
      'ru' => 'Редактировать логотип',
      'hy' => 'Խմբագրել լոգոն',
      _ => 'Edit logo',
    };
  }


  Future<void> _openFullscreenMap() async {
    final point = _selectedPoint ?? _defaultPoint;

    final result = await Navigator.of(context).push<_SellerCompanyMapResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _SellerCompanyFullscreenMapScreen(
          initialPoint: point,
          initialAddress: _addressController.text.trim(),
          resolveAddress: _reverseGeocodePoint,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _selectedPoint = result.point;
      if (result.address.trim().isNotEmpty) {
        _addressController.text = result.address.trim();
      }
    });

    try {
      _mapController.move(result.point, 17);
    } catch (_) {
      // Mini-map may not be attached yet.
    }
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context)!;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.companyLogo,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(
                    Icons.photo_camera_outlined,
                    color: accentColor,
                  ),
                  title: Text(
                    switch (Localizations.localeOf(context).languageCode) {
                      'ru' => 'Сделать фото',
                      'hy' => 'Լուսանկարել',
                      _ => 'Take photo',
                    },
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onTap: () =>
                      Navigator.pop(sheetContext, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: accentColor,
                  ),
                  title: Text(
                    switch (Localizations.localeOf(context).languageCode) {
                      'ru' => 'Выбрать из галереи',
                      'hy' => 'Ընտրել պատկերասրահից',
                      _ => 'Choose from gallery',
                    },
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onTap: () =>
                      Navigator.pop(sheetContext, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    final image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1800,
      maxHeight: 1800,
    );

    if (image == null || !mounted) return;

    await _cropCompanyLogo(
      sourceImage: image,
      rememberAsOriginal: true,
    );
  }

  Future<void> _editCurrentLogo() async {
    final original = _originalImage;
    if (original == null) return;

    await _cropCompanyLogo(
      sourceImage: original,
      rememberAsOriginal: false,
    );
  }

  Future<void> _cropCompanyLogo({
    required XFile sourceImage,
    required bool rememberAsOriginal,
  }) async {
    if (!mounted) return;

    final edited = await ImageFrameEditorScreen.open(
      context,
      source: sourceImage,
      mode: ImageFrameEditorMode.companyLogo,
      outputFileName: 'company_logo.png',
    );

    if (edited == null || !mounted) return;

    setState(() {
      if (rememberAsOriginal) {
        _originalImage = sourceImage;
      }
      _image = edited.file;
      _imagePreviewBytes = edited.bytes;
    });
  }

  String _addressSearchLanguageChain() {
    final current = Localizations.localeOf(context).languageCode.toLowerCase();
    final languages = <String>[current, 'hy', 'ru', 'en'];

    return languages.toSet().join(',');
  }

  String? _streetFallbackQuery(String query) {
    final normalized = query.trim().replaceAll(RegExp(r'\s+'), ' ');

    // Common case: "Комитаса 25", "Komitas 25", "Կոմիտաս 25".
    // If OSM has the street but not the house number, retry the street itself.
    final match = RegExp(
      r'^(.*?)(?:,\s*|\s+)(\d+[A-Za-zА-Яа-яԱ-Ֆա-ֆ0-9/-]*)$',
      caseSensitive: false,
    ).firstMatch(normalized);

    if (match == null) return null;

    final street = (match.group(1) ?? '').trim();
    if (street.length < 3) return null;

    return street;
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

  Future<List<_NominatimCandidate>> _searchNominatim(
      String query,
      ) async {
    final normalized = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return const <_NominatimCandidate>[];

    final cacheKey =
        '${_addressSearchLanguageChain()}|${normalized.toLowerCase()}';

    final cached = _addressSearchCache[cacheKey];
    if (cached != null) return cached;

    await _respectNominatimRateLimit();

    final response = await _geocodingDio.get(
      'https://nominatim.openstreetmap.org/search',
      queryParameters: {
        'q': normalized,
        'format': 'jsonv2',
        'limit': 5,
        'addressdetails': 1,
        'namedetails': 1,
        'dedupe': 1,
        'countrycodes': 'am',
        'accept-language': _addressSearchLanguageChain(),
      },
    );

    final raw = response.data;
    if (raw is! List) {
      _addressSearchCache[cacheKey] = const <_NominatimCandidate>[];
      return const <_NominatimCandidate>[];
    }

    final results = <_NominatimCandidate>[];
    final seen = <String>{};

    for (final entry in raw) {
      if (entry is! Map) continue;

      final item = Map<String, dynamic>.from(entry);
      final latitude = double.tryParse(item['lat']?.toString() ?? '');
      final longitude = double.tryParse(item['lon']?.toString() ?? '');
      final label = item['display_name']?.toString().trim() ?? '';

      if (latitude == null ||
          longitude == null ||
          label.isEmpty ||
          latitude < 38.7 ||
          latitude > 41.4 ||
          longitude < 43.3 ||
          longitude > 46.8) {
        continue;
      }

      final dedupeKey =
          '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
      if (!seen.add(dedupeKey)) continue;

      results.add(
        _NominatimCandidate(
          point: LatLng(latitude, longitude),
          label: label,
        ),
      );
    }

    _addressSearchCache[cacheKey] =
    List<_NominatimCandidate>.unmodifiable(results);

    return results;
  }

  Future<_NominatimCandidate?> _chooseAddressResult(
      List<_NominatimCandidate> results,
      ) {
    final l10n = AppLocalizations.of(context)!;

    return showModalBottomSheet<_NominatimCandidate>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.68,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(26),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_searching_rounded,
                        color: accentColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.findOnMap,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: Text(
                    l10n.companyMapPointHelper,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 58,
                    ),
                    itemBuilder: (context, index) {
                      final result = results[index];

                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFF5F1C9),
                          child: Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFF7A6C00),
                          ),
                        ),
                        title: Text(
                          result.label,
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                        ),
                        onTap: () =>
                            Navigator.of(sheetContext).pop(result),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
      final city = firstNonEmpty([
        'city',
        'town',
        'village',
        'municipality',
        'city_district',
      ]);
      final suburb = firstNonEmpty([
        'suburb',
        'neighbourhood',
        'quarter',
      ]);

      final streetPart = [
        if (road.isNotEmpty) road,
        if (house.isNotEmpty) house,
      ].join(' ').trim();

      final parts = <String>[];
      if (streetPart.isNotEmpty) parts.add(streetPart);
      if (suburb.isNotEmpty && suburb != city) parts.add(suburb);
      if (city.isNotEmpty) parts.add(city);

      if (parts.isNotEmpty) return parts.join(', ');
    }

    return data['display_name']?.toString().trim() ?? '';
  }

  Future<String?> _reverseGeocodePoint(LatLng point) async {
    await _respectNominatimRateLimit();

    final response = await _geocodingDio.get(
      'https://nominatim.openstreetmap.org/reverse',
      queryParameters: {
        'lat': point.latitude,
        'lon': point.longitude,
        'format': 'jsonv2',
        'zoom': 18,
        'addressdetails': 1,
        'accept-language': _addressSearchLanguageChain(),
      },
    );

    final raw = response.data;
    if (raw is! Map) return null;

    final address = _compactReverseAddress(
      Map<String, dynamic>.from(raw),
    );

    return address.isEmpty ? null : address;
  }

  Future<void> _selectPointAndResolveAddress(
      LatLng point, {
        bool moveMap = false,
      }) async {
    if (!mounted) return;

    setState(() {
      _selectedPoint = point;
      _isResolvingLocation = true;
    });

    if (moveMap) {
      try {
        _mapController.move(point, 17);
      } catch (_) {
        // Map may not be mounted yet.
      }
    }

    try {
      final address = await _reverseGeocodePoint(point);
      if (!mounted) return;

      if (address != null && address.trim().isNotEmpty) {
        setState(() {
          _addressController.text = address.trim();
        });
      }
    } catch (_) {
      // Keep the selected point even if reverse geocoding is unavailable.
    } finally {
      if (mounted) {
        setState(() => _isResolvingLocation = false);
      }
    }
  }

  Future<void> _findAddressOnMap({bool showMessage = true}) async {
    final query = _addressController.text.trim();
    if (query.isEmpty || _isSearchingAddress) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSearchingAddress = true);

    try {
      var results = await _searchNominatim(query);
      var usedStreetFallback = false;

      if (results.isEmpty) {
        final fallback = _streetFallbackQuery(query);

        if (fallback != null &&
            fallback.toLowerCase() != query.toLowerCase()) {
          results = await _searchNominatim(fallback);
          usedStreetFallback = results.isNotEmpty;
        }
      }

      if (!mounted) return;

      if (results.isEmpty) {
        if (showMessage) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.addressNotFound),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      _NominatimCandidate? selected;

      // If the exact query produced one clear result, use it immediately.
      // If there are several possibilities (or only a street-level fallback),
      // let the seller choose instead of silently taking the first match.
      if (results.length == 1 && !usedStreetFallback) {
        selected = results.first;
      } else {
        selected = await _chooseAddressResult(results);
      }

      final chosen = selected;
      if (chosen == null || !mounted) return;

      setState(() {
        _selectedPoint = chosen.point;
        _addressController.text = chosen.label;
      });

      try {
        _mapController.move(chosen.point, usedStreetFallback ? 16 : 17);
      } catch (_) {
        // Map may not be mounted yet.
      }
    } on DioException catch (e) {
      if (showMessage && mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.type == DioExceptionType.connectionTimeout ||
                  e.type == DioExceptionType.receiveTimeout
                  ? l10n.companyAddressLookupTimeout
                  : l10n.addressLookupFailed,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearchingAddress = false);
      }
    }
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final current = _parseTime(controller.text);

    final l10n = AppLocalizations.of(context)!;
    final selected = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 9, minute: 0),
      helpText: l10n.selectTime,
      cancelText: l10n.cancel,
      confirmText: l10n.done,
    );

    if (selected == null || !mounted) return;

    controller.text =
    '${selected.hour.toString().padLeft(2, '0')}:'
        '${selected.minute.toString().padLeft(2, '0')}';

    setState(() {});
  }

  TimeOfDay? _parseTime(String value) {
    final parts = value.trim().split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _submit() async {
    if (_saving) return;

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final slug = _selectedCompanySlug;

    if (slug == null || slug.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.companyCouldNotDetermine),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final point = _selectedPoint;
    if (point == null) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.companySelectLocation),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await ApiService.updateSellerCompany(
        companySlug: slug,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        description: _descriptionController.text.trim(),
        phone: ArmenianPhone.normalize(_phoneController.text),
        latitude: point.latitude.toStringAsFixed(6),
        longitude: point.longitude.toStringAsFixed(6),
        openTime: _openTimeController.text.trim(),
        closeTime: _closeTimeController.text.trim(),
        instagram: _instagramController.text.trim(),
        facebook: _facebookController.text.trim(),
        imageBytes: _imagePreviewBytes,
        imageFileName: _image?.name,
      );

      if (!mounted) return;

      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.companyUpdated),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.companySaveError}: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EE),
      appBar: AppBar(
        title: Text(
          l10n.myCompany,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/auth_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _companies.isEmpty
            ? _buildEmpty()
            : _buildForm(),
      ),
      bottomNavigationBar: _loading || _companies.isEmpty
          ? null
          : Container(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox.shrink()
                    : const Icon(Icons.save_outlined),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                  accentColor.withValues(alpha: 0.55),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                label: _saving
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  l10n.saveChanges,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _glassCard(
          child: Text(
            l10n.sellerCompanyNotFound,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final l10n = AppLocalizations.of(context)!;
    final point = _selectedPoint ?? _defaultPoint;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
        children: [
          if (_companies.length > 1) ...[
            _sectionTitle(l10n.organization),
            const SizedBox(height: 8),
            _glassCard(
              child: DropdownButtonFormField<String>(
                value: _selectedCompanySlug,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.company,
                  prefixIcon: const Icon(Icons.storefront_outlined),
                  border: InputBorder.none,
                ),
                items: _companies.map((company) {
                  final slug = company['slug']?.toString() ?? '';
                  final name = company['name']?.toString() ?? slug;
                  return DropdownMenuItem<String>(
                    value: slug,
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (slug) async {
                  if (slug == null) return;

                  final company = _companies.firstWhere(
                        (item) => item['slug']?.toString() == slug,
                    orElse: () => _companies.first,
                  );

                  final selected =
                  Map<String, dynamic>.from(company);

                  if (!mounted) return;
                  _selectCompany(selected);
                },
              ),
            ),
            const SizedBox(height: 18),
          ],

          _sectionTitle(l10n.companyLogo),
          const SizedBox(height: 8),
          _glassCard(
            padding: EdgeInsets.zero,
            child: Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.30),
                ),
              ),
              child: _buildImagePickerContent(),
            ),
          ),

          const SizedBox(height: 22),
          _sectionTitle(l10n.companyBasicInformation),
          const SizedBox(height: 8),

          _fieldCard(
            controller: _nameController,
            label: l10n.companyName,
            icon: Icons.store_mall_directory_outlined,
            readOnly: true,
            suffixIcon: Icons.lock_outline_rounded,
            helperText:
            l10n.companyNameLockedHelper,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.enterCompanyName;
              }
              return null;
            },
          ),

          const SizedBox(height: 12),
          _fieldCard(
            controller: _descriptionController,
            label: l10n.description,
            icon: Icons.notes_rounded,
            minLines: 4,
            maxLines: 7,
          ),

          const SizedBox(height: 12),
          _phoneCard(l10n),

          const SizedBox(height: 22),
          _sectionTitle(l10n.companyAddressAndLocation),
          const SizedBox(height: 8),

          _glassCard(
            child: TextFormField(
              controller: _addressController,
              keyboardType: TextInputType.streetAddress,
              textInputAction: TextInputAction.search,
              onFieldSubmitted: (_) => _findAddressOnMap(),
              decoration: InputDecoration(
                labelText: l10n.address,
                hintText: l10n.enterCompanyAddress,
                prefixIcon: const Icon(Icons.location_on_outlined),
                suffixIcon: IconButton(
                  tooltip: l10n.findOnMap,
                  onPressed:
                  _isSearchingAddress ? null : () => _findAddressOnMap(),
                  icon: _isSearchingAddress
                      ? const SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.search_rounded),
                ),
                border: InputBorder.none,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.enterAddress;
                }
                return null;
              },
            ),
          ),

          const SizedBox(height: 10),
          Text(
            l10n.companyMapPointHelper,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),
          _glassCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                height: 290,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: point,
                          initialZoom: 15,
                          minZoom: 3,
                          maxZoom: 19,
                          onTap: (_, tappedPoint) {
                            _selectPointAndResolveAddress(tappedPoint);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.armenia.app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: point,
                                width: 54,
                                height: 54,
                                child: const Icon(
                                  Icons.location_pin,
                                  size: 50,
                                  color: Colors.red,
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
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Material(
                        color: accentColor,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _openFullscreenMap,
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              Icons.open_in_full_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_isResolvingLocation)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.my_location_rounded,
                size: 17,
                color: accentColor,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${point.latitude.toStringAsFixed(6)}, '
                      '${point.longitude.toStringAsFixed(6)}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),
          _sectionTitle(l10n.workingHours),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _timeCard(
                  controller: _openTimeController,
                  label: l10n.openingTime,
                  icon: Icons.wb_sunny_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _timeCard(
                  controller: _closeTimeController,
                  label: l10n.closingTime,
                  icon: Icons.nightlight_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),
          _sectionTitle(l10n.socialNetworks),
          const SizedBox(height: 8),

          _fieldCard(
            controller: _instagramController,
            label: 'Instagram',
            hintText: 'https://instagram.com/...',
            icon: Icons.camera_alt_outlined,
            keyboardType: TextInputType.url,
          ),

          const SizedBox(height: 12),
          _fieldCard(
            controller: _facebookController,
            label: 'Facebook',
            hintText: 'https://facebook.com/...',
            icon: Icons.facebook_outlined,
            keyboardType: TextInputType.url,
          ),
        ],
      ),
    );
  }

  Widget _phoneCard(AppLocalizations l10n) {
    return _glassCard(
      child: TextFormField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        textDirection: TextDirection.ltr,
        style: const TextStyle(
          color: Color(0xFF333333),
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
        textAlignVertical: TextAlignVertical.center,
        strutStyle: const StrutStyle(
          fontSize: 16,
          height: 1.2,
          forceStrutHeight: true,
        ),
        inputFormatters: const [
          ArmenianPhoneInputFormatter(),
        ],
        decoration: InputDecoration(
          labelText: l10n.phone,
          hintText: 'XX-XX-XX-XX',
          prefixIcon: const Icon(Icons.phone_outlined),
          prefixText: '+374 ',
          prefixStyle: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
          border: InputBorder.none,
        ),
        validator: (value) {
          final local = ArmenianPhone.localDigits(value);

          if (local.isEmpty) {
            return switch (Localizations.localeOf(context).languageCode) {
              'ru' => 'Введите номер телефона',
              'hy' => 'Մուտքագրեք հեռախոսահամարը',
              _ => 'Enter phone number',
            };
          }

          if (local.length != ArmenianPhone.localDigitsLength) {
            return switch (Localizations.localeOf(context).languageCode) {
              'ru' => 'Введите 8 цифр: +374 XX-XX-XX-XX',
              'hy' => 'Մուտքագրեք 8 թվանշան՝ +374 XX-XX-XX-XX',
              _ => 'Enter 8 digits: +374 XX-XX-XX-XX',
            };
          }

          return null;
        },
      ),
    );
  }

  Widget _timeCard({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return _glassCard(
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: () => _pickTime(controller),
        decoration: InputDecoration(
          labelText: label,
          hintText: '09:00',
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.schedule_rounded),
          border: InputBorder.none,
        ),
        validator: _validateTime,
      ),
    );
  }

  Widget _fieldCard({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    int minLines = 1,
    int maxLines = 1,
    bool readOnly = false,
    IconData? suffixIcon,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return _glassCard(
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        minLines: minLines,
        maxLines: maxLines,
        readOnly: readOnly,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          helperText: helperText,
          helperMaxLines: 2,
          prefixIcon: Icon(icon),
          suffixIcon:
          suffixIcon == null ? null : Icon(suffixIcon, size: 20),
          alignLabelWithHint: maxLines > 1,
          border: InputBorder.none,
        ),
      ),
    );
  }

  String? _validateTime(String? value) {
    final l10n = AppLocalizations.of(context)!;
    final text = (value ?? '').trim();

    if (text.isEmpty) return null;

    final match =
    RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').firstMatch(text);

    if (match == null) return l10n.timeFormat;
    return null;
  }

  Widget _buildImagePickerContent() {
    final hasNewImage = _imagePreviewBytes != null && _originalImage != null;

    final existingImage =
        _selectedCompany?['image_url']?.toString() ??
            _selectedCompany?['image']?.toString() ??
            '';

    final hasAnyImage = _imagePreviewBytes != null || existingImage.isNotEmpty;

    Widget logo;

    if (_imagePreviewBytes != null) {
      logo = Image.memory(
        _imagePreviewBytes!,
        fit: BoxFit.cover,
        width: 142,
        height: 142,
      );
    } else if (existingImage.isNotEmpty) {
      logo = Image.network(
        ApiService.fixImageUrl(existingImage),
        fit: BoxFit.cover,
        width: 142,
        height: 142,
        errorBuilder: (_, __, ___) => _emptyLogoCircle(),
      );
    } else {
      logo = _emptyLogoCircle();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: GestureDetector(
            onTap: hasAnyImage ? null : _pickImage,
            child: Container(
              width: 152,
              height: 152,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.55),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(5),
              child: ClipOval(child: logo),
            ),
          ),
        ),

        // A separate replacement button: Camera / Gallery.
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _pickImage,
              customBorder: const CircleBorder(),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.75),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  size: 21,
                  color: Color(0xFF5B5200),
                ),
              ),
            ),
          ),
        ),

        // Re-edit only a newly selected local source. Existing saved logos
        // intentionally have no re-edit action.
        if (hasNewImage)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _editCurrentLogo,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.crop_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _companyLogoEditLabel(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _emptyLogoCircle() {
    return Container(
      width: 142,
      height: 142,
      color: accentColor.withValues(alpha: 0.08),
      child: const Icon(
        Icons.add_photo_alternate_outlined,
        size: 46,
        color: accentColor,
      ),
    );
  }

  Widget _imageLabel(String text) {
    return Positioned(
      right: 12,
      bottom: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.edit_outlined,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyImagePicker() {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_photo_alternate_outlined,
              size: 32,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.selectCompanyPhoto,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Color(0xFF292929),
        ),
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding =
    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}


class _SellerCompanyMapResult {
  final LatLng point;
  final String address;

  const _SellerCompanyMapResult({
    required this.point,
    required this.address,
  });
}

class _SellerCompanyFullscreenMapScreen extends StatefulWidget {
  final LatLng initialPoint;
  final String initialAddress;
  final Future<String?> Function(LatLng point) resolveAddress;

  const _SellerCompanyFullscreenMapScreen({
    required this.initialPoint,
    required this.initialAddress,
    required this.resolveAddress,
  });

  @override
  State<_SellerCompanyFullscreenMapScreen> createState() =>
      _SellerCompanyFullscreenMapScreenState();
}

class _SellerCompanyFullscreenMapScreenState
    extends State<_SellerCompanyFullscreenMapScreen> {
  static const Color accentColor = Color(0xFFD1BC00);

  late final MapController _mapController;
  late LatLng _selectedPoint;
  late String _address;

  bool _resolving = false;
  int _resolveGeneration = 0;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialPoint;
    _address = widget.initialAddress.trim();
    _mapController = MapController();
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

  Future<void> _selectPoint(LatLng point) async {
    final generation = ++_resolveGeneration;

    setState(() {
      _selectedPoint = point;
      _resolving = true;
    });

    try {
      final address = await widget.resolveAddress(point);
      if (!mounted || generation != _resolveGeneration) return;

      if (address != null && address.trim().isNotEmpty) {
        setState(() => _address = address.trim());
      }
    } catch (_) {
      // The point can still be selected when address lookup is unavailable.
    } finally {
      if (mounted && generation == _resolveGeneration) {
        setState(() => _resolving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          l10n.companyAddressAndLocation,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF292929),
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.close_rounded,
            color: Color(0xFF292929),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
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
                  onTap: (_, tappedPoint) => _selectPoint(tappedPoint),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.armenia.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedPoint,
                        width: 54,
                        height: 54,
                        child: const Icon(
                          Icons.location_pin,
                          size: 50,
                          color: Colors.red,
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
            ),
            Positioned(
              top: 14,
              right: 14,
              child: Material(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(16),
                elevation: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _mapController.move(_selectedPoint, 17),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.center_focus_strong_rounded,
                      color: accentColor,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
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
                          Icons.location_on_outlined,
                          color: accentColor,
                          size: 21,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _resolving
                              ? Row(
                            children: [
                              const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  _text(
                                    ru: 'Определяем адрес…',
                                    en: 'Resolving address…',
                                    hy: 'Որոշվում է հասցեն…',
                                  ),
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          )
                              : Text(
                            _address.isEmpty
                                ? _text(
                              ru: 'Нажмите на карту, чтобы выбрать точку.',
                              en: 'Tap the map to choose a point.',
                              hy: 'Սեղմեք քարտեզի վրա՝ կետ ընտրելու համար։',
                            )
                                : _address,
                            style: const TextStyle(
                              color: Color(0xFF333333),
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_selectedPoint.latitude.toStringAsFixed(6)}, '
                          '${_selectedPoint.longitude.toStringAsFixed(6)}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF444444),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(l10n.cancel),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _resolving
                                ? null
                                : () => Navigator.of(context).pop(
                              _SellerCompanyMapResult(
                                point: _selectedPoint,
                                address: _address,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                              accentColor.withValues(alpha: 0.45),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(l10n.saveChanges),
                          ),
                        ),
                      ],
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

class _NominatimCandidate {
  final LatLng point;
  final String label;

  const _NominatimCandidate({
    required this.point,
    required this.label,
  });
}

