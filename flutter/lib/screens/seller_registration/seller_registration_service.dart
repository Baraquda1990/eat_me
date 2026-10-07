import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../services/api_service.dart';
import '../../utils/armenian_phone.dart';
import 'seller_registration_provider.dart';


class SellerApplicationGuardException implements Exception {
  const SellerApplicationGuardException({
    required this.reason,
    required this.status,
    required this.statusDisplay,
    this.applicationId,
  });

  final String reason;
  final String status;
  final String statusDisplay;
  final int? applicationId;

  bool get isLocked => reason == 'locked';
  bool get requiresResume => reason == 'resume_required';
  bool get applicationMismatch => reason == 'application_mismatch';

  @override
  String toString() {
    if (statusDisplay.trim().isNotEmpty) return statusDisplay.trim();
    return 'Seller application is not available for this action.';
  }
}

class SellerRegistrationService {
  SellerRegistrationService({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

  final Dio _dio;
  final String _baseUrl;

  Future<void> _ensureAuthorization() async {
    final token = await ApiService.getValidAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    _dio.options.headers['Authorization'] = 'Bearer $token';
    _dio.options.headers['Accept'] = 'application/json';
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['results'] is List) {
      return data['results'] as List;
    }
    return const [];
  }

  Future<List<SellerBusinessCategory>> getCategories({
    required String channelCode,
  }) async {
    final response = await _dio.get(
      '$_baseUrl/seller-applications/categories/',
      queryParameters: {
        if (channelCode.trim().isNotEmpty) 'channel': channelCode.trim(),
      },
    );

    final rawList = _extractList(response.data);

    return rawList
        .whereType<Map>()
        .map(
          (item) => SellerBusinessCategory.fromJson(
        Map<String, dynamic>.from(item),
      ),
    )
        .toList();
  }


  Future<Map<String, dynamic>?> getMyApplication() async {
    await _ensureAuthorization();
    final response = await _dio.get(
      '$_baseUrl/seller-applications/my/',
    );
    if (response.data is! Map) return null;
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['application'] == null && data['id'] == null) return null;
    return data['application'] is Map
        ? Map<String, dynamic>.from(data['application'] as Map)
        : data;
  }

  Future<List<String>> resolveApplicationChannelCodes(
      Map<String, dynamic> application,
      ) async {
    final ids = ((application['requested_channels'] as List?) ?? const [])
        .map((value) => int.tryParse(value.toString()))
        .whereType<int>()
        .toSet();
    if (ids.isEmpty) return const [];
    final channels = await getChannels();
    return channels
        .where((item) => ids.contains(int.tryParse(item['id'].toString())))
        .map((item) => item['code']?.toString().toLowerCase() ?? '')
        .where((code) => code.isNotEmpty)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getChannels() async {
    final response = await _dio.get(
      '$_baseUrl/seller-applications/channels/',
    );

    return _extractList(response.data)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<int>> _resolveRequestedChannelIds(String channelCode) async {
    final channels = await getChannels();
    final normalized = channelCode.trim().toLowerCase();

    final requestedCodes = <String>{};
    if (normalized == 'hot') {
      requestedCodes.add('hot');
    } else if (normalized == 'deals' || normalized == 'long') {
      requestedCodes.add('deals');
    } else if (normalized == 'both' ||
        normalized == 'hot_deals' ||
        normalized == 'hot+deals' ||
        normalized == 'hot_and_deals') {
      requestedCodes.addAll({'hot', 'deals'});
    } else {
      requestedCodes.addAll(
        normalized
            .split(RegExp(r'[,;+\s]+'))
            .where((value) => value.isNotEmpty)
            .map((value) => value == 'long' ? 'deals' : value),
      );
    }

    final ids = channels
        .where((channel) {
      final code = channel['code']?.toString().toLowerCase() ?? '';
      return requestedCodes.contains(code);
    })
        .map((channel) => int.tryParse(channel['id'].toString()))
        .whereType<int>()
        .toList();

    if (ids.isEmpty) {
      throw Exception('Не удалось определить направление продавца.');
    }

    return ids;
  }

  String? _decimalCoordinate(double? value) {
    if (value == null) return null;
    // Avoid binary floating-point tails such as 40.17720000000001.
    // The backend DecimalField accepts at most 9 digits in total.
    return value.toStringAsFixed(6);
  }

  SellerApplicationGuardException _guardException(
      Map<String, dynamic> application, {
        required String reason,
      }) {
    return SellerApplicationGuardException(
      reason: reason,
      status: application['status']?.toString().trim().toLowerCase() ?? '',
      statusDisplay: application['status_display']?.toString().trim() ?? '',
      applicationId: int.tryParse(application['id']?.toString() ?? ''),
    );
  }

  Future<Map<String, dynamic>?> _ensureEditableApplication({
    int? expectedApplicationId,
    bool allowMissing = false,
  }) async {
    final existing = await getMyApplication();

    if (existing == null) {
      if (allowMissing) return null;

      throw const SellerApplicationGuardException(
        reason: 'missing',
        status: '',
        statusDisplay: '',
      );
    }

    final existingId = int.tryParse(existing['id']?.toString() ?? '');
    final editable = existing['is_editable'] == true;

    if (!editable) {
      throw _guardException(existing, reason: 'locked');
    }

    if (expectedApplicationId != null &&
        existingId != expectedApplicationId) {
      throw _guardException(
        existing,
        reason: 'application_mismatch',
      );
    }

    return existing;
  }

  Future<Map<String, dynamic>> saveDraft({
    required SellerRegistrationProvider provider,
  }) async {
    await _ensureAuthorization();

    final existing = await getMyApplication();

    if (existing != null) {
      final existingId = int.tryParse(existing['id']?.toString() ?? '');

      if (existing['is_editable'] != true) {
        throw _guardException(existing, reason: 'locked');
      }

      // A brand-new local wizard must never silently overwrite an existing
      // editable draft. The existing application has to be loaded first.
      if (provider.applicationId == null ||
          provider.applicationId != existingId) {
        throw _guardException(existing, reason: 'resume_required');
      }
    }

    final requestedChannelIds =
    await _resolveRequestedChannelIds(provider.channelCode);

    final response = await _dio.post(
      '$_baseUrl/seller-applications/my/',
      data: {
        'requested_channels': requestedChannelIds,
        'organization_name': provider.organizationName.trim(),
        'tax_number': provider.taxNumber.trim(),
        'address': provider.address.trim(),
        'latitude': _decimalCoordinate(provider.latitude),
        'longitude': _decimalCoordinate(provider.longitude),
        'business_phone':
        ArmenianPhone.normalize(provider.businessPhone),
        if (provider.businessEmail.trim().isNotEmpty)
          'business_email': provider.businessEmail.trim(),
        'contact_name': provider.contactName.trim(),
        'contact_phone':
        ArmenianPhone.normalize(provider.contactPhone),
        if (provider.contactEmail.trim().isNotEmpty)
          'contact_email': provider.contactEmail.trim(),
        'business_category': provider.businessCategoryId,
        'current_step': 4,
      },
    );

    if (response.data is! Map) {
      throw const FormatException('Invalid seller application response.');
    }

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> uploadDocument({
    required int applicationId,
    required String documentType,
    required Uint8List bytes,
    required String fileName,
    String description = '',
  }) async {
    await _ensureAuthorization();
    await _ensureEditableApplication(
      expectedApplicationId: applicationId,
    );

    final formData = FormData.fromMap({
      'document_type': documentType,
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
      ),
      if (description.trim().isNotEmpty) 'description': description.trim(),
    });

    final response = await _dio.post(
      '$_baseUrl/seller-applications/$applicationId/documents/',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    if (response.data is! Map) {
      throw const FormatException('Invalid document upload response.');
    }

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> deleteDocument(int documentId) async {
    await _ensureAuthorization();
    await _ensureEditableApplication();

    await _dio.delete(
      '$_baseUrl/seller-applications/documents/$documentId/',
    );
  }

  Future<Map<String, dynamic>> saveBankAndBranding({
    required int applicationId,
    required String bankName,
    required String iban,
    required String accountHolderName,
    required String publicDescription,
    Uint8List? logoBytes,
    String? logoFileName,
  }) async {
    await _ensureAuthorization();
    await _ensureEditableApplication(
      expectedApplicationId: applicationId,
    );

    final formData = FormData.fromMap({
      'bank_name': bankName.trim(),
      'iban': iban.trim(),
      'account_holder_name': accountHolderName.trim(),
      'public_description': publicDescription.trim(),
      'current_step': 5,
      if (logoBytes != null && logoFileName != null)
        'logo': MultipartFile.fromBytes(
          logoBytes,
          filename: logoFileName,
        ),
    });

    final response = await _dio.patch(
      '$_baseUrl/seller-applications/$applicationId/',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    if (response.data is! Map) {
      throw const FormatException('Invalid seller application response.');
    }

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Uint8List> downloadAgencyAgreement({
    required int applicationId,
  }) async {
    await _ensureAuthorization();

    final response = await _dio.get<List<int>>(
      '$_baseUrl/seller-applications/$applicationId/agreement/',
      options: Options(responseType: ResponseType.bytes),
    );

    final data = response.data;
    if (data == null || data.isEmpty) {
      throw const FormatException('Agency agreement file is empty.');
    }

    return Uint8List.fromList(data);
  }

  Future<Map<String, dynamic>> getAgencyAgreementPreview({
    required int applicationId,
    String? language,
  }) async {
    await _ensureAuthorization();

    final response = await _dio.get(
      '$_baseUrl/seller-applications/$applicationId/agreement/preview/',
      queryParameters: {
        if (language != null && language.trim().isNotEmpty)
          'language': language.trim(),
      },
    );

    if (response.data is! Map) {
      throw const FormatException('Invalid agreement preview response.');
    }

    return Map<String, dynamic>.from(response.data as Map);
  }

  // Backward-compatible helper used by seller profile.
  Future<Map<String, dynamic>> getAcceptedAgencyAgreementPreview({
    required int applicationId,
  }) {
    return getAgencyAgreementPreview(
      applicationId: applicationId,
    );
  }

  Future<Map<String, dynamic>> submitApplication({
    required int applicationId,
    required bool agreementAccepted,
    required String agreementLanguage,
  }) async {
    await _ensureAuthorization();
    await _ensureEditableApplication(
      expectedApplicationId: applicationId,
    );

    final response = await _dio.post(
      '$_baseUrl/seller-applications/$applicationId/submit/',
      data: {
        'agreement_accepted': agreementAccepted,
        'agreement_language': agreementLanguage,
      },
    );

    if (response.data is! Map) {
      throw const FormatException('Invalid submit response.');
    }

    return Map<String, dynamic>.from(response.data as Map);
  }

}
