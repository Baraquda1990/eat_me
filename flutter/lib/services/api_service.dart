import 'package:flutter/foundation.dart';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../models/tag.dart';
import '../models/user.dart';
import '../models/map_company.dart';
import '../models/legal_document.dart';


class HotReservationException implements Exception {
  final String code;
  final String message;
  final int? available;

  const HotReservationException({
    required this.code,
    required this.message,
    this.available,
  });

  @override
  String toString() => message;
}


class ProductPageResult {
  final List<Product> products;
  final int count;
  final bool hasMore;
  final Map<String, int> tagCounts;
  final int untaggedCount;

  const ProductPageResult({
    required this.products,
    required this.count,
    required this.hasMore,
    this.tagCounts = const <String, int>{},
    this.untaggedCount = 0,
  });
}

class ApiService {
  static const String baseUrl = 'http://85.29.147.68';
  static const String apiPrefix = '/api_eatme';
  static const int pageSize = 10;

  static String get apiUrl => '$baseUrl$apiPrefix';
  static String get authUrl => '$apiUrl/auth';

  static bool _googleSignInInitialized = false;

  static const String googleWebClientId =
      '701891817101-7l1bdih2eveqi7cv2ico4cb751nr1qru.apps.googleusercontent.com';

  static final Dio _dioEatme = Dio(
    BaseOptions(
      baseUrl: apiUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static String? _accessToken;
  static String? _refreshToken;
  static Future<bool>? _refreshFuture;
  static final ValueNotifier<int> notificationsVersion = ValueNotifier<int>(0);

  static String _requestLanguage = 'en';

  static void setRequestLanguage(String language) {
    final code = language.trim().toLowerCase().split('-').first;
    _requestLanguage = ['ru', 'en', 'hy'].contains(code) ? code : 'en';

    // Existing Tag objects also switch language immediately after a locale
    // change; screens do not need to refetch tags only to translate the name.
    Tag.setLanguageCode(_requestLanguage);
  }

  static Future<void> init() async {
    await _loadTokens();

    final prefs = await SharedPreferences.getInstance();
    setRequestLanguage(prefs.getString('app_language') ?? 'en');

    _dioEatme.interceptors.clear();
    _dioEatme.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          await _ensureValidAccessToken();

          options.headers['Accept-Language'] = _requestLanguage;

          if (_accessToken != null && _accessToken!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }

          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final refreshed = await _refreshAccessToken();

            if (refreshed) {
              final requestOptions = error.requestOptions;
              requestOptions.headers['Authorization'] = 'Bearer $_accessToken';

              final clonedResponse = await _dioEatme.fetch(requestOptions);
              return handler.resolve(clonedResponse);
            }
          }

          return handler.next(error);
        },
      ),
    );
  }

  static String humanizeError(Object error) {
    final msg = error.toString().toLowerCase();

    if (msg.contains('not authenticated') ||
        msg.contains('401')) {
      return 'Войдите в аккаунт';
    }

    if (msg.contains('время получения истекло') ||
        msg.contains('pickup') && msg.contains('expired')) {
      return 'Укажите новое время получения товара';
    }

    if (msg.contains('укажите время получения') ||
        msg.contains('pickup_from') ||
        msg.contains('pickup_until')) {
      return 'Укажите время получения Hot-товара';
    }

    if (msg.contains('нулевым остатком') ||
        msg.contains('zero stock')) {
      return 'Сначала увеличьте остаток товара';
    }

    if (msg.contains('out of stock') ||
        msg.contains('нет в наличии')) {
      return 'Товара больше нет';
    }

    if (msg.contains('quantity') ||
        msg.contains('count')) {
      return 'Недостаточно количества';
    }

    if (msg.contains('socket') ||
        msg.contains('connection') ||
        msg.contains('timeout')) {
      return 'Проверьте интернет';
    }

    return 'Не удалось выполнить операцию';
  }

  static Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    _accessToken = access;
    _refreshToken = refresh;

    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  static Future<void> _loadTokens() async {
    _accessToken = await _storage.read(key: 'access_token');
    _refreshToken = await _storage.read(key: 'refresh_token');
  }

  static Future<void> loadTokens() async {
    await _loadTokens();
  }

  static Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;

    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  static Future<bool> isLoggedIn() async {
    await _loadTokens();
    return _refreshToken != null && _refreshToken!.isNotEmpty;
  }

  static Future<String?> getValidAccessToken() async {
    await _loadTokens();
    return _accessToken;
  }

  static Future<void> _ensureValidAccessToken() async {
    if (_accessToken == null) {
      await _loadTokens();
    }

    if (_accessToken == null || _accessToken!.isEmpty) return;

    if (JwtDecoder.isExpired(_accessToken!)) {
      await _refreshAccessToken();
    }
  }

  static Future<bool> refreshAccessToken() async {
    return _refreshAccessToken();
  }

  static Future<bool> _refreshAccessToken() async {
    if (_refreshFuture != null) return _refreshFuture!;

    _refreshFuture = _performRefresh();
    final result = await _refreshFuture!;
    _refreshFuture = null;

    return result;
  }

  static Future<bool> _performRefresh() async {
    try {
      await _loadTokens();

      if (_refreshToken == null || _refreshToken!.isEmpty) return false;

      final response = await Dio().post(
        '$authUrl/jwt/refresh/',
        data: {'refresh': _refreshToken},
      );

      if (response.statusCode == 200) {
        _accessToken = response.data['access'];
        await _storage.write(key: 'access_token', value: _accessToken!);
        return true;
      }

      await logout();
      return false;
    } catch (_) {
      await logout();
      return false;
    }
  }

  static String fixImageUrl(String url) {
    if (url.isEmpty) return '';

    final mediaIndex = url.indexOf('/media/');
    if (mediaIndex != -1) {
      final path = url.substring(mediaIndex + '/media'.length);
      return '$baseUrl/eatme_media$path';
    }

    final eatmeMediaIndex = url.indexOf('/eatme_media/');
    if (eatmeMediaIndex != -1) {
      return '$baseUrl${url.substring(eatmeMediaIndex)}';
    }

    if (url.startsWith('/uploads/')) {
      return '$baseUrl/eatme_media$url';
    }

    if (url.startsWith('uploads/')) {
      return '$baseUrl/eatme_media/$url';
    }

    return url;
  }

  static bool _startsWithBytes(
      Uint8List bytes,
      List<int> signature,
      ) {
    if (bytes.length < signature.length) return false;

    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }

    return true;
  }

  static MultipartFile _imageMultipart(
      Uint8List bytes, {
        required String fileName,
      }) {
    String subtype;
    String extension;

    if (_startsWithBytes(bytes, const [0xFF, 0xD8, 0xFF])) {
      subtype = 'jpeg';
      extension = 'jpg';
    } else if (_startsWithBytes(
      bytes,
      const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    )) {
      subtype = 'png';
      extension = 'png';
    } else if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      subtype = 'webp';
      extension = 'webp';
    } else {
      throw Exception(
        'Invalid image bytes: expected JPEG, PNG or WEBP.',
      );
    }

    final trimmedName = fileName.trim();
    final baseName = trimmedName.isEmpty
        ? 'image'
        : trimmedName.replaceFirst(
      RegExp(r'\.[^.]+$'),
      '',
    );

    return MultipartFile.fromBytes(
      bytes,
      filename: '$baseName.$extension',
      contentType: MediaType('image', subtype),
    );
  }

  // ================= PROFILE =================

  static Future<Map<String, dynamic>> getProfile() async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final response = await _dioEatme.get('/profile/');
    return Map<String, dynamic>.from(response.data);
  }

  static Future<void> updateProfile({
    required String phone,
    required String address,
  }) async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    await _dioEatme.patch(
      '/profile/',
      data: {
        'phone': phone,
        'address': address,
      },
    );
  }

  static Future<Map<String, dynamic>> updatePersonalData({
    required String phone,
    required String address,
    required String houseNumber,
    required String floor,
    required double? latitude,
    required double? longitude,
    required String additionalInfo,
  }) async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final response = await _dioEatme.patch(
      '/profile/',
      data: {
        'phone': phone,
        'address': address,
        'house_number': houseNumber,
        'floor': floor,
        'delivery_latitude': latitude,
        'delivery_longitude': longitude,
        'delivery_additional_info': additionalInfo,
      },
    );

    return Map<String, dynamic>.from(response.data);
  }

  static Future<Map<String, dynamic>> updateProfileAvatar({
    required Uint8List avatarBytes,
    String fileName = 'avatar.jpg',
  }) async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final safeFileName =
    fileName.trim().isEmpty ? 'avatar.jpg' : fileName.trim();

    final formData = FormData.fromMap({
      'avatar': _imageMultipart(
        avatarBytes,
        fileName: safeFileName,
      ),
    });

    try {
      final response = await _dioEatme.patch(
        '/profile/',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      final data = e.response?.data;
      throw Exception(
        data?.toString() ?? 'Failed to update profile avatar',
      );
    }
  }

  static Future<void> updateLanguage(String language) async {
    final code = language.trim().toLowerCase();

    if (!['ru', 'en', 'hy'].contains(code)) {
      return;
    }

    setRequestLanguage(code);
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      return;
    }

    await _dioEatme.patch(
      '/profile/',
      data: {
        'language': code,
      },
    );
  }

  static Future<String?> getProfileLanguage() async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      return null;
    }

    final profile = await getProfile();
    final language = profile['language']?.toString().toLowerCase();

    if (language == null || !['ru', 'en', 'hy'].contains(language)) {
      return null;
    }

    return language;
  }

  static Future<void> syncSavedLanguageToBackend() async {
    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString('app_language') ?? 'en';

    try {
      await updateLanguage(language);
    } catch (_) {
      // Не блокируем вход, если язык не удалось отправить на сервер.
    }
  }

  // ================= PRODUCTS =================

  static Future<ProductPageResult> getProductsPage({
    int page = 1,
    String? search,
    String? ordering,
    String? companySlug,
    String? tagSlug,
    List<String>? tagSlugs,
    String? type,
    bool promoted = false,
    bool untagged = false,
    bool includeMeta = false,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final normalizedTags = (tagSlugs ?? const <String>[])
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();

      final response = await _dioEatme.get(
        '/products/',
        queryParameters: {
          'limit': pageSize,
          'offset': (page - 1) * pageSize,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          if (ordering != null && ordering.isNotEmpty)
            'ordering': ordering,
          if (companySlug != null && companySlug.isNotEmpty)
            'company': companySlug,
          if (normalizedTags.isNotEmpty)
            'tags': normalizedTags.join(','),
          if (normalizedTags.isEmpty &&
              tagSlug != null &&
              tagSlug.isNotEmpty)
            'tag': tagSlug,
          if (type != null && type.isNotEmpty) 'type': type,
          if (promoted) 'promoted': 1,
          if (untagged) 'untagged': 1,
          if (includeMeta) 'include_meta': 1,
          if (latitude != null && longitude != null) 'lat': latitude,
          if (latitude != null && longitude != null) 'lng': longitude,
        },
      );

      final data = response.data;

      if (data is Map) {
        final rawResults = data['results'];
        final products = rawResults is List
            ? rawResults
            .map((e) => Product.fromJson(
          Map<String, dynamic>.from(e as Map),
        ))
            .toList()
            : <Product>[];

        final count = int.tryParse(data['count']?.toString() ?? '') ??
            products.length;

        final rawTagCounts = data['tag_counts'];
        final tagCounts = <String, int>{};

        if (rawTagCounts is Map) {
          rawTagCounts.forEach((key, value) {
            final slug = key?.toString() ?? '';
            if (slug.isEmpty) return;
            tagCounts[slug] =
                int.tryParse(value?.toString() ?? '0') ?? 0;
          });
        }

        return ProductPageResult(
          products: products,
          count: count,
          hasMore: data['next'] != null,
          tagCounts: tagCounts,
          untaggedCount:
          int.tryParse(data['untagged_count']?.toString() ?? '0') ?? 0,
        );
      }

      if (data is List) {
        final products = data
            .map((e) => Product.fromJson(
          Map<String, dynamic>.from(e as Map),
        ))
            .toList();

        return ProductPageResult(
          products: products,
          count: products.length,
          hasMore: products.length >= pageSize,
        );
      }

      return const ProductPageResult(
        products: <Product>[],
        count: 0,
        hasMore: false,
      );
    } catch (_) {
      rethrow;
    }
  }

  /// Backwards-compatible helper for existing screens.
  static Future<List<Product>> getProducts({
    int page = 1,
    String? search,
    String? ordering,
    String? companySlug,
    String? tagSlug,
    List<String>? tagSlugs,
    String? type,
    bool promoted = false,
    bool untagged = false,
    double? latitude,
    double? longitude,
  }) async {
    final result = await getProductsPage(
      page: page,
      search: search,
      ordering: ordering,
      companySlug: companySlug,
      tagSlug: tagSlug,
      tagSlugs: tagSlugs,
      type: type,
      promoted: promoted,
      untagged: untagged,
      latitude: latitude,
      longitude: longitude,
    );

    return result.products;
  }

  static Future<Product?> getProductBySlug(String slug) async {
    try {
      final response = await _dioEatme.get('/products/$slug/');
      return Product.fromJson(response.data);
    } catch (e) {
      debugPrint('GET PRODUCT BY SLUG ERROR: $e');
      return null;
    }
  }

  /// Registers opening/viewing of a product detail page.
  /// Returns the current views_count from backend.
  static Future<int> registerProductView(String productSlug) async {
    if (productSlug.trim().isEmpty) return 0;

    try {
      final response = await _dioEatme.post(
        '/products/${productSlug.trim()}/view/',
      );

      final data = response.data;
      if (data is Map) {
        return int.tryParse(data['views_count']?.toString() ?? '0') ?? 0;
      }

      return 0;
    } on DioException catch (e) {
      debugPrint(
        'REGISTER PRODUCT VIEW ERROR: '
            '${e.response?.statusCode} ${e.response?.data ?? e.message}',
      );
      return 0;
    } catch (e) {
      debugPrint('REGISTER PRODUCT VIEW ERROR: $e');
      return 0;
    }
  }

  /// Registers a successful Share action.
  /// Call this only when the user actually starts sharing the product.
  /// Returns the current shares_count from backend.
  static Future<int> registerProductShare(String productSlug) async {
    if (productSlug.trim().isEmpty) return 0;

    try {
      final response = await _dioEatme.post(
        '/products/${productSlug.trim()}/share/',
      );

      final data = response.data;
      if (data is Map) {
        return int.tryParse(data['shares_count']?.toString() ?? '0') ?? 0;
      }

      return 0;
    } on DioException catch (e) {
      debugPrint(
        'REGISTER PRODUCT SHARE ERROR: '
            '${e.response?.statusCode} ${e.response?.data ?? e.message}',
      );
      return 0;
    } catch (e) {
      debugPrint('REGISTER PRODUCT SHARE ERROR: $e');
      return 0;
    }
  }

  static Future<int> getProductsCount({
    String? search,
    String? ordering,
    String? companySlug,
    String? tagSlug,
    String? type,
  }) async {
    try {
      final response = await _dioEatme.get(
        '/products/',
        queryParameters: {
          'limit': 1,
          'offset': 0,
          if (search != null && search.isNotEmpty) 'search': search,
          if (ordering != null && ordering.isNotEmpty) 'ordering': ordering,
          if (companySlug != null && companySlug.isNotEmpty) 'company': companySlug,
          if (tagSlug != null && tagSlug.isNotEmpty) 'tag': tagSlug,
          if (type != null && type.isNotEmpty) 'type': type,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final count = data['count'];
        if (count is int) return count;
        return int.tryParse(count?.toString() ?? '') ?? 0;
      }

      if (data is List) return data.length;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<List<Product>> getProductsByCompany(
      String companySlug, {
        int page = 1,
      }) async {
    return getProducts(page: page, companySlug: companySlug);
  }

  static Future<List<Tag>> getTags({bool includeEmpty = false}) async {
    try {
      final response = await _dioEatme.get(
        '/tag/',
        queryParameters: {
          if (includeEmpty) 'include_empty': 1,
        },
      );
      final data = response.data;
      final results = data is Map<String, dynamic> ? data['results'] : data;

      return (results as List).map((e) => Tag.fromJson(e)).toList();
    } catch (_) {
      rethrow;
    }
  }

  /// Full tag dictionary for seller create/edit forms, including tags that
  /// are not yet attached to any product.
  static Future<List<Tag>> getSellerTags() {
    return getTags(includeEmpty: true);
  }

  static Future<List<Tag>> getTagsByType(String type) async {
    try {
      final response = await _dioEatme.get(
        '/tag/',
        queryParameters: {
          if (type.isNotEmpty) 'type': type,
        },
      );

      final data = response.data;
      final results = data is Map<String, dynamic> ? data['results'] : data;

      return (results as List).map((e) => Tag.fromJson(e)).toList();
    } catch (_) {
      rethrow;
    }
  }

  static Future<Company> getCompanyBySlug(String slug) async {
    try {
      final response = await _dioEatme.get('/company/$slug/');
      return Company.fromJson(response.data);
    } catch (_) {
      rethrow;
    }
  }

  static Future<List<MapCompany>> getMapCompanies() async {
    try {
      final response = await _dioEatme.get('/company/');
      final data = response.data;
      final results = data is Map<String, dynamic> ? data['results'] : data;

      return (results as List).map((e) => MapCompany.fromJson(e)).where((c) {
        final validLat = c.latitude >= -90 && c.latitude <= 90;
        final validLng = c.longitude >= -180 && c.longitude <= 180;
        return validLat && validLng;
      }).toList();
    } catch (_) {
      rethrow;
    }
  }

  static Future<List<MapCompany>> getCompaniesByType(String type) async {
    try {
      final response = await _dioEatme.get(
        '/company/',
        queryParameters: {
          if (type.isNotEmpty) 'type': type,
        },
      );

      final data = response.data;
      final results = data is Map<String, dynamic> ? data['results'] : data;

      return (results as List)
          .map((e) => MapCompany.fromJson(e))
          .where((c) => c.slug.isNotEmpty)
          .toList();
    } catch (_) {
      rethrow;
    }
  }

  // ================= FAVORITES =================

  static Future<List<Product>> getFavorites() async {
    await _loadTokens();
    if (_accessToken == null || _accessToken!.isEmpty) return [];

    final endpoints = <String>[
      '/favourites/detail/',
      '/favourites/detail',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await _dioEatme.get(endpoint);
        final data = response.data;

        if (data is List) {
          return data.map((e) => Product.fromJson(e)).toList();
        }

        if (data is Map<String, dynamic> && data['results'] is List) {
          return (data['results'] as List)
              .map((e) => Product.fromJson(e))
              .toList();
        }
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) rethrow;
      }
    }

    final slugs = await getFavoriteSlugs();
    if (slugs.isEmpty) return [];

    final List<Product> result = [];
    for (int page = 1; page <= 50; page++) {
      final products = await getProducts(page: page);
      result.addAll(products.where((p) => slugs.contains(p.slug)));
      if (products.length < pageSize) break;
    }

    return result;
  }

  static Future<Set<String>> getFavoriteSlugs() async {
    await _loadTokens();
    if (_accessToken == null || _accessToken!.isEmpty) return {};

    final endpoints = <String>[
      '/favourites/list/',
      '/favourites/list',
      '/favourites/',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await _dioEatme.get(endpoint);
        final data = response.data;
        final Set<String> slugs = {};

        final list = data is Map<String, dynamic> && data['results'] is List
            ? data['results'] as List
            : data is List
            ? data
            : const [];

        for (final item in list) {
          if (item is Map) {
            final value = item['products'] ?? item['product'] ?? item['slug'];
            if (value is String && value.isNotEmpty) {
              slugs.add(value);
            } else if (value is Map && value['slug'] is String) {
              slugs.add(value['slug'] as String);
            }
          }
        }

        return slugs;
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) rethrow;
      }
    }

    return {};
  }

  static Future<void> addToFavorites(String productSlug) async {
    await _loadTokens();
    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    try {
      await _dioEatme.post(
        '/favourites/create/',
        data: {'products': productSlug},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) return;
      throw Exception('Failed to add to favorites');
    }
  }

  static Future<void> removeFromFavorites(String productSlug) async {
    await _loadTokens();
    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final endpoints = <String>[
      '/favourites/destroy/$productSlug/',
      '/favourites/destroy/$productSlug',
    ];

    for (final endpoint in endpoints) {
      try {
        await _dioEatme.delete(endpoint);
        return;
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) rethrow;
      }
    }

    throw Exception('Failed to remove from favorites');
  }

  static Future<bool> isFavorite(String productSlug) async {
    try {
      final slugs = await getFavoriteSlugs();
      return slugs.contains(productSlug);
    } catch (_) {
      return false;
    }
  }

  // ================= CART =================

  static Future<Map<String, dynamic>> getCart() async {
    await _loadTokens();
    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final endpoints = <String>[
      '/cart/',
      '/cart',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await _dioEatme.get(endpoint);

        return response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) rethrow;
      }
    }

    throw Exception('Cart endpoint not found');
  }

  static Future<void> addToCart({
    required String productSlug,
    int quantity = 1,
  }) async {
    await _loadTokens();
    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    await _dioEatme.post(
      '/cart/add/',
      data: {
        'product_slug': productSlug,
        'quantity': quantity,
      },
    );
  }

  static Future<void> removeCartItem(String productSlug) async {
    await _loadTokens();
    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final endpoints = <String>[
      '/cart/item/$productSlug/',
      '/cart/item/$productSlug',
    ];

    for (final endpoint in endpoints) {
      try {
        await _dioEatme.delete(endpoint);
        return;
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) rethrow;
      }
    }

    throw Exception('Cart item endpoint not found');
  }


  static Future<Map<String, dynamic>> reserveHotProduct({
    required String productSlug,
    required int quantity,
  }) async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      throw const HotReservationException(
        code: 'not_authenticated',
        message: 'Not authenticated',
      );
    }

    try {
      final response = await _dioEatme.post(
        '/cart/reserve-hot/',
        data: {
          'product_slug': productSlug,
          'quantity': quantity,
        },
      );

      final data = response.data;

      if (data is Map<String, dynamic>) {
        return data;
      }

      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }

      return <String, dynamic>{};
    } on DioException catch (e) {
      final responseData = e.response?.data;

      if (responseData is Map) {
        final code = responseData['code']?.toString().trim() ?? '';
        final message =
        responseData['error']?.toString().trim().isNotEmpty == true
            ? responseData['error'].toString().trim()
            : responseData['detail']?.toString().trim().isNotEmpty == true
            ? responseData['detail'].toString().trim()
            : 'Failed to reserve HOT product';

        final available = int.tryParse(
          responseData['available']?.toString() ?? '',
        );

        throw HotReservationException(
          code: code.isEmpty ? 'unknown' : code,
          message: message,
          available: available,
        );
      }

      throw HotReservationException(
        code: 'network_or_server_error',
        message: e.message ?? 'Failed to reserve HOT product',
      );
    }
  }

  static Future<void> checkoutCart({String status = 'paided'}) async {
    await _loadTokens();
    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final endpoints = <String>[
      '/cart/checkout/',
      '/cart/checkout',
    ];

    DioException? lastError;

    for (final endpoint in endpoints) {
      try {
        await _dioEatme.patch(endpoint);
        return;
      } on DioException catch (e) {
        lastError = e;

        if (e.response?.statusCode == 404) {
          continue;
        }

        final data = e.response?.data;
        throw Exception(
          'Checkout failed: ${e.response?.statusCode ?? ''} ${data ?? e.message}',
        );
      }
    }

    throw Exception(
      'Checkout endpoint not found: ${lastError?.response?.data ?? lastError?.message ?? ''}',
    );
  }

  static Future<void> updateCartItemQuantity({
    required String productSlug,
    required int quantity,
  }) async {
    await _loadTokens();
    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final endpoints = <String>[
      '/cart/item/$productSlug/update/',
      '/cart/item/$productSlug/update',
    ];

    for (final endpoint in endpoints) {
      try {
        await _dioEatme.patch(
          endpoint,
          data: {'quantity': quantity},
        );
        return;
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) rethrow;
      }
    }

    throw Exception('Update quantity endpoint not found');
  }

  static Future<List<dynamic>> getPastOrders() async {
    await _loadTokens();
    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final response = await _dioEatme.get('/cart/past-orders/');
    final data = response.data;

    if (data is List) return data;

    if (data is Map<String, dynamic> && data['results'] is List) {
      return data['results'] as List;
    }

    return [];
  }

  // ================= LEGAL =================

  static String _normalizedLegalLanguage(String? language) {
    final code = (language ?? _requestLanguage)
        .trim()
        .toLowerCase()
        .split('-')
        .first;
    return ['ru', 'en', 'hy'].contains(code) ? code : 'en';
  }

  static Future<List<LegalDocumentInfo>> getLegalDocuments({
    String action = 'all',
    String? language,
  }) async {
    final lang = _normalizedLegalLanguage(language);
    final response = await _dioEatme.get(
      '/legal/documents/',
      queryParameters: {
        'action': action,
        'lang': lang,
      },
    );

    final data = response.data;
    final raw = data is Map ? data['documents'] : null;
    if (raw is! List) return const <LegalDocumentInfo>[];

    return raw
        .whereType<Map>()
        .map((item) => LegalDocumentInfo.fromJson(
      Map<String, dynamic>.from(item),
    ))
        .toList();
  }

  static Future<LegalStatusResult> getLegalStatus({
    required String action,
    String? language,
  }) async {
    await _loadTokens();
    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final response = await _dioEatme.get(
      '/legal/status/',
      queryParameters: {
        'action': action,
        'lang': _normalizedLegalLanguage(language),
      },
    );

    return LegalStatusResult.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  static Future<LegalStatusResult> acceptLegalDocuments({
    required String action,
    required List<LegalDocumentInfo> documents,
  }) async {
    await _loadTokens();
    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final response = await _dioEatme.post(
      '/legal/accept/',
      data: {
        'action': action,
        'acceptances': documents
            .map((document) => document.toAcceptancePayload())
            .toList(),
      },
    );

    return LegalStatusResult.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  // ================= AUTH =================

  static Future<void> register({
    required String username,
    required String email,
    required String phone,
    required String password,
    required String rePassword,
    required List<Map<String, dynamic>> legalAcceptances,
  }) async {
    try {
      await _dioEatme.post(
        '/auth/users/',
        data: {
          'username': username,
          'email': email,
          'phone': phone,
          'password': password,
          're_password': rePassword,
          'legal_acceptances': legalAcceptances,
        },
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data.toString() ?? 'Registration error');
    }
  }


  static Future<void> _initGoogleSignIn() async {
    if (_googleSignInInitialized) return;

    await GoogleSignIn.instance.initialize(
      clientId: googleWebClientId,
      serverClientId: googleWebClientId,
    );

    _googleSignInInitialized = true;
  }

  static Future<void> loginWithGoogle() async {
    try {
      await _initGoogleSignIn();

      final account = await GoogleSignIn.instance.authenticate();
      final auth = account.authentication;
      final idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google idToken is empty');
      }

      final response = await _dioEatme.post(
        '/google-for-flutter/google-login/',
        data: {'id_token': idToken},
      );

      await saveTokens(
        access: response.data['access'],
        refresh: response.data['refresh'],
      );

      await syncSavedLanguageToBackend();

      notificationsVersion.value++;
    } on GoogleSignInException catch (e) {
      throw Exception(e.description ?? e.code.name);
    } on DioException catch (e) {
      throw Exception(e.response?.data.toString() ?? 'Google login error');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<void> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dioEatme.post(
        '/auth/jwt/create/',
        data: {'username': username, 'password': password},
      );

      await saveTokens(
        access: response.data['access'],
        refresh: response.data['refresh'],
      );

      await syncSavedLanguageToBackend();

      notificationsVersion.value++;
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Login error');
    }
  }

  static Future<User> getCurrentUser() async {
    try {
      final response = await _dioEatme.get('/auth/users/me/');
      return User.fromJson(response.data);
    } catch (_) {
      throw Exception('Failed to get user');
    }
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String reNewPassword,
  }) async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('not_authenticated');
    }

    try {
      await _dioEatme.post(
        '/auth/users/set_password/',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          // Djoser requires this only when SET_PASSWORD_RETYPE=True.
          // Sending it is compatible with both configurations.
          're_new_password': reNewPassword,
        },
      );
    } on DioException catch (e) {
      final data = e.response?.data;

      if (data is Map) {
        if (data.containsKey('current_password')) {
          throw Exception('current_password_invalid');
        }
        if (data.containsKey('new_password') ||
            data.containsKey('re_new_password')) {
          throw Exception('new_password_invalid');
        }
      }

      if (e.response?.statusCode == 401) {
        throw Exception('not_authenticated');
      }

      throw Exception('password_change_failed');
    }
  }

  static Future<void> resetPassword({required String email}) async {
    try {
      await _dioEatme.post(
        '/auth/users/reset_password/',
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data.toString() ?? 'Ошибка восстановления пароля');
    }
  }

  static Future<void> resetPasswordConfirm({
    required String uid,
    required String token,
    required String newPassword,
    required String reNewPassword,
  }) async {
    try {
      await _dioEatme.post(
        '/auth/users/reset_password_confirm/',
        data: {
          'uid': uid,
          'token': token,
          'new_password': newPassword,
          're_new_password': reNewPassword,
        },
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data.toString() ?? 'Ошибка подтверждения пароля');
    }
  }

  static Future<void> resetUsername({required String email}) async {
    try {
      await _dioEatme.post(
        '/auth/users/reset_username/',
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data.toString() ?? 'Ошибка восстановления логина');
    }
  }

  static Future<void> resetUsernameConfirm({
    required String uid,
    required String token,
    required String newUsername,
  }) async {
    try {
      await _dioEatme.post(
        '/auth/users/reset_username_confirm/',
        data: {
          'uid': uid,
          'token': token,
          'new_username': newUsername,
        },
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data.toString() ?? 'Ошибка подтверждения логина');
    }
  }

  // ================= SELLER =================

  static Future<bool> checkIsSeller() async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      return false;
    }

    try {
      final profile = await getProfile();
      final typeUser = profile['type_user']?.toString().toLowerCase() ?? '';
      return typeUser == 'seller';
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getMyProfile() async {
    await _loadTokens();
    if (_accessToken == null || _accessToken!.isEmpty) return null;

    final endpoints = <String>[
      '/profiles/me/',
      '/profiles/me',
      '/profile/me/',
      '/profile/me',
      '/profiles/current/',
      '/profiles/current',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await _dioEatme.get(endpoint);
        final data = response.data;

        if (data is Map<String, dynamic>) {
          return data;
        }

        if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
          return data.first as Map<String, dynamic>;
        }
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) rethrow;
      }
    }

    return null;
  }

  static Future<List<Map<String, dynamic>>> getMyCompanies() async {
    await _loadTokens();
    if (_accessToken == null || _accessToken!.isEmpty) return [];

    final endpoints = <String>[
      '/company/my/',
      '/company/my',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await _dioEatme.get(endpoint);
        final data = response.data;

        final list = data is Map<String, dynamic> && data['results'] is List
            ? data['results'] as List
            : data is List
            ? data
            : const [];

        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } on DioException catch (e) {
        if (e.response?.statusCode == 403) return [];
        if (e.response?.statusCode != 404) rethrow;
      }
    }

    return [];
  }

  static Future<void> createSellerProduct({
    required String companySlug,
    required String name,
    required Uint8List imageBytes,
    required String imageFileName,
    required String description,
    required String price,
    required int discount,
    required int count,
    required String type,
    bool dineInOnly = false,
    String? packageQuantity,
    String? weight,
    String? deliveryType,
    int? deliveryDays,
    int? deliveryRadiusKm,
    String? locationAddress,
    double? locationLatitude,
    double? locationLongitude,
    String? expirationDate,
    String? canUseUntil,
    String? pickupFrom,
    String? pickupUntil,
    String? publishAtLocal,
    List<String> tagSlugs = const [],
  }) async {
    await _loadTokens();
    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final data = <String, dynamic>{
      'company': companySlug,
      'name': name,
      'image': _imageMultipart(
        imageBytes,
        fileName: imageFileName,
      ),
      'description': description,
      'price': price,
      'discount': discount,
      'count': count,
      'type': type,
      'dine_in_only': dineInOnly,
      'package_quantity': packageQuantity ?? '',
      'weight': weight ?? '',
      'delivery_type': deliveryType ?? 'pickup',
    };

    if (deliveryDays != null) {
      data['delivery_days'] = deliveryDays;
    }

    if (deliveryRadiusKm != null) {
      data['delivery_radius_km'] = deliveryRadiusKm;
    }

    if (locationAddress != null && locationAddress.trim().isNotEmpty) {
      data['location_address'] = locationAddress.trim();
    }

    if (locationLatitude != null && locationLongitude != null) {
      // Product coordinates are stored with 6 decimal places on the backend.
      // Raw mobile doubles may contain many more fractional digits, so normalize
      // them before multipart serialization.
      data['location_latitude'] = locationLatitude.toStringAsFixed(6);
      data['location_longitude'] = locationLongitude.toStringAsFixed(6);
    }

    if (expirationDate != null && expirationDate.trim().isNotEmpty) {
      data['expiration_date'] = expirationDate.trim();
    }

    if (canUseUntil != null && canUseUntil.trim().isNotEmpty) {
      data['can_use_until'] = canUseUntil.trim();
    }

    if (pickupFrom != null && pickupFrom.trim().isNotEmpty) {
      data['pickup_from'] = pickupFrom.trim();
    }

    if (pickupUntil != null && pickupUntil.trim().isNotEmpty) {
      data['pickup_until'] = pickupUntil.trim();
    }

    // Local wall-clock time of the Armenian shop.
    // Backend interprets this value as Asia/Yerevan.
    if (publishAtLocal != null && publishAtLocal.trim().isNotEmpty) {
      data['publish_at_local'] = publishAtLocal.trim();
    }

    final formData = FormData.fromMap(data);

    for (final slug in tagSlugs) {
      if (slug.trim().isNotEmpty) {
        formData.fields.add(MapEntry('tag', slug.trim()));
      }
    }

    try {
      await _dioEatme.post(
        '/products/create/',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      throw Exception(data?.toString() ?? 'Failed to create product');
    }
  }

  static Future<List<Product>> getMySellerProducts() async {
    await _loadTokens();
    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final endpoints = <String>[
      '/products/my/',
      '/products/my',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await _dioEatme.get(endpoint);
        final data = response.data;
        final results = data is Map<String, dynamic> && data['results'] is List
            ? data['results'] as List
            : data is List
            ? data
            : const [];

        return results
            .whereType<Map>()
            .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } on DioException catch (e) {
        if (e.response?.statusCode == 403) return [];
        if (e.response?.statusCode != 404) rethrow;
      }
    }

    return [];
  }

  static Future<void> updateSellerProduct({
    required String productSlug,
    required String companySlug,
    required String name,
    Uint8List? imageBytes,
    String? imageFileName,
    required String description,
    required String price,
    required int discount,
    required int count,
    required String type,
    bool dineInOnly = false,
    String? packageQuantity,
    String? weight,
    String? deliveryType,
    int? deliveryDays,
    int? deliveryRadiusKm,
    String? locationAddress,
    double? locationLatitude,
    double? locationLongitude,
    String? expirationDate,
    String? canUseUntil,
    String? pickupFrom,
    String? pickupUntil,
    String? publishAtLocal,
    List<String> tagSlugs = const [],
  }) async {
    await _loadTokens();
    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final data = <String, dynamic>{
      'company': companySlug,
      'name': name,
      'description': description,
      'price': price,
      'discount': discount,
      'count': count,
      'type': type,
      'dine_in_only': dineInOnly,
      'package_quantity': packageQuantity ?? '',
      'weight': weight ?? '',
      'delivery_type': deliveryType ?? 'pickup',
    };

    if (deliveryDays != null) {
      data['delivery_days'] = deliveryDays;
    }

    if (deliveryRadiusKm != null) {
      data['delivery_radius_km'] = deliveryRadiusKm;
    }

    if (locationAddress != null) {
      data['location_address'] = locationAddress.trim();
    }

    if (locationLatitude != null && locationLongitude != null) {
      // Product coordinates are stored with 6 decimal places on the backend.
      // Raw mobile doubles may contain many more fractional digits, so normalize
      // them before multipart serialization.
      data['location_latitude'] = locationLatitude.toStringAsFixed(6);
      data['location_longitude'] = locationLongitude.toStringAsFixed(6);
    }

    if (expirationDate != null && expirationDate.trim().isNotEmpty) {
      data['expiration_date'] = expirationDate.trim();
    }

    if (canUseUntil != null && canUseUntil.trim().isNotEmpty) {
      data['can_use_until'] = canUseUntil.trim();
    }

    if (pickupFrom != null && pickupFrom.trim().isNotEmpty) {
      data['pickup_from'] = pickupFrom.trim();
    }

    if (pickupUntil != null && pickupUntil.trim().isNotEmpty) {
      data['pickup_until'] = pickupUntil.trim();
    }

    if (publishAtLocal != null && publishAtLocal.trim().isNotEmpty) {
      data['publish_at_local'] = publishAtLocal.trim();
    }

    if (imageBytes != null) {
      data['image'] = _imageMultipart(
        imageBytes,
        fileName: imageFileName ?? 'product.jpg',
      );
    }

    final formData = FormData.fromMap(data);

    for (final slug in tagSlugs) {
      if (slug.trim().isNotEmpty) {
        formData.fields.add(MapEntry('tag', slug.trim()));
      }
    }

    try {
      await _dioEatme.patch(
        '/products/$productSlug/update/',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
    } on DioException catch (e) {
      final responseData = e.response?.data;
      throw Exception(responseData?.toString() ?? 'Failed to update product');
    }
  }


  static Future<Product> setSellerProductActive({
    required String productSlug,
    required bool isActive,
  }) async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    try {
      final response = await _dioEatme.patch(
        '/products/$productSlug/status/',
        data: {
          'is_active': isActive,
        },
      );

      return Product.fromJson(
        Map<String, dynamic>.from(response.data),
      );
    } on DioException catch (e) {
      final data = e.response?.data;

      if (data is Map && data['detail'] != null) {
        throw Exception(data['detail'].toString());
      }

      throw Exception(
        data?.toString() ?? 'Failed to change product status',
      );
    }
  }

  static Future<Product> publishSellerProductNow({
    required String productSlug,
  }) {
    return setSellerProductActive(
      productSlug: productSlug,
      isActive: true,
    );
  }

  static Future<void> deleteSellerProduct(String productSlug) async {
    await _loadTokens();
    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final endpoints = <String>[
      '/products/$productSlug/delete/',
      '/products/$productSlug/delete',
    ];

    for (final endpoint in endpoints) {
      try {
        await _dioEatme.delete(endpoint);
        return;
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) {
          final data = e.response?.data;
          throw Exception(data?.toString() ?? 'Failed to delete product');
        }
      }
    }

    throw Exception('Delete product endpoint not found');
  }

  static Future<void> updateSellerCompany({
    required String companySlug,
    required String name,
    required String address,
    required String description,
    required String phone,
    required String instagram,
    required String facebook,
    required String latitude,
    required String longitude,
    required String openTime,
    required String closeTime,
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    await _loadTokens();
    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final data = <String, dynamic>{
      'name': name,
      'address': address,
      'description': description,
      'phone': phone,
      'instagram': instagram,
      'facebook': facebook,
      'latitude': latitude,
      'longitude': longitude,
      'open_time': openTime,
      'close_time': closeTime,
    };

    if (imageBytes != null) {
      data['image'] = _imageMultipart(
        imageBytes,
        fileName: imageFileName ?? 'company.jpg',
      );
    }

    final formData = FormData.fromMap(data);

    try {
      await _dioEatme.patch(
        '/company/$companySlug/update/',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
    } on DioException catch (e) {
      final responseData = e.response?.data;
      throw Exception(responseData?.toString() ?? 'Failed to update company');
    }
  }

  // ================= REVIEWS =================

  static Future<void> addReview({
    required int cardId,
    required int companyId,
    required int quality,
    required int value,
    required int descriptionMatch,
    required int service,
    String comment = '',
  }) async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    await _dioEatme.post(
      '/reviews/add/',
      data: {
        'card': cardId,
        'company': companyId,
        'quality': quality,
        'value': value,
        'description_match': descriptionMatch,
        'service': service,
        'comment': comment,
      },
    );
  }

  /// Public reviews for a company. Authentication is not required.
  static Future<List<Map<String, dynamic>>> getCompanyReviews({
    required String companySlug,
  }) async {
    final slug = companySlug.trim();

    if (slug.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final response = await _dioEatme.get(
      '/company/${Uri.encodeComponent(slug)}/reviews/',
    );

    final data = response.data;

    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (data is Map && data['results'] is List) {
      return (data['results'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return <Map<String, dynamic>>[];
  }

  static Future<List<Map<String, dynamic>>> getMyReviews() async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final response = await _dioEatme.get('/reviews/my/');

    final data = response.data;

    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }

    if (data is Map && data['results'] is List) {
      return List<Map<String, dynamic>>.from(data['results']);
    }

    return [];
  }

  static Future<Map<String, dynamic>> requestReviewEdit({
    required int reviewId,
  }) async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    try {
      final response = await _dioEatme.post(
        '/reviews/my/$reviewId/edit-request/',
      );

      if (response.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(response.data);
      }

      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }

      return <String, dynamic>{};
    } on DioException catch (e) {
      final data = e.response?.data;

      if (data is Map && data['detail'] != null) {
        throw Exception(data['detail'].toString());
      }

      throw Exception(
        data?.toString() ?? 'Failed to request review editing',
      );
    }
  }


  static Future<void> updateReview({
    required int reviewId,
    required int quality,
    required int value,
    required int descriptionMatch,
    required int service,
    required String comment,
  }) async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    try {
      await _dioEatme.patch(
        '/reviews/my/$reviewId/',
        data: {
          'quality': quality,
          'value': value,
          'description_match': descriptionMatch,
          'service': service,
          'comment': comment,
        },
      );
    } on DioException catch (e) {
      final data = e.response?.data;

      if (data is Map && data['detail'] != null) {
        throw Exception(data['detail'].toString());
      }

      throw Exception(
        data?.toString() ?? 'Failed to update review',
      );
    }
  }

  static Future<void> deleteReview(int reviewId) async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    await _dioEatme.delete(
      '/reviews/my/$reviewId/',
    );
  }

  static Future<List<Map<String, dynamic>>> getSellerReviews() async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final response = await _dioEatme.get('/reviews/seller/');

    final data = response.data;

    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }

    if (data is Map && data['results'] is List) {
      return List<Map<String, dynamic>>.from(data['results']);
    }

    return [];
  }

  static Future<Map<String, dynamic>> getSellerStats() async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final response = await _dioEatme.get('/seller/stats/');

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }

    return <String, dynamic>{};
  }

  static Future<List<Map<String, dynamic>>> getSellerSales() async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final response = await _dioEatme.get('/seller/sales/');
    final data = response.data;

    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }

    if (data is Map && data['results'] is List) {
      return List<Map<String, dynamic>>.from(data['results']);
    }

    return [];
  }

  static Future<Map<String, dynamic>> getSellerOrder(
      int cardId,
      int companyId,
      ) async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final response = await _dioEatme.get(
      '/seller/orders/$cardId/$companyId/',
    );

    if (response.data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(response.data);
    }

    return <String, dynamic>{};
  }

  // ================= RECOMMENDED PRODUCTS =================

  static Future<List<Product>> getRecommendedProducts({
    String? mode,
  }) async {
    final response = await _dioEatme.get(
      '/products/recommended/',
      queryParameters: {
        if (mode != null && mode.trim().isNotEmpty)
          'mode': mode.trim(),
      },
    );

    final data = response.data;

    if (data is Map && data['results'] is List) {
      return (data['results'] as List)
          .map((json) => Product.fromJson(
        Map<String, dynamic>.from(json as Map),
      ))
          .toList();
    }

    if (data is List) {
      return data
          .map((json) => Product.fromJson(
        Map<String, dynamic>.from(json as Map),
      ))
          .toList();
    }

    return [];
  }

  // ================= NOTIFICATIONS =================

  static Future<void> createNotificationAlarm({
    required String productType,
    required List<String> tagSlugs,
    List<String> companySlugs = const [],
    required DateTime notifyAt,
    required DateTime notifyUntil,
    required int timezoneOffsetMinutes,
    double? radiusKm,
    double? latitude,
    double? longitude,
  }) async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    final data = <String, dynamic>{
    'product_type': productType,
    'tags': tagSlugs,
    'companies': companySlugs,
    'notify_at': notifyAt.toUtc().toIso8601String(),
    'notify_until': notifyUntil.toUtc().toIso8601String(),
    'timezone_offset_minutes': timezoneOffsetMinutes,
    'is_active': true,
    'radius_km': ?radiusKm,
    'latitude': ?latitude,
    'longitude': ?longitude,
    };

    try {
    await _dioEatme.post(
    '/notifications/alarms/',
    data: data,
    );
    } on DioException catch (e) {
    // Временная совместимость со старым backend, пока поля radius_km/latitude/longitude
    // ещё не добавлены в Django serializer. После обновления backend этот fallback
    // можно удалить.
    if (e.response?.statusCode == 400 &&
    (radiusKm != null || latitude != null || longitude != null)) {
    await _dioEatme.post(
    '/notifications/alarms/',
    data: {
    'product_type': productType,
    'tags': tagSlugs,
    'companies': companySlugs,
    'notify_at': notifyAt.toUtc().toIso8601String(),
    'notify_until': notifyUntil.toUtc().toIso8601String(),
    'timezone_offset_minutes': timezoneOffsetMinutes,
    'is_active': true,
    },
    );
    } else {
    rethrow;
    }
    }

    notificationsVersion.value++;
  }

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    await _loadTokens();

    debugPrint(
      'ACCESS TOKEN EXISTS: ${_accessToken != null && _accessToken!.isNotEmpty}',
    );

    if (_accessToken == null || _accessToken!.isEmpty) {

      return [];
    }

    try {
      final response = await _dioEatme.get('/notifications/');


      final data = response.data;

      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }

      if (data is Map && data['results'] is List) {
        return List<Map<String, dynamic>>.from(data['results']);
      }


      return [];
    } catch (e) {

      return [];
    }
  }

  static Future<int> getUnreadNotificationsCount() async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      return 0;
    }

    try {
      final response = await _dioEatme.get('/notifications/unread-count/');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final count = data['count'];
        if (count is int) return count;
        return int.tryParse(count?.toString() ?? '0') ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> markNotificationRead(int id) async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    await _dioEatme.patch('/notifications/$id/read/');
    notificationsVersion.value++;
  }

  static Future<List<Map<String, dynamic>>> getNotificationAlarms() async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      return [];
    }

    try {
      final response = await _dioEatme.get('/notifications/alarms/');
      final data = response.data;

      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }

      if (data is Map && data['results'] is List) {
        return List<Map<String, dynamic>>.from(data['results']);
      }

      return [];
    } catch (e) {
      debugPrint('GET NOTIFICATION ALARMS ERROR: $e');
      return [];
    }
  }

  static Future<void> deleteNotificationAlarm(int id) async {
    await _loadTokens();

    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('Not authenticated');
    }

    await _dioEatme.delete('/notifications/alarms/$id/');
    notificationsVersion.value++;
  }

  static Future<void> registerDeviceToken({
    required String token,
    String deviceType = 'android',
  }) async {
    try {
      await _loadTokens();

      if (_accessToken == null || _accessToken!.isEmpty) {
        debugPrint('REGISTER DEVICE TOKEN: No access token, skipping');
        return;
      }

      if (token.trim().isEmpty) {
        debugPrint('REGISTER DEVICE TOKEN: Token is empty, skipping');
        return;
      }

      debugPrint('REGISTER DEVICE TOKEN: Registering token for device type: $deviceType');

      await _dioEatme.post(
        '/notifications/device/',
        data: {
          'token': token,
          'device_type': deviceType,
        },
      );

      debugPrint('REGISTER DEVICE TOKEN: Success');
    } catch (e) {
      debugPrint('REGISTER DEVICE TOKEN ERROR: $e');
      // Не выбрасываем исключение, чтобы не блокировать работу приложения
    }
  }
}