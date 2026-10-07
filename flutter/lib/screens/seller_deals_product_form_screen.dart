// lib/screens/seller_deals_product_form_screen.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

import '../models/product.dart';
import '../models/tag.dart';
import '../services/api_service.dart';
import '../widgets/deal_product_card.dart';
import '../widgets/seller_product_location_picker.dart';
import 'deal_detail_screen.dart';
import 'product_camera_screen.dart';
import 'image_frame_editor_screen.dart';

class SellerDealsProductFormScreen extends StatefulWidget {
  final Product? product;

  const SellerDealsProductFormScreen({
    super.key,
    this.product,
  });

  @override
  State<SellerDealsProductFormScreen> createState() =>
      _SellerDealsProductFormScreenState();
}

class _SellerDealsProductFormScreenState
    extends State<SellerDealsProductFormScreen> {
  static const Color accentColor = Color(0xFFD1BC00);
  static const int _descriptionMaxLength = 700;

  static const List<int> _deliveryRadiusOptions = <int>[
    1,
    3,
    5,
    10,
    20,
    30,
    50,
  ];

  static const List<int> _deliveryDaysOptions = <int>[
    1,
    2,
    3,
    5,
    7,
    14,
  ];

  final _formKey = GlobalKey<FormState>();

  final _photoSectionKey = GlobalKey();
  final _categorySectionKey = GlobalKey();
  final _deliverySectionKey = GlobalKey();

  final _nameFieldKey = GlobalKey<FormFieldState<String>>();
  final _packageFieldKey = GlobalKey<FormFieldState<String>>();
  final _descriptionFieldKey = GlobalKey<FormFieldState<String>>();
  final _expirationFieldKey = GlobalKey<FormFieldState<String>>();
  final _bestBeforeFieldKey = GlobalKey<FormFieldState<String>>();
  final _countFieldKey = GlobalKey<FormFieldState<String>>();
  final _priceFieldKey = GlobalKey<FormFieldState<String>>();
  final _discountFieldKey = GlobalKey<FormFieldState<String>>();

  final _nameFocusNode = FocusNode();
  final _packageFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _countFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();
  final _discountFocusNode = FocusNode();

  final _nameController = TextEditingController();
  final _packageQuantityController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _expirationDateController = TextEditingController();
  final _canUseUntilController = TextEditingController();
  final _countController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _discountController = TextEditingController(text: '0');

  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  bool _hasNoExpirationDate = false;

  List<Map<String, dynamic>> _companies = <Map<String, dynamic>>[];
  List<Tag> _tags = <Tag>[];

  String? _selectedCompanySlug;
  final Set<String> _selectedTagSlugs = <String>{};

  bool _hasUnsavedChanges = false;
  bool _trackingChanges = false;

  bool _firstListingGuideActive = false;
  bool _firstListingGuideInitialized = false;
  bool _firstListingWelcomeShown = false;
  final Set<String> _firstListingHelpShown = <String>{};

  int _deliveryRadiusKm = 5;
  int _deliveryDays = 1;

  LatLng? _deliveryCenter;
  String _deliveryAddress = '';
  bool _deliveryLocationWasEdited = false;

  // Publication time is in Yerevan time. 0 means publish now.
  int _publishDelayHours = 0;
  DateTime? _customPublishAt;
  bool _publicationScheduleChanged = false;

  XFile? _image;
  Uint8List? _imagePreviewBytes;

  bool get _isEdit => widget.product != null;

  bool get _isScheduledEdit =>
      _isEdit &&
          widget.product!.inactiveReason.trim().toLowerCase() == 'scheduled';

  bool get _isExpiredEdit =>
      _isEdit &&
          widget.product!.inactiveReason.trim().toLowerCase() ==
              'expiration_expired';

  bool get _canReactivateExpiredProduct {
    if (!_isExpiredEdit) return false;
    if (_hasNoExpirationDate) return true;

    final newExpiration = _parseDate(_expirationDateController.text);
    final oldExpiration = _parseDate(widget.product!.expirationDate ?? '');
    if (newExpiration == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final newDateOnly = DateTime(
      newExpiration.year,
      newExpiration.month,
      newExpiration.day,
    );

    return !newDateOnly.isBefore(today) &&
        !_sameCalendarDate(newExpiration, oldExpiration);
  }

  bool _sameCalendarDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  void initState() {
    super.initState();
    _fillProductData();

    for (final controller in <TextEditingController>[
      _nameController,
      _packageQuantityController,
      _descriptionController,
      _expirationDateController,
      _canUseUntilController,
      _countController,
      _priceController,
      _discountController,
    ]) {
      controller.addListener(_markDirty);
    }

    if (!_isEdit) {
      _publishDelayHours = 0;
      _customPublishAt = null;
    }

    _loadData();
  }

  void _fillProductData() {
    final product = widget.product;
    if (product == null) return;

    final discount = product.price > 0
        ? (((product.price - product.getDiscountPrice) / product.price) * 100)
        .round()
        : 0;

    _selectedCompanySlug = product.company.slug;
    _nameController.text = product.name;
    _packageQuantityController.text = product.packageQuantity ?? '';
    _descriptionController.text = product.description ?? '';
    _expirationDateController.text =
        _formatDateForInput(product.expirationDate);
    _canUseUntilController.text = _formatDateForInput(product.canUseUntil);
    _hasNoExpirationDate =
        _expirationDateController.text.trim().isEmpty &&
            _canUseUntilController.text.trim().isEmpty;
    _countController.text = product.count.toString();
    _priceController.text = product.price.toStringAsFixed(0);
    _discountController.text = discount.clamp(0, 100).toString();

    _deliveryDays = product.deliveryDays ?? 1;
    _deliveryRadiusKm = product.deliveryRadiusKm ?? 5;

    if (product.locationLatitude != null && product.locationLongitude != null) {
      _deliveryCenter = LatLng(
        product.locationLatitude!,
        product.locationLongitude!,
      );
      _deliveryAddress = product.locationAddress?.trim() ?? '';
      _deliveryLocationWasEdited = true;
    }

    final productTags = product.tag ?? const <Tag>[];
    _selectedTagSlugs
      ..clear()
      ..addAll(productTags.take(3).map((tag) => tag.slug));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _packageQuantityController.dispose();
    _descriptionController.dispose();
    _expirationDateController.dispose();
    _canUseUntilController.dispose();
    _countController.dispose();
    _priceController.dispose();
    _discountController.dispose();

    _nameFocusNode.dispose();
    _packageFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _countFocusNode.dispose();
    _priceFocusNode.dispose();
    _discountFocusNode.dispose();

    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait<dynamic>([
        ApiService.getMyCompanies(),
        ApiService.getSellerTags(),
      ]);

      if (!mounted) return;

      final companies = List<Map<String, dynamic>>.from(results[0] as List);
      final tags = List<Tag>.from(results[1] as List);

      setState(() {
        _companies = companies;
        _tags = tags;
        _selectedCompanySlug ??= companies.isNotEmpty
            ? companies.first['slug']?.toString()
            : null;
        _loading = false;
      });

      _syncDeliveryLocationFromCompany(force: !_deliveryLocationWasEdited);
      _trackingChanges = true;
      _hasUnsavedChanges = false;

      await _initializeFirstListingGuide();
    } catch (error) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)!.loadDataError}: $error'),
          behavior: SnackBarBehavior.floating,
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

  double? _parseCoordinate(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim().replaceAll(',', '.'));
  }

  LatLng? get _selectedCompanyPoint {
    final company = _selectedCompanyData;
    if (company == null) return null;

    final latitude = _parseCoordinate(company['latitude']);
    final longitude = _parseCoordinate(company['longitude']);

    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    return LatLng(latitude, longitude);
  }

  String get _selectedCompanyAddress {
    return _selectedCompanyData?['address']?.toString().trim() ?? '';
  }

  LatLng get _effectiveDeliveryPoint =>
      _deliveryCenter ?? _selectedCompanyPoint ?? const LatLng(40.1792, 44.4991);

  String get _effectiveDeliveryAddress {
    if (_deliveryAddress.trim().isNotEmpty) return _deliveryAddress.trim();
    return _selectedCompanyAddress;
  }

  void _syncDeliveryLocationFromCompany({bool force = false}) {
    if (_deliveryLocationWasEdited && !force) return;
    final point = _selectedCompanyPoint;
    if (point == null) return;

    _deliveryCenter = point;
    _deliveryAddress = _selectedCompanyAddress;
    if (force) _deliveryLocationWasEdited = false;
  }

  Future<void> _pickImage() async {
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
                  AppLocalizations.of(context)!.addProductPhoto,
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
                    AppLocalizations.of(context)!.takePhoto,
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
                    AppLocalizations.of(context)!.chooseFromGallery,
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
        imageQuality: 80,
        maxWidth: 1800,
        maxHeight: 1800,
      );
    }

    if (sourceImage == null || !mounted) return;

    final edited = await ImageFrameEditorScreen.open(
      context,
      source: sourceImage,
      mode: ImageFrameEditorMode.product,
      outputFileName: 'deals_product.png',
    );

    if (edited == null || !mounted) return;

    setState(() {
      _image = edited.file;
      _imagePreviewBytes = edited.bytes;
    });

    _markDirty();
  }

  Future<void> _pickDate(
      TextEditingController controller, {
        required String title,
      }) async {
    final now = DateTime.now();
    final current = _parseDate(controller.text) ?? now;

    final result = await showDatePicker(
      context: context,
      initialDate: current.isBefore(DateTime(now.year, now.month, now.day))
          ? now
          : current,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 3650)),
      helpText: title,
      cancelText: AppLocalizations.of(context)!.cancel,
      confirmText: AppLocalizations.of(context)!.done,
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

    if (result == null) return;

    controller.text =
    '${result.day.toString().padLeft(2, '0')}.'
        '${result.month.toString().padLeft(2, '0')}.'
        '${result.year}';

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _selectCategory() async {
    if (_tags.isEmpty) return;

    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final tempSelected = <String>{..._selectedTagSlugs};
        String? selectionError;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.76,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _localizedInline(
                                    'Выберите до 3 тегов',
                                    'Choose up to 3 tags',
                                    'Ընտրեք մինչև 3 պիտակ',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _localizedInline(
                                    'Выбрано: ${tempSelected.length}/3',
                                    'Selected: ${tempSelected.length}/3',
                                    'Ընտրված է՝ ${tempSelected.length}/3',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF8A7900),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: tempSelected.isEmpty
                                ? null
                                : () {
                              setSheetState(() {
                                tempSelected.clear();
                                selectionError = null;
                              });
                            },
                            child: Text(
                              _localizedInline('Очистить', 'Clear', 'Մաքրել'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selectionError != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            selectionError!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                        itemCount: _tags.length,
                        itemBuilder: (context, index) {
                          final tag = _tags[index];
                          final isSelected = tempSelected.contains(tag.slug);

                          return CheckboxListTile(
                            value: isSelected,
                            activeColor: accentColor,
                            checkColor: Colors.black,
                            controlAffinity: ListTileControlAffinity.trailing,
                            title: Text(
                              tag.name,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                              ),
                            ),
                            onChanged: (_) {
                              setSheetState(() {
                                if (isSelected) {
                                  tempSelected.remove(tag.slug);
                                  selectionError = null;
                                  return;
                                }

                                if (tempSelected.length >= 3) {
                                  selectionError = _localizedInline(
                                    'Можно выбрать не более 3 тегов.',
                                    'You can select no more than 3 tags.',
                                    'Կարելի է ընտրել առավելագույնը 3 պիտակ։',
                                  );
                                  return;
                                }

                                tempSelected.add(tag.slug);
                                selectionError = null;
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(
                            sheetContext,
                            <String>{...tempSelected},
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.done,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
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
      },
    );

    if (selected == null || !mounted) return;

    setState(() {
      _selectedTagSlugs
        ..clear()
        ..addAll(selected.take(3));
    });
    _markDirty();
  }

  String _selectedTagsName() {
    if (_selectedTagSlugs.isEmpty) {
      return AppLocalizations.of(context)!.sellerChooseCategory;
    }

    final names = _tags
        .where((tag) => _selectedTagSlugs.contains(tag.slug))
        .map((tag) => tag.name)
        .take(3)
        .toList();

    if (names.isEmpty) {
      return AppLocalizations.of(context)!.sellerChooseCategory;
    }

    return names.join(' • ');
  }

  DateTime _nowInYerevan() {
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
    String two(int number) => number.toString().padLeft(2, '0');

    return '${value.year}-${two(value.month)}-${two(value.day)}'
        'T${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  String? _publishAtLocalForApi() {
    if (_isEdit && !_publicationScheduleChanged) return null;

    if (_customPublishAt != null) {
      return _formatPublishAtLocalForApi(_customPublishAt!);
    }

    if (_publishDelayHours <= 0) {
      return null;
    }

    return _formatPublishAtLocalForApi(
      _nowInYerevan().add(Duration(hours: _publishDelayHours)),
    );
  }

  String _publicationLabel() {
    final l10n = AppLocalizations.of(context)!;

    if (_isEdit && !_publicationScheduleChanged) {
      return l10n.sellerChangePublicationTime;
    }

    if (_customPublishAt != null) {
      final value = _customPublishAt!;
      String two(int n) => n.toString().padLeft(2, '0');

      return '${two(value.day)}.${two(value.month)} '
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
      helpText: AppLocalizations.of(context)!.sellerPublicationTime,
      cancelText: AppLocalizations.of(context)!.cancel,
      confirmText: AppLocalizations.of(context)!.done,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child!,
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

    if (!result.isAfter(now)) {
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

  Future<void> _showPublicationOptions() async {
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

  Product _buildDraftPreviewProduct() {
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
        .take(3)
        .toList();

    final price = double.tryParse(
      _priceController.text.trim().replaceAll(',', '.'),
    ) ??
        0;
    final discount =
    (int.tryParse(_discountController.text.trim()) ?? 0).clamp(0, 100);
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
      slug: widget.product?.slug ?? 'seller-preview-deal',
      price: price,
      getDiscountPrice: discount > 0 ? finalPrice : price,
      type: 'long',
      description: _descriptionController.text.trim().isEmpty
          ? AppLocalizations.of(context)!.sellerPreviewProductDescription
          : _descriptionController.text.trim(),
      company: previewCompany,
      tag: selectedTags,
      count: int.tryParse(_countController.text.trim()) ?? 0,
      packageQuantity: _packageQuantityController.text.trim(),
      weight: '',
      deliveryType: 'delivery',
      deliveryDays: _deliveryDays,
      deliveryRadiusKm: _deliveryRadiusKm,
      locationAddress: _effectiveDeliveryAddress,
      locationLatitude: _effectiveDeliveryPoint.latitude,
      locationLongitude: _effectiveDeliveryPoint.longitude,
      expirationDate: _hasNoExpirationDate
          ? null
          : _dateForApi(_expirationDateController.text),
      canUseUntil: _hasNoExpirationDate
          ? null
          : _dateForApi(_canUseUntilController.text),
      isPromoted: widget.product?.isPromoted ?? false,
    );
  }

  Future<void> _showPreview() async {
    if (!mounted) return;

    final previewProduct = _buildDraftPreviewProduct();

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
              child: DealProductCard(
                product: previewProduct,
                width: double.infinity,
                previewImageBytes: _imagePreviewBytes,
                previewMode: true,
                onPreviewTap: () {
                  Navigator.of(dialogContext).pop();
                  Future<void>.delayed(
                    Duration.zero,
                    _showPreviewDetail,
                  );
                },
                onAddToCart: (_) async {},
                onToggleFavorite: () async {},
                isAddingToCart: false,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPreviewDetail() async {
    if (!mounted) return;

    final previewProduct = _buildDraftPreviewProduct();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DealDetailScreen(
          product: previewProduct,
          previewImageBytes: _imagePreviewBytes,
          previewMode: true,
        ),
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
      _showError(AppLocalizations.of(context)!.sellerNoOrganisation);
      await _scrollToSection(_photoSectionKey);
      return;
    }

    if (_selectedTagSlugs.isEmpty) {
      _showError(AppLocalizations.of(context)!.sellerCategoryRequired);
      await _scrollToSection(_categorySectionKey);
      return;
    }

    if (_selectedTagSlugs.length > 3) {
      _showError(_localizedInline(
        'Можно выбрать не более 3 тегов.',
        'You can select no more than 3 tags.',
        'Կարելի է ընտրել առավելագույնը 3 պիտակ։',
      ));
      await _scrollToSection(_categorySectionKey);
      return;
    }

    if (!_isEdit && _imagePreviewBytes == null) {
      _showError(AppLocalizations.of(context)!.selectProductPhoto);
      await _scrollToSection(_photoSectionKey);
      return;
    }

    final expirationDate = _hasNoExpirationDate
        ? null
        : _parseDate(_expirationDateController.text);
    final canUseUntil = _hasNoExpirationDate
        ? null
        : _parseDate(_canUseUntilController.text);
    final expirationDateApi = _hasNoExpirationDate
        ? null
        : _dateForApi(_expirationDateController.text);
    final canUseUntilApi = _hasNoExpirationDate
        ? null
        : _dateForApi(_canUseUntilController.text);

    if (!_hasNoExpirationDate &&
        _expirationDateController.text.trim().isNotEmpty &&
        expirationDate == null) {
      _showError(AppLocalizations.of(context)!.sellerCheckExpirationDate);
      await _scrollToSection(_expirationFieldKey);
      return;
    }

    if (!_hasNoExpirationDate &&
        _canUseUntilController.text.trim().isNotEmpty &&
        canUseUntil == null) {
      _showError(AppLocalizations.of(context)!.sellerCheckUseBeforeDate);
      await _scrollToSection(_bestBeforeFieldKey);
      return;
    }

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    if (expirationDate != null) {
      final expirationOnly = DateTime(
        expirationDate.year,
        expirationDate.month,
        expirationDate.day,
      );

      if (expirationOnly.isBefore(todayOnly)) {
        final originalExpirationDate = _isEdit
            ? _parseDate(widget.product!.expirationDate ?? '')
            : null;
        final unchangedExpiredDate =
            _isEdit &&
                _sameCalendarDate(expirationDate, originalExpirationDate);

        // An already expired item stays visible in the seller cabinet and can
        // still be edited. We only reject creating a product with a past date
        // or changing an existing product to a different past date.
        if (!unchangedExpiredDate) {
          _showError(_localizedInline(
            'Нельзя указывать новый срок годности в прошлом.',
            'You cannot set a new expiration date in the past.',
            'Չի կարելի նոր պիտանելիության ժամկետ նշել անցյալում։',
          ));
          await _scrollToSection(_expirationFieldKey);
          return;
        }
      }
    }

    if (
    expirationDate != null &&
        canUseUntil != null &&
        canUseUntil.isAfter(expirationDate)
    ) {
      _showError(_localizedInline(
        'Дата «Лучше употребить до» не может быть позже срока годности.',
        'The “Best Before” date cannot be later than the expiration date.',
        '«Best Before» ամսաթիվը չի կարող լինել պիտանելիության ժամկետից ուշ։',
      ));
      await _scrollToSection(_bestBeforeFieldKey);
      return;
    }

    final count = int.tryParse(_countController.text.trim()) ?? 0;
    final discount = int.tryParse(_discountController.text.trim()) ?? 0;

    setState(() => _saving = true);

    try {
      if (_isEdit) {
        await ApiService.updateSellerProduct(
          productSlug: widget.product!.slug,
          companySlug: _selectedCompanySlug!,
          name: _nameController.text.trim(),
          imageBytes: _imagePreviewBytes,
          imageFileName: _image?.name,
          description: _descriptionController.text.trim(),
          price: _priceController.text.trim().replaceAll(',', '.'),
          discount: discount,
          count: count,
          type: 'long',
          packageQuantity: _packageQuantityController.text.trim(),
          weight: '',
          deliveryType: 'delivery',
          deliveryDays: _deliveryDays,
          deliveryRadiusKm: _deliveryRadiusKm,
          locationAddress: _effectiveDeliveryAddress,
          locationLatitude: _effectiveDeliveryPoint.latitude,
          locationLongitude: _effectiveDeliveryPoint.longitude,
          expirationDate: expirationDateApi,
          canUseUntil: canUseUntilApi,
          publishAtLocal: _publishAtLocalForApi(),
          tagSlugs: _selectedTagSlugs.toList(),
        );
      } else {
        await ApiService.createSellerProduct(
          companySlug: _selectedCompanySlug!,
          name: _nameController.text.trim(),
          imageBytes: _imagePreviewBytes!,
          imageFileName: _image?.name ?? 'deals_product.jpg',
          description: _descriptionController.text.trim(),
          price: _priceController.text.trim().replaceAll(',', '.'),
          discount: discount,
          count: count,
          type: 'long',
          packageQuantity: _packageQuantityController.text.trim(),
          weight: '',
          deliveryType: 'delivery',
          deliveryDays: _deliveryDays,
          deliveryRadiusKm: _deliveryRadiusKm,
          locationAddress: _effectiveDeliveryAddress,
          locationLatitude: _effectiveDeliveryPoint.latitude,
          locationLongitude: _effectiveDeliveryPoint.longitude,
          expirationDate: expirationDateApi,
          canUseUntil: canUseUntilApi,
          publishAtLocal: _publishAtLocalForApi(),
          tagSlugs: _selectedTagSlugs.toList(),
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
      }

      _hasUnsavedChanges = false;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString());
      await _focusFieldForApiError(error);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _scrollToSection(
      GlobalKey key, {
        FocusNode? focusNode,
      }) async {
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

    if (_packageFieldKey.currentState?.hasError ?? false) {
      await _scrollToSection(_packageFieldKey, focusNode: _packageFocusNode);
      return;
    }

    if (_descriptionFieldKey.currentState?.hasError ?? false) {
      await _scrollToSection(
        _descriptionFieldKey,
        focusNode: _descriptionFocusNode,
      );
      return;
    }

    if (_countFieldKey.currentState?.hasError ?? false) {
      await _scrollToSection(_countFieldKey, focusNode: _countFocusNode);
      return;
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

    if (text.contains('tag') ||
        text.contains('category') ||
        text.contains('категор') ||
        text.contains('тег')) {
      await _scrollToSection(_categorySectionKey);
      return;
    }

    if (text.contains('expiration')) {
      await _scrollToSection(_expirationFieldKey);
      return;
    }

    if (text.contains('can_use_until') ||
        text.contains('best before') ||
        text.contains('use before')) {
      await _scrollToSection(_bestBeforeFieldKey);
      return;
    }

    if (text.contains('delivery') ||
        text.contains('radius') ||
        text.contains('location') ||
        text.contains('latitude') ||
        text.contains('longitude') ||
        text.contains('address') ||
        text.contains('достав') ||
        text.contains('адрес') ||
        text.contains('координат')) {
      await _scrollToSection(_deliverySectionKey);
      return;
    }

    if (text.contains('name') || text.contains('назван')) {
      await _scrollToSection(_nameFieldKey, focusNode: _nameFocusNode);
      return;
    }

    if (text.contains('package_quantity') ||
        text.contains('package') ||
        text.contains('пакет')) {
      await _scrollToSection(
        _packageFieldKey,
        focusNode: _packageFocusNode,
      );
      return;
    }

    if (text.contains('description') || text.contains('описан')) {
      await _scrollToSection(
        _descriptionFieldKey,
        focusNode: _descriptionFocusNode,
      );
      return;
    }

    if (text.contains('count') ||
        text.contains('stock') ||
        text.contains('quantity') ||
        text.contains('остат')) {
      await _scrollToSection(_countFieldKey, focusNode: _countFocusNode);
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

  void _markDirty() {
    if (!_trackingChanges || _saving || _hasUnsavedChanges) return;
    if (!mounted) return;
    setState(() => _hasUnsavedChanges = true);
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

  Widget _buildExpiredStatusBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB4AB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.event_busy_rounded,
              size: 21,
              color: Color(0xFFB3261E),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _localizedInline(
                    'Срок годности истёк',
                    'Expiration date has passed',
                    'Պիտանելիության ժամկետը լրացել է',
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB3261E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _localizedInline(
                    'Товар автоматически снят с продажи. Укажите новый срок годности, при необходимости обновите остаток и цену. После сохранения товар снова появится в продаже.',
                    'The product was automatically taken off sale. Set a new expiration date and update stock or price if needed. After saving, the product will go back on sale.',
                    'Ապրանքն ավտոմատ հանվել է վաճառքից։ Նշեք նոր պիտանելիության ժամկետը, անհրաժեշտության դեպքում թարմացրեք մնացորդն ու գինը։ Պահպանումից հետո ապրանքը կրկին կվաճառվի։',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Color(0xFF7A1C16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            _isEdit
                ? _localizedInline(
              'Редактировать товар',
              'Edit product',
              'Խմբագրել ապրանքը',
            )
                : _localizedInline(
              'Добавить товар',
              'Add product',
              'Ավելացնել ապրանք',
            ),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildForm(),
        bottomNavigationBar: _loading ? null : _buildBottomBar(),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 160),
        children: [
          if (_isExpiredEdit) _buildExpiredStatusBanner(),
          KeyedSubtree(
            key: _photoSectionKey,
            child: _buildPhotoSection(),
          ),
          const SizedBox(height: 16),
          if (_companies.length > 1) ...[
            _buildCompanySelector(),
            const SizedBox(height: 12),
          ],
          _buildOutlinedTextField(
            fieldKey: _nameFieldKey,
            focusNode: _nameFocusNode,
            controller: _nameController,
            label: AppLocalizations.of(context)!.sellerDealsNameLabel,
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
            validator: _requiredValidator(AppLocalizations.of(context)!.enterProductName),
          ),
          const SizedBox(height: 12),
          _buildOutlinedTextField(
            fieldKey: _packageFieldKey,
            focusNode: _packageFocusNode,
            controller: _packageQuantityController,
            label: AppLocalizations.of(context)!.sellerDealsPackageLabel,
            icon: Icons.edit_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            validator: (value) {
              final quantity = int.tryParse((value ?? '').trim());

              if (quantity == null || quantity < 1) {
                return _localizedInline(
                  'Укажите количество в упаковке цифрами.',
                  'Enter the package quantity using digits.',
                  'Փաթեթի քանակը նշեք թվերով։',
                );
              }

              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildOutlinedTextField(
            fieldKey: _descriptionFieldKey,
            focusNode: _descriptionFocusNode,
            controller: _descriptionController,
            label: AppLocalizations.of(context)!.sellerDescriptionLabel,
            icon: Icons.edit_rounded,
            minLines: 4,
            maxLines: 6,
            maxLength: _descriptionMaxLength,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return AppLocalizations.of(context)!.enterDescription;
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
              AppLocalizations.of(context)!.sellerDealsDescriptionExample,
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFFB49900),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          KeyedSubtree(
            key: _deliverySectionKey,
            child: _buildDeliveryRadiusField(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    AppLocalizations.of(context)!.sellerWhenDeliver,
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
                    'delivery_time',
                    _showDeliveryTimingHelp,
                  ),
                ),
              ),
            ],
          ),
          _buildDeliveryDaysField(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    AppLocalizations.of(context)!.sellerExpirationDate,
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
                    'dates',
                    _showDatesHelp,
                  ),
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.75),
                width: 1.1,
              ),
            ),
            child: CheckboxListTile(
              value: _hasNoExpirationDate,
              activeColor: accentColor,
              checkColor: Colors.black,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 2,
              ),
              title: Text(
                _localizedInline(
                  'Товар не имеет срока годности',
                  'Product has no expiration date',
                  'Ապրանքը պիտանելիության ժամկետ չունի',
                ),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF555555),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _hasNoExpirationDate = value == true;

                  if (_hasNoExpirationDate) {
                    _expirationDateController.clear();
                    _canUseUntilController.clear();
                  }
                });
                _markDirty();
              },
            ),
          ),
          _buildOutlinedTextField(
            fieldKey: _expirationFieldKey,
            controller: _expirationDateController,
            label: AppLocalizations.of(context)!.sellerExpirationDate,
            icon: Icons.edit_rounded,
            readOnly: true,
            enabled: !_hasNoExpirationDate,
            onTap: _hasNoExpirationDate
                ? null
                : () async {
              await _showFirstListingHelpOnce(
                'dates',
                _showDatesHelp,
              );
              if (!mounted) return;
              await _pickDate(
                _expirationDateController,
                title:
                AppLocalizations.of(context)!.sellerExpirationDate,
              );
            },
            suffixIcon: _hasNoExpirationDate
                ? const Icon(Icons.block_rounded, size: 18)
                : _dateClearButton(_expirationDateController),
          ),
          const SizedBox(height: 12),
          _buildOutlinedTextField(
            fieldKey: _bestBeforeFieldKey,
            controller: _canUseUntilController,
            label: AppLocalizations.of(context)!.sellerBestBeforeDate,
            icon: Icons.edit_rounded,
            readOnly: true,
            enabled: !_hasNoExpirationDate,
            onTap: _hasNoExpirationDate
                ? null
                : () async {
              await _showFirstListingHelpOnce(
                'dates',
                _showDatesHelp,
              );
              if (!mounted) return;
              await _pickDate(
                _canUseUntilController,
                title:
                AppLocalizations.of(context)!.sellerUseBeforeDate,
              );
            },
            suffixIcon: _hasNoExpirationDate
                ? const Icon(Icons.block_rounded, size: 18)
                : _dateClearButton(_canUseUntilController),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              _hasNoExpirationDate
                  ? _localizedInline(
                'Даты не требуются для этого товара.',
                'Dates are not required for this product.',
                'Այս ապրանքի համար ամսաթվեր չեն պահանջվում։',
              )
                  : AppLocalizations.of(context)!.sellerDatesOptionalHint,
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFFB49900),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _buildOutlinedTextField(
            fieldKey: _countFieldKey,
            focusNode: _countFocusNode,
            controller: _countController,
            label: AppLocalizations.of(context)!.sellerDealsStockRemaining,
            icon: Icons.inventory_2_outlined,
            keyboardType: TextInputType.number,
            alwaysShowLabel: true,
            validator: (value) {
              final count = int.tryParse((value ?? '').trim());
              if (count == null || count < 1) {
                return AppLocalizations.of(context)!.sellerEnterStockQuantity;
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                  child: Text(
                    AppLocalizations.of(context)!.sellerSetPrice,
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
                  label: AppLocalizations.of(context)!.sellerFullPrice,
                  icon: Icons.edit_rounded,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  onTap: () => _showFirstListingHelpOnce(
                    'price',
                    _showPriceHelp,
                  ),
                  validator: (value) {
                    final price = double.tryParse(
                      (value ?? '').trim().replaceAll(',', '.'),
                    );
                    if (price == null || price <= 0) {
                      return AppLocalizations.of(context)!.enterPrice;
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: _buildOutlinedTextField(
                  fieldKey: _discountFieldKey,
                  focusNode: _discountFocusNode,
                  controller: _discountController,
                  label: AppLocalizations.of(context)!.discountPercent,
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
            key: _categorySectionKey,
            child: _buildCategoryField(),
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
          child: Text(name, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCompanySlug = value;
          _syncDeliveryLocationFromCompany(force: true);
        });
        _markDirty();
      },
    );
  }

  Widget _buildDeliveryRadiusField() {
    final center = _effectiveDeliveryPoint;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_shipping_outlined,
                color: accentColor,
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.sellerDeliveryArea,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF555555),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F1C9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  AppLocalizations.of(context)!
                      .sellerRadiusKm(_deliveryRadiusKm),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF5C5200),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SellerProductLocationPicker(
            initialPoint: center,
            initialAddress: _effectiveDeliveryAddress,
            radiusKm: _deliveryRadiusKm,
            onChanged: (location) {
              final companyPoint = _selectedCompanyPoint;
              final companyAddress = _selectedCompanyAddress;
              final moved = companyPoint == null ||
                  location.point.latitude != companyPoint.latitude ||
                  location.point.longitude != companyPoint.longitude ||
                  location.address.trim() != companyAddress;

              setState(() {
                _deliveryCenter = location.point;
                _deliveryAddress = location.address.trim();
                _deliveryLocationWasEdited = moved;
                if (location.radiusKm != null) {
                  _deliveryRadiusKm = location.radiusKm!;
                }
              });
              _markDirty();
            },
            onRadiusChanged: (radius) {
              setState(() => _deliveryRadiusKm = radius);
              _markDirty();
            },
          ),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context)!.sellerDeliveryRadiusHint,
            style: const TextStyle(
              fontSize: 10.8,
              color: Color(0xFF777777),
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          Slider(
            value: _deliveryRadiusKm.toDouble(),
            min: 1,
            max: 50,
            divisions: 49,
            activeColor: accentColor,
            label:
            AppLocalizations.of(context)!.sellerRadiusKm(_deliveryRadiusKm),
            onChanged: (value) {
              setState(() => _deliveryRadiusKm = value.round());
              _markDirty();
            },
          ),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: _deliveryRadiusOptions.map((radius) {
              final selected = radius == _deliveryRadiusKm;
              return ChoiceChip(
                label: Text(
                  AppLocalizations.of(context)!.sellerRadiusKm(radius),
                ),
                selected: selected,
                showCheckmark: false,
                selectedColor: accentColor.withValues(alpha: 0.20),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: selected ? accentColor : const Color(0xFFE1E1E1),
                ),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight:
                  selected ? FontWeight.w900 : FontWeight.w700,
                  color: selected
                      ? const Color(0xFF625700)
                      : const Color(0xFF666666),
                ),
                onSelected: (_) {
                  setState(() => _deliveryRadiusKm = radius);
                  _markDirty();
                },
              );
            }).toList(),
          ),
          if (_deliveryLocationWasEdited) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () {
                setState(() => _syncDeliveryLocationFromCompany(force: true));
                _markDirty();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                _localizedInline(
                  'Использовать точку организации',
                  'Use organisation location',
                  'Օգտագործել կազմակերպության կետը',
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF7A6C00),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }


  Future<int?> _pickCustomDeliveryDays() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(
      text: _deliveryDays > 14 ? _deliveryDays.toString() : '',
    );

    String? errorText;

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submit() {
              final days = int.tryParse(controller.text.trim());

              if (days == null || days < 1 || days > 365) {
                setDialogState(() {
                  errorText = l10n.sellerCustomDeliveryDaysRange;
                });
                return;
              }

              Navigator.of(dialogContext).pop(days);
            }

            return AlertDialog(
              title: Text(l10n.sellerCustomDeliveryDaysTitle),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(),
                decoration: InputDecoration(
                  labelText: l10n.sellerCustomDeliveryDaysHint,
                  errorText: errorText,
                  suffixText: l10n.sellerDaysShort,
                  border: const OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(l10n.done),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  Widget _buildDeliveryDaysField() {
    final l10n = AppLocalizations.of(context)!;

    final options = <int>{
      ..._deliveryDaysOptions,
      _deliveryDays,
    }.toList()
      ..sort();

    final items = <DropdownMenuItem<int>>[
      ...options.map((days) {
        return DropdownMenuItem<int>(
          value: days,
          child: Text(
            days == 1
                ? l10n.sellerWithinOneDay
                : l10n.sellerWithinDays(days),
          ),
        );
      }),
      DropdownMenuItem<int>(
        value: -1,
        child: Row(
          children: [
            const Icon(
              Icons.edit_calendar_outlined,
              size: 18,
              color: accentColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.sellerCustomDeliveryDays,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ];

    return DropdownButtonFormField<int>(
      initialValue: _deliveryDays,
      isExpanded: true,
      decoration: _outlinedDecoration(
        label: l10n.sellerWhenDeliver,
        prefixIcon: Icons.calendar_month_outlined,
        alwaysShowLabel: true,
      ),
      items: items,
      onChanged: (value) async {
        if (value == null) return;

        if (value == -1) {
          final customDays = await _pickCustomDeliveryDays();
          if (!mounted || customDays == null) return;

          setState(() => _deliveryDays = customDays);
          _markDirty();
          return;
        }

        setState(() => _deliveryDays = value);
        _markDirty();
      },
    );
  }

  Widget _buildCategoryField() {
    final selected = _selectedTagSlugs.isNotEmpty;

    return InkWell(
      onTap: _selectCategory,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor, width: 1.1),
        ),
        child: Row(
          children: [
            const Icon(Icons.edit_rounded, color: accentColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.category,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF999999),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedTagsName(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? const Color(0xFF454545)
                          : const Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF555555),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + safeBottom),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor:
                      accentColor.withValues(alpha: 0.45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                        : Text(
                      _canReactivateExpiredProduct
                          ? _localizedInline(
                        'Сохранить и вернуть в продажу',
                        'Save and put back on sale',
                        'Պահպանել և վերադարձնել վաճառքի',
                      )
                          : (_isEdit
                          ? AppLocalizations.of(context)!.sellerSave
                          : AppLocalizations.of(context)!.publishProduct),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: _showPublicationOptions,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 44,
                  constraints: const BoxConstraints(minWidth: 118),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F5CF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.65),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 17,
                        color: Color(0xFF5E5400),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          _publicationLabel(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF5E5400),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Color(0xFF5E5400),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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

  String _cleanHelpText(String value) {
    var result = value.replaceAll(
      RegExp(r'Deals', caseSensitive: false),
      '',
    );

    result = result.replaceAll(RegExp(r'\s{2,}'), ' ');
    result = result.replaceAll(RegExp(r'\s+([,.;:!?])'), r'$1');

    return result.trim();
  }

  Widget _helpParagraph(String text, {Color? color, FontWeight fontWeight = FontWeight.w600}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        _cleanHelpText(text),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(
            minHeight: 180,
            maxHeight: 280,
          ),
          color: const Color(0xFFF8F3EA),
          padding: const EdgeInsets.all(8),
          child: SvgPicture.asset(
            'assets/images/deals_help_bg.svg',
            fit: BoxFit.contain,
          ),
        ),
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
                    text: '${_cleanHelpText(title)}: ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: _cleanHelpText(body)),
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
                            _cleanHelpText(title),
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
                            _cleanHelpText(subtitle),
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
                            _cleanHelpText(accentLine),
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
      subtitle: l10n.sellerHelpPhotoDealsIntro,
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
          l10n.sellerHelpPhotoBackgroundDeals,
        ),
        _helpBullet(
          l10n.sellerHelpPhotoLightingTitle,
          l10n.sellerHelpPhotoLightingDeals,
        ),
        _helpBullet(
          l10n.sellerHelpPhotoShowTitle,
          l10n.sellerHelpPhotoShowDeals,
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
      accentLine: l10n.sellerHelpNameDealsAccent,
      children: [
        _helpParagraph(l10n.sellerHelpNameDealsBody1),
        _helpParagraph(l10n.sellerHelpNameDealsBody2),
      ],
    );
  }

  Future<void> _showDeliveryTimingHelp() {
    final l10n = AppLocalizations.of(context)!;

    return _showHelpSheet(
      icon: Icons.schedule_rounded,
      title: l10n.sellerHelpDeliveryTitle,
      subtitle: l10n.sellerHelpDeliveryIntro,
      children: [
        _helpParagraph(l10n.sellerHelpDeliveryBody1),
        _helpParagraph(l10n.sellerHelpDeliveryBody2),
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

  String _localizedInline(String ru, String en, String hy) {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    switch (code) {
      case 'hy':
        return hy;
      case 'ru':
        return ru;
      default:
        return en;
    }
  }


  Future<void> _showDatesHelp() {
    return _showHelpSheet(
      icon: Icons.calendar_month_rounded,
      title: _localizedInline(
        'Зачем указывать дату?',
        'Why Add a Date?',
        'Ինչու ավելացնել ամսաթիվը?',
      ),
      subtitle: _localizedInline(
        'Эти поля необязательны, но они делают карточку товара понятнее и повышают доверие покупателей.',
        'These fields are optional, but they make your product listing clearer and build customer trust.',
        'Այս դաշտերը պարտադիր չեն, բայց ապրանքի քարտը դարձնում են ավելի հասկանալի և ավելացնում են գնորդների վստահությունը։',
      ),
      accentLine: _localizedInline(
        'Короткий совет по сроку годности',
        'Quick Tip for setting best before date',
        'Արագ հուշում՝ «Best before» ամսաթիվը լրացնելու համար',
      ),
      children: [
        _helpBullet(
          _localizedInline(
            'Полная прозрачность',
            'Total Transparency',
            'Լիակատար թափանցիկություն',
          ),
          _localizedInline(
            'Покупателям важно заранее понимать качество и свежесть товара, который они получат.',
            'Customers love knowing the quality of what they are getting.',
            'Գնորդները սիրում են իմանալ, թե ինչ որակի ապրանք են ստանալու։',
          ),
        ),
        _helpBullet(
          _localizedInline(
            'Быстрые продажи',
            'Fast Sales',
            'Արագ վաճառք',
          ),
          _localizedInline(
            'Товары с понятным индикатором свежести вызывают больше доверия и помогают покупателю быстрее решиться на заказ.',
            'Items with a clear freshness indicator give buyers confidence to pick up the bag right away.',
            'Թարմության հստակ նշումով ապրանքներն ավելի վստահություն են ներշնչում և օգնում են գնորդներին արագ որոշում կայացնել։',
          ),
        ),
        const SizedBox(height: 6),
        _helpBullet(
          _localizedInline(
            'Правило «Лучше употребить до»',
            'The "Best Before" Rule',
            '«Best Before» կանոնը',
          ),
          _localizedInline(
            'Напоминайте покупателям через встроенную подсказку приложения, что отметка «Лучше употребить до» говорит о пике вкуса и качества, а не о безопасности. Такие товары полностью вкусные и безопасные — их можно съесть сразу после получения или заморозить.',
            'Remind your customers (via our built-in app disclaimer) that “Best Before” is about peak flavor and quality, not safety. These items are 100% delicious and safe to eat right away or freeze upon pickup!',
            'Հիշեցրեք գնորդներին հավելվածի ներկառուցված բացատրության միջոցով, որ «Best Before»-ը վերաբերում է առավելագույն համին և որակին, ոչ թե անվտանգությանը։ Այսպիսի ապրանքները լիովին համեղ և անվտանգ են․ կարելի է վերցնելուց անմիջապես հետո ուտել կամ սառեցնել։',
          ),
        ),
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
    List<TextInputFormatter>? inputFormatters,
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
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      decoration: _outlinedDecoration(
        label: label,
        prefixIcon: icon,
        suffixIcon: suffixIcon,
        alwaysShowLabel: alwaysShowLabel,
      ),
    );
  }

  InputDecoration _outlinedDecoration({
    required String label,
    required IconData prefixIcon,
    Widget? suffixIcon,
    bool alwaysShowLabel = false,
  }) {
    const normalBorder = BorderSide(color: accentColor, width: 1.1);

    return InputDecoration(
      labelText: label,
      alignLabelWithHint: true,
      floatingLabelBehavior: alwaysShowLabel
          ? FloatingLabelBehavior.always
          : FloatingLabelBehavior.never,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(prefixIcon, color: accentColor, size: 18),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      counterStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF8A7900),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: normalBorder,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: accentColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: normalBorder,
      ),
    );
  }

  Widget _dateClearButton(TextEditingController controller) {
    if (controller.text.trim().isEmpty) {
      return const Icon(Icons.calendar_today_outlined, size: 18);
    }

    return IconButton(
      tooltip: AppLocalizations.of(context)!.sellerClearDate,
      onPressed: () {
        setState(controller.clear);
      },
      icon: const Icon(Icons.close_rounded, size: 18),
    );
  }

  String? Function(String?) _requiredValidator(String message) {
    return (value) {
      if (value == null || value.trim().isEmpty) return message;
      return null;
    };
  }

  DateTime? _parseDate(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;

    if (text.contains('.')) {
      final parts = text.split('.');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);

        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
    }

    if (text.contains('-')) {
      final parts = text.split('-');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);

        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
    }

    return null;
  }

  String _formatDateForInput(String? value) {
    if (value == null || value.trim().isEmpty) return '';

    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) return value;

    return '${parsed.day.toString().padLeft(2, '0')}.'
        '${parsed.month.toString().padLeft(2, '0')}.'
        '${parsed.year}';
  }

  String? _dateForApi(String value) {
    final parsed = _parseDate(value);
    if (parsed == null) return null;

    return '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';
  }
}
