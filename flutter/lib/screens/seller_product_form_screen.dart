// lib/screens/seller_product_form_screen.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';

import '../models/product.dart';
import '../models/tag.dart';
import '../services/api_service.dart';
import '../widgets/product_card.dart';
import '../widgets/seller_product_location_picker.dart';
import 'product_detail_screen.dart';
import 'product_camera_screen.dart';
import 'image_frame_editor_screen.dart';

class SellerProductFormScreen extends StatefulWidget {
  final Product? product;

  const SellerProductFormScreen({
    super.key,
    this.product,
  });

  @override
  State<SellerProductFormScreen> createState() => _SellerProductFormScreenState();
}

class _SellerProductFormScreenState extends State<SellerProductFormScreen> {
  static const Color accentColor = Color(0xFFD1BC00);
  static const int _maxProductTags = 3;
  static const int _descriptionMaxLength = 700;

  final _formKey = GlobalKey<FormState>();

  final _photoSectionKey = GlobalKey();
  final _pickupWindowKey = GlobalKey();
  final _locationSectionKey = GlobalKey();
  final _tagsSectionKey = GlobalKey();

  final _nameFieldKey = GlobalKey<FormFieldState<String>>();
  final _descriptionFieldKey = GlobalKey<FormFieldState<String>>();
  final _countFieldKey = GlobalKey<FormFieldState<String>>();
  final _seatsFieldKey = GlobalKey<FormFieldState<String>>();
  final _priceFieldKey = GlobalKey<FormFieldState<String>>();
  final _discountFieldKey = GlobalKey<FormFieldState<String>>();

  final _nameFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _countFocusNode = FocusNode();
  final _seatsFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();
  final _discountFocusNode = FocusNode();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pickupDetailsController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _countController = TextEditingController(text: '1');
  final _seatsController = TextEditingController(text: '1');

  final _packageQuantityController = TextEditingController();
  final _weightController = TextEditingController();
  final _deliveryDaysController = TextEditingController();
  final _expirationDateController = TextEditingController();
  final _canUseUntilController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;

  List<Map<String, dynamic>> _companies = [];
  List<Tag> _tags = [];

  final Set<String> _selectedTagSlugs = <String>{};

  String? _selectedCompanySlug;
  // This screen is the HOT publication form.
  // Editing keeps the existing product type for backward compatibility.
  String _selectedType = 'hot';

  DateTime? _pickupFrom;
  DateTime? _pickupUntil;

  // UI state for publication time. Backend publish_at will be connected separately.
  int _publishDelayHours = 0;
  DateTime? _customPublishAt;
  bool _publicationScheduleChanged = false;
  bool _tagsExpanded = false;

  bool _hasUnsavedChanges = false;
  bool _trackingChanges = false;
  bool _dineInOnly = false;

  bool _firstListingGuideActive = false;
  bool _firstListingGuideInitialized = false;
  bool _firstListingWelcomeShown = false;
  final Set<String> _firstListingHelpShown = <String>{};

  XFile? _image;
  Uint8List? _imagePreviewBytes;

  double? _selectedLatitude;
  double? _selectedLongitude;
  String _selectedAddress = '';
  bool _locationWasEdited = false;

  bool get _isEdit => widget.product != null;

  bool get _isScheduledEdit =>
      _isEdit &&
          widget.product!.inactiveReason.trim().toLowerCase() == 'scheduled';

  @override
  void initState() {
    super.initState();
    _fillProductData();

    for (final controller in <TextEditingController>[
      _nameController,
      _descriptionController,
      _pickupDetailsController,
      _priceController,
      _discountController,
      _countController,
      _seatsController,
      _packageQuantityController,
      _weightController,
      _deliveryDaysController,
      _expirationDateController,
      _canUseUntilController,
    ]) {
      controller.addListener(_markDirty);
    }

    if (!_isEdit) {
      _publishDelayHours = 0;
      _customPublishAt = null;
    }

    _loadSellerCompanies();
  }

  void _fillProductData() {
    final product = widget.product;
    if (product == null) return;

    final discount = product.price > 0
        ? (((product.price - product.getDiscountPrice) / product.price) * 100).round()
        : 0;

    _nameController.text = product.name;
    _descriptionController.text = product.description ?? '';
    _priceController.text = product.price.toStringAsFixed(0);
    _discountController.text = discount.clamp(0, 100).toString();
    _countController.text = product.count.toString();
    _dineInOnly = product.dineInOnly;
    _seatsController.text = product.dineInOnly
        ? product.count.toString()
        : '1';

    _packageQuantityController.text = product.packageQuantity ?? '';
    _weightController.text = product.weight ?? '';
    _deliveryDaysController.text = product.deliveryDays?.toString() ?? '';
    _expirationDateController.text = _formatDateForInput(product.expirationDate);
    _canUseUntilController.text = _formatDateForInput(product.canUseUntil);

    _selectedCompanySlug = product.company.slug;
    _selectedType = product.type.isNotEmpty ? product.type : 'hot';

    _pickupFrom = product.pickupFromArmenia;
    _pickupUntil = product.pickupUntilArmenia;

    if (product.locationLatitude != null && product.locationLongitude != null) {
      _selectedLatitude = product.locationLatitude;
      _selectedLongitude = product.locationLongitude;
      _selectedAddress = product.locationAddress?.trim() ?? '';
      _locationWasEdited = true;
    }

    final productTags = product.tag ?? const <Tag>[];
    _selectedTagSlugs
      ..clear()
      ..addAll(
        productTags
            .map((tag) => tag.slug)
            .where((slug) => slug.trim().isNotEmpty),
      );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _pickupDetailsController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _countController.dispose();
    _seatsController.dispose();

    _packageQuantityController.dispose();
    _weightController.dispose();
    _deliveryDaysController.dispose();
    _expirationDateController.dispose();
    _canUseUntilController.dispose();

    _nameFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _countFocusNode.dispose();
    _seatsFocusNode.dispose();
    _priceFocusNode.dispose();
    _discountFocusNode.dispose();

    super.dispose();
  }

  Future<void> _loadSellerCompanies() async {
    try {
      final results = await Future.wait([
        ApiService.getMyCompanies(),
        ApiService.getSellerTags(),
      ]);

      final companies = results[0] as List<Map<String, dynamic>>;
      final tags = results[1] as List<Tag>;

      if (!mounted) return;

      setState(() {
        _companies = companies;
        _tags = tags;
        _selectedCompanySlug ??= companies.isNotEmpty
            ? companies.first['slug']?.toString()
            : null;
        _loading = false;
      });

      _syncLocationFromCompany(force: !_locationWasEdited);
      _trackingChanges = true;
      _hasUnsavedChanges = false;

      await _initializeFirstListingGuide();
    } catch (e) {
      if (!mounted) return;

      final l10n = AppLocalizations.of(context)!;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.loadDataError}: $e'),
        ),
      );
    }
  }


  Map<String, dynamic>? get _selectedCompanyData {
    for (final company in _companies) {
      if (company['slug']?.toString() == _selectedCompanySlug) {
        return company;
      }
    }
    return _companies.isNotEmpty ? _companies.first : null;
  }

  double? _tryParseCoordinate(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.'));
  }

  LatLng get _mapCenter {
    return LatLng(
      _selectedLatitude ?? 40.1792,
      _selectedLongitude ?? 44.4991,
    );
  }

  void _syncLocationFromCompany({bool force = false}) {
    final company = _selectedCompanyData;
    if (company == null) return;

    if (_locationWasEdited && !force) return;

    final latitude = _tryParseCoordinate(company['latitude']);
    final longitude = _tryParseCoordinate(company['longitude']);
    final address = company['address']?.toString().trim() ?? '';

    _selectedLatitude = latitude;
    _selectedLongitude = longitude;
    _selectedAddress = address;

    if (force) {
      _locationWasEdited = false;
    }
  }

  String _composeDescriptionForApi() {
    final bagDescription = _descriptionController.text.trim();

    // "Как забрать товар" is not applicable to dine-in offers.
    // Keep the text in the controller so it is restored if the seller
    // switches back to a normal HOT pickup offer, but do not send it.
    if (_dineInOnly) {
      return bagDescription;
    }

    final pickupDetails = _pickupDetailsController.text.trim();

    if (pickupDetails.isEmpty) {
      return bagDescription;
    }

    if (bagDescription.isEmpty) {
      return 'Pickup details: $pickupDetails';
    }

    return '$bagDescription\n\nPickup details: $pickupDetails';
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
                  l10n.addProductPhoto,
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
                    l10n.takePhoto,
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
                    l10n.chooseFromGallery,
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

    if (source == null || !mounted) return;

    XFile? sourceImage;

    if (source == ImageSource.camera) {
      sourceImage = await Navigator.of(context).push<XFile>(
        MaterialPageRoute(
          builder: (_) => const ProductCameraScreen(),
        ),
      );
    } else {
      sourceImage = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1800,
        maxHeight: 1800,
      );
    }

    if (sourceImage == null || !mounted) return;

    final edited = await ImageFrameEditorScreen.open(
      context,
      source: sourceImage,
      mode: ImageFrameEditorMode.product,
      outputFileName: 'hot_product.png',
    );

    if (edited == null || !mounted) return;

    setState(() {
      _image = edited.file;
      _imagePreviewBytes = edited.bytes;
    });

    _markDirty();
  }

  Future<void> _pickPickupDateTime({
    required bool isFrom,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final now = Product.nowInArmenia();

    final current = isFrom ? _pickupFrom : _pickupUntil;
    final fallback = isFrom
        ? now.add(const Duration(minutes: 30))
        : (_pickupFrom ?? now).add(const Duration(hours: 2));

    final seed = current ?? fallback;
    final today = DateTime(now.year, now.month, now.day);
    final seedDate = DateTime(seed.year, seed.month, seed.day);

    final date = await showDatePicker(
      context: context,
      initialDate: seedDate.isBefore(today) ? today : seedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: l10n.chooseDate,
      cancelText: l10n.cancel,
      confirmText: l10n.done,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: accentColor,
              onPrimary: Colors.black,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: seed.hour,
        minute: seed.minute,
      ),
      initialEntryMode: TimePickerEntryMode.inputOnly,
      helpText: l10n.selectTime,
      cancelText: l10n.cancel,
      confirmText: l10n.done,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: accentColor,
                onPrimary: Colors.black,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (time == null || !mounted) return;

    final result = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isFrom) {
        _pickupFrom = result;

        if (_pickupUntil == null || !_pickupUntil!.isAfter(result)) {
          _pickupUntil = result.add(const Duration(hours: 2));
        }
      } else {
        _pickupUntil = result;
      }
    });
    _markDirty();
  }

  String _formatPickupDateTime(DateTime? value) {
    if (value == null) return '';

    String two(int number) => number.toString().padLeft(2, '0');

    return '${two(value.day)}.${two(value.month)}.${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }


  Widget _buildPickupWindowFields() {
    Widget timeField({
      required String title,
      required DateTime? value,
      required VoidCallback onTap,
    }) {
      final display = _formatPickupDateTime(value);

      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor, width: 1.1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C7C7C),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        display.isEmpty ? AppLocalizations.of(context)!.sellerSelectDateTime : display,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: display.isEmpty ? Colors.grey.shade500 : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.schedule_rounded, size: 18, color: accentColor),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  _dineInOnly
                      ? _localizedInline(
                    'Время посещения',
                    'Visit time',
                    'Այցելության ժամ',
                  )
                      : AppLocalizations.of(context)!.sellerPickupWindow,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildHelpIconButton(
                onTap: () => _showGuideHelpManually(
                  'pickup_window',
                  _dineInOnly ? _showVisitTimeHelp : _showPickupHelp,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            timeField(
              title: AppLocalizations.of(context)!.sellerFrom,
              value: _pickupFrom,
              onTap: () async {
                await _showFirstListingHelpOnce(
                  'pickup_window',
                  _dineInOnly ? _showVisitTimeHelp : _showPickupHelp,
                );
                if (!mounted) return;
                await _pickPickupDateTime(isFrom: true);
              },
            ),
            const SizedBox(width: 10),
            const Text(
              '–',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7A7A7A),
              ),
            ),
            const SizedBox(width: 10),
            timeField(
              title: AppLocalizations.of(context)!.sellerTo,
              value: _pickupUntil,
              onTap: () async {
                await _showFirstListingHelpOnce(
                  'pickup_window',
                  _dineInOnly ? _showVisitTimeHelp : _showPickupHelp,
                );
                if (!mounted) return;
                await _pickPickupDateTime(isFrom: false);
              },
            ),
          ],
        ),
      ],
    );
  }


  DateTime _nowInYerevan() {
    // Armenia uses UTC+4 year-round.
    // We intentionally build a timezone-neutral wall-clock DateTime,
    // because backend receives publish_at_local and interprets it as Asia/Yerevan.
    final shifted = DateTime.now().toUtc().add(const Duration(hours: 4));

    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
    );
  }

  String _formatPublishAtLocalForApi(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');

    return '${value.year}-${two(value.month)}-${two(value.day)}'
        'T${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  String? _publishAtLocalForApi() {
    // During edit, no selection means "keep the existing schedule".
    if (_isEdit && !_publicationScheduleChanged) return null;

    if (_customPublishAt != null) {
      return _formatPublishAtLocalForApi(_customPublishAt!);
    }

    if (_publishDelayHours <= 0) {
      // Creation: 0 means publish now.
      // Scheduled edit never offers "now" here; Play on dashboard does that.
      return null;
    }

    final yerevanPublishAt = _nowInYerevan().add(
      Duration(hours: _publishDelayHours),
    );

    return _formatPublishAtLocalForApi(yerevanPublishAt);
  }

  String _publicationLabel() {
    final l10n = AppLocalizations.of(context)!;

    if (_isEdit && !_publicationScheduleChanged) {
      return l10n.sellerChangePublicationTime;
    }

    if (_customPublishAt != null) {
      final value = _customPublishAt!;
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(value.day)}.${two(value.month)}.${value.year} '
          '${two(value.hour)}:${two(value.minute)}';
    }

    if (_publishDelayHours <= 0) return l10n.sellerPublishNow;
    return l10n.sellerPublishInHours(_publishDelayHours);
  }

  Future<void> _pickCustomPublicationDateTime() async {
    final now = _nowInYerevan();
    final seed = _customPublishAt ?? now.add(const Duration(hours: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: seed,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: AppLocalizations.of(context)!.sellerPublicationDate,
      cancelText: AppLocalizations.of(context)!.cancel,
      confirmText: AppLocalizations.of(context)!.next,
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: seed.hour, minute: seed.minute),
      initialEntryMode: TimePickerEntryMode.inputOnly,
      helpText: AppLocalizations.of(context)!.sellerPublicationTime,
      cancelText: AppLocalizations.of(context)!.cancel,
      confirmText: AppLocalizations.of(context)!.done,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (time == null || !mounted) return;

    final result = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    if (!result.isAfter(_nowInYerevan())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.sellerPublicationMustBeFuture),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _customPublishAt = result;
      _publishDelayHours = -1;
      _publicationScheduleChanged = true;
    });
    _markDirty();
  }

  Future<void> _showPublicationPicker() async {
    final l10n = AppLocalizations.of(context)!;

    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final options = <MapEntry<int, String>>[
          if (!_isEdit) MapEntry(0, l10n.sellerPublishNow),
          MapEntry(1, l10n.sellerPublishInHours(1)),
          MapEntry(2, l10n.sellerPublishInHours(2)),
          MapEntry(3, l10n.sellerPublishInHours(3)),
          MapEntry(6, l10n.sellerPublishInHours(6)),
          MapEntry(12, l10n.sellerPublishInHours(12)),
          MapEntry(24, l10n.sellerPublishInHours(24)),
          MapEntry(-1, l10n.sellerChoosePublishDateTime),
        ];

        return SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
            children: options.map((entry) {
              final isSelected = _publicationScheduleChanged &&
                  (entry.key == -1
                      ? _customPublishAt != null
                      : _customPublishAt == null &&
                      _publishDelayHours == entry.key);

              return ListTile(
                leading: Icon(
                  entry.key == 0
                      ? Icons.bolt_rounded
                      : entry.key == -1
                      ? Icons.event_rounded
                      : Icons.schedule_rounded,
                  color: isSelected ? accentColor : Colors.grey.shade600,
                ),
                title: Text(
                  entry.value,
                  style: TextStyle(
                    fontWeight:
                    isSelected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(
                  Icons.check_circle_rounded,
                  color: accentColor,
                )
                    : null,
                onTap: () => Navigator.pop(sheetContext, entry.key),
              );
            }).toList(),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;

    if (selected == -1) {
      await _pickCustomPublicationDateTime();
      return;
    }

    setState(() {
      _publishDelayHours = selected;
      _customPublishAt = null;
      _publicationScheduleChanged = true;
    });
    _markDirty();
  }

  Product _buildDraftHotPreviewProduct() {
    final companyJson = _selectedCompanyData ?? <String, dynamic>{};

    final previewCompany = Company.fromJson({
      ...companyJson,
      'id': companyJson['id'] ?? 0,
      'slug': companyJson['slug'] ?? _selectedCompanySlug ?? 'preview-store',
      'name': companyJson['name'] ?? AppLocalizations.of(context)!.sellerYourOrganisation,
      'address': companyJson['address'] ?? '',
      'image_url': companyJson['image_url'] ?? '',
    });

    final selectedTags = _tags
        .where((tag) => _selectedTagSlugs.contains(tag.slug))
        .toList();

    final price = double.tryParse(
      _priceController.text.trim().replaceAll(',', '.'),
    ) ??
        0;
    final discount =
    (int.tryParse(_discountController.text.trim()) ?? 0).clamp(0, 100).toInt();
    final finalPrice = price * (1 - discount / 100);

    final existingImageUrl = widget.product?.imageUrl ?? '';
    final existingCardImageUrl =
        widget.product?.cardImageUrl ?? existingImageUrl;
    final existingThumbImageUrl =
        widget.product?.thumbImageUrl ?? existingImageUrl;

    return Product(
      name: _nameController.text.trim().isEmpty
          ? AppLocalizations.of(context)!.sellerPreviewProductName
          : _nameController.text.trim(),
      imageUrl: existingImageUrl,
      imageCardUrl: existingCardImageUrl,
      imageThumbUrl: existingThumbImageUrl,
      slug: widget.product?.slug ?? 'seller-preview-hot',
      price: price,
      getDiscountPrice: discount > 0 ? finalPrice : price,
      type: 'hot',
      description: _composeDescriptionForApi().isEmpty
          ? AppLocalizations.of(context)!.sellerPreviewProductDescription
          : _composeDescriptionForApi(),
      company: previewCompany,
      tag: selectedTags,
      count: _dineInOnly
          ? (int.tryParse(_seatsController.text.trim()) ?? 0)
          : (int.tryParse(_countController.text.trim()) ?? 0),
      dineInOnly: _dineInOnly,
      pickupFrom: _pickupFrom == null
          ? null
          : Product.armeniaWallTimeToIso(_pickupFrom!),
      pickupUntil: _pickupUntil == null
          ? null
          : Product.armeniaWallTimeToIso(_pickupUntil!),
      pickupDeadline: _pickupUntil == null
          ? null
          : Product.armeniaWallTimeToIso(_pickupUntil!),
      packageQuantity: _packageQuantityController.text.trim(),
      weight: _weightController.text.trim(),
      deliveryType: 'pickup',
      locationAddress: _selectedAddress,
      locationLatitude: _selectedLatitude,
      locationLongitude: _selectedLongitude,
      isPromoted: widget.product?.isPromoted ?? false,
    );
  }

  Future<void> _showPreview() async {
    if (!mounted) return;

    final previewProduct = _buildDraftHotPreviewProduct();

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              child: ProductCard(
                product: previewProduct,
                previewImageBytes: _imagePreviewBytes,
                previewMode: true,
                onPreviewTap: () {
                  Navigator.of(dialogContext).pop();
                  Future<void>.delayed(
                    Duration.zero,
                    _showPreviewDetail,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPreviewDetail() async {
    if (!mounted) return;

    final previewProduct = _buildDraftHotPreviewProduct();

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.50),
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, animation, _) {
          return FadeTransition(
            opacity: animation,
            child: ProductDetailScreen(
              product: previewProduct,
              previewImageBytes: _imagePreviewBytes,
              previewMode: true,
            ),
          );
        },
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 0.96,
                  end: 1,
                ).animate(curved),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }


  Future<void> _submit() async {
    if (_saving) return;

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      await _focusFirstInvalidField();
      return;
    }

    if (_selectedCompanySlug == null || _selectedCompanySlug!.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.companyNotFound)),
      );
      return;
    }

    if (!_isEdit && _image == null) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectProductPhoto)),
      );
      await _scrollToSection(_photoSectionKey);
      return;
    }

    final l10n = AppLocalizations.of(context)!;

    if (_selectedType == 'hot') {
      if (_pickupFrom == null || _pickupUntil == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pickupWindowRequired)),
        );
        await _scrollToSection(_pickupWindowKey);
        return;
      }

      if (!_pickupUntil!.isAfter(_pickupFrom!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pickupUntilAfterFrom)),
        );
        await _scrollToSection(_pickupWindowKey);
        return;
      }

      final pickupUntilUtc =
      Product.armeniaWallTimeToUtc(_pickupUntil!);

      if (!pickupUntilUtc.isAfter(DateTime.now().toUtc())) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pickupUntilFuture)),
        );
        await _scrollToSection(_pickupWindowKey);
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final price = _priceController.text.trim().replaceAll(',', '.');
      final discount = int.tryParse(_discountController.text.trim()) ?? 0;
      final count = _dineInOnly
          ? (int.tryParse(_seatsController.text.trim()) ?? 0)
          : (int.tryParse(_countController.text.trim()) ?? 1);
      final description = _composeDescriptionForApi();
      final name = _nameController.text.trim();

      final packageQuantity = _packageQuantityController.text.trim();
      final weight = _weightController.text.trim();
      final deliveryDays = int.tryParse(_deliveryDaysController.text.trim());
      final expirationDate = _dateToApi(_expirationDateController.text.trim());
      final canUseUntil = _dateToApi(_canUseUntilController.text.trim());
      final publishAtLocal = _publishAtLocalForApi();

      final deliveryTypeToSend =
      _selectedType == 'long' ? 'delivery' : 'pickup';

      final pickupFromToSend = _selectedType == 'hot' && _pickupFrom != null
          ? Product.armeniaWallTimeToIso(_pickupFrom!)
          : null;

      final pickupUntilToSend = _selectedType == 'hot' && _pickupUntil != null
          ? Product.armeniaWallTimeToIso(_pickupUntil!)
          : null;

      if (_isEdit) {
        await ApiService.updateSellerProduct(
          productSlug: widget.product!.slug,
          companySlug: _selectedCompanySlug!,
          name: name,
          imageBytes: _imagePreviewBytes,
          imageFileName: _image?.name,
          description: description,
          price: price,
          discount: discount,
          count: count,
          type: _selectedType,
          dineInOnly: _dineInOnly,
          tagSlugs: _selectedTagSlugs.toList(),
          packageQuantity: packageQuantity,
          weight: weight,
          deliveryType: deliveryTypeToSend,
          deliveryDays: deliveryDays,
          locationAddress: _selectedAddress,
          locationLatitude: _selectedLatitude,
          locationLongitude: _selectedLongitude,
          expirationDate: expirationDate,
          canUseUntil: canUseUntil,
          pickupFrom: pickupFromToSend,
          pickupUntil: pickupUntilToSend,
          publishAtLocal: publishAtLocal,
        );
      } else {
        final imageBytes = await _image!.readAsBytes();

        await ApiService.createSellerProduct(
          companySlug: _selectedCompanySlug!,
          name: name,
          imageBytes: imageBytes,
          imageFileName: _image!.name,
          description: description,
          price: price,
          discount: discount,
          count: count,
          type: _selectedType,
          dineInOnly: _dineInOnly,
          tagSlugs: _selectedTagSlugs.toList(),
          packageQuantity: packageQuantity,
          weight: weight,
          deliveryType: deliveryTypeToSend,
          deliveryDays: deliveryDays,
          locationAddress: _selectedAddress,
          locationLatitude: _selectedLatitude,
          locationLongitude: _selectedLongitude,
          expirationDate: expirationDate,
          canUseUntil: canUseUntil,
          pickupFrom: pickupFromToSend,
          pickupUntil: pickupUntilToSend,
          publishAtLocal: publishAtLocal,
        );
      }

      if (!mounted) return;

      final wasFirstListing =
          !_isEdit && _firstListingGuideActive;

      if (wasFirstListing) {
        await _markFirstListingPublished();
        if (!mounted) return;
        await _showFirstListingPublishedDialog();
        if (!mounted) return;
      } else {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? l10n.productUpdated : l10n.productAdded),
          ),
        );
      }

      _hasUnsavedChanges = false;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? '${l10n.productUpdateError}: $e'
                : '${l10n.productCreateError}: $e',
          ),
        ),
      );
      await _focusFieldForApiError(e);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _markDirty() {
    if (!_trackingChanges || _saving || _hasUnsavedChanges) return;
    if (!mounted) return;
    setState(() => _hasUnsavedChanges = true);
  }

  String _localizedInline(String ru, String en, String hy) {
    final language = Localizations.localeOf(context).languageCode.toLowerCase();
    if (language == 'hy') return hy;
    if (language == 'en') return en;
    return ru;
  }

  String get _firstListingGuideStorageKey {
    final companySlug = (_selectedCompanySlug ?? 'seller')
        .trim()
        .toLowerCase();
    return 'seller_first_listing_published_v1:$companySlug';
  }

  Future<void> _initializeFirstListingGuide() async {
    if (_isEdit || _firstListingGuideInitialized) return;
    if ((_selectedCompanySlug ?? '').trim().isEmpty) return;

    _firstListingGuideInitialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final completed =
          prefs.getBool(_firstListingGuideStorageKey) ?? false;

      if (!mounted || completed) return;

      setState(() {
        _firstListingGuideActive = true;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showFirstListingWelcome();
        }
      });
    } catch (_) {
      // The guide must never block product publication.
    }
  }

  Future<void> _showFirstListingWelcome() async {
    if (!_firstListingGuideActive ||
        _firstListingWelcomeShown ||
        !mounted) {
      return;
    }

    _firstListingWelcomeShown = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            _localizedInline(
              'Добро пожаловать!',
              'Welcome!',
              'Բարի գալուստ։',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            _localizedInline(
              'Спасибо, что стали нашим партнером в деле сокращения пищевых отходов и превращения ваших вечерних излишков в дополнительный доход. Поскольку это ваше первое объявление, мы подготовили краткое и простое руководство, которое поможет вам сделать отличную фотографию и настроить пакет для быстрой продажи.',
              'Thank you for partnering with us to reduce food waste and turn your end-of-day surplus into extra revenue. Since this is your very first listing, we’ve put together a quick, easy guide to help you snap a great photo and set up your bag for a fast sale.',
              'Շնորհակալություն մեզ հետ համագործակցելու և սննդի թափոնները կրճատելու, ինչպես նաև օրվա վերջի ավելցուկը հավելյալ եկամտի վերածելու համար։ Քանի որ սա ձեր առաջին հայտարարությունն է, մենք պատրաստել ենք արագ և պարզ ուղեցույց, որը կօգնի ձեզ անել հիանալի լուսանկար և կարգավորել փաթեթը՝ արագ վաճառքի համար։',
            ),
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF444444),
              fontWeight: FontWeight.w600,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: 130,
              child: FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.black,
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showFirstListingHelpOnce(
      String step,
      Future<void> Function() showHelp,
      ) async {
    if (!_firstListingGuideActive ||
        _firstListingHelpShown.contains(step) ||
        !mounted) {
      return;
    }

    _firstListingHelpShown.add(step);
    await showHelp();
  }

  Future<void> _showGuideHelpManually(
      String step,
      Future<void> Function() showHelp,
      ) async {
    if (_firstListingGuideActive) {
      _firstListingHelpShown.add(step);
    }

    await showHelp();
  }

  Future<void> _handleFirstListingPhotoTap() async {
    await _showFirstListingHelpOnce('photo', _showPhotoHelp);
    if (!mounted) return;
    await _pickImage();
  }

  Future<void> _markFirstListingPublished() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_firstListingGuideStorageKey, true);
    } catch (_) {
      // Publication has already succeeded; persistence failure must not fail it.
    }

    if (mounted) {
      setState(() {
        _firstListingGuideActive = false;
      });
    }
  }

  Future<void> _showFirstListingPublishedDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: accentColor,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _localizedInline(
                    'Ваш первый товар опубликован!',
                    'Your first product has been published!',
                    'Ձեր առաջին ապրանքը հրապարակվել է։',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF252525),
                  ),
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: 130,
              child: FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.black,
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            _localizedInline(
              'Выйти без сохранения?',
              'Leave without saving?',
              'Դուրս գալ առանց պահպանելու՞',
            ),
          ),
          content: Text(
            _localizedInline(
              'Внесённые изменения будут потеряны.',
              'Your unsaved changes will be lost.',
              'Չպահպանված փոփոխությունները կկորչեն։',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                _localizedInline('Остаться', 'Stay', 'Մնալ'),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.black,
              ),
              child: Text(
                _localizedInline('Выйти', 'Leave', 'Դուրս գալ'),
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _handleBack() async {
    final canLeave = await _confirmDiscardChanges();
    if (!canLeave || !mounted) return;

    _hasUnsavedChanges = false;
    Navigator.of(context).pop();
  }

  Future<void> _scrollToSection(GlobalKey key, {FocusNode? focusNode}) async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (!mounted) return;

    final fieldContext = key.currentContext;
    if (fieldContext != null) {
      await Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.18,
      );
    }

    if (focusNode != null && mounted) {
      focusNode.requestFocus();
    }
  }

  Future<void> _focusFirstInvalidField() async {
    if (_nameFieldKey.currentState?.hasError ?? false) {
      await _scrollToSection(_nameFieldKey, focusNode: _nameFocusNode);
      return;
    }

    if (_descriptionFieldKey.currentState?.hasError ?? false) {
      await _scrollToSection(
        _descriptionFieldKey,
        focusNode: _descriptionFocusNode,
      );
      return;
    }

    if (_dineInOnly) {
      if (_seatsFieldKey.currentState?.hasError ?? false) {
        await _scrollToSection(
          _seatsFieldKey,
          focusNode: _seatsFocusNode,
        );
        return;
      }
    } else {
      if (_countFieldKey.currentState?.hasError ?? false) {
        await _scrollToSection(
          _countFieldKey,
          focusNode: _countFocusNode,
        );
        return;
      }
    }

    if (_priceFieldKey.currentState?.hasError ?? false) {
      await _scrollToSection(_priceFieldKey, focusNode: _priceFocusNode);
      return;
    }

    if (_discountFieldKey.currentState?.hasError ?? false) {
      await _scrollToSection(
        _discountFieldKey,
        focusNode: _discountFocusNode,
      );
    }
  }

  Future<void> _focusFieldForApiError(Object error) async {
    final text = error.toString().toLowerCase();

    if (text.contains('image') ||
        text.contains('photo') ||
        text.contains('изображ') ||
        text.contains('фото')) {
      await _scrollToSection(_photoSectionKey);
      return;
    }

    if (text.contains('pickup') ||
        text.contains('pickup_from') ||
        text.contains('pickup_until')) {
      await _scrollToSection(_pickupWindowKey);
      return;
    }

    if (text.contains('location') ||
        text.contains('latitude') ||
        text.contains('longitude') ||
        text.contains('address') ||
        text.contains('адрес') ||
        text.contains('координат')) {
      await _scrollToSection(_locationSectionKey);
      return;
    }

    if (text.contains('tag') ||
        text.contains('category') ||
        text.contains('категор') ||
        text.contains('тег')) {
      await _scrollToSection(_tagsSectionKey);
      return;
    }

    if (text.contains('name') || text.contains('назван')) {
      await _scrollToSection(_nameFieldKey, focusNode: _nameFocusNode);
      return;
    }

    if (text.contains('description') || text.contains('описан')) {
      await _scrollToSection(
        _descriptionFieldKey,
        focusNode: _descriptionFocusNode,
      );
      return;
    }

    if (text.contains('seat') ||
        text.contains('мест') ||
        text.contains('dine_in')) {
      if (_dineInOnly) {
        await _scrollToSection(
          _seatsFieldKey,
          focusNode: _seatsFocusNode,
        );
      }
      return;
    }

    if (text.contains('count') ||
        text.contains('stock') ||
        text.contains('остат') ||
        text.contains('quantity')) {
      if (_dineInOnly) {
        await _scrollToSection(
          _seatsFieldKey,
          focusNode: _seatsFocusNode,
        );
      } else {
        await _scrollToSection(
          _countFieldKey,
          focusNode: _countFocusNode,
        );
      }
      return;
    }

    if (text.contains('discount') || text.contains('скид')) {
      await _scrollToSection(
        _discountFieldKey,
        focusNode: _discountFocusNode,
      );
      return;
    }

    if (text.contains('price') || text.contains('цен')) {
      await _scrollToSection(_priceFieldKey, focusNode: _priceFocusNode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F8F8),
        appBar: AppBar(
          leading: IconButton(
            onPressed: _saving ? null : _handleBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            _isEdit ? l10n.editProduct : l10n.addProduct,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _companies.isEmpty
            ? _buildEmptyCompanies()
            : _buildForm(),
        bottomNavigationBar: _loading || _companies.isEmpty
            ? null
            : SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 7, 14, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFEAEAEA)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: OutlinedButton(
                    onPressed: _saving ? null : _showPreview,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: Colors.black87,
                      side: const BorderSide(color: Color(0xFFDADADA)),
                      shape: const CircleBorder(),
                    ),
                    child: const Icon(
                      Icons.preview_rounded,
                      size: 19,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                              : Text(
                            _isEdit
                                ? l10n.saveChanges
                                : l10n.publishProduct,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap:
                      _saving ? null : _showPublicationPicker,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F1C9),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 18,
                              color: Color(0xFF5C5200),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _publicationLabel(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF5C5200),
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: Color(0xFF5C5200),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildEmptyCompanies() {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          l10n.companyNotFound,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }



  Widget _buildSectionTitleWithHelp({
    required String title,
    required VoidCallback onHelp,
  }) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF666666),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildHelpIconButton(onTap: onHelp),
        ),
      ],
    );
  }


  Widget _buildForm() {
    final l10n = AppLocalizations.of(context)!;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 130),
        children: [
          KeyedSubtree(key: _photoSectionKey, child: _buildPhotoSection()),
          const SizedBox(height: 16),
          if (_companies.length > 1) ...[
            _buildCompanySelector(),
            const SizedBox(height: 12),
          ],
          _buildOutlinedTextField(
            fieldKey: _nameFieldKey,
            focusNode: _nameFocusNode,
            controller: _nameController,
            label: l10n.sellerHotNameLabel,
            icon: Icons.edit_rounded,
            onTap: () => _showFirstListingHelpOnce(
              'name',
              _showNameHelp,
            ),
            suffixIcon: _buildTextFieldHelpButton(
                  () => _showGuideHelpManually(
                'name',
                _showNameHelp,
              ),
            ),
            alwaysShowLabel: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.enterProductName;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              l10n.sellerHotNameExample,
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFFB49900),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _buildOutlinedTextField(
            fieldKey: _descriptionFieldKey,
            focusNode: _descriptionFocusNode,
            controller: _descriptionController,
            label: l10n.sellerDescriptionLabel,
            icon: Icons.edit_rounded,
            minLines: 4,
            maxLines: 6,
            maxLength: _descriptionMaxLength,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.enterDescription;
              }
              if (value.length > _descriptionMaxLength) {
                return _localizedInline(
                  'Описание не должно превышать 700 символов.',
                  'Description must not exceed 700 characters.',
                  'Նկարագրությունը չպետք է գերազանցի 700 նիշը։',
                );
              }
              return null;
            },
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              l10n.sellerHotDescriptionExample,
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFFB49900),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          KeyedSubtree(
            key: _locationSectionKey,
            child: _buildLocationSection(),
          ),
          const SizedBox(height: 16),
          KeyedSubtree(key: _pickupWindowKey, child: _buildPickupWindowFields()),
          const SizedBox(height: 16),

          _buildSectionTitleWithHelp(
            title: _localizedInline(
              'Как забрать товар',
              'How to pick up the product',
              'Ինչպես ստանալ ապրանքը',
            ),
            onHelp: _dineInOnly
                ? _showDineInPickupDisabledHelp
                : () => _showGuideHelpManually(
              'pickup_details',
              _showPickupDetailsHelp,
            ),
          ),
          _buildOutlinedTextField(
            controller: _pickupDetailsController,
            label: _dineInOnly
                ? _localizedInline(
              'Не требуется для заказов в заведении',
              'Not required for dine-in orders',
              'Տեղում օգտագործվող պատվերների համար չի պահանջվում',
            )
                : '',
            icon: Icons.edit_rounded,
            enabled: !_dineInOnly,
            onTap: _dineInOnly
                ? null
                : () => _showFirstListingHelpOnce(
              'pickup_details',
              _showPickupDetailsHelp,
            ),
            minLines: 3,
            maxLines: 5,
          ),

          const SizedBox(height: 18),

          _buildSectionTitleWithHelp(
            title: _localizedInline(
              'Формат заказа',
              'Order format',
              'Պատվերի ձևաչափ',
            ),
            onHelp: _showDineInHelp,
          ),
          Container(
            decoration: BoxDecoration(
              color: _dineInOnly
                  ? accentColor.withValues(alpha: 0.10)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accentColor,
                width: 1.1,
              ),
            ),
            child: SwitchListTile.adaptive(
              value: _dineInOnly,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 3,
              ),
              secondary: const Icon(
                Icons.restaurant_rounded,
                color: accentColor,
              ),
              title: Text(
                _localizedInline(
                  'Только в заведении',
                  'Dine-in only',
                  'Միայն տեղում',
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF222222),
                ),
              ),
              subtitle: Text(
                _localizedInline(
                  'Покупатель употребляет заказ в вашем заведении.',
                  'The customer consumes the order at your venue.',
                  'Գնորդը պատվերը օգտագործում է ձեր հաստատությունում։',
                ),
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF666666),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _dineInOnly = value;
                  if (value && _seatsController.text.trim().isEmpty) {
                    final current =
                        int.tryParse(_countController.text.trim()) ?? 1;
                    _seatsController.text = current < 0
                        ? '0'
                        : current.toString();
                  }
                });
                _markDirty();
              },
            ),
          ),
          const SizedBox(height: 16),

          if (_dineInOnly) ...[
            _buildSectionTitleWithHelp(
              title: _localizedInline(
                'Доступные места',
                'Available seats',
                'Հասանելի տեղեր',
              ),
              onHelp: _showDineInHelp,
            ),
            _buildOutlinedTextField(
              fieldKey: _seatsFieldKey,
              focusNode: _seatsFocusNode,
              controller: _seatsController,
              label: '',
              icon: Icons.event_seat_rounded,
              keyboardType: TextInputType.number,
              validator: (value) {
                final seats = int.tryParse((value ?? '').trim());
                if (seats == null || seats < 1) {
                  return _localizedInline(
                    'Укажите количество доступных мест.',
                    'Enter the number of available seats.',
                    'Նշեք հասանելի տեղերի քանակը։',
                  );
                }
                return null;
              },
            ),
          ] else ...[
            _buildSectionTitleWithHelp(
              title: _localizedInline(
                'Количество в наличии',
                'Quantity in stock',
                'Առկա քանակ',
              ),
              onHelp: () => _showGuideHelpManually(
                'stock',
                _showStockQuantityHelp,
              ),
            ),
            _buildOutlinedTextField(
              fieldKey: _countFieldKey,
              focusNode: _countFocusNode,
              controller: _countController,
              label: '',
              icon: Icons.edit_rounded,
              keyboardType: TextInputType.number,
              onTap: () => _showFirstListingHelpOnce(
                'stock',
                _showStockQuantityHelp,
              ),
              validator: (value) {
                final count = int.tryParse((value ?? '').trim());
                if (count == null || count < 0) {
                  return l10n.sellerEnterStockQuantity;
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    l10n.sellerSetPrice,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildHelpIconButton(
                  onTap: () => _showGuideHelpManually(
                    'price',
                    _showPriceHelp,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: _buildOutlinedTextField(
                  fieldKey: _priceFieldKey,
                  focusNode: _priceFocusNode,
                  controller: _priceController,
                  label: l10n.sellerFullPrice,
                  icon: Icons.edit_rounded,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onTap: () => _showFirstListingHelpOnce(
                    'price',
                    _showPriceHelp,
                  ),
                  validator: (value) {
                    final price = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
                    if (price == null || price <= 0) {
                      return l10n.enterPrice;
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: _buildOutlinedTextField(
                  fieldKey: _discountFieldKey,
                  focusNode: _discountFocusNode,
                  controller: _discountController,
                  label: l10n.discountPercent,
                  icon: Icons.percent_rounded,
                  keyboardType: TextInputType.number,
                  alwaysShowLabel: true,
                  validator: (value) {
                    final discount = int.tryParse((value ?? '').trim());
                    if (discount == null || discount < 0 || discount > 100) {
                      return '0-100';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          KeyedSubtree(
            key: _tagsSectionKey,
            child: _buildTagsSection(),
          ),
        ],
      ),
    );
  }


  Widget _buildTagsSection() {
    final l10n = AppLocalizations.of(context)!;

    if (_tags.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor, width: 1.1),
        ),
        child: Text(
          l10n.noTagsAdded,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final selectedCount = _selectedTagSlugs.length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor, width: 1.1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              setState(() => _tagsExpanded = !_tagsExpanded);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 19,
                    color: accentColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.sellerRecommendedTags,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF555555),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F1C9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$selectedCount/$_maxProductTags',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF5C5200),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _tagsExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF6A6A6A),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _tagsExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedCount >= _maxProductTags
                        ? AppLocalizations.of(context)!.sellerMaxTagsSelected(_maxProductTags)
                        : AppLocalizations.of(context)!.sellerChooseUpToTags(_maxProductTags),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selectedCount >= _maxProductTags
                          ? const Color(0xFF8A7800)
                          : const Color(0xFF888888),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tags.map((tag) {
                      final selected =
                      _selectedTagSlugs.contains(tag.slug);
                      final canSelect =
                          selected || selectedCount < _maxProductTags;

                      return FilterChip(
                        selected: selected,
                        label: Text(tag.name),
                        selectedColor:
                        accentColor.withValues(alpha: 0.18),
                        checkmarkColor: const Color(0xFF7A6C00),
                        side: BorderSide(
                          color: selected
                              ? accentColor
                              : canSelect
                              ? Colors.grey.shade300
                              : Colors.grey.shade200,
                        ),
                        backgroundColor: Colors.white,
                        disabledColor: const Color(0xFFF5F5F5),
                        labelStyle: TextStyle(
                          fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected
                              ? const Color(0xFF444444)
                              : canSelect
                              ? const Color(0xFF555555)
                              : const Color(0xFFB8B8B8),
                        ),
                        onSelected: canSelect
                            ? (value) {
                          setState(() {
                            if (value) {
                              if (_selectedTagSlugs.length <
                                  _maxProductTags) {
                                _selectedTagSlugs.add(tag.slug);
                              }
                            } else {
                              _selectedTagSlugs.remove(tag.slug);
                            }
                          });
                          _markDirty();
                        }
                            : null,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPhotoSection() {
    final hasImage = _imagePreviewBytes != null ||
        (_isEdit && (widget.product?.imageUrl ?? '').isNotEmpty);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleFirstListingPhotoTap,
          child: AspectRatio(
            aspectRatio: 3 / 2,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/sell_bg.png',
                  fit: BoxFit.cover,
                ),
                if (_imagePreviewBytes != null)
                  Image.memory(
                    _imagePreviewBytes!,
                    fit: BoxFit.cover,
                  )
                else if (_isEdit &&
                    (widget.product?.imageUrl ?? '').isNotEmpty)
                  Image.network(
                    widget.product!.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),

                // Before a photo is selected, keep the large upload prompt.
                if (!hasImage)
                  Center(
                    child: Container(
                      width: 190,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.sellerAddPhotoShort,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(context)!.sellerTapUploadImage,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF777777),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // After selection, show the photo cleanly and keep only
                // a compact change-photo action in the top-right corner.
                if (hasImage)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.sellerTapChangePhoto,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),

                Positioned(
                  top: 12,
                  right: 12,
                  child: _buildHelpIconButton(
                    onTap: () => _showGuideHelpManually(
                      'photo',
                      _showPhotoHelp,
                    ),
                    size: 34,
                  ),
                ),
                if (hasImage)
                  Positioned(
                    top: 54,
                    right: 12,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanySelector() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCompanySlug,
      isExpanded: true,
      decoration: _outlinedDecoration(
        label: AppLocalizations.of(context)!.sellerOrganisation,
        prefixIcon: Icons.storefront_rounded,
      ),
      items: _companies.map((company) {
        final slug = company['slug']?.toString() ?? '';
        final name = company['name']?.toString() ?? slug;

        return DropdownMenuItem<String>(
          value: slug,
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _selectedCompanySlug = value;
          _syncLocationFromCompany(force: true);
        });
        _markDirty();
      },
    );
  }

  Widget _buildLocationSection() {
    final company = _selectedCompanyData;
    final companyAddress = company?['address']?.toString().trim() ?? '';
    final address = _selectedAddress.isNotEmpty
        ? _selectedAddress
        : companyAddress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            AppLocalizations.of(context)!.sellerPickupLocation,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF666666),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accentColor, width: 1.1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SellerProductLocationPicker(
                initialPoint: _mapCenter,
                initialAddress: address,
                onChanged: (location) {
                  final changedFromCompany =
                      location.point.latitude !=
                          _tryParseCoordinate(company?['latitude']) ||
                          location.point.longitude !=
                              _tryParseCoordinate(company?['longitude']) ||
                          location.address.trim() != companyAddress;

                  setState(() {
                    _selectedLatitude = location.point.latitude;
                    _selectedLongitude = location.point.longitude;
                    _selectedAddress = location.address.trim();
                    _locationWasEdited = changedFromCompany;
                  });
                  _markDirty();
                },
              ),
              const SizedBox(height: 10),
              Text(
                _locationWasEdited
                    ? AppLocalizations.of(context)!.sellerPickupPointMovedHint
                    : AppLocalizations.of(context)!
                    .sellerPickupPointOrganisationHint,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF777777),
                  height: 1.3,
                ),
              ),
              if (_selectedLatitude != null &&
                  _selectedLongitude != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${AppLocalizations.of(context)!.latitude}: '
                      '${_selectedLatitude!.toStringAsFixed(6)} • '
                      '${AppLocalizations.of(context)!.longitude}: '
                      '${_selectedLongitude!.toStringAsFixed(6)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF909090),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (_locationWasEdited) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _syncLocationFromCompany(force: true));
                    _markDirty();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    AppLocalizations.of(context)!
                        .sellerUseOrganisationLocation,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF7A6C00),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHelpIconButton({
    required VoidCallback onTap,
    double size = 28,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            shape: BoxShape.circle,
            border: Border.all(color: accentColor, width: 1.1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '?',
            style: TextStyle(
              color: const Color(0xFF7A6C00),
              fontSize: size * 0.55,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFieldHelpButton(VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: _buildHelpIconButton(
        onTap: onTap,
        size: 24,
      ),
    );
  }

  Widget _helpParagraph(String text, {Color? color, FontWeight fontWeight = FontWeight.w600}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: color ?? const Color(0xFF333333),
          fontWeight: fontWeight,
        ),
      ),
    );
  }

  Widget _helpPhotoExampleCard({
    required String label,
    required Color labelColor,
    required String assetPath,
    String? fallbackEmoji,
  }) {
    return Container(
      width: 132,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F3EA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7D99A), width: 1.2),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: labelColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(
            height: 98,
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    fallbackEmoji ?? '🖼️',
                    style: const TextStyle(fontSize: 34),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _helpPhotoCompareExamples() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _helpPhotoExampleCard(
            label: 'BEFORE',
            labelColor: const Color(0xFFE95E5E),
            assetPath: 'assets/icons/photo_before.png',
            fallbackEmoji: '📷',
          ),
          const SizedBox(width: 10),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFE8E8E8),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFCACACA)),
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: Color(0xFF777777),
            ),
          ),
          const SizedBox(width: 10),
          _helpPhotoExampleCard(
            label: 'AFTER',
            labelColor: const Color(0xFF42A853),
            assetPath: 'assets/icons/photo_after.png',
            fallbackEmoji: '✨',
          ),
        ],
      ),
    );
  }

  Widget _helpBullet(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Icon(Icons.circle, size: 7, color: Color(0xFF232323)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF333333),
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showHelpSheet({
    required IconData icon,
    required String title,
    String? subtitle,
    String? accentLine,
    required List<Widget> children,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.84;
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(maxHeight: maxHeight),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.2),
                          color: accentColor,
                        ),
                        child: Icon(icon, color: Colors.white, size: 38),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.45,
                              color: Color(0xFF333333),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (accentLine != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            accentLine,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.4,
                              color: Color(0xFFB49900),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        ...children,
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(sheetContext)!.sellerHelpContinue,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPhotoHelp() {
    final l10n = AppLocalizations.of(context)!;

    return _showHelpSheet(
      icon: Icons.photo_camera_outlined,
      title: l10n.sellerHelpPhotoTitle,
      subtitle: l10n.sellerHelpPhotoHotIntro,
      accentLine: l10n.sellerHelpPhotoStepTitle,
      children: [
        _helpPhotoCompareExamples(),
        _helpParagraph(
          l10n.sellerHelpPhotoCleanTitle,
          fontWeight: FontWeight.w900,
        ),
        _helpParagraph(
          l10n.sellerHelpPhotoCleanAccent,
          color: const Color(0xFFB49900),
          fontWeight: FontWeight.w900,
        ),
        _helpParagraph(l10n.sellerHelpPhotoCleanBody),
        _helpBullet(
          l10n.sellerHelpPhotoBackgroundTitle,
          l10n.sellerHelpPhotoBackgroundHot,
        ),
        _helpBullet(
          l10n.sellerHelpPhotoLightingTitle,
          l10n.sellerHelpPhotoLightingHot,
        ),
        _helpBullet(
          l10n.sellerHelpPhotoShowTitle,
          l10n.sellerHelpPhotoShowHot,
        ),
        _helpBullet(
          _localizedInline(
            'Формат и разрешение',
            'Format and resolution',
            'Ձևաչափ և լուծաչափ',
          ),
          _localizedInline(
            'Используйте горизонтальное изображение в формате 3:2. Рекомендуемый размер — 1800 × 1200 пикселей. Располагайте товар ближе к центру кадра, чтобы он хорошо выглядел в карточках и на странице товара.',
            'Use a horizontal image in a 3:2 aspect ratio. The recommended size is 1800 × 1200 pixels. Keep the product near the center of the frame so it looks good in cards and on the product page.',
            'Օգտագործեք հորիզոնական պատկեր՝ 3:2 հարաբերակցությամբ։ Առաջարկվող չափը՝ 1800 × 1200 պիքսել։ Ապրանքը տեղադրեք կադրի կենտրոնին մոտ, որպեսզի այն լավ երևա քարտերում և ապրանքի էջում։',
          ),
        ),
      ],
    );
  }

  Future<void> _showNameHelp() {
    final l10n = AppLocalizations.of(context)!;

    return _showHelpSheet(
      icon: Icons.edit_note_rounded,
      title: l10n.sellerHelpListingTitle,
      subtitle: l10n.sellerHelpListingIntro,
      accentLine: l10n.sellerHelpNameHotAccent,
      children: [
        _helpParagraph(l10n.sellerHelpNameHotBody1),
        _helpParagraph(l10n.sellerHelpNameHotBody2),
      ],
    );
  }

  Future<void> _showVisitTimeHelp() {
    return _showHelpSheet(
      icon: Icons.schedule_rounded,
      title: _localizedInline(
        'Время посещения',
        'Visit time',
        'Այցելության ժամ',
      ),
      subtitle: _localizedInline(
        'Укажите период, в который покупатель может прийти и воспользоваться предложением в заведении.',
        'Set the period when the customer can visit and use the offer at your venue.',
        'Նշեք այն ժամանակահատվածը, երբ գնորդը կարող է այցելել և օգտվել առաջարկից ձեր հաստատությունում։',
      ),
      children: [
        _helpParagraph(
          _localizedInline(
            'Покупатель увидит это время как «Когда прийти».',
            'The customer will see this time as “When to visit”.',
            'Գնորդը այս ժամանակը կտեսնի որպես «Երբ այցելել»։',
          ),
        ),
      ],
    );
  }

  Future<void> _showDineInPickupDisabledHelp() {
    return _showHelpSheet(
      icon: Icons.restaurant_rounded,
      title: _localizedInline(
        'Как забрать товар',
        'How to pick up the product',
        'Ինչպես ստանալ ապրանքը',
      ),
      subtitle: _localizedInline(
        'Для режима «Только в заведении» это поле не используется.',
        'This field is not used for “Dine-in only” offers.',
        '«Միայն տեղում» ռեժիմում այս դաշտը չի օգտագործվում։',
      ),
      children: [
        _helpParagraph(
          _localizedInline(
            'Покупатель приходит в указанное время посещения и употребляет заказ в заведении.',
            'The customer visits during the specified visit time and consumes the order at the venue.',
            'Գնորդը գալիս է նշված այցելության ժամանակ և պատվերն օգտագործում է հաստատությունում։',
          ),
        ),
      ],
    );
  }

  Future<void> _showPickupHelp() {
    final l10n = AppLocalizations.of(context)!;

    return _showHelpSheet(
      icon: Icons.schedule_rounded,
      title: l10n.sellerHelpListingTitle,
      subtitle: l10n.sellerHelpPickupIntro,
      children: [
        _helpParagraph(l10n.sellerHelpPickupBody1),
        _helpParagraph(l10n.sellerHelpPickupBody2),
      ],
    );
  }

  Future<void> _showPickupDetailsHelp() {
    return _showHelpSheet(
      icon: Icons.shopping_bag_outlined,
      title: _localizedInline(
        'Как забрать товар',
        'How to pick up the product',
        'Ինչպես ստանալ ապրանքը',
      ),
      subtitle: _localizedInline(
        'Эта инструкция будет понятна покупателю после покупки.',
        'This instruction helps the buyer collect the order after purchase.',
        'Այս հրահանգը կօգնի գնորդին ստանալ պատվերը գնումից հետո։',
      ),
      children: [
        _helpParagraph(
          _localizedInline(
            'Укажите, где и как получить заказ. Например: «Подойдите к кассе и назовите номер заказа».',
            'Explain where and how to collect the order. For example: “Go to the counter and provide the order number.”',
            'Նշեք՝ որտեղ և ինչպես ստանալ պատվերը։ Օրինակ՝ «Մոտեցեք դրամարկղին և նշեք պատվերի համարը»։',
          ),
        ),
      ],
    );
  }

  Future<void> _showDineInHelp() {
    return _showHelpSheet(
      icon: Icons.event_seat_rounded,
      title: _localizedInline(
        'Только в заведении',
        'Dine-in only',
        'Միայն տեղում',
      ),
      subtitle: _localizedInline(
        'Используйте этот режим, если предложение предназначено для употребления в вашем заведении.',
        'Use this mode when the offer must be consumed at your venue.',
        'Օգտագործեք այս ռեժիմը, եթե առաջարկը պետք է օգտագործվի ձեր հաստատությունում։',
      ),
      children: [
        _helpParagraph(
          _localizedInline(
            'Вместо количества товара укажите число доступных мест. Каждое бронирование уменьшает число свободных мест. На карточке покупатель увидит значок стула и актуальное количество мест.',
            'Instead of product stock, enter the number of available seats. Each reservation reduces the number of available seats. The customer card shows a seat icon and the current seat count.',
            'Ապրանքի քանակի փոխարեն նշեք հասանելի տեղերի քանակը։ Յուրաքանչյուր ամրագրումից հետո ազատ տեղերի քանակը կնվազի։ Քարտում գնորդը կտեսնի նստատեղի նշանը և հասանելի տեղերի ընթացիկ քանակը։',
          ),
        ),
      ],
    );
  }

  Future<void> _showStockQuantityHelp() {
    return _showHelpSheet(
      icon: Icons.inventory_2_outlined,
      title: _localizedInline(
        'Количество в наличии',
        'Quantity in stock',
        'Առկա քանակ',
      ),
      subtitle: _localizedInline(
        'Укажите фактическое количество товара, доступное для покупки.',
        'Enter the actual number of units available for purchase.',
        'Նշեք գնման համար հասանելի ապրանքի իրական քանակը։',
      ),
      children: [
        _helpParagraph(
          _localizedInline(
            'Например, значение «1» означает, что покупатель может приобрести только одну доступную единицу.',
            'For example, a value of “1” means only one unit is currently available for purchase.',
            'Օրինակ՝ «1» արժեքը նշանակում է, որ գնման համար հասանելի է միայն մեկ միավոր։',
          ),
        ),
      ],
    );
  }

  Future<void> _showPriceHelp() {
    final l10n = AppLocalizations.of(context)!;

    return _showHelpSheet(
      icon: Icons.attach_money_rounded,
      title: l10n.sellerHelpPriceTitle,
      subtitle: l10n.sellerHelpPriceIntro,
      children: [
        _helpParagraph(l10n.sellerHelpPriceBody1),
        _helpParagraph(l10n.sellerHelpPriceBody2),
      ],
    );
  }


  Widget _buildOutlinedTextField({
    Key? fieldKey,
    FocusNode? focusNode,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int minLines = 1,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
    bool readOnly = false,
    bool enabled = true,
    VoidCallback? onTap,
    Widget? suffixIcon,
    bool alwaysShowLabel = false,
  }) {
    return TextFormField(
      key: fieldKey,
      focusNode: focusNode,
      controller: controller,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      readOnly: readOnly,
      enabled: enabled,
      onTap: onTap,
      decoration: _outlinedDecoration(
        label: label,
        prefixIcon: icon,
        suffixIcon: suffixIcon,
        alwaysShowLabel: alwaysShowLabel,
        enabled: enabled,
      ),
    );
  }

  InputDecoration _outlinedDecoration({
    required String label,
    required IconData prefixIcon,
    Widget? suffixIcon,
    bool alwaysShowLabel = false,
    bool enabled = true,
  }) {
    const normalBorder = BorderSide(
      color: accentColor,
      width: 1.1,
    );

    final normalizedLabel = label.trim();

    return InputDecoration(
      labelText: normalizedLabel.isEmpty ? null : normalizedLabel,
      alignLabelWithHint: true,
      floatingLabelBehavior: normalizedLabel.isEmpty
          ? FloatingLabelBehavior.never
          : (alwaysShowLabel
          ? FloatingLabelBehavior.always
          : FloatingLabelBehavior.never),
      filled: true,
      fillColor: enabled ? Colors.white : const Color(0xFFF2F2F2),
      prefixIcon: Icon(
        prefixIcon,
        color: enabled ? accentColor : const Color(0xFFAAAAAA),
        size: 18,
      ),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      counterStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF8A7900),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: normalBorder,
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFD5D5D5),
          width: 1.1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: accentColor,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.2,
        ),
      ),
    );
  }


  String _formatDateForInput(String? value) {
    if (value == null || value.trim().isEmpty) return '';

    final text = value.trim();

    if (text.contains('T')) {
      final date = text.split('T').first;
      final parts = date.split('-');
      if (parts.length == 3) {
        return '${parts[2]}.${parts[1]}.${parts[0]}';
      }
    }

    if (text.contains('-')) {
      final parts = text.split('-');
      if (parts.length == 3) {
        return '${parts[2]}.${parts[1]}.${parts[0]}';
      }
    }

    if (text.contains('.')) {
      return text;
    }

    return text;
  }

  String _dateToApi(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';

    if (text.contains('.')) {
      final parts = text.split('.');
      if (parts.length == 3) {
        return '${parts[2]}-${parts[1]}-${parts[0]}';
      }
    }

    return text;
  }
}
