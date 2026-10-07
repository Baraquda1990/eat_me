// lib/services/seller_delivery_api.dart

import 'package:dio/dio.dart';

import 'api_service.dart';

class SellerDeliveryApi {
  SellerDeliveryApi._();

  static Dio get _dio => Dio(
    BaseOptions(
      baseUrl: ApiService.apiUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  static Future<Options> _authorizedOptions() async {
    final token = await ApiService.getValidAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    return Options(
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getActiveDeliveries() async {
    final response = await _dio.get(
      '/seller/deliveries/',
      options: await _authorizedOptions(),
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

  static Future<String> updateDeliveryStatus({
    required int itemId,
    required String status,
  }) async {
    final response = await _dio.patch(
      '/seller/deliveries/$itemId/status/',
      data: {
        'delivery_status': status,
      },
      options: await _authorizedOptions(),
    );

    if (response.data is Map) {
      return response.data['delivery_status']?.toString() ?? status;
    }

    return status;
  }
}
