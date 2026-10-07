// lib/screens/profile_screen.dart
import 'dart:typed_data';
import 'seller_registration/seller_type_screen.dart';
import 'seller_registration/seller_company_info_screen.dart';
import 'seller_registration/seller_registration_provider.dart';
import 'seller_registration/seller_registration_service.dart';
import 'seller_company_form_screen.dart';
import 'seller_agreement_view_screen.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';

import '../providers/auth_provider.dart';
import '../providers/favorite_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/locale_provider.dart';
import '../services/api_service.dart';
import '../services/pin_service.dart';

import 'login_screen.dart';
import 'register_screen.dart';
import 'cart_screen.dart';
import 'purchases_screen.dart';
import 'favorite_screen.dart';
import 'seller_main_screen.dart';
import 'my_reviews_screen.dart';
import 'personal_data_screen.dart';
import 'image_frame_editor_screen.dart';
import 'legal_documents_screen.dart';
import 'change_password_screen.dart';
import 'pin_settings_screen.dart';
import 'support_screen.dart';
import 'about_screen.dart';
import '../utils/legal_ui_text.dart';
import '../utils/download_bytes.dart';
import '../utils/armenian_phone.dart';


class ProfileScreen extends StatefulWidget {
  final bool showSellerPanelEntry;
  final bool sellerMode;

  const ProfileScreen({
    super.key,
    this.showSellerPanelEntry = true,
    this.sellerMode = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  static const Color accentColor = Color(0xFFD1BC00);

  late Future<Map<String, dynamic>> _profileFuture;
  late Future<Map<String, dynamic>?> _sellerApplicationFuture;

  final ImagePicker _profileImagePicker = ImagePicker();
  XFile? _avatarOriginalImage;
  XFile? _avatarCroppedFile;
  Uint8List? _avatarPreviewBytes;
  String _avatarPreviewFileName = 'avatar.png';
  bool _avatarUploading = false;
  bool _sellerAgreementDownloading = false;

  final Dio _profileGeocodingDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'Appsosa/1.0 (am.appsosa.app)',
      },
    ),
  );


  Future<Map<String, dynamic>> _safeGetProfile() async {
    final isLoggedIn = await ApiService.isLoggedIn();

    if (!isLoggedIn) {
      return <String, dynamic>{};
    }

    try {
      return await ApiService.getProfile();
    } catch (_) {
      return <String, dynamic>{};
    }
  }


  SellerRegistrationService _sellerRegistrationService() {
    return SellerRegistrationService(
      dio: Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
      ),
      baseUrl: ApiService.apiUrl,
    );
  }

  Future<Map<String, dynamic>?> _safeGetSellerApplication() async {
    final isLoggedIn = await ApiService.isLoggedIn();
    if (!isLoggedIn) return null;
    try {
      return await _sellerRegistrationService().getMyApplication();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _profileFuture = _safeGetProfile();
    _sellerApplicationFuture = _safeGetSellerApplication();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        context.read<CartProvider>().loadCart(silent: true);
        context.read<FavoriteProvider>().loadFavorites();
      }
    });
  }

  void _reloadProfile() {
    if (!mounted) return;
    setState(() {
      _profileFuture = _safeGetProfile();
      _sellerApplicationFuture = _safeGetSellerApplication();
    });
  }

  Future<void> _refreshProfileData() async {
    if (!mounted) return;

    await context.read<AuthProvider>().checkLoginStatus();
    if (!mounted) return;

    final profileFuture = _safeGetProfile();
    final applicationFuture = _safeGetSellerApplication();

    setState(() {
      _profileFuture = profileFuture;
      _sellerApplicationFuture = applicationFuture;
    });

    await Future.wait<dynamic>([
      profileFuture,
      applicationFuture,
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshProfileData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    // Manual logout disables quick local access on this device.
    await PinService.clear();
    await context.read<AuthProvider>().logout();
    await context.read<FavoriteProvider>().loadFavorites();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.logoutSuccess)),
      );
    }
  }

  void _openCart(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  void _openPurchases(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PurchasesScreen()),
    );
  }

  void _openMyReviews(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MyReviewsScreen(),
      ),
    );
  }

  Future<void> _openPersonalData(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const PersonalDataScreen(),
      ),
    );

    if (saved == true && mounted) {
      await _refreshProfileData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _avatarText(
              ru: 'Личные данные сохранены',
              en: 'Personal details saved',
              hy: 'Անձնական տվյալները պահպանված են',
            ),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openFavorites(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FavoriteScreen()),
    );
  }

  void _openSellerDashboard(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SellerMainScreen(
          profileScreen: ProfileScreen(
            showSellerPanelEntry: false,
            sellerMode: true,
          ),
        ),
      ),
    );
  }

  Future<void> _openSellerCompanySettings(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SellerCompanyFormScreen(),
      ),
    );

    if (mounted) {
      await _refreshProfileData();
    }
  }

  Future<void> _viewSellerAgreement(BuildContext context) async {
    try {
      final application = await _sellerApplicationFuture;
      final applicationId =
      int.tryParse(application?['id']?.toString() ?? '');

      if (applicationId == null) {
        throw StateError('Seller application not found');
      }

      final preview = await _sellerRegistrationService()
          .getAcceptedAgencyAgreementPreview(
        applicationId: applicationId,
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SellerAgreementViewScreen(
            preview: preview,
          ),
        ),
      );
    } catch (e) {
      debugPrint('SELLER AGREEMENT PREVIEW ERROR: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _avatarText(
              ru: 'Не удалось открыть договор.',
              en: 'Could not open the agreement.',
              hy: 'Չհաջողվեց բացել պայմանագիրը։',
            ),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showSellerAgreementActions(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _avatarText(
                    ru: 'Агентский договор',
                    en: 'Agency Agreement',
                    hy: 'Գործակալության պայմանագիր',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  onTap: () => Navigator.of(sheetContext).pop('view'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: accentColor),
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF8D2),
                    child: Icon(
                      Icons.visibility_outlined,
                      color: Color(0xFF7A6C00),
                    ),
                  ),
                  title: Text(
                    _avatarText(
                      ru: 'Просмотреть договор',
                      en: 'View agreement',
                      hy: 'Դիտել պայմանագիրը',
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  onTap: () => Navigator.of(sheetContext).pop('download'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: accentColor),
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF8D2),
                    child: Icon(
                      Icons.download_outlined,
                      color: Color(0xFF7A6C00),
                    ),
                  ),
                  title: Text(
                    _avatarText(
                      ru: 'Скачать договор',
                      en: 'Download agreement',
                      hy: 'Ներբեռնել պայմանագիրը',
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'view') {
      await _viewSellerAgreement(context);
    } else if (action == 'download') {
      await _downloadSellerAgreement(context);
    }
  }

  Future<void> _downloadSellerAgreement(BuildContext context) async {
    if (_sellerAgreementDownloading) return;

    setState(() => _sellerAgreementDownloading = true);

    try {
      final application = await _sellerApplicationFuture;
      final applicationId =
      int.tryParse(application?['id']?.toString() ?? '');

      if (applicationId == null) {
        throw StateError('Seller application not found');
      }

      final bytes = await _sellerRegistrationService().downloadAgencyAgreement(
        applicationId: applicationId,
      );

      final fileName = 'Appsosa_Agency_Agreement_$applicationId.docx';
      bool saved = false;

      if (kIsWeb) {
        saved = await downloadBytesInBrowser(
          bytes: bytes,
          fileName: fileName,
          mimeType:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
      } else {
        final savedPath = await FilePicker.platform.saveFile(
          dialogTitle: _avatarText(
            ru: 'Сохранить договор',
            en: 'Save Agency Agreement',
            hy: 'Պահպանել գործակալության պայմանագիրը',
          ),
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: const ['docx'],
          bytes: bytes,
        );
        saved = savedPath != null;
      }

      if (!mounted || !saved) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _avatarText(
              ru: 'Договор скачан.',
              en: 'Agreement downloaded.',
              hy: 'Համաձայնագիրը ներբեռնվել է։',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('SELLER AGREEMENT DOWNLOAD ERROR: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _avatarText(
              ru: 'Не удалось скачать договор.',
              en: 'Could not download the agreement.',
              hy: 'Չհաջողվեց ներբեռնել համաձայնագիրը։',
            ),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sellerAgreementDownloading = false);
      }
    }
  }

  void _openSupport(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SupportScreen(),
      ),
    );
  }

  void _openAbout(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AboutScreen(),
      ),
    );
  }

  void _openChangePassword(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ChangePasswordScreen(),
      ),
    );
  }

  Future<void> _openPinSettings(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const PinSettingsScreen(),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  void _openLegalDocuments(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LegalDocumentsScreen(),
      ),
    );
  }

  Future<void> _openSellerRegistration(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SellerTypeScreen(),
      ),
    );

    if (mounted) {
      await _refreshProfileData();
    }
  }


  Future<void> _openSellerApplication(
      BuildContext context,
      Map<String, dynamic> application,
      ) async {
    if (application['is_editable'] != true) return;

    try {
      final service = _sellerRegistrationService();
      final channelCodes =
      await service.resolveApplicationChannelCodes(application);
      final provider = SellerRegistrationProvider()
        ..loadFromApplication(
          application,
          channelCodes: channelCodes,
        );

      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: const SellerCompanyInfoScreen(),
          ),
        ),
      );
      if (mounted) _reloadProfile();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('РќРµ СѓРґР°Р»РѕСЃСЊ РѕС‚РєСЂС‹С‚СЊ Р·Р°СЏРІРєСѓ: $error'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openLogin(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );

    if (result == true && context.mounted) {
      await context.read<AuthProvider>().checkLoginStatus();
      await context.read<FavoriteProvider>().loadFavorites();
      await context.read<CartProvider>().loadCart();
      _reloadProfile();
    }
  }

  void _openRegister(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );

    if (result == true && context.mounted) {
      await context.read<AuthProvider>().checkLoginStatus();
      _reloadProfile();
    }
  }

  String _avatarText({
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

  String _clientPhoneDigits(dynamic value) {
    return ArmenianPhone.localDigits(value);
  }

  String _normalizeClientPhone(dynamic value) {
    return ArmenianPhone.normalize(value);
  }

  String _profileAddressLanguageChain() {
    final current = Localizations.localeOf(context).languageCode.toLowerCase();
    return <String>[current, 'hy', 'ru', 'en'].toSet().join(',');
  }

  Future<String> _detectCurrentAddress() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const _ProfileLocationException('service_disabled');
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const _ProfileLocationException('permission_denied');
    }

    if (permission == LocationPermission.deniedForever) {
      throw const _ProfileLocationException('permission_denied_forever');
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final response = await _profileGeocodingDio.get(
      'https://nominatim.openstreetmap.org/reverse',
      queryParameters: {
        'lat': position.latitude,
        'lon': position.longitude,
        'format': 'jsonv2',
        'zoom': 18,
        'addressdetails': 1,
        'accept-language': _profileAddressLanguageChain(),
      },
    );

    final data = response.data;
    if (data is! Map) {
      throw const _ProfileLocationException('address_not_found');
    }

    final map = Map<String, dynamic>.from(data);
    final address = _compactNominatimAddress(map);

    if (address.isEmpty) {
      throw const _ProfileLocationException('address_not_found');
    }

    return address;
  }

  String _compactNominatimAddress(Map<String, dynamic> data) {
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
      final suburb = firstNonEmpty(['suburb', 'neighbourhood', 'quarter']);

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

  String _profileLocationErrorText(Object error) {
    final code = error is _ProfileLocationException ? error.code : '';

    return switch (code) {
      'service_disabled' => _avatarText(
        ru: 'Включите геолокацию на устройстве.',
        en: 'Turn on location services on your device.',
        hy: 'Միացրեք տեղորոշումը սարքում։',
      ),
      'permission_denied' => _avatarText(
        ru: 'Разрешите Appsosa доступ к местоположению.',
        en: 'Allow Appsosa to access your location.',
        hy: 'Թույլատրեք Appsosa-ին հասանելիություն ձեր տեղադրությանը։',
      ),
      'permission_denied_forever' => _avatarText(
        ru: 'Доступ к геолокации запрещён. Разрешите его в настройках устройства.',
        en: 'Location access is blocked. Enable it in device settings.',
        hy: 'Տեղորոշման հասանելիությունն արգելափակված է։ Միացրեք այն սարքի կարգավորումներում։',
      ),
      'address_not_found' => _avatarText(
        ru: 'Местоположение найдено, но адрес определить не удалось.',
        en: 'Location found, but the address could not be determined.',
        hy: 'Տեղադրությունը գտնվել է, բայց հասցեն որոշել չհաջողվեց։',
      ),
      _ => _avatarText(
        ru: 'Не удалось определить местоположение. Попробуйте ещё раз.',
        en: 'Could not determine your location. Please try again.',
        hy: 'Չհաջողվեց որոշել ձեր տեղադրությունը։ Փորձեք կրկին։',
      ),
    };
  }

  Future<bool> _confirmDiscardProfileChanges(BuildContext dialogContext) async {
    if (!mounted) return false;

    final discard = await showDialog<bool>(
      context: dialogContext,
      builder: (confirmContext) {
        return AlertDialog(
          title: Text(
            _avatarText(
              ru: 'Есть несохранённые изменения',
              en: 'Unsaved changes',
              hy: 'Կան չպահպանված փոփոխություններ',
            ),
          ),
          content: Text(
            _avatarText(
              ru: 'Выйти без сохранения изменений?',
              en: 'Leave without saving your changes?',
              hy: 'Դուրս գալ առանց փոփոխությունները պահպանելու՞',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(confirmContext).pop(false),
              child: Text(
                _avatarText(
                  ru: 'Остаться',
                  en: 'Stay',
                  hy: 'Մնալ',
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(confirmContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: Text(
                _avatarText(
                  ru: 'Выйти',
                  en: 'Leave',
                  hy: 'Դուրս գալ',
                ),
              ),
            ),
          ],
        );
      },
    );

    return discard ?? false;
  }

  Future<void> _showAvatarSourceMenu() async {
    if (_avatarUploading) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_camera_outlined,
                    color: accentColor,
                  ),
                  title: Text(
                    _avatarText(
                      ru: 'Сделать фото',
                      en: 'Take photo',
                      hy: 'Լուսանկարել',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(
                    ImageSource.camera,
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: accentColor,
                  ),
                  title: Text(
                    _avatarText(
                      ru: 'Выбрать из галереи',
                      en: 'Choose from gallery',
                      hy: 'Ընտրել պատկերասրահից',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(
                    ImageSource.gallery,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) return;
    await _pickProfileAvatar(source);
  }

  Future<void> _pickProfileAvatar(ImageSource source) async {
    final image = await _profileImagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );

    if (image == null || !mounted) return;

    _avatarOriginalImage = image;

    final cropOk = await _cropProfileAvatar(image);
    if (!cropOk || !mounted) {
      _clearPendingAvatarPreview();
      return;
    }

    await _showAvatarPreviewActions();
  }

  Future<bool> _cropProfileAvatar(XFile sourceImage) async {
    if (!mounted) return false;

    final edited = await ImageFrameEditorScreen.open(
      context,
      source: sourceImage,
      mode: ImageFrameEditorMode.avatar,
      outputFileName: 'avatar.png',
    );

    if (edited == null || !mounted) return false;

    setState(() {
      _avatarCroppedFile = edited.file;
      _avatarPreviewBytes = edited.bytes;
      _avatarPreviewFileName = edited.file.name;
    });

    return true;
  }

  Future<void> _showAvatarPreviewActions() async {
    while (mounted && _avatarPreviewBytes != null) {
      final action = await showModalBottomSheet<String>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return WillPopScope(
            onWillPop: () async {
              return _confirmDiscardProfileChanges(sheetContext);
            },
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _avatarText(
                        ru: 'Как будет выглядеть фото',
                        en: 'How your photo will look',
                        hy: 'Ինչպես կերևա լուսանկարը',
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 168,
                      height: 168,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentColor,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.memory(
                          _avatarPreviewBytes!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.of(sheetContext).pop('edit'),
                        icon: const Icon(Icons.tune_rounded),
                        label: Text(
                          _avatarText(
                            ru: 'Редактировать фото',
                            en: 'Edit photo',
                            hy: 'Խմբագրել լուսանկարը',
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: const BorderSide(color: accentColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.of(sheetContext).pop('save'),
                        icon: const Icon(Icons.check_rounded),
                        label: Text(
                          _avatarText(
                            ru: 'Сохранить',
                            en: 'Save',
                            hy: 'Պահպանել',
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () async {
                        final discard =
                        await _confirmDiscardProfileChanges(sheetContext);
                        if (!discard || !sheetContext.mounted) return;
                        Navigator.of(sheetContext).pop('discard');
                      },
                      child: Text(
                        _avatarText(
                          ru: 'Отменить',
                          en: 'Cancel',
                          hy: 'Չեղարկել',
                        ),
                        style: const TextStyle(
                          color: Color(0xFF777777),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      if (!mounted) return;

      if (action == 'edit') {
        final original = _avatarOriginalImage;
        if (original == null) {
          _clearPendingAvatarPreview();
          return;
        }

        final ok = await _cropProfileAvatar(original);
        if (!ok || !mounted) {
          _clearPendingAvatarPreview();
          return;
        }
        continue;
      }

      if (action == 'save') {
        await _uploadPendingAvatar();
        return;
      }

      // Cancel/back after confirmation: keep the existing saved avatar unchanged.
      _clearPendingAvatarPreview();
      return;
    }
  }

  Future<void> _uploadPendingAvatar() async {
    final bytes = _avatarPreviewBytes;
    if (bytes == null || _avatarUploading) return;

    setState(() => _avatarUploading = true);

    try {
      final updatedProfile = await ApiService.updateProfileAvatar(
        avatarBytes: bytes,
        fileName: _avatarPreviewFileName,
      );

      if (!mounted) return;

      setState(() {
        _avatarUploading = false;
        _avatarPreviewBytes = null;
        _avatarOriginalImage = null;
        _avatarCroppedFile = null;
        _profileFuture = Future.value(updatedProfile);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _avatarText(
              ru: 'Фото профиля сохранено',
              en: 'Profile photo saved',
              hy: 'Պրոֆիլի լուսանկարը պահպանված է',
            ),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _avatarUploading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _avatarText(
              ru: 'Не удалось сохранить фото профиля',
              en: 'Could not save profile photo',
              hy: 'Չհաջողվեց պահպանել պրոֆիլի լուսանկարը',
            ),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _clearPendingAvatarPreview() {
    if (!mounted) return;
    setState(() {
      _avatarOriginalImage = null;
      _avatarCroppedFile = null;
      _avatarPreviewBytes = null;
    });
  }

  String _profileAvatarUrl(Map<String, dynamic> profile) {
    final candidates = [
      profile['avatar_url'],
      profile['avatar'],
      profile['image_url'],
    ];

    for (final value in candidates) {
      final raw = value?.toString().trim() ?? '';
      if (raw.isNotEmpty) return ApiService.fixImageUrl(raw);
    }

    return '';
  }

  Widget _buildProfileAvatar(Map<String, dynamic> profile) {
    final avatarUrl = _profileAvatarUrl(profile);

    Widget image;

    if (_avatarPreviewBytes != null) {
      image = Image.memory(
        _avatarPreviewBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (avatarUrl.isNotEmpty) {
      image = Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => const Icon(
          Icons.person_rounded,
          size: 46,
          color: Color(0xFF777777),
        ),
      );
    } else {
      image = const Icon(
        Icons.person_rounded,
        size: 46,
        color: Color(0xFF777777),
      );
    }

    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 104,
            height: 104,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor,
                width: 1.4,
              ),
            ),
            child: ClipOval(
              child: Container(
                color: const Color(0xFFF1EFF3),
                child: image,
              ),
            ),
          ),
          if (_avatarUploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.62),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 25,
                    height: 25,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
            ),

          // Separate replacement button. The saved/old avatar itself is not
          // re-editable; this button starts Camera / Gallery.
          Positioned(
            right: -2,
            bottom: 2,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _avatarUploading ? null : _showAvatarSourceMenu,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.photo_camera_outlined,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileIdentityHeader({
    required AuthProvider auth,
    required Map<String, dynamic> profile,
  }) {
    final username = (auth.username ?? '').trim();
    final loginText = username.isEmpty ? 'user' : username;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildProfileAvatar(profile),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              loginText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfileField({
    required String title,
    required String field,
    required String currentValue,
    required Map<String, dynamic> profile,
    required TextInputType keyboardType,
    int maxLines = 1,
  }) async {
    final parentContext = context;
    final initialEditValue =
    field == 'phone' ? ArmenianPhone.formatLocal(currentValue) : currentValue;
    final controller = TextEditingController(text: initialEditValue);

    bool saving = false;
    bool dirty = false;
    bool locatingAddress = false;
    String? fieldError;

    final saved = await showModalBottomSheet<bool>(
      context: parentContext,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            Future<void> requestClose() async {
              if (saving || locatingAddress) return;

              // Flutter Web can briefly calculate a negative viewInset when a
              // focused HTML text input is removed at the same moment as the
              // modal route. Dismiss focus first and let the browser viewport
              // settle before popping the sheet.
              FocusManager.instance.primaryFocus?.unfocus();
              if (kIsWeb) {
                await Future<void>.delayed(const Duration(milliseconds: 250));
              }

              if (!sheetContext.mounted) return;

              if (!dirty) {
                Navigator.of(sheetContext).pop(false);
                return;
              }

              final discard =
              await _confirmDiscardProfileChanges(sheetContext);
              if (!discard || !sheetContext.mounted) return;

              setModalState(() => dirty = false);
              Navigator.of(sheetContext).pop(false);
            }

            Future<void> useCurrentLocation() async {
              if (field != 'address' || saving || locatingAddress) return;

              FocusScope.of(sheetContext).unfocus();

              setModalState(() {
                locatingAddress = true;
                fieldError = null;
              });

              try {
                final detectedAddress = await _detectCurrentAddress();

                if (!sheetContext.mounted) return;

                controller.text = detectedAddress;
                controller.selection = TextSelection.collapsed(
                  offset: controller.text.length,
                );

                setModalState(() {
                  locatingAddress = false;
                  dirty = controller.text != initialEditValue;
                  fieldError = null;
                });
              } catch (error) {
                if (!sheetContext.mounted) return;

                setModalState(() {
                  locatingAddress = false;
                  fieldError = _profileLocationErrorText(error);
                });
              }
            }

            Future<void> save() async {
              if (saving || locatingAddress) return;

              final newValue = controller.text.trim();
              final phoneDigits =
              field == 'phone' ? _clientPhoneDigits(newValue) : '';

              if (field == 'phone' &&
                  phoneDigits.isNotEmpty &&
                  phoneDigits.length != ArmenianPhone.localDigitsLength) {
                setModalState(() {
                  fieldError = _avatarText(
                    ru: 'Введите 8 цифр номера: +374 XX-XX-XX-XX',
                    en: 'Enter 8 digits: +374 XX-XX-XX-XX',
                    hy: 'Մուտքագրեք համարի 8 թվանշանը՝ +374 XX-XX-XX-XX',
                  );
                });
                return;
              }

              setModalState(() {
                saving = true;
                fieldError = null;
              });

              FocusManager.instance.primaryFocus?.unfocus();
              if (kIsWeb) {
                await Future<void>.delayed(
                  const Duration(milliseconds: 250),
                );
              }

              if (!sheetContext.mounted) return;

              try {
                final phone = field == 'phone'
                    ? (phoneDigits.isEmpty
                    ? ''
                    : ArmenianPhone.normalize(newValue))
                    : _normalizeClientPhone(profile['phone']);

                final address = field == 'address'
                    ? newValue
                    : profile['address']?.toString() ?? '';

                await ApiService.updateProfile(
                  phone: phone,
                  address: address,
                );

                if (!sheetContext.mounted) return;

                setModalState(() {
                  saving = false;
                  dirty = false;
                });
                Navigator.of(sheetContext).pop(true);
              } catch (_) {
                if (!sheetContext.mounted) return;

                setModalState(() {
                  saving = false;
                  fieldError = _avatarText(
                    ru: 'Не удалось сохранить. Проверьте это поле.',
                    en: 'Could not save. Please check this field.',
                    hy: 'Չհաջողվեց պահպանել։ Ստուգեք այս դաշտը։',
                  );
                });

                if (parentContext.mounted) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(parentContext)!.profileSaveError,
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            }

            return WillPopScope(
              onWillPop: () async {
                if (saving || locatingAddress) return false;

                FocusManager.instance.primaryFocus?.unfocus();
                if (kIsWeb) {
                  await Future<void>.delayed(
                    const Duration(milliseconds: 250),
                  );
                }

                if (!dirty) return true;
                return _confirmDiscardProfileChanges(sheetContext);
              },
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: kIsWeb
                      ? 0
                      : MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: saving || locatingAddress ? null : requestClose,
                            tooltip: _avatarText(
                              ru: 'Закрыть',
                              en: 'Close',
                              hy: 'Փակել',
                            ),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: controller,
                        autofocus: !kIsWeb,
                        keyboardType: keyboardType,
                        style: field == 'phone'
                            ? const TextStyle(
                          color: Color(0xFF333333),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        )
                            : null,
                        textAlignVertical: field == 'phone'
                            ? TextAlignVertical.center
                            : null,
                        strutStyle: field == 'phone'
                            ? const StrutStyle(
                          fontSize: 16,
                          height: 1.2,
                          forceStrutHeight: true,
                        )
                            : null,
                        inputFormatters: field == 'phone'
                            ? const <TextInputFormatter>[
                          ArmenianPhoneInputFormatter(),
                        ]
                            : null,
                        maxLines: maxLines,
                        textInputAction:
                        maxLines == 1 ? TextInputAction.done : null,
                        onSubmitted: maxLines == 1
                            ? (_) {
                          save();
                        }
                            : null,
                        onChanged: (value) {
                          final nextDirty = value != initialEditValue;
                          if (nextDirty != dirty || fieldError != null) {
                            setModalState(() {
                              dirty = nextDirty;
                              fieldError = null;
                            });
                          }
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF6F6F6),
                          prefixText:
                          field == 'phone' ? '+374 ' : null,
                          prefixStyle: field == 'phone'
                              ? const TextStyle(
                            color: Color(0xFF333333),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          )
                              : null,
                          hintText: field == 'phone'
                              ? 'XX-XX-XX-XX'
                              : field == 'address'
                              ? _avatarText(
                            ru: 'Введите адрес или определите местоположение',
                            en: 'Enter an address or use your location',
                            hy: 'Մուտքագրեք հասցեն կամ որոշեք տեղադրությունը',
                          )
                              : null,
                          suffixIcon: field == 'address'
                              ? Padding(
                            padding: const EdgeInsets.all(7),
                            child: Material(
                              color: accentColor.withValues(alpha: 0.13),
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: saving || locatingAddress
                                    ? null
                                    : useCurrentLocation,
                                customBorder: const CircleBorder(),
                                child: SizedBox(
                                  width: 38,
                                  height: 38,
                                  child: Center(
                                    child: locatingAddress
                                        ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: accentColor,
                                      ),
                                    )
                                        : const Icon(
                                      Icons.my_location_rounded,
                                      size: 20,
                                      color: Color(0xFF7A6C00),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                              : null,
                          suffixIconConstraints: field == 'address'
                              ? const BoxConstraints(
                            minWidth: 52,
                            minHeight: 52,
                          )
                              : null,
                          errorText: fieldError,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 1.2,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: saving || locatingAddress ? null : save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: saving
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : Text(
                            AppLocalizations.of(parentContext)!
                                .profileSave,
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
            );
          },
        );
      },
    );

    // showModalBottomSheet can still be finishing its reverse animation
    // after its Future completes, especially on Flutter Web. Delayed cleanup
    // prevents the outgoing TextField from seeing a disposed controller.
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      controller.dispose();
    });

    if (saved == true && mounted) {
      _reloadProfile();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.profileSaved,
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          widget.sellerMode ? l10n.organizationSettings : l10n.profile,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: widget.sellerMode
            ? const []
            : const [
          _ProfileLanguageSwitcher(),
          SizedBox(width: 8),
        ],
      ),
      body: auth.isLoggedIn
          ? widget.sellerMode
          ? _buildSellerModeProfile(context)
          : _buildLoggedInProfile(context, auth)
          : _buildAuthRequiredWidget(context),
    );
  }

  Widget _buildAuthRequiredWidget(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/auth_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 72),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 80),
            Image.asset(
              'assets/images/logo.png',
              width: 140,
              height: 140,
            ),
            const SizedBox(height: 32),
            Text(
              l10n.welcome,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.loginPrompt,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF666666),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => _openLogin(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  l10n.login,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _openRegister(context),
              child: Text(
                l10n.registerPrompt,
                style: const TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerModeProfile(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: EdgeInsets.only(
        top: 16,
        bottom: 72 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        _buildMenuItem(
          icon: Icons.business_rounded,
          title: l10n.organizationSettings,
          onTap: () => _openSellerCompanySettings(context),
        ),
        _buildMenuItem(
          icon: Icons.description_outlined,
          title: _avatarText(
            ru: 'Агентский договор',
            en: 'Agency Agreement',
            hy: 'Գործակալության պայմանագիր',
          ),
          subtitle: _avatarText(
            ru: 'Просмотреть или скачать принятый договор',
            en: 'View or download the accepted agreement',
            hy: 'Դիտել կամ ներբեռնել ընդունված պայմանագիրը',
          ),
          onTap: () => _showSellerAgreementActions(context),
        ),
        _buildMenuItem(
          icon: Icons.support_agent_rounded,
          title: _avatarText(
            ru: 'Техподдержка',
            en: 'Support',
            hy: 'Տեխնիկական աջակցություն',
          ),
          subtitle: _avatarText(
            ru: 'Связаться с поддержкой Appsosa',
            en: 'Contact Appsosa support',
            hy: 'Կապվել Appsosa-ի աջակցության հետ',
          ),
          onTap: () => _openSupport(context),
        ),
        const SizedBox(height: 10),
        _buildMenuItem(
          icon: Icons.info_outline_rounded,
          title: _avatarText(
            ru: 'О нас',
            en: 'About us',
            hy: 'Մեր մասին',
          ),
          subtitle: _avatarText(
            ru: 'О сервисе Appsosa',
            en: 'About Appsosa',
            hy: 'Appsosa ծառայության մասին',
          ),
          onTap: () => _openAbout(context),
        ),
      ],
    );
  }

  Widget _buildLoggedInProfile(BuildContext context, AuthProvider auth) {
    final l10n = AppLocalizations.of(context)!;

    return RefreshIndicator(
      onRefresh: _refreshProfileData,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          final profile = snapshot.data ?? <String, dynamic>{};
          final phone = ArmenianPhone.formatInternational(profile['phone']);
          final address = profile['address']?.toString() ?? '';

          return ListView(
            padding: EdgeInsets.only(
              bottom: 72 + MediaQuery.of(context).padding.bottom,
            ),
            children: [
              _buildProfileIdentityHeader(
                auth: auth,
                profile: profile,
              ),

              Consumer<FavoriteProvider>(
                builder: (context, favorites, _) {
                  final count = favorites.favoriteSlugs.length;
                  return _buildMenuItem(
                    icon: Icons.favorite_border,
                    title: l10n.favorites,
                    badgeCount: count,
                    onTap: () => _openFavorites(context),
                  );
                },
              ),

              Consumer<CartProvider>(
                builder: (context, cart, _) {
                  return _buildMenuItem(
                    icon: Icons.shopping_bag_outlined,
                    title: l10n.cart,
                    subtitle: cart.totalPrice > 0
                        ? '${cart.totalPrice.toStringAsFixed(0)} \u058F'
                        : null,
                    badgeCount: cart.itemsCount,
                    onTap: () => _openCart(context),
                  );
                },
              ),

              _buildMenuItem(
                icon: Icons.receipt_long_outlined,
                title: l10n.myPurchases,
                subtitle: l10n.myPurchasesSubtitle,
                onTap: () => _openPurchases(context),
              ),

              _buildMenuItem(
                icon: Icons.rate_review_outlined,
                title: l10n.myReviews,
                subtitle: l10n.myReviewsSubtitle,
                onTap: () => _openMyReviews(context),
              ),

              _buildMenuItem(
                icon: Icons.badge_outlined,
                title: _avatarText(
                  ru: 'Личные данные',
                  en: 'Personal details',
                  hy: 'Անձնական տվյալներ',
                ),
                subtitle: address.isNotEmpty
                    ? address
                    : (phone.isNotEmpty
                    ? phone
                    : _avatarText(
                  ru: 'Телефон и данные для доставки',
                  en: 'Phone and delivery details',
                  hy: 'Հեռախոս և առաքման տվյալներ',
                )),
                onTap: () => _openPersonalData(context),
              ),

              _buildMenuItem(
                icon: Icons.lock_reset_rounded,
                title: _profileSecurityText(
                  context,
                  ru: 'Сменить пароль',
                  en: 'Change password',
                  hy: 'Փոխել գաղտնաբառը',
                ),
                subtitle: _profileSecurityText(
                  context,
                  ru: 'Изменить пароль аккаунта',
                  en: 'Update your account password',
                  hy: 'Թարմացնել հաշվի գաղտնաբառը',
                ),
                onTap: () => _openChangePassword(context),
              ),

              FutureBuilder<bool>(
                future: PinService.hasPinFor(auth.username),
                builder: (context, pinSnapshot) {
                  final pinEnabled = pinSnapshot.data ?? false;

                  return _buildMenuItem(
                    icon: Icons.pin_rounded,
                    title: _profileSecurityText(
                      context,
                      ru: 'PIN-код',
                      en: 'PIN',
                      hy: 'PIN կոդ',
                    ),
                    subtitle: pinEnabled
                        ? _profileSecurityText(
                      context,
                      ru: 'Включён · изменить или отключить',
                      en: 'Enabled · change or disable',
                      hy: 'Միացված է · փոխել կամ անջատել',
                    )
                        : _profileSecurityText(
                      context,
                      ru: 'Создать 4-значный код для быстрого входа',
                      en: 'Create a 4-digit code for quick access',
                      hy: 'Ստեղծել 4-նիշ կոդ արագ մուտքի համար',
                    ),
                    onTap: () => _openPinSettings(context),
                  );
                },
              ),

              _buildMenuItem(
                icon: Icons.gavel_rounded,
                title: LegalUiText.of(context).legalInformation,
                subtitle: LegalUiText.of(context).legalInformationSubtitle,
                onTap: () => _openLegalDocuments(context),
              ),

              _buildMenuItem(
                icon: Icons.support_agent_rounded,
                title: _avatarText(
                  ru: 'Техподдержка',
                  en: 'Support',
                  hy: 'Տեխնիկական աջակցություն',
                ),
                subtitle: _avatarText(
                  ru: 'Связаться с поддержкой Appsosa',
                  en: 'Contact Appsosa support',
                  hy: 'Կապվել Appsosa-ի աջակցության հետ',
                ),
                onTap: () => _openSupport(context),
              ),

              FutureBuilder<Map<String, dynamic>?>(
                future: _sellerApplicationFuture,
                builder: (context, applicationSnapshot) {
                  final application = applicationSnapshot.data;
                  if (application == null) {
                    if (auth.isSeller) return const SizedBox.shrink();
                    return _buildMenuItem(
                      icon: Icons.storefront_outlined,
                      title: l10n.becomeSeller,
                      subtitle: l10n.becomeSellerSubtitle,
                      onTap: () => _openSellerRegistration(context),
                    );
                  }
                  return _buildSellerApplicationCard(
                    context,
                    application,
                  );
                },
              ),

              if (auth.isSeller && widget.showSellerPanelEntry)
                _buildMenuItem(
                  icon: Icons.storefront_rounded,
                  title: l10n.sellerPanel,
                  subtitle: l10n.sellerPanelSubtitle,
                  borderColor: Colors.redAccent,
                  onTap: () => _openSellerDashboard(context),
                ),

              const SizedBox(height: 18),
              _buildMenuItem(
                icon: Icons.info_outline_rounded,
                title: _avatarText(
                  ru: 'О нас',
                  en: 'About us',
                  hy: 'Մեր մասին',
                ),
                subtitle: _avatarText(
                  ru: 'О сервисе Appsosa',
                  en: 'About Appsosa',
                  hy: 'Appsosa ծառայության մասին',
                ),
                onTap: () => _openAbout(context),
              ),

              const SizedBox(height: 8),
              _buildMenuItem(
                icon: Icons.logout,
                title: l10n.logout,
                color: Colors.red,
                onTap: () => _logout(context),
              ),
            ],
          );
        },
      ),
    );
  }


  String _profileSecurityText(
      BuildContext context, {
        required String ru,
        required String en,
        required String hy,
      }) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'hy':
        return hy;
      case 'ru':
        return ru;
      default:
        return en;
    }
  }

  Widget _buildSellerApplicationCard(
      BuildContext context,
      Map<String, dynamic> application,
      ) {
    final l10n = AppLocalizations.of(context)!;
    final status = application['status']?.toString() ?? 'draft';

    final statusDisplay = switch (status) {
      'approved' => l10n.sellerStatusApproved,
      'rejected' => l10n.sellerStatusRejected,
      'changes_requested' => l10n.sellerStatusChangesRequested,
      'pending' => l10n.sellerStatusPending,
      'draft' => l10n.sellerStatusDraft,
      _ => l10n.sellerApplication,
    };

    final comment = application['admin_comment']?.toString().trim() ?? '';
    final editable = application['is_editable'] == true;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'approved':
        statusColor = const Color(0xFF2E9B55);
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        break;
      case 'changes_requested':
        statusColor = const Color(0xFFE67E22);
        statusIcon = Icons.edit_note_rounded;
        break;
      case 'pending':
        statusColor = accentColor;
        statusIcon = Icons.schedule_rounded;
        break;
      default:
        statusColor = Colors.blueGrey;
        statusIcon = Icons.description_outlined;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(statusIcon, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.sellerApplication,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      statusDisplay,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.sellerApplicationChangesRequired,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(comment, style: const TextStyle(height: 1.35)),
                ],
              ),
            ),
          ],
          if (editable || status == 'approved') ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (status == 'approved') {
                    _openSellerCompanySettings(context);
                  } else {
                    _openSellerApplication(context, application);
                  }
                },
                icon: const Icon(Icons.edit_outlined),
                label: Text(
                  status == 'approved'
                      ? l10n.organizationSettings
                      : status == 'changes_requested'
                      ? l10n.fixSellerApplication
                      : l10n.continueSellerApplication,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    Color? color,
    Color? borderColor,
    int badgeCount = 0,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: borderColor == null
            ? null
            : Border.all(
          color: borderColor,
          width: 1.5,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: color ?? Colors.grey[700]),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            color: color ?? Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}


// РџРµСЂРµРєР»СЋС‡Р°С‚РµР»СЊ СЏР·С‹РєР° Р±РµР· С„Р»Р°РіРѕРІ
class _ProfileLanguageSwitcher extends StatelessWidget {
  const _ProfileLanguageSwitcher();

  @override
  Widget build(BuildContext context) {
    final currentCode =
        context.watch<LocaleProvider>().locale.languageCode;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ProfileLanguageButton(
          label: 'ARM',
          code: 'hy',
          selected: currentCode == 'hy',
        ),
        _ProfileLanguageButton(
          label: 'EN',
          code: 'en',
          selected: currentCode == 'en',
        ),
        _ProfileLanguageButton(
          label: 'RU',
          code: 'ru',
          selected: currentCode == 'ru',
        ),
      ],
    );
  }
}

class _ProfileLanguageButton extends StatelessWidget {
  final String label;
  final String code;
  final bool selected;

  const _ProfileLanguageButton({
    required this.label,
    required this.code,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.read<LocaleProvider>().setLocale(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD1BC00) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : const Color(0xFF555555),
          ),
        ),
      ),
    );
  }
}


class _ProfileLocationException implements Exception {
  final String code;

  const _ProfileLocationException(this.code);
}
